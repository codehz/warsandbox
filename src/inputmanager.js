var o={},n={};document.addEventListener("mousedown",e=>{e.preventDefault();const t=n[e.button];t&&!o[e.button]&&(o[e.button]=!0,t(!0))}),document.addEventListener("mouseup",e=>{e.preventDefault();const t=n[e.button];t&&(delete o[e.button],t(!1))}),document.addEventListener("keydown",e=>{e.preventDefault();const t=n[e.keyCode];t&&!o[e.keyCode]&&(o[e.keyCode]=!0,t(!0))}),document.addEventListener("keyup",e=>{e.preventDefault();const t=n[e.keyCode];t&&(delete o[e.keyCode],t(!1))});export function detect(e,t){for(const d of e)n[d]=t}export function undetect(e){for(const t of e)delete n[t]}export function reset(){n={}}