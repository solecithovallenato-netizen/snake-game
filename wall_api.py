from http.server import HTTPServer, BaseHTTPRequestHandler
import json, os, time

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
