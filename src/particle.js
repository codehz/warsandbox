import*as e from"../web_modules/three.js";const n=`
  attribute float size;
  attribute vec3 particleColor;

  varying vec3 vColor;

  void main() {
    vColor = particleColor;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * (300.0 / -mvPosition.z);
    gl_Position = projectionMatrix * mvPosition;
  }
`,a=`
  varying vec3 vColor;

  void main() {
    gl_FragColor = vec4(vColor, 1.0);
  }
`;export function createParticleSystem(o){const t=new e.BufferGeometry();t.boundingBox=new e.Box3(),t.boundingSphere=new e.Sphere(),t.setAttribute("size",new e.InterleavedBufferAttribute(o,1,0)),t.setAttribute("position",new e.InterleavedBufferAttribute(o,3,1)),t.setAttribute("color",new e.InterleavedBufferAttribute(o,3,4));const r=new e.ShaderMaterial({vertexShader:n,fragmentShader:a,transparent:!0}),i=new e.Points(t,r);return i}
