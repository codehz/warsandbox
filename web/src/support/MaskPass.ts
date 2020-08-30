import { Camera, Scene, WebGLRenderer, WebGLRenderTarget } from "three";
import { Pass } from "./Pass.js";

export class MaskPass extends Pass {
    scene: Scene;
    camera: Camera;
    inverse: boolean = false;

    constructor(scene: Scene, camera: Camera) {
        super();
        this.scene = scene;
        this.camera = camera;
        this.clear = true;
        this.needsSwap = true;
    }

    render(renderer: WebGLRenderer, writeBuffer: WebGLRenderTarget, readBuffer: WebGLRenderTarget, _deltaTime: number, _maskActive: boolean) {
        const context = renderer.getContext();
        const state = renderer.state;

        state.buffers.color.setMask(false);
        state.buffers.depth.setMask(false);

        state.buffers.color.setLocked(true);
        state.buffers.depth.setLocked(true);

        const writeValue = this.inverse ? 0 : 1;
        const clearValue = this.inverse ? 1 : 0;

        state.buffers.stencil.setTest(true);
        state.buffers.stencil.setOp(context.REPLACE, context.REPLACE, context.REPLACE);
        state.buffers.stencil.setFunc(context.ALWAYS, writeValue, 0xffffffff);
        state.buffers.stencil.setClear(clearValue);
        state.buffers.stencil.setLocked(true);

        renderer.setRenderTarget(readBuffer);
        if (this.clear) renderer.clear();
        renderer.render(this.scene, this.camera);

        renderer.setRenderTarget(writeBuffer);
        if (this.clear) renderer.clear();
        renderer.render(this.scene, this.camera);

        state.buffers.color.setLocked(false);
        state.buffers.depth.setLocked(false);

        state.buffers.stencil.setLocked(false);
        state.buffers.stencil.setFunc(context.EQUAL, 1, 0xffffffff); // draw if == 1
        state.buffers.stencil.setOp(context.KEEP, context.KEEP, context.KEEP);
        state.buffers.stencil.setLocked(true);
    }
};

export class ClearMaskPass extends Pass {
    constructor() {
        super();
        this.needsSwap = false;
    }

    render(renderer: WebGLRenderer, _writeBuffer: WebGLRenderTarget, _readBuffer: WebGLRenderTarget, _deltaTime: number, _maskActive: boolean = false) {
        renderer.state.buffers.stencil.setLocked(false);
        renderer.state.buffers.stencil.setTest(false);
    }
}