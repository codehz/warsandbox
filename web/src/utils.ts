export let memory: WebAssembly.Memory;

export async function fetchModule<T extends Record<string, any>>(target: string, asset: T) {
    const resp = await fetch(target);
    const module = await WebAssembly.instantiateStreaming(resp, {
        asset, console: {
            console_debug(stradd: number, strlen: number) {
                console.debug(readStringWithLength(stradd, strlen));
            },
            console_info(stradd: number, strlen: number) {
                console.info(readStringWithLength(stradd, strlen));
            },
            console_log(stradd: number, strlen: number) {
                console.log(readStringWithLength(stradd, strlen));
            },
            console_warn(stradd: number, strlen: number) {
                console.warn(readStringWithLength(stradd, strlen));
            },
            console_error(stradd: number, strlen: number) {
                console.error(readStringWithLength(stradd, strlen));
            }
        },
    });
    const ret = module.instance.exports as unknown as WasmExport;
    memory = ret.memory;
    return ret;
}

const decoder = new TextDecoder();

export function readString(address: number) {
    const bytes = new Uint8Array(memory.buffer, address);
    const len = bytes.findIndex(x => x == 0);
    return decoder.decode(bytes.subarray(0, len));
}
export function readStringWithLength(addr: number, len: number) {
    const bytes = new Uint8Array(memory.buffer, addr, len);
    return decoder.decode(bytes);
}
export function readUint32(address: number) {
    const bytes = new Uint32Array(memory.buffer, address, 1);
    return bytes[0];
}
export function writeUint32(address: number, data: number) {
    const bytes = new Uint32Array(memory.buffer, address, 1);
    bytes[0] = data;
}
export function writeFloat(address: number, data: number) {
    const bytes = new Float32Array(memory.buffer, address, 1);
    bytes[0] = data;
}
export function getUint8BufferFromSlice(addr: number, len: number) {
    return new Uint8Array(memory.buffer, addr, len);
}
export function getFloat32BufferFromSlice(addr: number, len: number) {
    return new Float32Array(memory.buffer, addr, len / 4);
}
export function getUint32BufferFromSlice(addr: number, len: number) {
    return new Uint32Array(memory.buffer, addr, len / 4);
}

export function readCameraInfo(addr: number): {
    pos: [number, number, number],
    rot: [number, number]
} {
    const arr = getFloat32BufferFromSlice(addr, 5 * 4);
    return {
        pos: [arr[0], arr[1], arr[2]],
        rot: [arr[3], arr[4]]
    };
}

type StdLayoutStruct<T extends string[]> = Record<T[number], number>;

export function readStdLayoutStruct<T extends string[]>(addr: number, ...fields: T): StdLayoutStruct<T> {
    let ret = {} as StdLayoutStruct<T>;
    const buffer = getUint32BufferFromSlice(addr, 4 * fields.length);
    for (const idx in fields) {
        const key = fields[idx];
        ret[key] = buffer[idx];
    }
    return ret;
}

export interface MapInfo {
    chunkWidth: number,
    chunkHeight: number,
    width: number,
    length: number,
    dataOffset: number,
    dataSize: number,
    indicesOffset: number,
    indicesSize: number,
    size: number,
};

export function readMapInfo(addr: number): MapInfo {
    const basic = readStdLayoutStruct(addr, "chunkWidth", "chunkHeight", "width", "length");
    const dataOffset = 8;
    const dataSize = basic.chunkWidth * basic.chunkWidth * basic.chunkHeight * 192 * 4;
    const indicesOffset = dataOffset + dataSize;
    const indicesSize = basic.chunkWidth * basic.chunkWidth * basic.chunkHeight * 6 * 6 * 4;
    const size = indicesOffset + indicesOffset;
    return Object.assign({}, basic, {
        dataOffset,
        dataSize,
        indicesOffset,
        indicesSize,
        size
    });
}

export class ProxiedArray<T extends ArrayLike<number>> {
    private addr: number;
    private countAddr: number;
    private base: number;
    private builder: (addr: number, len: number) => T;

    constructor(addr: number, countAddr: number, base: number, builder: (addr: number, len: number) => T) {
        this.addr = addr;
        this.countAddr = countAddr;
        this.base = base;
        this.builder = builder;
    }

    get data() {
        const len = readUint32(this.countAddr);
        return this.builder(this.addr, len * this.base);
    }

    proxy<R extends { array: ArrayLike<number> }>(target: R): R {
        const self = this;
        Object.defineProperty(target, "array", {
            get() {
                return self.data;
            }
        });
        return target;
    }
};

export function readExported(info: MapInfo, addr: number) {
    return {
        data: new ProxiedArray(addr + info.dataOffset, addr, 4, getFloat32BufferFromSlice),
        indices: new ProxiedArray(addr + info.indicesOffset, addr + 4, 4, getUint32BufferFromSlice),
    };
}