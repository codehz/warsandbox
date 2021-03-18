import * as THREE from "../_snowpack/pkg/three.js";
const vertexShader = `
  attribute float size;
  attribute vec3 particleColor;

  varying vec3 vColor;

  void main() {
    vColor = particleColor;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * (1400.0 / -mvPosition.z);
    gl_Position = projectionMatrix * mvPosition;
  }
`;
const fragmentShader = `
  varying vec3 vColor;

  void main() {
    gl_FragColor = vec4(vColor, 1.0);
  }
`;
export function createParticleSystem(data) {
  const buffer = data.proxy(new THREE.InterleavedBuffer(data.data, 7));
  const geometry = new THREE.BufferGeometry();
  geometry.boundingSphere = new THREE.Sphere(new THREE.Vector3(32, 512, 128), 1e3);
  geometry.setAttribute("size", new THREE.InterleavedBufferAttribute(buffer, 1, 0));
  geometry.setAttribute("position", new THREE.InterleavedBufferAttribute(buffer, 3, 1));
  geometry.setAttribute("particleColor", new THREE.InterleavedBufferAttribute(buffer, 3, 4));
  const material = new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader,
    transparent: true,
    depthWrite: false
  });
  const points = new THREE.Points(geometry, material);
  return points;
}
