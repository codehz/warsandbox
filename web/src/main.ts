import * as THREE from "three";
import * as utils from "./utils";
import * as input from "./inputmanager";
import { VoxelTextureManager } from "./texture";
import { createParticleSystem } from "./particle";

export async function main(
    scene: THREE.Scene,
    camera: THREE.Camera,
    renderer: THREE.WebGLRenderer,
    adjust: () => void) {
    const textbase = 4;
    const loader = new VoxelTextureManager(textbase, 16);
    await loader.add("assets/bedrock.png");
    await loader.add("assets/test.png");
    const testtex = new THREE.MeshPhongMaterial({
        map: loader.getTexture(),
        side: THREE.FrontSide,
    });
    testtex.map.minFilter = THREE.NearestFilter;
    testtex.map.magFilter = THREE.NearestFilter;
    testtex.map.flipY = false;

    console.time("init");

    const mod = await utils.fetchModule("native/engine.wasm", {});
    const mapInfo = utils.readMapInfo(mod.mapInfo);
    console.log(mapInfo);
    console.timeLog("init", "fetch");
    mod.loadSampleMap();
    console.timeLog("init", "load map");

    mod.initEngine();
    console.timeLog("init", "init engine");
    mod.initPlayer();
    console.timeLog("init", "init player");
    const blockTextureCount = utils.readUint16(mod.blockTextureCount);
    const textmap = utils.getUint16BufferFromSlice(mod.blockTextureMapping, blockTextureCount * 2);
    for (let i = 0; i < blockTextureCount; i++) {
        textmap[i] = i;
    }
    utils.writeUint16(mod.blockTextureBase, textbase);
    console.timeEnd("init");

    const chunkBoundingBox = new THREE.Box3(
        new THREE.Vector3(0, 0, 0),
        new THREE.Vector3(mapInfo.chunkWidth, mapInfo.chunkWidth, mapInfo.chunkHeight));
    const chunkBoundingSphere = new THREE.Sphere(
        new THREE.Vector3(
            (mapInfo.chunkWidth / 2),
            (mapInfo.chunkWidth / 2),
            (mapInfo.chunkHeight / 2)),
        ((mapInfo.chunkWidth / 2) ** 2 +
            (mapInfo.chunkWidth / 2) ** 2 +
            (mapInfo.chunkHeight / 2) ** 2) ** 0.5);

    console.time("geo");
    const chunkMeshs: THREE.Mesh<THREE.BufferGeometry>[] = [];
    for (let j = 0; j < mapInfo.length; j++) {
        for (let i = 0; i < mapInfo.width; i++) {
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
            chunkMeshs.push(tmesh);
            var box = new THREE.BoxHelper(tmesh, 0xffff00);
            scene.add(box);
        }
    }
    console.timeEnd("geo");

    const highlight = new THREE.Mesh(
        new THREE.BoxGeometry(1.001, 1.001, 1.001),
        [
            new THREE.MeshBasicMaterial({
                color: 0x00FF00,
                opacity: 0.2,
                transparent: true,
                depthWrite: false,
                vertexColors: false,
            }),
            new THREE.MeshBasicMaterial({
                color: 0xFF00FF,
                opacity: 0.2,
                transparent: true,
                depthWrite: false,
                vertexColors: false,
            })
        ]);
    console.log(highlight);
    highlight.renderOrder = 998;
    scene.add(highlight);

    const particleInfo = utils.readParticleInfo(mod.particle);
    const particles = createParticleSystem(particleInfo);
    scene.add(particles);

    let paused = true;

    setInterval(() => {
        if (paused) return;
        mod.tick();
        const info = utils.readCameraInfo(mod.cameraInfo);
        placePlane(highlight, info.highlight, info.selectedFace);
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
    input.detect([49], o => mgr.selectedSlot = 0);
    input.detect([50], o => mgr.selectedSlot = 1);
    input.detect([51], o => mgr.selectedSlot = 2);
    input.detect([52], o => mgr.selectedSlot = 3);
    input.detect([53], o => mgr.selectedSlot = 4);
    input.detect([54], o => mgr.selectedSlot = 5);
    input.detect([55], o => mgr.selectedSlot = 6);
    input.detect([56], o => mgr.selectedSlot = 7);

    enterGameMode((o) => paused = !o);

    document.onmousemove = (e) => {
        if (paused) return;
        mgr.rotate = [-e.movementX / 100, -e.movementY / 100];
    }
}

function placePlane(plane: THREE.Mesh<THREE.BoxGeometry>, pos: [number, number, number], face: number) {
    plane.position.set(pos[0] + 0.5, pos[1] + 0.5, pos[2] + 0.5);
    if (face > 5) return;
    for (let i = 0; i < 6; i++) {
        if (i != face) {
            plane.geometry.groups[i].materialIndex = 1;
            // plane.geometry.faces[i * 2].color.setHex(0x00FF00);
            // plane.geometry.faces[i * 2 + 1].color.setHex(0x00FF00);
        } else {
            plane.geometry.groups[i].materialIndex = 0;
            // plane.geometry.faces[i * 2].color.setHex(0xFF00FF);
            // plane.geometry.faces[i * 2 + 1].color.setHex(0xFF00FF);
        }
    }
    // plane.geometry.colorsNeedUpdate = true;
}

function enterGameMode(f: (f: boolean) => void) {
    document.onfullscreenchange = (e) => {
        if (!!document.fullscreenElement) {
            document.body.requestPointerLock();
        } else {
            f(false);
            document.body.onclick = cb;
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
            document.body.onclick = cb;
        }
    }
    const cb = () => {
        document.body.onclick = null;
        if (document.fullscreenElement)
            document.body.requestPointerLock();
        else
            document.body.requestFullscreen({ navigationUI: "hide" });
    }
    document.body.onclick = cb;
}