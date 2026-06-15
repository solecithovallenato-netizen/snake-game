# Snake Game + 手势实验

单文件 HTML5 贪吃蛇游戏 + Three.js 手势交互实验合集，部署在 GitHub Pages。

**在线地址**：[solecithovallenato-netizen.github.io/snake-game](https://solecithovallenato-netizen.github.io/snake-game/)

## 文件

| 文件 | 说明 |
|------|------|
| `index.html` | 贪吃蛇游戏（~3640行），含登录/好友/排行榜/成就/音乐 |
| `particles.html` | 手势粒子交互（Three.js + MediaPipe Hands） |
| `gesture-sandbox.html` | 手势物理沙盒——FPS 视角 + 双手捏合抓起/扔出 3D 物体（Three.js + Cannon-es） |
| `gesture-photo.html` | 照片→3D 场景——上传照片，AI 识别物体自动生成 3D 实体场景 |
| `animations.js` | UI 动画工具包——弹簧物理、stagger/sequence、CSS/Canvas/Three.js 通用 |
| `animations-demo.html` | 动画工具包交互演示页 |
| `campus-wall.html` | 广白墙——校园匿名墙（发帖/评论/点赞/回复/举报/PWA） |
| `campus-wall-admin.html` | 广白墙管理面板（审核/隐藏/聊天回复） |
| `wall_api.py` | 广白墙后端——HTTP API on :8089，JSON 文件存储 |
| `yushe-blog.html` | 虞舍博客——全功能单文件博客（111篇文章，分类/标签云/归档/友链/热榜/时间胶囊/鸟瞰/海报） |
| `moss.html` | 数字苔藓——活的网页花园（642行Canvas、6种植物、四季昼夜、浇水互动） |
| `moss-assets/` | 花园素材——23张水彩手绘植物PNG |
| `blog-local/` | 博客后端（Docker Compose + SSL） |
| `vision.py` | 视觉工具——智谱 GLM-4V-Flash（免费）图片描述/JSON场景输出 |
| `worker/photo_backend.py` | 照片分析后端（FastAPI + Qwen-VL + Depth Anything） |
| `worker/tencent_scf.py` | 腾讯云 SCF Python Web 函数（网易云 API 代理） |

## 快速开始

```bash
# 本地运行
python -m http.server 8080
# 浏览器打开 http://localhost:8080
```

## 部署

```bash
git add index.html && git commit -m "update" && git push
```

推送后 GitHub Pages 自动部署，30 秒生效。

## 技术栈

- **前端**：原生 HTML/CSS/JS，Three.js，Cannon-es，MediaPipe Hands
- **后端服务**：Firebase Realtime Database（排行榜/好友/ID 系统）
- **登录**：Firebase Anonymous Auth（游客）+ QQ OAuth
- **音乐**：腾讯云 SCF 代理网易云 API → `music.126.net` CDN
- **后端**：Python FastAPI（wall_api :8089 / photo_backend :8765）、Docker Compose（博客）

## 更多

详细开发文档见 [CLAUDE.md](CLAUDE.md)。

虞舍·数字苔藓 项目完整交付物：[`作业/最终交付物/`](作业/最终交付物/)。

## 博客 & 花园

- 虞舍博客：http://10.42.78.75
- 数字苔藓：http://10.42.78.75/moss
- 花园 API：http://10.42.78.75/garden/state
