import * as THREE from "three";
import * as utils from "./utils";
import * as input from "./inputmanager";

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
            const exported = utils.readMap(mapInfo, addr);
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
            tmesh.castShadow = true;
            tmesh.receiveShadow = true;
            tmesh.position.add(new THREE.Vector3(i * mapInfo.chunkWidth, j * mapInfo.chunkWidth, 0));
            scene.add(tmesh);
            var box = new THREE.BoxHelper(tmesh, 0xffff00);
            scene.add(box);
        }
    }
    console.timeEnd("geo");

    let paused = true;

    setInterval(() => {
        if (paused) return;
        mod.tick()
        ftime = +new Date();
    }, 50);
    mod.tick();
    let ftime = +new Date();

    renderer.setAnimationLoop(() => {
        if (paused) return;
        const delta = (+new Date() - ftime) / 50;
        if (delta > 0.1 && delta < 1)
            mod.microtick(delta);
        const info = utils.readCameraInfo(mod.cameraInfo);
        camera.position.set(info.pos[0], info.pos[1], info.pos[2] + 1.7);
        const pitch = info.rot[1];
        const yaw = info.rot[0];
        camera.rotation.set(Math.PI / 2 + pitch, 0, yaw, 'YZX');
        camera.matrixWorldNeedsUpdate = true;
        adjust();
        renderer.render(scene, camera);
    });

    const mgr = utils.getControlMapper(mod.control);
    const kbdm = new utils.KeyboardMapper(mgr);

    input.detect([87, 38], o => kbdm.up = o);
    input.detect([83, 40], o => kbdm.down = o);
    input.detect([65, 37], o => kbdm.left = o);
    input.detect([68, 39], o => kbdm.right = o);
    input.detect([32], o => mgr.jump = o);
    input.detect([16], o => mgr.sneak = o);
    input.detect([17], o => mgr.boost = o);
    input.detect([0], o => mgr.use1 = o);
    input.detect([1], o => mgr.use2 = o);
    input.detect([2], o => mgr.use3 = o);

    enterGameMode(renderer.domElement, (o) => paused = !o);

    document.onmousemove = (e) => {
        if (paused) return;
        mgr.rotate = [-e.movementX / 100, -e.movementY / 100];
    }
}

function enterGameMode(canvas: HTMLCanvasElement, f: (f: boolean) => void) {
    document.onfullscreenchange = (e) => {
        if (!!document.fullscreenElement) {
            canvas.requestPointerLock();
        } else {
            f(false);
            canvas.onclick = cb;
        }
    }
    document.onfullscreenerror = (e) => {
        console.warn(e);
        f(false);
    }
    document.onpointerlockchange = (e) => {
        if (!!document.pointerLockElement) {
            try {
                (navigator as any).keyboard.lock();
            } catch { }
            f(true);
        } else {
            f(false);
            canvas.onclick = cb;
        }
    }
    const cb = () => {
        canvas.onclick = null;
        if (document.fullscreenElement)
            canvas.requestPointerLock();
        else
            canvas.requestFullscreen({ navigationUI: "hide" });
    }
    canvas.onclick = cb;
}