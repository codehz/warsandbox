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
export function getDataViewFromSlice(addr: number, len: number) {
    return new DataView(memory.buffer, addr, len);
}

export class KeyboardMapper {
    private control: ControlMapper;
    private _up: boolean = false;
    private _down: boolean = false;
    private _left: boolean = false;
    private _right: boolean = false;

    constructor(control: ControlMapper) {
        this.control = control;
    }

    private update() {
        let x = 0;
        let y = 0;
        if (this._left) x -= 1;
        if (this._right) x += 1;
        if (this._up) y += 1;
        if (this._down) y -= 1;
        const n = (x ** 2 + y ** 2) ** 0.5;
        if (n == 0) {
            this.control.move = [0, 0];
        } else {
            x /= n;
            y /= n;
            this.control.move = [x, y];
        }
    }

    set up(s: boolean) {
        this._up = s;
        this.update();
    }
    set down(s: boolean) {
        this._down = s;
        this.update();
    }
    set left(s: boolean) {
        this._left = s;
        this.update();
    }
    set right(s: boolean) {
        this._right = s;
        this.update();
    }
};

class ControlMapper {
    addr: number;
    static MOVE_X = 0;
    static MOVE_Y = 4;
    static ROTATE_X = 8;
    static ROTATE_Y = 12;
    static JUMP = 16;
    static SNEAK = 17;
    static BOOST = 18;
    static USE1 = 19;
    static USE2 = 20;
    static USE3 = 21;

    constructor(addr: number) {
        this.addr = addr;
    }

    get view() { return getDataViewFromSlice(this.addr, 22); }

    set move([x, y]: [number, number]) {
        const view = this.view;
        view.setFloat32(ControlMapper.MOVE_X, x, true);
        view.setFloat32(ControlMapper.MOVE_Y, y, true);
    }

    set rotate([x, y]: [number, number]) {
        const view = this.view;
        view.setFloat32(ControlMapper.ROTATE_X, view.getFloat32(ControlMapper.ROTATE_X, true) + x, true);
        view.setFloat32(ControlMapper.ROTATE_Y, view.getFloat32(ControlMapper.ROTATE_Y, true) + y, true);
    }

    set jump(val: boolean) { this.view.setUint8(ControlMapper.JUMP, val ? 1 : 0); }
    set sneak(val: boolean) { this.view.setUint8(ControlMapper.SNEAK, val ? 1 : 0); }
    set boost(val: boolean) { this.view.setUint8(ControlMapper.BOOST, val ? 1 : 0); }
    set use1(val: boolean) { this.view.setUint8(ControlMapper.USE1, val ? 1 : 0); }
    set use2(val: boolean) { this.view.setUint8(ControlMapper.USE2, val ? 1 : 0); }
    set use3(val: boolean) { this.view.setUint8(ControlMapper.USE3, val ? 1 : 0); }
}
export function getControlMapper(addr: number) {
    return new ControlMapper(addr);
}
export function readCameraInfo(addr: number): {
    pos: [number, number, number],
    rot: [number, number],
    highlight: [number, number, number],
    selectedFace: number
} {
    const arr = getFloat32BufferFromSlice(addr, 8 * 4);
    const iarr = getUint32BufferFromSlice(addr + 8 * 4, 4);
    return {
        pos: [arr[0], arr[1], arr[2]],
        rot: [arr[3], arr[4]],
        highlight: [arr[5], arr[6], arr[7]],
        selectedFace: iarr[0],
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
    dirtymap(): number[],
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
        size,
        dirtymap() {
            const data = getUint8BufferFromSlice(addr + 4 * 4, basic.width * basic.length);
            const ret = []
            for (let i = 0; i < data.length; i++) {
                if (data[i] != 0) {
                    ret.push(i);
                    data[i] = 0;
                }
            }
            return ret;
        }
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

export function readMap(info: MapInfo, addr: number) {
    return {
        data: new ProxiedArray(addr + info.dataOffset, addr, 4, getFloat32BufferFromSlice),
        indices: new ProxiedArray(addr + info.indicesOffset, addr + 4, 4, getUint32BufferFromSlice),
    };
}