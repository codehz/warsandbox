import { WebGLRenderer, WebGLRenderTarget, OrthographicCamera, PlaneBufferGeometry, Mesh, Material, Renderer } from "three";

export class FullScreenQuad {
    static camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);
    static geometry = new PlaneBufferGeometry(2, 2);
    private mesh: Mesh;

    constructor(mat: Material) {
        this.mesh = new Mesh(FullScreenQuad.geometry, mat);
    }

    get material() {
        return this.mesh.material;
    }
    set material(val: Material | Material[]) {
        this.mesh.material = val;
    }

    dispose() {
        this.mesh.geometry.dispose();
    }

    render(renderer: Renderer) {
        renderer.render(this.mesh, FullScreenQuad.camera);
    }
};

export class Pass {
    enabled = true;
    needsSwap = true;
    clear = false;
    renderToScreen = false;

    setSize(_width: number, _height: number): void { }
    render(_renderer: WebGLRenderer, _writeBuffer: WebGLRenderTarget, _readBuffer: WebGLRenderTarget, _deltaTime: number, _maskActive: boolean = false) { console.error('THREE.Pass: .render() must be implemented in derived pass.'); }
};