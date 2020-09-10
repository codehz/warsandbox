import*as e from"../web_modules/three.js";import*as a from"./utils.js";import*as n from"./inputmanager.js";function W(o){return new Promise((c,d)=>{o.onLoad=c,o.onError=d})}export async function main(o,c,d,m){const L=new e.LoadingManager(),I=new e.TextureLoader(L),w=new e.MeshPhongMaterial({map:I.load("assets/test.png"),side:e.FrontSide});w.map.minFilter=e.LinearMipmapLinearFilter,w.map.magFilter=e.NearestFilter,await W(L),console.time("init");const s=await a.fetchModule("native/engine.wasm",{}),i=a.readMapInfo(s.mapInfo);console.log(i),console.timeLog("init","fetch"),s.loadSampleMap(),console.timeLog("init","load map"),s.initEngine(),console.timeLog("init","init engine"),s.initPlayer(),console.timeLog("init","init player"),console.timeEnd("init");const b=new e.Box3(new e.Vector3(0,0,0),new e.Vector3(i.chunkWidth,i.chunkWidth,i.chunkHeight)),x=new e.Sphere(new e.Vector3(i.chunkWidth/2,i.chunkWidth/2,i.chunkHeight/2),((i.chunkWidth/2)**2+(i.chunkWidth/2)**2+(i.chunkHeight/2)**2)**.5);console.time("geo");for(let t=0;t<i.width;t++)for(let r=0;r<i.length;r++){const M=s.generateGeomentryDataForChunk(t,r),h=a.readMap(i,M),B=h.data.proxy(new e.InterleavedBuffer(h.data.data,8)),u=new e.BufferGeometry(),E=h.indices.proxy(new e.BufferAttribute(h.indices.data,1));u.setIndex(E),u.setAttribute("position",new e.InterleavedBufferAttribute(B,3,0)),u.setAttribute("normal",new e.InterleavedBufferAttribute(B,3,3)),u.setAttribute("uv",new e.InterleavedBufferAttribute(B,2,6)),u.boundingBox=b,u.boundingSphere=x;const p=new e.Mesh(u,w);p.castShadow=!0,p.receiveShadow=!0,p.position.add(new e.Vector3(t*i.chunkWidth,r*i.chunkWidth,0)),o.add(p);var v=new e.BoxHelper(p,16776960);o.add(v)}console.timeEnd("geo");var k=new e.Mesh(new e.BoxGeometry(1.001,1.001,1.001),new e.MeshBasicMaterial({color:16777215,opacity:.5,transparent:!0,depthWrite:!1}));k.renderOrder=999,o.add(k);let f=!0;setInterval(()=>{if(f)return;s.tick(),y=+new Date()},50),s.tick();let y=+new Date();d.setAnimationLoop(()=>{if(f)return;const t=(+new Date()-y)/50;t>.1&&t<1&&s.microtick(t);const r=a.readCameraInfo(s.cameraInfo);c.position.set(r.pos[0],r.pos[1],r.pos[2]+1.7);const M=r.rot[1],h=r.rot[0];k.position.set(r.highlight[0]+.5,r.highlight[1]+.5,r.highlight[2]+.5),c.rotation.set(Math.PI/2+M,0,h,"YZX"),c.matrixWorldNeedsUpdate=!0,m(),d.render(o,c)});const l=a.getControlMapper(s.control),g=new a.KeyboardMapper(l);n.detect([87,38],t=>g.up=t),n.detect([83,40],t=>g.down=t),n.detect([65,37],t=>g.left=t),n.detect([68,39],t=>g.right=t),n.detect([32],t=>l.jump=t),n.detect([16],t=>l.sneak=t),n.detect([17],t=>l.boost=t),n.detect([0],t=>l.use1=t),n.detect([1],t=>l.use2=t),n.detect([2],t=>l.use3=t),A(d.domElement,t=>f=!t),document.onmousemove=t=>{if(f)return;l.rotate=[-t.movementX/100,-t.movementY/100]}}function A(o,c){document.onfullscreenchange=m=>{document.fullscreenElement?o.requestPointerLock():(c(!1),o.onclick=d)},document.onfullscreenerror=m=>{console.warn(m),c(!1)},document.onpointerlockchange=m=>{if(document.pointerLockElement){try{navigator.keyboard.lock()}catch{}c(!0)}else c(!1),o.onclick=d};const d=()=>{o.onclick=null,document.fullscreenElement?o.requestPointerLock():o.requestFullscreen({navigationUI:"hide"})};o.onclick=d}
