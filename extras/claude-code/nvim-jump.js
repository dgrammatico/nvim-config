// Claude Code hook: when Claude is about to edit (or has just written) a file,
// show that file in the running Neovim. Talks msgpack-RPC straight to Neovim's
// named pipe (much faster than spawning `nvim --server`). Never blocks Claude:
// any problem -> exit 0 silently.
const fs = require("fs");
const net = require("net");
const path = require("path");

const done = () => process.exit(0);
setTimeout(done, 1500).unref();

// --- tiny msgpack encoder (arrays, small ints, strings) ---
function enc(v) {
  if (Array.isArray(v)) {
    const parts = v.map(enc);
    const n = v.length;
    const head = n < 16 ? Buffer.from([0x90 | n]) : Buffer.from([0xdc, n >> 8, n & 255]);
    return Buffer.concat([head, ...parts]);
  }
  if (typeof v === "number") return Buffer.from([v & 0x7f]); // positive fixint only
  const s = Buffer.from(String(v), "utf8");
  const n = s.length;
  let head;
  if (n < 32) head = Buffer.from([0xa0 | n]);
  else if (n < 256) head = Buffer.from([0xd9, n]);
  else if (n < 65536) head = Buffer.from([0xda, n >> 8, n & 255]);
  else head = Buffer.from([0xdb, (n >>> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]);
  return Buffer.concat([head, s]);
}

let input = "";
process.stdin.on("data", (d) => (input += d));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input);
    const ti = data.tool_input || {};
    const file = ti.file_path || ti.notebook_path;
    if (!file) return done();
    // A brand-new file (Write before it exists): still open it now, as an empty buffer,
    // so the typing animation can show the whole file being written.
    const isNewFile = !fs.existsSync(file);
    if (isNewFile && !(data.hook_event_name === "PreToolUse" && data.tool_name === "Write")) return done();

    const serverFile = path.join(process.env.LOCALAPPDATA || "", "nvim-data", "claude-jump-server");
    if (!fs.existsSync(serverFile)) return done();
    const pipe = fs.readFileSync(serverFile, "utf8").trim();
    if (!pipe) return done();

    const full = path.resolve(file).replace(/\\/g, "/");
    // msgpack-RPC notification: [2, method, params]
    const msg = enc([2, "nvim_exec_lua", ["ClaudeJump(...)", [full]]]);
    const sock = net.connect(pipe);
    sock.on("error", done);
    sock.on("connect", () => sock.end(msg));
    sock.on("close", done);
  } catch (e) {
    done();
  }
});
