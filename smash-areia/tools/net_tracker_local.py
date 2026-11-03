# Tracker WebTorrent mínimo para testar o online sem internet: repassa offers e answers.
# Uso: pip install websockets && python3 tools/net_tracker_local.py   (escuta em ws://127.0.0.1:8765)
import asyncio, json, websockets
swarms = {}   # info_hash -> {peer_id: ws}
async def handler(ws):
    me = None
    try:
        async for msg in ws:
            d = json.loads(msg)
            if d.get("action") != "announce":
                continue
            ih, pid = d.get("info_hash"), d.get("peer_id")
            me = (ih, pid)
            sw = swarms.setdefault(ih, {})
            sw[pid] = ws
            if "answer" in d:
                to = sw.get(d.get("to_peer_id"))
                if to:
                    await to.send(json.dumps({"action": "announce", "info_hash": ih, "peer_id": pid,
                                              "offer_id": d["offer_id"], "answer": d["answer"]}))
                    print("answer", pid[:6], "->", d.get("to_peer_id", "")[:6], flush=True)
                continue
            offers = d.get("offers", [])
            others = [(p, w) for p, w in sw.items() if p != pid]
            for (p, w), o in zip(others, offers):
                await w.send(json.dumps({"action": "announce", "info_hash": ih, "peer_id": pid,
                                         "offer_id": o["offer_id"], "offer": o["offer"]}))
                print("offer", pid[:6], "->", p[:6], flush=True)
            await ws.send(json.dumps({"action": "announce", "interval": 120, "info_hash": ih, "complete": len(sw), "incomplete": 0}))
    except Exception as e:
        print("err", e, flush=True)
    finally:
        if me and me[0] in swarms:
            swarms[me[0]].pop(me[1], None)
async def main():
    async with websockets.serve(handler, "127.0.0.1", 8765):
        print("tracker on 8765", flush=True)
        await asyncio.Future()
asyncio.run(main())
