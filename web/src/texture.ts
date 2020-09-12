import * as THREE from "three";

export class VoxelTextureManager {
  base: number;
  size: number;
  canvas: OffscreenCanvas;
  ctx: OffscreenCanvasRenderingContext2D;
  count: number = 0;

  constructor(base: number, size: number) {
    this.base = base;
    this.size = size;
    this.canvas = new OffscreenCanvas(size * base, size * base);
    this.ctx = this.canvas.getContext("2d");
    this.ctx.fillStyle = "#0000FF";
    this.ctx.fillRect(0, 0, size * base, size * base);
  }

  async add(url: string) {
    const id = this.count++;
    const image = new Image(this.size, this.size);
    await new Promise((resolve, reject) => {
      image.src = url;
      image.onload = resolve;
      image.onerror = reject;
    });
    this.ctx.drawImage(
      image,
      (id % this.base) * this.size,
      ((id / this.base) | 0) * this.size,
      this.size,
      this.size,
    );
    return id;
  }

  getTexture() {
    console.log(this.canvas)
    return new THREE.CanvasTexture(this.canvas as any as HTMLCanvasElement);
  }
}