import { Pass } from "./Pass.js";
import { Scene, Camera, Material, Color, WebGLRenderer, WebGLRenderTarget } from "three";

export class RenderPass extends Pass {
    scene: Scene;
    camera: Camera;
    overrideMaterial?: Material;
    clearColor?: Color;
    clearAlpha: number;
    clearDepth: boolean;
    _oldClearColor: Color = new Color();

    constructor(scene: Scene, camera: Camera, overrideMaterial?: Material, clearColor?: Color, clearAlpha: number = 0) {
        super();
        this.scene = scene;
        this.camera = camera;
        this.overrideMaterial = overrideMaterial;
        this.clearColor = clearColor;
        this.clearAlpha = clearAlpha;

        this.clear = true;
        this.clearDepth = false;
        this.needsSwap = false;
    }

    render(renderer: WebGLRenderer, _writeBuffer: WebGLRenderTarget, readBuffer: WebGLRenderTarget, _deltaTime: number, _maskActive: boolean = false) {
        const oldAutoClear = renderer.autoClear;
        renderer.autoClear = false;

        let oldClearAlpha: number, oldOverrideMaterial: Material;
        if (this.overrideMaterial !== undefined) {
            oldOverrideMaterial = this.scene.overrideMaterial;
            this.scene.overrideMaterial = this.overrideMaterial;
        }

        if (this.clearColor) {
            renderer.getClearColor(this._oldClearColor);
            oldClearAlpha = renderer.getClearAlpha();
            renderer.setClearColor(this.clearColor, this.clearAlpha);
        }

        if (this.clearDepth) {
            renderer.clearDepth();
        }

        renderer.setRenderTarget(this.renderToScreen ? null : readBuffer);

        // TODO: Avoid using autoClear properties, see https://github.com/mrdoob/three.js/pull/15571#issuecomment-465669600
        if (this.clear) renderer.clear(renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil);
        renderer.render(this.scene, this.camera);

        if (this.clearColor) {
            renderer.setClearColor(this._oldClearColor, oldClearAlpha);
        }

        if (this.overrideMaterial !== undefined) {
            this.scene.overrideMaterial = oldOverrideMaterial;
        }

        renderer.autoClear = oldAutoClear;
    }
}