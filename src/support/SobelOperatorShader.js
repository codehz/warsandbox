import {Vector2} from "../../_snowpack/pkg/three.js";
export const SobelOperatorShader = {
  uniforms: {
    tDiffuse: {value: null},
    resolution: {value: new Vector2()}
  },
  vertexShader: [
    "varying vec2 vUv;",
    "void main() {",
    "	vUv = uv;",
    "	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );",
    "}"
  ].join("\n"),
  fragmentShader: [
    "uniform sampler2D tDiffuse;",
    "uniform vec2 resolution;",
    "varying vec2 vUv;",
    "void main() {",
    "	vec2 texel = vec2( 1.0 / resolution.x, 1.0 / resolution.y );",
    "	const mat3 Gx = mat3( -1, -2, -1, 0, 0, 0, 1, 2, 1 );",
    "	const mat3 Gy = mat3( -1, 0, 1, -2, 0, 2, -1, 0, 1 );",
    "	float tx0y0 = texture2D( tDiffuse, vUv + texel * vec2( -1, -1 ) ).r;",
    "	float tx0y1 = texture2D( tDiffuse, vUv + texel * vec2( -1,  0 ) ).r;",
    "	float tx0y2 = texture2D( tDiffuse, vUv + texel * vec2( -1,  1 ) ).r;",
    "	float tx1y0 = texture2D( tDiffuse, vUv + texel * vec2(  0, -1 ) ).r;",
    "	float tx1y1 = texture2D( tDiffuse, vUv + texel * vec2(  0,  0 ) ).r;",
    "	float tx1y2 = texture2D( tDiffuse, vUv + texel * vec2(  0,  1 ) ).r;",
    "	float tx2y0 = texture2D( tDiffuse, vUv + texel * vec2(  1, -1 ) ).r;",
    "	float tx2y1 = texture2D( tDiffuse, vUv + texel * vec2(  1,  0 ) ).r;",
    "	float tx2y2 = texture2D( tDiffuse, vUv + texel * vec2(  1,  1 ) ).r;",
    "	float valueGx = Gx[0][0] * tx0y0 + Gx[1][0] * tx1y0 + Gx[2][0] * tx2y0 + ",
    "		Gx[0][1] * tx0y1 + Gx[1][1] * tx1y1 + Gx[2][1] * tx2y1 + ",
    "		Gx[0][2] * tx0y2 + Gx[1][2] * tx1y2 + Gx[2][2] * tx2y2; ",
    "	float valueGy = Gy[0][0] * tx0y0 + Gy[1][0] * tx1y0 + Gy[2][0] * tx2y0 + ",
    "		Gy[0][1] * tx0y1 + Gy[1][1] * tx1y1 + Gy[2][1] * tx2y1 + ",
    "		Gy[0][2] * tx0y2 + Gy[1][2] * tx1y2 + Gy[2][2] * tx2y2; ",
    "	float G = sqrt( ( valueGx * valueGx ) + ( valueGy * valueGy ) );",
    "	gl_FragColor = vec4( vec3( G ), 1 );",
    "}"
  ].join("\n")
};
