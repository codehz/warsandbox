import*as e from"../web_modules/three.js";const a=`
  attribute float size;
  attribute vec3 particleColor;

  varying vec3 vColor;

  void main() {
    vColor = particleColor;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * (1400.0 / -mvPosition.z);
    gl_Position = projectionMatrix * mvPosition;
  }
`,s=`
  varying vec3 vColor;

  void main() {
    gl_FragColor = vec4(vColor, 1.0);
  }
`;export function createParticleSystem(o){const r=o.proxy(new e.InterleavedBuffer(o.data,7)),t=new e.BufferGeometry();t.boundingSphere=new e.Sphere(new e.Vector3(32,512,128),1e3),t.setAttribute("size",new e.InterleavedBufferAttribute(r,1,0)),t.setAttribute("position",new e.InterleavedBufferAttribute(r,3,1)),t.setAttribute("particleColor",new e.InterleavedBufferAttribute(r,3,4));const i=new e.ShaderMaterial({vertexShader:a,fragmentShader:s,transparent:!0,depthWrite:!1}),n=new e.Points(t,i);return n}
