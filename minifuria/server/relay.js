// Servidor de salas do Mini Fúria (Node.js). Mesmo protocolo de minifuria/scripts/net_server.gd:
// texto = JSON de controle; binário = [tipo u8][dados] que é repassado aos outros da sala como [tipo][remetente u16 LE][dados].
// Uso:  npm install && PORT=9080 node relay.js
// Em hospedagens com HTTPS (Render, Fly.io, Railway...) o endereço vira wss://seu-app.exemplo.com — é o que o jogo
// na web precisa (página https só conecta em wss).
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = parseInt(process.env.PORT || "9080", 10);
const MAX_ROOM = 8;
const clients = new Map(); // id -> {ws, name, room}
const rooms = new Map();   // code -> {name, host, members: [], max, open}
let nextId = 1;

const srv = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end(`Mini Fúria — servidor de salas ok · ${clients.size} conectados · ${rooms.size} salas\n`);
});
const wss = new WebSocketServer({ server: srv, maxPayload: 1 << 16 });

function send(id, d) {
  const c = clients.get(id);
  if (c && c.ws.readyState === 1) c.ws.send(JSON.stringify(d));
}
function roomSend(code, d, except = -1) {
  const r = rooms.get(code);
  if (!r) return;
  const txt = JSON.stringify(d);
  for (const m of r.members) if (m !== except) { const c = clients.get(m); if (c && c.ws.readyState === 1) c.ws.send(txt); }
}
function newCode() {
  const abc = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  for (let t = 0; t < 50; t++) {
    let s = "";
    for (let i = 0; i < 4; i++) s += abc[Math.floor(Math.random() * abc.length)];
    if (!rooms.has(s)) return s;
  }
  return String(Math.floor(Math.random() * 100000));
}
function joined(id, code) {
  const r = rooms.get(code);
  send(id, { t: "joined", code, name: r.name, host: r.host, max: r.max, me: id,
    members: r.members.map((m) => ({ id: m, name: clients.get(m).name })) });
}
function leave(id) {
  const c = clients.get(id);
  if (!c || !c.room) return;
  const code = c.room;
  c.room = "";
  const r = rooms.get(code);
  if (!r) return;
  r.members = r.members.filter((m) => m !== id);
  if (r.members.length === 0) { rooms.delete(code); return; }
  roomSend(code, { t: "peer_leave", id });
  if (r.host === id) { r.host = r.members[0]; roomSend(code, { t: "host", id: r.host }); }
}
function handle(id, d) {
  const c = clients.get(id);
  switch (d.t) {
    case "hello": c.name = String(d.name || "?").slice(0, 16); break;
    case "list":
      send(id, { t: "rooms", list: [...rooms].map(([code, r]) => ({ code, name: r.name, n: r.members.length, max: r.max, open: r.open })) });
      break;
    case "create": {
      leave(id);
      const code = newCode();
      rooms.set(code, { name: String(d.name || c.name + "'s sala").slice(0, 24), host: id, members: [id],
        max: Math.max(2, Math.min(MAX_ROOM, parseInt(d.max || MAX_ROOM, 10))), open: true });
      c.room = code;
      joined(id, code);
      break;
    }
    case "join": {
      const code = String(d.code || "").toUpperCase().trim();
      const r = rooms.get(code);
      if (!r) return send(id, { t: "err", msg: `Sala ${code} não existe` });
      if (!r.open) return send(id, { t: "err", msg: "A corrida já começou nessa sala" });
      if (r.members.length >= r.max) return send(id, { t: "err", msg: "Sala cheia" });
      leave(id);
      r.members.push(id);
      c.room = code;
      roomSend(code, { t: "peer_join", id, name: c.name }, id);
      joined(id, code);
      break;
    }
    case "leave": leave(id); break;
    case "lock": { const r = rooms.get(c.room); if (r && r.host === id) r.open = !!d.open; break; }
    case "room": {
      const r = rooms.get(c.room);
      if (!r) return;
      const msg = { t: "room", from: id, d: d.d || {} };
      if (d.to !== undefined) { if (r.members.includes(+d.to)) send(+d.to, msg); }
      else roomSend(c.room, msg, id);
      break;
    }
    case "ping": send(id, { t: "pong", c: d.c || 0 }); break;
  }
}

wss.on("connection", (ws) => {
  const id = nextId++;
  clients.set(id, { ws, name: "?", room: "" });
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));
  send(id, { t: "welcome", id, ver: 1 });
  ws.on("message", (data, isBinary) => {
    if (!isBinary) {
      let d;
      try { d = JSON.parse(data.toString()); } catch { return; }
      if (d && typeof d === "object") handle(id, d);
      return;
    }
    const c = clients.get(id);
    const r = c && rooms.get(c.room);
    if (!r || data.length < 1 || data.length > 4096) return;
    const out = Buffer.allocUnsafe(data.length + 2);
    out[0] = data[0];
    out.writeUInt16LE(id, 1);
    data.copy(out, 3, 1);
    for (const m of r.members) if (m !== id) { const o = clients.get(m); if (o && o.ws.readyState === 1) o.ws.send(out); }
  });
  ws.on("close", () => { leave(id); clients.delete(id); });
});
// derruba conexões mortas (celular que perdeu o sinal)
setInterval(() => {
  for (const c of clients.values()) {
    if (!c.ws.isAlive) { c.ws.terminate(); continue; }
    c.ws.isAlive = false;
    c.ws.ping();
  }
}, 15000);

srv.listen(PORT, () => console.log(`[servidor] Mini Fúria ouvindo na porta ${PORT}`));
