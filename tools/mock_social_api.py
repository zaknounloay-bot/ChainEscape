#!/usr/bin/env python3
"""Local stand-in for the "chain-escape-api" Supabase Edge Function (tests only).

    python3 tools/mock_social_api.py --port 8790

Implements the documented contract:
  GET  /                       -> {"ok": true, "service": "chain-escape-api", "version": 3}
  POST /   photo_message_reveal: {challenge_type, difficulty, puzzle, message?, image_base64?, image_type?}
           friend_challenge:     {challenge_type, difficulty, puzzle, surprise_me?}
                               -> {"ok": true, "challenge_id": "<uuid>", "expires_at": "..."}
  GET  /?action=read&id=<id>   -> {"ok": true, "challenge": {..., "media_url": "https://..." | null}}
with type-specific validation:
  common            puzzle format / version / rules, size 1-12, map shape and
                    cell tokens
  photo_message_reveal  difficulty easy|medium|hard, message <= 200, image MIME
                    and <= 5 MB, photo or message required
  friend_challenge  difficulty easy|medium|hard|very_hard, cells only plain
                    arrows or clockwise spinners, no message / image,
                    surprise_me optional boolean; payload {} or
                    {"surprise_me": true}, never any media
(the reference for the real Edge Function: docs/backend/friend_challenge_phase2.md).

Photos: READ's media_url points at <media-base>/storage/v1/object/sign/...
?token=<n> (a stand-in for a Supabase signed URL); with --media-base set to
this server it serves the stored image (CORS *), else it is a dummy https URL.

Test controls (never part of the real API):
  POST /__mode   {"fail_next": "500" | "429" | "timeout" | "garbage" | "bad_id",
                  "fail_next_read": "500" | "timeout" | "garbage"}
  POST /__expire {"id": "..."}       GET /__last  (last CREATE body)
  GET  /__count                      (number of CREATE requests received)
  GET  /__reads                      (number of READ requests received)
  POST /__media  {"fail": bool, "delay": seconds, "expire": true}
                 (expire = every photo URL handed out so far stops working)
  POST /__put    {"id": "...", "challenge": {...}}  (stores a raw challenge:
                 malformed / unsupported data for the client's validation)
"""
import argparse
import base64
import json
import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

STORE = {}
EXPIRED = set()
STATE = {"fail_next": "", "fail_next_read": "", "last": None, "count": 0, "reads": 0}
IMAGES = {}
MEDIA = {"fail": False, "delay": 0.0, "ver": 1, "base": "https://mock.invalid"}
DIFFICULTIES = {
    "photo_message_reveal": {"easy", "medium", "hard"},
    "friend_challenge": {"easy", "medium", "hard", "very_hard"},
}
TYPES = set(DIFFICULTIES)
MIMES = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
CELL = re.compile(r"^(\.|[RBGYP][\^v<>]\S*|X[A-D])$")
FRIEND_CELL = re.compile(r"^(\.|[RBGYP][\^v<>](@)?)$")


