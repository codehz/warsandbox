import * as THREE from "three";
import * as utils from "./utils";

function waitForLoadingManager(mgr: THREE.LoadingManager) {
    return new Promise((resolve, reject) => {
        mgr.onLoad = resolve;
        mgr.onError = reject;
    });
}

export async function main(scene: THREE.Scene, camera: THREE.Camera, renderer: THREE.WebGLRenderer, adjust: () => void) {
    const loadingManager = new THREE.LoadingManager();
    const loader = new THREE.TextureLoader(loadingManager);
    const testtex = new THREE.MeshPhongMaterial({
        map: loader.load("/assets/test.png"),
        side: THREE.FrontSide,
    });
    testtex.map.minFilter = THREE.LinearMipmapLinearFilter;
    testtex.map.magFilter = THREE.NearestFilter;
    await waitForLoadingManager(loadingManager);

    const mod = await utils.fetchModule("/native/engine.wasm", {});
    mod.loadSampleMap();

    mod.initRegistry();
    mod.initPlayer();

    mod.tick();

    for (let i = 0; i < 16; i++) {
        for (let j = 0; j < 4; j++) {
            const addr = mod.generateGeomentryDataForChunk(i, j);
            const dataCount = utils.readUint32(addr);
            const dataOffset = utils.readUint32(addr + 4);
            const indicesCount = utils.readUint32(addr + 8);
            const indicesOffset = utils.readUint32(addr + 12);
            const buffer = utils.getFloat32BufferFromSlice(addr + dataOffset, dataCount * 4);
            const interleaveBuffer = new THREE.InterleavedBuffer(buffer, 8);
            const indexBuffer = utils.getUint32BufferFromSlice(addr + indicesOffset, indicesCount * 4);
            const test = new THREE.BufferGeometry();
            test.setIndex(new THREE.BufferAttribute(indexBuffer, 1));
            test.setAttribute("position", new THREE.InterleavedBufferAttribute(interleaveBuffer, 3, 0));
            test.setAttribute("normal", new THREE.InterleavedBufferAttribute(interleaveBuffer, 3, 3));
            test.setAttribute("uv", new THREE.InterleavedBufferAttribute(interleaveBuffer, 2, 6));
            test.boundingBox = new THREE.Box3(new THREE.Vector3(0, 0, 0), new THREE.Vector3(16, 16, 32));
            test.boundingSphere = new THREE.Sphere(new THREE.Vector3(8, 8, 16), Math.sqrt(8 ** 2 + 8 ** 2 + 16 ** 2));
            const tmesh = new THREE.Mesh(test, testtex);
            tmesh.position.add(new THREE.Vector3(j * 16, i * 16, 0));
            scene.add(tmesh);
        }
    }

    setInterval(() => mod.tick(), 50);

    renderer.setAnimationLoop(() => {
        const info = utils.readCameraInfo(mod.cameraInfo);
        camera.position.set(...info.pos);
        let pitch = info.rot[1];
        let yaw = info.rot[0];
        camera.rotation.set(Math.PI / 2 + pitch, 0, yaw, 'YZX');
        camera.matrixWorldNeedsUpdate = true;
        adjust();
        renderer.render(scene, camera);
    });

    // adjust();
    // renderer.render(scene, camera);
}