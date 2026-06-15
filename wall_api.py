from http.server import HTTPServer, BaseHTTPRequestHandler
import json, os, time, random

DATA_FILE = "/opt/blog/data/wall_posts.json"
CHAT_FILE = "/opt/blog/data/wall_chat.json"
BLOG_FILE = "/opt/blog/data/blog_articles.json"
GARDEN_FILE = "/opt/blog/data/garden.json"

def garden_load():
    if not os.path.exists(GARDEN_FILE):
        return {"totalVisits": 0, "lastVisitAt": 0, "dailyWaterings": {}, "plants": []}
    with open(GARDEN_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def garden_save(data):
    os.makedirs(os.path.dirname(GARDEN_FILE), exist_ok=True)
    with open(GARDEN_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def load():
    if not os.path.exists(DATA_FILE): return []
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def garden_season():
    m = time.localtime().tm_mon
    if 3 <= m <= 5: return "spring"
    if 6 <= m <= 8: return "summer"
    if 9 <= m <= 11: return "autumn"
    return "winter"

def garden_season_weights():
    """Return weighted plant type probabilities for current season."""
    s = garden_season()
    if s == "spring": return [("flower", 0.60), ("grass", 0.20), ("fern", 0.05), ("mushroom", 0.05), ("succulent", 0.05), ("vine", 0.05)]
    if s == "summer": return [("fern", 0.30), ("vine", 0.20), ("grass", 0.20), ("flower", 0.10), ("mushroom", 0.10), ("succulent", 0.10)]
    if s == "autumn": return [("mushroom", 0.40), ("grass", 0.30), ("fern", 0.10), ("flower", 0.10), ("vine", 0.05), ("succulent", 0.05)]
    return [("succulent", 0.40), ("grass", 0.40), ("fern", 0.05), ("flower", 0.05), ("mushroom", 0.05), ("vine", 0.05)]

def garden_random_plant_type():
    weights = garden_season_weights()
    r = random.random()
    acc = 0
    for ptype, w in weights:
        acc += w
        if r <= acc:
            return ptype
    return weights[-1][0]

def garden_apply_decay(plant, now_ms=None):
    """Apply health decay: -0.5 per hour since last watered. Returns effective health."""
    if now_ms is None:
        now_ms = int(time.time() * 1000)
    h = plant.get("health", 30)
    if h <= 0:
        return 0  # Already withered, permanent
    last = plant.get("lastWateredAt", plant.get("createdAt", now_ms))
    hours = (now_ms - last) / 3600000.0
    decay = hours * 0.5
    effective = max(0, h - decay)
    # Update plant record with decayed value
    plant["health"] = effective
    if effective <= 0:
        plant["stage"] = "withered"
    elif effective < 20:
        plant["stage"] = "seed"
    elif effective < 40:
        plant["stage"] = "sprout"
    elif effective < 70:
        plant["stage"] = "growing"
    else:
        plant["stage"] = "blooming"
    return effective

def garden_check_glowing(data):
    """Check if last 7 consecutive days each have >=1 watering. If yes, add glowing plant."""
    dw = data.get("dailyWaterings", {})
    # Check last 7 days
    t = time.time()
    consecutive = 0
    for i in range(7):
        day = time.strftime("%Y-%m-%d", time.localtime(t - (i+1)*86400))
        if dw.get(day, 0) >= 1:
            consecutive += 1
        else:
            break
    if consecutive >= 7 and not any(p.get("type") == "glowing" for p in data["plants"]):
        data["plants"].append({
            "id": "glow-" + str(int(time.time()*1000000)),
            "type": "glowing",
            "x": random.random() * 0.7 + 0.15,
            "y": random.random() * 0.5 + 0.1,
            "size": 1.0,
            "health": 100,
            "stage": "blooming",
            "variant": 0,
            "createdAt": int(time.time()*1000),
            "lastWateredAt": int(time.time()*1000),
            "wateredBy": []
        })
        return True
    return False

def garden_check_mushroom_boom(data):
    """15% chance in autumn to spawn 5 extra mushrooms. Max once per day."""
    s = garden_season()
    if s != "autumn": return False
    last = data.get("lastMushroomBoomAt", 0)
    if last > 0 and (int(time.time() * 1000) - last) < 86400000:
        return False
    if random.random() > 0.15: return False
    data["lastMushroomBoomAt"] = int(time.time() * 1000)
    for _ in range(5):
        data["plants"].append({
            "id": "boom-" + str(int(time.time()*1000000)) + "-" + str(_),
            "type": "mushroom",
            "x": random.random() * 0.8 + 0.1,
            "y": random.random() * 0.4 + 0.3,
            "size": random.random() * 0.5 + 0.3,
            "health": 40 + int(random.random() * 20),
            "stage": "growing",
            "variant": random.randint(0, 2),
            "createdAt": int(time.time()*1000),
            "lastWateredAt": int(time.time()*1000),
            "wateredBy": []
        })
    return True

def garden_enforce_cap(data, max_plants=200):
    """Remove oldest plants if over cap. Prefer withered > non-blooming."""
    plants = data["plants"]
    if len(plants) <= max_plants: return
    # Sort: withered first, then by createdAt (oldest first)
    def sort_key(p):
        is_withered = 0 if p.get("health", 0) <= 0 else 1
        is_blooming = 1 if p.get("stage") == "blooming" else 0
        return (is_withered, is_blooming, p.get("createdAt", 0))
    plants.sort(key=sort_key)
    data["plants"] = plants[-(max_plants):]

def save(posts):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(posts, f, ensure_ascii=False, indent=2)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/blog/rss":
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            articles.sort(key=lambda a: a.get("createdAt", 0), reverse=True)
            items = []
            for a in articles[:20]:
                date_str = time.strftime("%a, %d %b %Y %H:%M:%S GMT", time.gmtime(a.get("createdAt", 0) / 1000))
                items.append(f"<item><title>{a.get('title','')}</title><link>/</link><description><![CDATA[{a.get('content','')[:500]}]]></description><pubDate>{date_str}</pubDate><guid>{a.get('id','')}</guid></item>")
            rss = '<?xml version="1.0" encoding="utf-8"?><rss version="2.0"><channel><title>虞舍 · 博客</title><link>/</link><description>读书 · 写作 · 思考</description>'+''.join(items)+'</channel></rss>'
            self.send_response(200)
            self.send_header("Content-Type", "application/rss+xml; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(rss.encode())

        elif self.path.startswith("/blog/articles"):
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            self._json(articles)

        elif self.path == "/chat":
            msgs = []
            if os.path.exists(CHAT_FILE):
                with open(CHAT_FILE, "r", encoding="utf-8") as f:
                    msgs = json.load(f)
            pwd = self.headers.get("X-Admin-Password", "")
            if pwd != "ys2026":
                uid = self.headers.get("X-User-Id", "")
                msgs = [m for m in msgs if m.get("uid") == uid or (m.get("from") == "admin" and m.get("toUid") == uid)]
            self._json(msgs)
        elif self.path.startswith("/posts"):
            pwd = self.headers.get("X-Admin-Password", "")
            posts = load()
            if pwd != "ys2026":
                posts = [p for p in posts if p.get("status") in ("approved", None, "")]
            posts.sort(key=lambda p: p.get("createdAt", 0), reverse=True)
            self._json(posts)
        elif self.path == "/garden/state":
            data = garden_load()
            # Apply decay to all plants before returning
            now_ms = int(time.time() * 1000)
            for p in data["plants"]:
                garden_apply_decay(p, now_ms)
            garden_check_glowing(data)
            garden_check_mushroom_boom(data)
            garden_enforce_cap(data)
            garden_save(data)
            self._json({
                "totalVisits": data["totalVisits"],
                "plants": data["plants"],
                "season": garden_season(),
                "month": time.localtime().tm_mon
            })
        elif self.path == "/moss.html" or self.path == "/moss":
            moss_file = os.path.join(os.path.dirname(__file__), "moss.html")
            if os.path.exists(moss_file):
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                with open(moss_file, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404); self.end_headers()
        elif self.path.startswith("/moss-assets/"):
            asset_path = os.path.join(os.path.dirname(__file__), self.path.lstrip("/"))
            if os.path.exists(asset_path) and os.path.isfile(asset_path):
                ext = os.path.splitext(asset_path)[1].lower()
                mimes = {".png":"image/png",".jpg":"image/jpeg",".svg":"image/svg+xml"}
                self.send_response(200)
                self.send_header("Content-Type", mimes.get(ext, "application/octet-stream"))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                with open(asset_path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404); self.end_headers()
        else:
            self.send_response(404); self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}

        if self.path.startswith("/blog/articles/") and "/comments" in self.path:
            pid = self.path.split("/")[3]
            name = body.get("name", "匿名").strip()
            text = body.get("text", "").strip()
            if not text: self.send_response(400); self.end_headers(); return
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            for a in articles:
                if a["id"] == pid:
                    a.setdefault("comments",[]).append({"name":name,"text":text,"time":int(time.time()*1000)})
                    with open(BLOG_FILE, "w", encoding="utf-8") as f:
                        json.dump(articles, f, ensure_ascii=False)
                    self._json({"comments":a["comments"]})
                    return
            self.send_response(404); self.end_headers()

        elif self.path.startswith("/blog/articles/") and "/view" in self.path:
            pid = self.path.split("/")[3]
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            for a in articles:
                if a["id"] == pid:
                    a["views"] = a.get("views",0) + 1
                    with open(BLOG_FILE, "w", encoding="utf-8") as f:
                        json.dump(articles, f, ensure_ascii=False)
                    self._json({"views":a["views"]})
                    return
            self.send_response(404); self.end_headers()

        elif self.path == "/blog/articles":
            pwd = body.get("password", "") or self.headers.get("X-Admin-Password", "")
            if pwd != "ys2026": self.send_response(403); self.end_headers(); return
            title = body.get("title","").strip()
            content = body.get("content","").strip()
            if not title or not content: self.send_response(400); self.end_headers(); return
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            articles.append({"id":str(int(time.time()*1000000)),"title":title,"content":content,
                           "category":body.get("category",""),"tags":body.get("tags",""),
                           "createdAt":int(time.time()*1000),"views":0,"comments":[]})
            with open(BLOG_FILE, "w", encoding="utf-8") as f:
                json.dump(articles, f, ensure_ascii=False)
            self._json({"ok":True})

        elif self.path == "/chat":
            text = body.get("text", "").strip()
            if not text: self.send_response(400); self.end_headers(); return
            msgs = []
            if os.path.exists(CHAT_FILE):
                with open(CHAT_FILE, "r", encoding="utf-8") as f:
                    msgs = json.load(f)
            msgs.append({"nickname": body.get("nickname", "匿名"), "text": text,
                        "time": int(time.time()*1000), "from": "user",
                        "uid": body.get("uid", "anonymous")})
            with open(CHAT_FILE, "w", encoding="utf-8") as f:
                json.dump(msgs, f, ensure_ascii=False)
            self._json({"ok": True})

        elif self.path == "/posts":
            content = body.get("content", "").strip()
            if not content or len(content) < 2:
                self.send_response(400); self.end_headers(); return
            post = {
                "id": str(int(time.time() * 1000000)),
                "nickname": body.get("nickname", "").strip() or "匿名",
                "code": body.get("code", ""),
                "ownerId": body.get("ownerId", ""),
                "content": content,
                "tag": body.get("tag", "碎碎念"),
                "createdAt": int(time.time() * 1000),
                "likes": {}, "dislikes": {}, "reports": {},
                "comments": [], "status": "pending"
            }
            posts = load(); posts.append(post); save(posts)
            self._json(post)

        elif "/like" in self.path:
            pid = self.path.split("/")[2]
            uid = body.get("uid", "anon")
            posts = load()
            for p in posts:
                if p["id"] == pid:
                    p.setdefault("likes", {})
                    if p["likes"].get(uid): del p["likes"][uid]
                    else: p["likes"][uid] = True
                    save(posts)
                    self._json({"likes": p["likes"], "dislikes": p.get("dislikes",{})})
                    return
            self.send_response(404); self.end_headers()

        elif "/dislike" in self.path:
            pid = self.path.split("/")[2]
            uid = body.get("uid", "anon")
            posts = load()
            for p in posts:
                if p["id"] == pid:
                    p.setdefault("dislikes", {})
                    if p["dislikes"].get(uid): del p["dislikes"][uid]
                    else: p["dislikes"][uid] = True
                    save(posts)
                    self._json({"likes": p.get("likes",{}), "dislikes": p["dislikes"]})
                    return
            self.send_response(404); self.end_headers()

        elif "/report" in self.path:
            pid = self.path.split("/")[2]
            uid = body.get("uid", "anon")
            rtype = body.get("type", "其他")
            reason = body.get("reason", "")
            posts = load()
            for p in posts:
                if p["id"] == pid:
                    p.setdefault("reports", {})
                    p["reports"][uid] = {"type": rtype, "reason": reason, "time": int(time.time()*1000)}
                    save(posts)
                    self._json({"reports": len(p["reports"])})
                    return
            self.send_response(404); self.end_headers()

        elif "/comments" in self.path:
            pid = self.path.split("/")[2]
            text = body.get("text", "").strip()
            if not text: self.send_response(400); self.end_headers(); return
            reply_to = body.get("replyTo", "")
            reply_idx = body.get("replyIdx")
            posts = load()
            for p in posts:
                if p["id"] == pid:
                    comment = {
                        "nickname": body.get("nickname", "匿名"), "text": text,
                        "code": body.get("code", ""),
                        "uid": body.get("uid", ""),
                        "time": int(time.time()*1000)
                    }
                    if reply_to and reply_idx is not None:
                        comment["replyTo"] = reply_to
                        # Insert as nested reply
                        target = p.setdefault("comments", [])[reply_idx]
                        target.setdefault("replies", []).append(comment)
                    else:
                        p.setdefault("comments", []).append(comment)
                    save(posts)
                    self._json({"comments": p["comments"]})
                    return
            self.send_response(404); self.end_headers()

        elif self.path == "/chat/reply":
            pwd = body.get("password", "")
            if pwd != "ys2026": self.send_response(403); self.end_headers(); return
            text = body.get("text", "").strip()
            if not text: self.send_response(400); self.end_headers(); return
            msgs = []
            if os.path.exists(CHAT_FILE):
                with open(CHAT_FILE, "r", encoding="utf-8") as f:
                    msgs = json.load(f)
            msgs.append({"nickname": "管理员", "text": text,
                        "time": int(time.time()*1000), "from": "admin",
                        "toUid": body.get("toUid", "")})
            with open(CHAT_FILE, "w", encoding="utf-8") as f:
                json.dump(msgs, f, ensure_ascii=False)
            self._json({"ok": True})

        elif "/hide" in self.path:
            pid = self.path.split("/")[2]
            pwd = body.get("password", "")
            if pwd != "ys2026": self.send_response(403); self.end_headers(); return
            posts = load()
            for p in posts:
                if p["id"] == pid:
                    p["status"] = "approved" if p.get("status") == "hidden" else "hidden"
                    save(posts)
                    self._json({"ok": True, "status": p["status"]})
                    return
            self.send_response(404); self.end_headers()

        elif "/approve" in self.path or "/reject" in self.path:
            pid = self.path.split("/")[2]
            pwd = body.get("password", "")
            if pwd != "ys2026":
                self.send_response(403); self.end_headers(); return
            new_status = "approved" if "/approve" in self.path else "rejected"
            posts = load()
            for p in posts:
                if p["id"] == pid:
                    p["status"] = new_status
                    save(posts)
                    self._json({"ok": True, "status": new_status})
                    return
            self.send_response(404); self.end_headers()

        elif self.path == "/garden/visit":
            sid = self.headers.get("X-Session-Id", "anon")
            data = garden_load()
            now = int(time.time() * 1000)

            # Always increment total visits
            data["totalVisits"] = data.get("totalVisits", 0) + 1
            data["lastVisitAt"] = now

            # Spawn new plant with season-weighted type
            ptype = garden_random_plant_type()
            new_plant = {
                "id": str(int(time.time() * 1000000)),
                "type": ptype,
                "x": random.random() * 0.8 + 0.1,
                "y": random.random() * 0.45 + 0.25,
                "size": random.random() * 0.5 + 0.3,
                "health": 30,
                "stage": "sprout",
                "variant": random.randint(0, 2),
                "createdAt": now,
                "lastWateredAt": now,
                "wateredBy": [sid]
            }
            data["plants"].append(new_plant)
            garden_enforce_cap(data)
            garden_save(data)
            self._json({"ok": True, "totalVisits": data["totalVisits"], "newPlant": new_plant})

        elif self.path == "/garden/water":
            sid = self.headers.get("X-Session-Id", "anon")
            x = body.get("x", 0.5)
            y = body.get("y", 0.5)
            data = garden_load()
            now = int(time.time() * 1000)

            # Rate limit: track watering times per session (max 3 per minute)
            water_times = data.setdefault("_waterTimes", {})
            times = water_times.get(sid, [])
            # Clean old entries (>1 min)
            times = [t for t in times if now - t < 60000]
            if len(times) >= 3:
                self.send_response(429)
                self.end_headers()
                self.wfile.write(b'{"error":"rate limited"}')
                return
            times.append(now)
            water_times[sid] = times

            # Update dailyWaterings
            today = time.strftime("%Y-%m-%d")
            dw = data.setdefault("dailyWaterings", {})
            dw[today] = dw.get(today, 0) + 1
            # Keep only last 14 days
            keys = sorted(dw.keys())
            if len(keys) > 14:
                for k in keys[:-14]:
                    del dw[k]

            # Water plants within distance threshold
            threshold = 0.08
            watered = []
            for p in data["plants"]:
                # Apply decay first to get effective health
                garden_apply_decay(p, now)
                if p.get("health", 0) <= 0:
                    continue  # skip withered (permanent)
                dist = ((p["x"] - x) ** 2 + (p["y"] - y) ** 2) ** 0.5
                if dist <= threshold * (1 + p.get("size", 0.5)):
                    p["health"] = min(100, p["health"] + 20)
                    p["lastWateredAt"] = now
                    if p["health"] >= 70:
                        p["stage"] = "blooming"
                    elif p["health"] >= 40:
                        p["stage"] = "growing"
                    elif p["health"] >= 20:
                        p["stage"] = "sprout"
                    else:
                        p["stage"] = "seed"
                    sid_list = p.setdefault("wateredBy", [])
                    if sid not in sid_list:
                        sid_list.append(sid)
                    watered.append({"id": p["id"], "health": p["health"], "stage": p["stage"]})

            garden_save(data)
            self._json({"ok": True, "watered": watered})

        else:
            self.send_response(404); self.end_headers()

    def do_PUT(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        pwd = self.headers.get("X-Admin-Password", "") or body.get("password", "")
        if pwd != "ys2026": self.send_response(403); self.end_headers(); return

        if self.path.startswith("/blog/articles/"):
            pid = self.path.split("/")[3]
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            for a in articles:
                if a["id"] == pid:
                    if "title" in body: a["title"] = body["title"].strip()
                    if "content" in body: a["content"] = body["content"].strip()
                    if "category" in body: a["category"] = body["category"]
                    if "tags" in body: a["tags"] = body["tags"]
                    with open(BLOG_FILE, "w", encoding="utf-8") as f:
                        json.dump(articles, f, ensure_ascii=False)
                    self._json({"ok": True})
                    return
            self.send_response(404); self.end_headers()
        else:
            self.send_response(404); self.end_headers()

    def do_DELETE(self):
        if self.path.startswith("/blog/articles/"):
            pid = self.path.split("/")[3]
            pwd = self.headers.get("X-Admin-Password", "")
            if pwd != "ys2026": self.send_response(403); self.end_headers(); return
            articles = []
            if os.path.exists(BLOG_FILE):
                with open(BLOG_FILE, "r", encoding="utf-8") as f:
                    articles = json.load(f)
            articles = [a for a in articles if a["id"] != pid]
            with open(BLOG_FILE, "w", encoding="utf-8") as f:
                json.dump(articles, f, ensure_ascii=False)
            self._json({"ok": True})
        elif self.path.startswith("/posts/"):
            pid = self.path.split("/")[2]
            pwd = self.headers.get("X-Admin-Password", "")
            if pwd != "ys2026":
                self.send_response(403); self.end_headers(); return
            posts = load()
            posts = [p for p in posts if p["id"] != pid]
            save(posts)
            self._json({"ok": True})
        else:
            self.send_response(404); self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Admin-Password, X-Session-Id")
        self.end_headers()

    def _json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def log_message(self, format, *args): pass

HTTPServer(("0.0.0.0", 8089), Handler).serve_forever()
