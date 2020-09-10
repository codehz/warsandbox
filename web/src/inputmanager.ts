type Callback = (status: boolean) => void;
var status: Record<number, boolean> = {};
var keydb: Record<number, Callback> = {};

document.addEventListener("mousedown", e => {
  e.preventDefault();
  const cb = keydb[e.button];
  if (cb && !status[e.button]) {
    status[e.button] = true;
    cb(true);
  }
});

document.addEventListener("mouseup", e => {
  e.preventDefault();
  const cb = keydb[e.button];
  if (cb) {
    delete status[e.button];
    cb(false);
  }
});

document.addEventListener("keydown", e => {
  e.preventDefault();
  const cb = keydb[e.keyCode];
  if (cb && !status[e.keyCode]) {
    status[e.keyCode] = true;
    cb(true);
  }
});

document.addEventListener("keyup", e => {
  e.preventDefault();
  const cb = keydb[e.keyCode];
  if (cb) {
    delete status[e.keyCode];
    cb(false);
  }
});

export function detect(range: number[], cb: Callback) {
  for (const idx of range) {
    keydb[idx] = cb;
  }
}

export function undetect(range: number[]) {
  for (const idx of range) {
    delete keydb[idx];
  }
}

export function reset() {
  keydb = {};
}