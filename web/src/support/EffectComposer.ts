import { WebGLRenderer, WebGLRenderTarget, Clock, LinearFilter, RGBAFormat, Vector2 } from "three";
import { Pass } from "./Pass.js";
import { ShaderPass } from "./ShaderPass.js";
import { CopyShader } from "./CopyShader.js";
import { MaskPass, ClearMaskPass } from "./MaskPass.js";

export class EffectComposer {
    renderer: WebGLRenderer;
    renderTarget1: WebGLRenderTarget;
    renderTarget2: WebGLRenderTarget;
    writeBuffer: WebGLRenderTarget;
    readBuffer: WebGLRenderTarget;
    passes: Pass[] = [];
    copyPass: ShaderPass;
    clock: Clock;
    renderToScreen: boolean;

    private pixelRatio: number;
    private width: number;
    private height: number;

    constructor(renderer: WebGLRenderer, renderTarget?: WebGLRenderTarget) {
        this.renderer = renderer;

        if (renderTarget === undefined) {
            var parameters = {
                minFilter: LinearFilter,
                magFilter: LinearFilter,
                format: RGBAFormat
            };

            var size = renderer.getSize(new Vector2());
            this.pixelRatio = renderer.getPixelRatio();
            this.width = size.width;
            this.height = size.height;

            renderTarget = new WebGLRenderTarget(this.width * this.pixelRatio, this.height * this.pixelRatio, parameters);
            renderTarget.texture.name = 'EffectComposer.rt1';
        } else {
            this.pixelRatio = 1;
            this.width = renderTarget.width;
            this.height = renderTarget.height;
        }

        this.renderTarget1 = renderTarget;
        this.renderTarget2 = renderTarget.clone();
        this.renderTarget2.texture.name = 'EffectComposer.rt2';

        this.writeBuffer = this.renderTarget1;
        this.readBuffer = this.renderTarget2;

        this.renderToScreen = true;

        this.copyPass = new ShaderPass(CopyShader);

        this.clock = new Clock();
    }
    swapBuffers(): void {
        var tmp = this.readBuffer;
        this.readBuffer = this.writeBuffer;
        this.writeBuffer = tmp;
    }
    addPass(pass: Pass): void {
        this.passes.push(pass);
        pass.setSize(this.width * this.pixelRatio, this.height * this.pixelRatio);
    }
    insertPass(pass: Pass, index: number): void {
        this.passes.splice(index, 0, pass);
        pass.setSize(this.width * this.pixelRatio, this.height * this.pixelRatio);
    }
    isLastEnabledPass(passIndex: number): boolean {
        for (var i = passIndex + 1; i < this.passes.length; i++) {
            if (this.passes[i].enabled) {
                return false;
            }
        }
        return true;
    }
    render(deltaTime?: number): void {
        if (deltaTime === undefined) {
            deltaTime = this.clock.getDelta();
        }
        var currentRenderTarget = this.renderer.getRenderTarget();
        var maskActive = false;
        var pass, i, il = this.passes.length;
        for (i = 0; i < il; i++) {
            pass = this.passes[i];
            if (pass.enabled === false) continue;
            pass.renderToScreen = (this.renderToScreen && this.isLastEnabledPass(i));
            pass.render(this.renderer, this.writeBuffer, this.readBuffer, deltaTime, maskActive);
            if (pass.needsSwap) {
                if (maskActive) {
                    var context = this.renderer.getContext();
                    var stencil = this.renderer.state.buffers.stencil;
                    //context.stencilFunc( context.NOTEQUAL, 1, 0xffffffff );
                    stencil.setFunc(context.NOTEQUAL, 1, 0xffffffff);
                    this.copyPass.render(this.renderer, this.writeBuffer, this.readBuffer, deltaTime);
                    //context.stencilFunc( context.EQUAL, 1, 0xffffffff );
                    stencil.setFunc(context.EQUAL, 1, 0xffffffff);
                }
                this.swapBuffers();
            }

            if (MaskPass !== undefined) {
                if (pass instanceof MaskPass) {
                    maskActive = true;
                } else if (pass instanceof ClearMaskPass) {
                    maskActive = false;
                }
            }

        }

        this.renderer.setRenderTarget(currentRenderTarget);
    }
    reset(renderTarget?: WebGLRenderTarget): void {
        if (renderTarget === undefined) {
            var size = this.renderer.getSize(new Vector2());
            this.pixelRatio = this.renderer.getPixelRatio();
            this.width = size.width;
            this.height = size.height;

            renderTarget = this.renderTarget1.clone();
            renderTarget.setSize(this.width * this.pixelRatio, this.height * this.pixelRatio);
        }

        this.renderTarget1.dispose();
        this.renderTarget2.dispose();
        this.renderTarget1 = renderTarget;
        this.renderTarget2 = renderTarget.clone();

        this.writeBuffer = this.renderTarget1;
        this.readBuffer = this.renderTarget2;
    }
    setSize(width: number, height: number): void {
        this.width = width;
        this.height = height;

        var effectiveWidth = this.width * this.pixelRatio;
        var effectiveHeight = this.height * this.pixelRatio;

        this.renderTarget1.setSize(effectiveWidth, effectiveHeight);
        this.renderTarget2.setSize(effectiveWidth, effectiveHeight);

        this.passes.forEach(x => x.setSize(effectiveWidth, effectiveHeight));
    }
    setPixelRatio(pixelRatio: number): void {
        this.pixelRatio = pixelRatio;
        this.setSize(this.width, this.height);
    }
}