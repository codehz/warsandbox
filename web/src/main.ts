import * as THREE from "three";
import * as utils from "./utils";
import * as kbd from "./keyboardmanager";

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

    console.time("init");

    const mod = await utils.fetchModule("/native/engine.wasm", {});
    const mapInfo = utils.readMapInfo(mod.mapInfo);
    console.log(mapInfo);
    console.timeLog("init", "fetch");
    mod.loadSampleMap();
    console.timeLog("init", "load map");

    mod.initEngine();
    console.timeLog("init", "init engine");
    mod.initPlayer();
    console.timeLog("init", "init player");

    // mod.tick();
    console.timeEnd("init");

    const chunkBoundingBox = new THREE.Box3(new THREE.Vector3(0, 0, 0), new THREE.Vector3(mapInfo.chunkWidth, mapInfo.chunkWidth, mapInfo.chunkHeight));
    const chunkBoundingSphere = new THREE.Sphere(new THREE.Vector3((mapInfo.chunkWidth / 2), (mapInfo.chunkWidth / 2), (mapInfo.chunkHeight / 2)), Math.sqrt((mapInfo.chunkWidth / 2) ** 2 + (mapInfo.chunkWidth / 2) ** 2 + (mapInfo.chunkHeight / 2) ** 2));

    console.time("geo");
    for (let i = 0; i < mapInfo.width; i++) {
        for (let j = 0; j < mapInfo.length; j++) {
            const addr = mod.generateGeomentryDataForChunk(i, j);
            const exported = utils.readExported(mapInfo, addr);
            const interleaveBuffer = exported.data.proxy(new THREE.InterleavedBuffer(exported.data.data, 8));
            const test = new THREE.BufferGeometry();
            const indexBuffer = exported.indices.proxy(new THREE.BufferAttribute(exported.indices.data, 1));
            test.setIndex(indexBuffer);
            test.setAttribute("position", new THREE.InterleavedBufferAttribute(interleaveBuffer, 3, 0));
            test.setAttribute("normal", new THREE.InterleavedBufferAttribute(interleaveBuffer, 3, 3));
            test.setAttribute("uv", new THREE.InterleavedBufferAttribute(interleaveBuffer, 2, 6));
            test.boundingBox = chunkBoundingBox;
            test.boundingSphere = chunkBoundingSphere;
            const tmesh = new THREE.Mesh(test, testtex);
            tmesh.position.add(new THREE.Vector3(i * mapInfo.chunkWidth, j * mapInfo.chunkWidth, 0));
            scene.add(tmesh);
        }
    }
    console.timeEnd("geo");

    setInterval(() => {
        mod.tick()
        ftime = +new Date();
    }, 50);
    mod.tick();
    let ftime = +new Date();

    renderer.setAnimationLoop(() => {
        const delta = (+new Date() - ftime) / 50;
        if (delta > 0.1)
            mod.microtick(delta);
        const info = utils.readCameraInfo(mod.cameraInfo);
        camera.position.set(info.pos[0], info.pos[1], info.pos[2] + 1.7);
        const pitch = info.rot[1] - Math.PI / 2;
        const yaw = info.rot[0];
        camera.rotation.set(Math.PI / 2 + pitch, 0, yaw, 'YZX');
        camera.matrixWorldNeedsUpdate = true;
        adjust();
        renderer.render(scene, camera);
    });

    const mgr = utils.getKeyboardMapper(mod.keyboard);

    kbd.detect([87, 38], o => mgr.up = o);
    kbd.detect([83, 40], o => mgr.down = o);
    kbd.detect([65, 37], o => mgr.left = o);
    kbd.detect([68, 39], o => mgr.right = o);
    kbd.detect([32], o => mgr.space = o);
}

