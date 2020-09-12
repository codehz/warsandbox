import * as THREE from "three";
import { main } from "./main";

const renderer = new THREE.WebGLRenderer();
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
document.body.appendChild(renderer.domElement);

const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
camera.up = new THREE.Vector3(0, 0, 1);
camera.position.z = 12;

const scene = new THREE.Scene();

const color = 0xFFFFFF;
const light = new THREE.DirectionalLight(color, 1);
light.shadow.mapSize.width = 2048;  // default
light.shadow.mapSize.height = 2048; // default
light.shadow.bias = 0;
light.shadow.camera.near = 0;    // default
light.shadow.camera.far = 100;     // default
light.shadow.camera.left = -50;
light.shadow.camera.right = 20;
light.shadow.camera.top = 50;
light.shadow.camera.bottom = -50;
light.castShadow = true;
light.position.set(0, 0, 40);
light.target.position.set(32, 32, 0);
scene.add(light);
scene.add(light.target);
scene.add(new THREE.CameraHelper(light.shadow.camera));

const amblight = new THREE.AmbientLight(color, 0.5);
scene.add(amblight);

var geometry = new THREE.BoxGeometry(3, 2);
var material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
var cube = new THREE.Mesh(geometry, material);
scene.add(cube);

var helper = new THREE.AxesHelper(8);
scene.add(helper);

const adjust = (() => {
    let width = 0;
    let height = 0;
    let dpi = 0;
    return () => {
        if (width != window.innerWidth || height != window.innerHeight || dpi != devicePixelRatio) {
            width = window.innerWidth;
            height = window.innerHeight;
            dpi = devicePixelRatio;
            renderer.setPixelRatio(dpi);
            renderer.setSize(width, height);
            camera.aspect = width / height;
            camera.updateProjectionMatrix();
        }
    };
})();

// let x = 0;
// const center = 32;
// const centerX = 160;

// function animate() {
//     detect();
//     camera.position.x = Math.sin(x) * centerX + centerX - 32;
//     camera.position.y = Math.cos(x) * center + center;
//     x += 0.001;
//     camera.lookAt(centerX, center, 0);
//     renderer.render(scene, camera);
// }
// renderer.setAnimationLoop(animate)

setTimeout(() => main(scene, camera, renderer, adjust), 1000);