def validate(b):
    if not isinstance(b, dict):
        return "body must be an object"
    t = b.get("challenge_type")
    if t not in TYPES:
        return "invalid challenge_type"
    if b.get("difficulty") not in DIFFICULTIES[t]:
        return "invalid difficulty"
    p = b.get("puzzle")
    if not isinstance(p, dict) or p.get("format") != "ce-puzzle" or p.get("v") != 1 or p.get("rules") != 1:
        return "invalid puzzle format"
    rows, cols, m = p.get("rows"), p.get("cols"), p.get("map")
    if not (isinstance(rows, int) and isinstance(cols, int) and 1 <= rows <= 12 and 1 <= cols <= 12):
        return "invalid puzzle size"
    if not isinstance(m, list) or len(m) != rows:
        return "invalid puzzle map"
    for row in m:
        cells = row.split() if isinstance(row, str) else None
        if not cells or len(cells) != cols or not all(CELL.match(c) for c in cells):
            return "invalid puzzle map"
    if t == "friend_challenge":
        cells = [c for row in m for c in row.split()]
        if not all(FRIEND_CELL.match(c) for c in cells):
            return "invalid puzzle map"
        if all(c == "." for c in cells):
            return "invalid puzzle map"
        if b.get("message") is not None or b.get("image_base64") is not None or b.get("image_type") is not None:
            return "friend_challenge carries no message or image"
        if "surprise_me" in b and not isinstance(b["surprise_me"], bool):
            return "invalid surprise_me"
        return ""
    msg = b.get("message")
    if msg is not None and (not isinstance(msg, str) or len(msg) > 200):
        return "invalid message"
    img = b.get("image_base64")
    if img is not None:
        if b.get("image_type") not in MIMES:
            return "invalid image type"
        try:
            raw = base64.b64decode(img, validate=True)
        except Exception:
            return "invalid image"
        if len(raw) > 5 * 1024 * 1024:
            return "image too large"
        if b["image_type"] == "image/jpeg" and raw[:3] != b"\xff\xd8\xff":
            return "invalid image"
    if not (msg and msg.strip()) and img is None:
        return "photo or message required"
    return ""


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj, raw=None, ctype="application/json"):
        data = raw if raw is not None else json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "content-type, apikey, authorization, accept")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self._send(204, None, b"")

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == "/__last":
            return self._send(200, STATE["last"])
        if u.path == "/__count":
            return self._send(200, {"count": STATE["count"]})
        if u.path == "/__reads":
            return self._send(200, {"reads": STATE["reads"]})
        if u.path.startswith("/storage/v1/object/sign/challenge-media/"):
            path = u.path[len("/storage/v1/object/sign/challenge-media/"):]
            if MEDIA["delay"]:
                time.sleep(MEDIA["delay"])
            if MEDIA["fail"]:
                return self._send(500, {"error": "storage unavailable"})
            if (q.get("token") or [""])[0] != str(MEDIA["ver"]):
                return self._send(400, {"error": "InvalidJWT", "message": "token expired"})
            img = IMAGES.get(path)
            if img is None:
                return self._send(404, {"error": "not found"})
            return self._send(200, None, img[0], img[1])
        if q.get("action") == ["read"]:
            STATE["reads"] += 1
            mode, STATE["fail_next_read"] = STATE["fail_next_read"], ""
            if mode == "timeout":
                time.sleep(6)
            if mode == "500":
                return self._send(500, {"ok": False, "error": "internal"})
            if mode == "garbage":
                return self._send(200, None, b"<html>not json</html>")
            cid = (q.get("id") or [""])[0]
            if cid in EXPIRED:
                return self._send(410, {"ok": False, "error": "challenge expired"})
            ch = STORE.get(cid)
            if ch is None:
                return self._send(404, {"ok": False, "error": "challenge not found"})
            out = dict(ch)
            media = (ch.get("payload") or {}).get("media") if isinstance(ch.get("payload"), dict) else None
            out["media_url"] = ("%s/storage/v1/object/sign/challenge-media/%s?token=%d" % (MEDIA["base"], media["path"], MEDIA["ver"])) if isinstance(media, dict) else None
            return self._send(200, {"ok": True, "challenge": out})
        return self._send(200, {"ok": True, "service": "chain-escape-api", "version": 3})

    def do_POST(self):
        u = urlparse(self.path)
        raw = self._body()
        if u.path == "/__mode":
            m = json.loads(raw or b"{}")
            STATE["fail_next"] = m.get("fail_next", STATE["fail_next"])
            STATE["fail_next_read"] = m.get("fail_next_read", STATE["fail_next_read"])
            return self._send(200, {"ok": True})
        if u.path == "/__media":
            m = json.loads(raw or b"{}")
            MEDIA["fail"] = bool(m.get("fail", MEDIA["fail"]))
            MEDIA["delay"] = float(m.get("delay", MEDIA["delay"]))
            if m.get("expire"):
                MEDIA["ver"] += 1
            return self._send(200, {"ok": True})
        if u.path == "/__put":
            m = json.loads(raw)
            STORE[m["id"]] = m["challenge"]
            return self._send(200, {"ok": True})
        if u.path == "/__expire":
            EXPIRED.add(json.loads(raw).get("id", ""))
            return self._send(200, {"ok": True})
        STATE["count"] += 1
        mode, STATE["fail_next"] = STATE["fail_next"], ""
        try:
            STATE["last"] = json.loads(raw)
        except Exception:
            STATE["last"] = None
        if mode == "timeout":
            time.sleep(6)
            return self._send(500, {"ok": False, "error": "late"})
        if mode == "500":
            return self._send(500, {"ok": False, "error": "internal: stack trace with secrets"})
        if mode == "429":
            return self._send(429, {"ok": False, "error": "rate limited"})
        if mode == "garbage":
            return self._send(200, None, b"<html>not json</html>")
        try:
            b = json.loads(raw)
        except Exception:
            return self._send(400, {"ok": False, "error": "invalid json"})
        err = validate(b)
        if err:
            return self._send(400, {"ok": False, "error": err})
        if mode == "bad_id":
            return self._send(200, {"ok": True, "challenge_id": "not-a-uuid", "expires_at": "x"})
        cid = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        expires = (now + timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        if b["challenge_type"] == "friend_challenge":
            payload = {"surprise_me": True} if b.get("surprise_me") is True else {}
        else:
            payload = {"message": b.get("message")}
        if b["challenge_type"] == "photo_message_reveal" and b.get("image_base64"):
            payload["media"] = {"type": "image", "path": "%s/reveal.%s" % (cid, MIMES[b["image_type"]]), "mime": b["image_type"]}
            IMAGES[payload["media"]["path"]] = (base64.b64decode(b["image_base64"]), b["image_type"])
        STORE[cid] = {"id": cid, "challenge_type": b["challenge_type"], "difficulty": b["difficulty"], "puzzle": b["puzzle"],
                      "payload": payload, "format_version": 1, "rules_version": 1,
                      "created_at": now.strftime("%Y-%m-%dT%H:%M:%S.000Z"), "expires_at": expires}
        return self._send(200, {"ok": True, "challenge_id": cid, "expires_at": expires})


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8790)
    ap.add_argument("--media-base", default="https://mock.invalid")
    a = ap.parse_args()
    MEDIA["base"] = a.media_base.rstrip("/")
    ThreadingHTTPServer(("127.0.0.1", a.port), H).serve_forever()
