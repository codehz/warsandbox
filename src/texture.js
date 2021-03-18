import * as THREE from "../_snowpack/pkg/three.js";
export class VoxelTextureManager {
  constructor(base, size) {
    this.count = 0;
    this.base = base;
    this.size = size;
    this.canvas = new OffscreenCanvas(size * base, size * base);
    this.ctx = this.canvas.getContext("2d");
    this.ctx.fillStyle = "#0000FF";
    this.ctx.fillRect(0, 0, size * base, size * base);
  }
  async add(url) {
    const id = this.count++;
    const image = new Image(this.size, this.size);
    await new Promise((resolve, reject) => {
      image.src = url;
      image.onload = resolve;
      image.onerror = reject;
    });
    this.ctx.drawImage(image, id % this.base * this.size, (id / this.base | 0) * this.size, this.size, this.size);
    return id;
  }
  getTexture() {
    console.log(this.canvas);
    return new THREE.CanvasTexture(this.canvas);
  }
}
