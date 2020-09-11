export let memory;export async function fetchModule(t,e){const n=await fetch(t),s=await WebAssembly.instantiateStreaming(n,{asset:e,console:{console_debug(o,i){console.debug(readStringWithLength(o,i))},console_info(o,i){console.info(readStringWithLength(o,i))},console_log(o,i){console.log(readStringWithLength(o,i))},console_warn(o,i){console.warn(readStringWithLength(o,i))},console_error(o,i){console.error(readStringWithLength(o,i))}}}),c=s.instance.exports;return memory=c.memory,c}const u=new TextDecoder();export function readString(t){const e=new Uint8Array(memory.buffer,t),n=e.findIndex(s=>s==0);return u.decode(e.subarray(0,n))}export function readStringWithLength(t,e){const n=new Uint8Array(memory.buffer,t,e);return u.decode(n)}export function readUint32(t){const e=new Uint32Array(memory.buffer,t,1);return e[0]}export function readUint16(t){const e=new Uint16Array(memory.buffer,t,1);return e[0]}export function writeUint32(t,e){const n=new Uint32Array(memory.buffer,t,1);n[0]=e}export function writeUint16(t,e){const n=new Uint16Array(memory.buffer,t,1);n[0]=e}export function writeFloat(t,e){const n=new Float32Array(memory.buffer,t,1);n[0]=e}export function getUint8BufferFromSlice(t,e){return new Uint8Array(memory.buffer,t,e)}export function getFloat32BufferFromSlice(t,e){return new Float32Array(memory.buffer,t,e/4)}export function getUint32BufferFromSlice(t,e){return new Uint32Array(memory.buffer,t,e/4)}export function getUint16BufferFromSlice(t,e){return new Uint16Array(memory.buffer,t,e/2)}export function getDataViewFromSlice(t,e){return new DataView(memory.buffer,t,e)}export class KeyboardMapper{constructor(t){this._up=!1,this._down=!1,this._left=!1,this._right=!1,this.control=t}update(){let t=0,e=0;this._left&&(t-=1),this._right&&(t+=1),this._up&&(e+=1),this._down&&(e-=1);const n=(t**2+e**2)**.5;n==0?this.control.move=[0,0]:(t/=n,e/=n,this.control.move=[t,e])}set up(t){this._up=t,this.update()}set down(t){this._down=t,this.update()}set left(t){this._left=t,this.update()}set right(t){this._right=t,this.update()}}class r{constructor(t){this.addr=t}get view(){return getDataViewFromSlice(this.addr,22)}set move([t,e]){const n=this.view;n.setFloat32(r.MOVE_X,t,!0),n.setFloat32(r.MOVE_Y,e,!0)}set rotate([t,e]){const n=this.view;n.setFloat32(r.ROTATE_X,n.getFloat32(r.ROTATE_X,!0)+t,!0),n.setFloat32(r.ROTATE_Y,n.getFloat32(r.ROTATE_Y,!0)+e,!0)}set jump(t){this.view.setUint8(r.JUMP,t?1:0)}set sneak(t){this.view.setUint8(r.SNEAK,t?1:0)}set boost(t){this.view.setUint8(r.BOOST,t?1:0)}set use1(t){this.view.setUint8(r.USE1,t?1:0)}set use2(t){this.view.setUint8(r.USE2,t?1:0)}set use3(t){this.view.setUint8(r.USE3,t?1:0)}}r.MOVE_X=0,r.MOVE_Y=4,r.ROTATE_X=8,r.ROTATE_Y=12,r.JUMP=16,r.SNEAK=17,r.BOOST=18,r.USE1=19,r.USE2=20,r.USE3=21;export function getControlMapper(t){return new r(t)}export function readCameraInfo(t){const e=getFloat32BufferFromSlice(t,8*4),n=getUint32BufferFromSlice(t+8*4,4);return{pos:[e[0],e[1],e[2]],rot:[e[3],e[4]],highlight:[e[5],e[6],e[7]],selectedFace:n[0]}}export function readStdLayoutStruct(t,...e){let n={};const s=getUint32BufferFromSlice(t,4*e.length);for(const c in e){const o=e[c];n[o]=s[c]}return n}export function readMapInfo(t){const e=readStdLayoutStruct(t,"chunkWidth","chunkHeight","width","length"),n=8,s=12,c=e.chunkWidth*e.chunkWidth*e.chunkHeight*192*4,o=s+c,i=e.chunkWidth*e.chunkWidth*e.chunkHeight*6*6*4,a=o+o;return Object.assign({},e,{versionOffset:n,dataOffset:s,dataSize:c,indicesOffset:o,indicesSize:i,size:a})}export class ProxiedArray{constructor(t,e,n,s,c){this.addr=t,this.versionAddr=e,this.countAddr=n,this.maxCount=s,this.builder=c}get version(){return readUint32(this.versionAddr)}get count(){return readUint32(this.countAddr)}get data(){return this.builder(this.addr,this.maxCount)}proxy(t){const e=this;return Object.defineProperty(t,"array",{get(){return e.data}}),Object.defineProperty(t,"count",{get(){return e.count}}),Object.defineProperty(t,"length",{get(){return this.maxCount}}),Object.defineProperty(t,"version",{get(){return e.version}}),t}}export function readMap(t,e){return{data:new ProxiedArray(e+t.dataOffset,e+t.versionOffset,e,t.dataSize,getFloat32BufferFromSlice),indices:new ProxiedArray(e+t.indicesOffset,e+t.versionOffset,e+4,t.indicesSize,getUint32BufferFromSlice)}}
