import {OrthographicCamera, PlaneBufferGeometry, Mesh} from "../../web_modules/three.js";
export class FullScreenQuad {
  constructor(mat) {
    this.mesh = new Mesh(FullScreenQuad.geometry, mat);
  }
  get material() {
    return this.mesh.material;
  }
  set material(val) {
    this.mesh.material = val;
  }
  dispose() {
    this.mesh.geometry.dispose();
  }
  render(renderer) {
    renderer.render(this.mesh, FullScreenQuad.camera);
  }
}
FullScreenQuad.camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);
FullScreenQuad.geometry = new PlaneBufferGeometry(2, 2);
;
export class Pass {
  constructor() {
    this.enabled = true;
    this.needsSwap = true;
    this.clear = false;
    this.renderToScreen = false;
  }
  setSize(_width, _height) {
  }
  render(_renderer, _writeBuffer, _readBuffer, _deltaTime, _maskActive = false) {
    console.error("THREE.Pass: .render() must be implemented in derived pass.");
  }
}
;
