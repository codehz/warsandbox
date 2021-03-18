export let memory;
export async function fetchModule(target, asset) {
  const resp = await fetch(target);
  const module = await WebAssembly.instantiateStreaming(resp, {
    asset,
    console: {
      console_debug(stradd, strlen) {
        console.debug(readStringWithLength(stradd, strlen));
      },
      console_info(stradd, strlen) {
        console.info(readStringWithLength(stradd, strlen));
      },
      console_log(stradd, strlen) {
        console.log(readStringWithLength(stradd, strlen));
      },
      console_warn(stradd, strlen) {
        console.warn(readStringWithLength(stradd, strlen));
      },
      console_error(stradd, strlen) {
        console.error(readStringWithLength(stradd, strlen));
      }
    }
  });
  const ret = module.instance.exports;
  memory = ret.memory;
  return ret;
}
const decoder = new TextDecoder();
export function readString(address) {
  const bytes = new Uint8Array(memory.buffer, address);
  const len = bytes.findIndex((x) => x == 0);
  return decoder.decode(bytes.subarray(0, len));
}
export function readStringWithLength(addr, len) {
  const bytes = new Uint8Array(memory.buffer, addr, len);
  return decoder.decode(bytes);
}
export function readUint32(address) {
  const bytes = new Uint32Array(memory.buffer, address, 1);
  return bytes[0];
}
export function readUint16(address) {
  const bytes = new Uint16Array(memory.buffer, address, 1);
  return bytes[0];
}
export function writeUint32(address, data) {
  const bytes = new Uint32Array(memory.buffer, address, 1);
  bytes[0] = data;
}
export function writeUint16(address, data) {
  const bytes = new Uint16Array(memory.buffer, address, 1);
  bytes[0] = data;
}
export function writeFloat(address, data) {
  const bytes = new Float32Array(memory.buffer, address, 1);
  bytes[0] = data;
}
export function getUint8BufferFromSlice(addr, len) {
  return new Uint8Array(memory.buffer, addr, len);
}
export function getFloat32BufferFromSlice(addr, len) {
  return new Float32Array(memory.buffer, addr, len / 4);
}
export function getUint32BufferFromSlice(addr, len) {
  return new Uint32Array(memory.buffer, addr, len / 4);
}
export function getUint16BufferFromSlice(addr, len) {
  return new Uint16Array(memory.buffer, addr, len / 2);
}
export function getDataViewFromSlice(addr, len) {
  return new DataView(memory.buffer, addr, len);
}
export class KeyboardMapper {
  constructor(control) {
    this._up = false;
    this._down = false;
    this._left = false;
    this._right = false;
    this.control = control;
  }
  update() {
    let x = 0;
    let y = 0;
    if (this._left)
      x -= 1;
    if (this._right)
      x += 1;
    if (this._up)
      y += 1;
    if (this._down)
      y -= 1;
    const n = (x ** 2 + y ** 2) ** 0.5;
    if (n == 0) {
      this.control.move = [0, 0];
    } else {
      x /= n;
      y /= n;
      this.control.move = [x, y];
    }
  }
  set up(s) {
    this._up = s;
    this.update();
  }
  set down(s) {
    this._down = s;
    this.update();
  }
  set left(s) {
    this._left = s;
    this.update();
  }
  set right(s) {
    this._right = s;
    this.update();
  }
}
;
const _ControlMapper = class {
  constructor(addr) {
    this.addr = addr;
  }
  get view() {
    return getDataViewFromSlice(this.addr, 23);
  }
  set move([x, y]) {
    const view = this.view;
    view.setFloat32(_ControlMapper.MOVE_X, x, true);
    view.setFloat32(_ControlMapper.MOVE_Y, y, true);
  }
  set rotate([x, y]) {
    const view = this.view;
    view.setFloat32(_ControlMapper.ROTATE_X, view.getFloat32(_ControlMapper.ROTATE_X, true) + x, true);
    view.setFloat32(_ControlMapper.ROTATE_Y, view.getFloat32(_ControlMapper.ROTATE_Y, true) + y, true);
  }
  set jump(val) {
    this.view.setUint8(_ControlMapper.JUMP, val ? 1 : 0);
  }
  set sneak(val) {
    this.view.setUint8(_ControlMapper.SNEAK, val ? 1 : 0);
  }
  set boost(val) {
    this.view.setUint8(_ControlMapper.BOOST, val ? 1 : 0);
  }
  set use1(val) {
    this.view.setUint8(_ControlMapper.USE1, val ? 1 : 0);
  }
  set use2(val) {
    this.view.setUint8(_ControlMapper.USE2, val ? 1 : 0);
  }
  set use3(val) {
    this.view.setUint8(_ControlMapper.USE3, val ? 1 : 0);
  }
  set selectedSlot(val) {
    this.view.setUint8(_ControlMapper.SELECTED_SLOT, val);
  }
};
let ControlMapper = _ControlMapper;
ControlMapper.MOVE_X = 0;
ControlMapper.MOVE_Y = 4;
ControlMapper.ROTATE_X = 8;
ControlMapper.ROTATE_Y = 12;
ControlMapper.JUMP = 16;
ControlMapper.SNEAK = 17;
ControlMapper.BOOST = 18;
ControlMapper.USE1 = 19;
ControlMapper.USE2 = 20;
ControlMapper.USE3 = 21;
ControlMapper.SELECTED_SLOT = 22;
export function getControlMapper(addr) {
  return new ControlMapper(addr);
}
export function readCameraInfo(addr) {
  const arr = getFloat32BufferFromSlice(addr, 8 * 4);
  const iarr = getUint32BufferFromSlice(addr + 8 * 4, 4);
  return {
    pos: [arr[0], arr[1], arr[2]],
    rot: [arr[3], arr[4]],
    highlight: [arr[5], arr[6], arr[7]],
    selectedFace: iarr[0]
  };
}
export function readStdLayoutStruct(addr, ...fields) {
  let ret = {};
  const buffer = getUint32BufferFromSlice(addr, 4 * fields.length);
  for (const idx in fields) {
    const key = fields[idx];
    ret[key] = buffer[idx];
  }
  return ret;
}
;
export function readMapInfo(addr) {
  const basic = readStdLayoutStruct(addr, "chunkWidth", "chunkHeight", "width", "length");
  const versionOffset = 8;
  const dataOffset = 12;
  const dataSize = basic.chunkWidth * basic.chunkWidth * basic.chunkHeight * 192 * 4;
  const indicesOffset = dataOffset + dataSize;
  const indicesSize = basic.chunkWidth * basic.chunkWidth * basic.chunkHeight * 6 * 6 * 4;
  const size = indicesOffset + indicesOffset;
  return Object.assign({}, basic, {
    versionOffset,
    dataOffset,
    dataSize,
    indicesOffset,
    indicesSize,
    size
  });
}
export function readParticleInfo(addr) {
  return new ProxiedArray(addr + 4, addr, 0, 256 * 7 * 4, getFloat32BufferFromSlice);
}
export class ProxiedArray {
  constructor(addr, versionAddr, countAddr, maxCount, builder) {
    this.addr = addr;
    this.versionAddr = versionAddr;
    this.countAddr = countAddr;
    this.maxCount = maxCount;
    this.builder = builder;
  }
  get version() {
    return readUint32(this.versionAddr);
  }
  get count() {
    return this.countAddr == 0 ? this.maxCount : readUint32(this.countAddr);
  }
  get data() {
    return this.builder(this.addr, this.maxCount);
  }
  proxy(target) {
    const self = this;
    Object.defineProperty(target, "array", {
      get() {
        return self.data;
      }
    });
    Object.defineProperty(target, "count", {
      get() {
        return self.count;
      }
    });
    Object.defineProperty(target, "length", {
      get() {
        return this.maxCount;
      }
    });
    Object.defineProperty(target, "version", {
      get() {
        return self.version;
      }
    });
    return target;
  }
}
;
export function readMap(info, addr) {
  return {
    data: new ProxiedArray(addr + info.dataOffset, addr + info.versionOffset, addr, info.dataSize, getFloat32BufferFromSlice),
    indices: new ProxiedArray(addr + info.indicesOffset, addr + info.versionOffset, addr + 4, info.indicesSize, getUint32BufferFromSlice)
  };
}
