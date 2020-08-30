import { Pass, FullScreenQuad } from "./Pass.js";
import { ShaderMaterial, UniformsUtils, IUniform, WebGLRenderer, WebGLRenderTarget } from "three";

interface ShaderDefinition {
    defines?: { [key: string]: any };
    uniforms: { [uniform: string]: IUniform };
    vertexShader: string;
    fragmentShader: string;
};

export class ShaderPass extends Pass {
    textureID: string;
    uniforms: { [uniform: string]: IUniform };
    material: ShaderMaterial;
    fsQuad: FullScreenQuad;

    constructor(shader: ShaderDefinition, textureID: string = "tDiffuse") {
        super();
        this.textureID = textureID;

        if (shader instanceof ShaderMaterial) {
            this.uniforms = shader.uniforms;
            this.material = shader;
        } else if (shader) {
            this.uniforms = UniformsUtils.clone(shader.uniforms);
            this.material = new ShaderMaterial({
                defines: Object.assign({}, shader.defines),
                uniforms: this.uniforms,
                vertexShader: shader.vertexShader,
                fragmentShader: shader.fragmentShader
            });
        }

        this.fsQuad = new FullScreenQuad(this.material);
    }

    render(renderer: WebGLRenderer, writeBuffer: WebGLRenderTarget, readBuffer: WebGLRenderTarget, _deltaTime: number, _maskActive?: boolean) {
        if (this.uniforms[this.textureID]) {
            this.uniforms[this.textureID].value = readBuffer.texture;
        }
        this.fsQuad.material = this.material;
        if (this.renderToScreen) {
            renderer.setRenderTarget(null);
            this.fsQuad.render(renderer);
        } else {
            renderer.setRenderTarget(writeBuffer);
            // TODO: Avoid using autoClear properties, see https://github.com/mrdoob/three.js/pull/15571#issuecomment-465669600
            if (this.clear) renderer.clear(renderer.autoClearColor, renderer.autoClearDepth, renderer.autoClearStencil);
            this.fsQuad.render(renderer);
        }
    }
}