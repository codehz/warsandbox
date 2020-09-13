import * as THREE from "three";

const vertexShader = `
  attribute float size;
  attribute vec3 particleColor;

  varying vec3 vColor;

  void main() {
    vColor = particleColor;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * (300.0 / -mvPosition.z);
    gl_Position = projectionMatrix * mvPosition;
  }
`;

const fragmentShader = `
  varying vec3 vColor;

  void main() {
    gl_FragColor = vec4(vColor, 1.0);
  }
`;

export function createParticleSystem(buffer: THREE.InterleavedBuffer): THREE.Points {
  const geometry = new THREE.BufferGeometry();
  geometry.boundingBox = new THREE.Box3();
  geometry.boundingSphere = new THREE.Sphere();
  geometry.setAttribute("size", new THREE.InterleavedBufferAttribute(buffer, 1, 0));
  geometry.setAttribute("position", new THREE.InterleavedBufferAttribute(buffer, 3, 1));
  geometry.setAttribute("color", new THREE.InterleavedBufferAttribute(buffer, 3, 4));
  const material = new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader,
    transparent: true,
  });
  const points = new THREE.Points(geometry, material);
  return points;
}