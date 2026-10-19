// Dry-runs a plymouth script in JS against a mock API: catches undefined
// names, bad calls and NaN positions. Not a renderer.
const fs = require('fs');
let src = fs.readFileSync(process.argv[2], 'utf8');
const frames = +(process.argv[3] || 600);
src = src.replace(/#.*$/gm, '').replace(/\bfun\s+(\w+)\s*\(/g, 'function $1(').replace(/\bglobal\./g, '');
const issues = new Set();
const dims = {};
function img(w, h, name) { return { w, h, name, GetWidth() { return this.w }, GetHeight() { return this.h },
  Scale(a, b) { if (!(a > 0 && b > 0)) issues.add(`Scale(${a},${b}) on ${name}`); return img(a, b, name) },
  Rotate() { return this } } }
function sprite(i) { const s = { i, SetImage(x) { if (!x || !x.GetWidth) issues.add('SetImage bad'); this.i = x },
  SetPosition(x, y, z) { chk(x, y) }, SetX(x) { chk(x) }, SetY(y) { chk(y) }, SetZ() {},
  SetOpacity(o) { if (!(o >= 0 && o <= 1.0001)) issues.add('opacity ' + o) }, GetImage() { return this.i } }; return s }
function chk(...v) { for (const x of v) if (!Number.isFinite(x)) issues.add('non-finite position ' + x) }
const { execSync } = require('child_process');
function Image(n) { if (!fs.existsSync(n)) issues.add('missing ' + n);
  const [w, h] = execSync(`magick identify -format "%w %h" ${n}`).toString().split(' ').map(Number); return img(w, h, n) }
Image.Text = (t) => img(100, 20, 'text');
function Sprite(i) { return sprite(i) }
let refresh, cbs = {};
const Plymouth = { SetRefreshFunction(f) { refresh = f }, SetDisplayNormalFunction(f) { cbs.normal = f },
  SetDisplayPasswordFunction(f) { cbs.pw = f }, SetBootProgressFunction(f) { cbs.prog = f },
  SetDisplayMessageFunction(f) { cbs.msg = f }, SetHideMessageFunction(f) { cbs.hide = f }, GetMode() { return 'boot' } };
const Window = { GetWidth() { return 2560 }, GetHeight() { return 1440 }, SetBackgroundTopColor() {}, SetBackgroundBottomColor() {} };
const M = { Int: Math.trunc, Sin: Math.sin, Cos: Math.cos, Abs: Math.abs, Random: Math.random, Sqrt: Math.sqrt, Min: Math.min, Max: Math.max };
const auto = () => new Proxy({}, { get(t, k) { if (typeof k === 'symbol') return undefined; if (!(k in t)) t[k] = auto(); return t[k] } });
const scope = new Proxy({ Image, Sprite, Plymouth, Window, Math: M, issues }, {
  has: (t, k) => typeof k === 'string' && !['console', 'undefined', 'Infinity', 'NaN'].includes(k),
  get(t, k) { if (typeof k === 'symbol') return undefined; if (!(k in t)) t[k] = auto(); return t[k] } });
const run = new Function('scope', `with (scope) { ${src}\n; return {refresh: Plymouth} }`);
run(scope);
for (let f = 0; f < frames; f++) {
  refresh();
  if (f === 100) cbs.pw('Password', 0);
  if (f > 100 && f < 130) cbs.pw('Password', f - 100);
  if (f === 200) cbs.normal();
  if (f > 200) cbs.prog(f / 50, f / 1000);
  if (f === 250) { cbs.msg('hello'); cbs.hide('hello') }
}
console.log(issues.size ? [...issues].join('\n') : `OK: ${frames} frames, no issues`);
