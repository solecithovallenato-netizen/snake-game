# Snake Game

单文件 HTML5 贪吃蛇游戏，极简高级感风格（暖灰黑底+金色强调），部署到 GitHub Pages。

## 当前状态（会话启动自动注入）

- 分支: !`git branch --show-current`
- 最新提交: !`git log -1 --oneline`
- 工作区: !`git status --short | head -8`

## 文件结构

| 文件 | 用途 |
|------|------|
| `index.html` | 贪吃蛇游戏，单文件 HTML+CSS+JS（~3640行） |
| `particles.html` | 实验性手势粒子交互页（Three.js + MediaPipe Hands） |
| `gesture-sandbox.html` | 手势物理沙盒——FPS 视角 + 双手独立捏合抓取/扔出（Three.js + Cannon-es + MediaPipe Hands + AnimKit） |
| `gesture-photo.html` | 照片→3D 场景——上传照片，Qwen-VL 识别物体+深度，自动搭建 3D 实体场景 |
| `animations.js` | UI 动画工具包——弹簧物理、stagger、sequence，可驱动 CSS/Canvas/Three.js |
| `animations-demo.html` | 动画工具包交互演示页 |
| `vendor/` | Three.js 0.157 + Cannon-es 0.20 本地副本（绕过 jsdelivr CDN 国内慢的问题） |
| `worker/photo_backend.py` | 照片分析后端——色彩分割 + Qwen-VL 空间分析 + Depth Anything 深度图（FastAPI，端口 8765） |
| `campus-wall.html` | 广白墙——校园匿名墙（发帖/评论/点赞/回复/举报/PWA） |
| `campus-wall-admin.html` | 广白墙管理面板（审核/隐藏/聊天回复，密码 ys2026） |
| `wall_api.py` | 博客+花园+广白墙后端——HTTP API on :8089，JSON 文件存储（文章CRUD、评论、RSS、/garden/* 花园端点） |
| `worker/tencent_scf.py` | 腾讯云 SCF Python Web 函数（网易云 API 代理） |
| `worker/depth_anything_v2/` | Depth Anything V2 模型源码（从 GitHub 手动下载） |
| `.gitignore` | 排除不相关文件 |
| `yushe-blog.html` | 虞舍博客——全功能单文件博客（111篇文章、分类/标签云/归档/友链/热榜/时间胶囊/鸟瞰/海报） |
| `moss.html` | 数字苔藓——活的网页花园（642行Canvas、6种植物、四季昼夜、浇水互动、萤火虫/蜗牛/蝴蝶） |
| `GPT_ASSET_GUIDE.md` | GPT 素材生成指南——23 张水彩风植物 PNG 的 prompt + 部署流程 |
| `moss-assets/` | 花园素材——23张水彩手绘 PNG（GPT 生成） |
| `blog-local/` | 博客本地部署（Docker Compose + SSL + 数据持久化） |
| `vision.py` | 视觉工具——调用智谱 GLM-4V-Flash（免费）返回图片描述，也支持 JSON 场景输出 |
| `ppt-master/` | PPT 生成工具（hugohe3/ppt-master），AI 驱动原生可编辑 PPTX |
| `wrangler.toml` | Cloudflare Workers 配置 |

## UI 动画工具包 (animations.js)

Spring 物理动画库，无依赖，`<script>` 引入即可用。可驱动 CSS DOM / Canvas / Three.js。

```js
// Canvas/Three.js 程序化弹簧
const sv = AnimKit.spring(0, AnimKit.SpringPresets.snappy);
sv.set(100);
function loop(dt) { sv.update(dt); obj.x = sv.value; }

// DOM 元素弹簧动画（可中断、手势速度交接）
AnimKit.to(el, { scale: 1, y: 0, opacity: 1 }, { preset: 'ui' });
AnimKit.stagger('.card', { y: 0, opacity: 1 }, { from: { y: 20, opacity: 0 }, each: 60 });
await AnimKit.sequence([[hero, { y: 0 }], [sub, { opacity: 1 }]]);
```

演示页：`animations-demo.html`（5 组交互示例：弹簧预设/级联/拖拽/编排/进退场）。

## 游戏特性

- 25×25 大地图，随难度3-12组随机障碍物（每组2-4格）
- 奖励五角星10-20秒出现（随难度），+30分，7秒后消失
- 音效：Web Audio API 生成（吃食物/奖励/死亡），无外部文件
- 暂停（P/Esc）、开局倒计时（3-2-1-GO）
- 移动端：dpad+滑动，Canvas自适应缩放
- 登录系统：Firebase Anonymous Auth（游客）+ QQ OAuth 登录
- 玩家卡片：左栏顶部显示头像+昵称+ID+平台，点击查看历史战绩（最近20局，统计总/最高/均分）
- 首次进入设定昵称，之后自动使用，支持改名
- 好友系统：搜 ID/昵称添加好友，好友请求确认，好友排行榜 tab
- 管理员：ID 000001 为管理员，好友榜 = 全局榜

## 成就系统

27 项成就（分数/连击/局数/食物/道具/难度/隐藏），存在 `localStorage` + `snakeStats` 后台统计。详见 `index.html` 源码。

## 背景音乐系统

播放器在顶栏居中区域：🎵 歌名 - 歌手 | ⏮ ▶ ⏭ | 进度条。状态存 `localStorage.snakeMusicMuted`。

### 网易云歌单（主要）
通过腾讯云 SCF 代理网易云 API，获取用户歌单（65首，37首可播）。音频通过 fetch+blob 下载后播放，URL 过期时自动刷新。

- SCF 地址：`https://1436731599-m40ke0j257.ap-guangzhou.tencentscf.com`
- 端点：`/songs`（全量歌单+URL）、`/urls?ids=1,2,3`（刷新URL）
- CDN：`music.126.net`，支持 HTTPS 和 CORS
- 歌单：用户 "This王玥" 收藏（ID `6923484606`）
- 部署：Python3.7 Web 函数，SCF 控制台 zip 上传，源码见 `worker/tencent_scf.py`

### 大厅音乐（lobby，降级）
当歌单不可用时，播放 lo-fi 暖色和弦垫子（Dm7-Am7-Gmaj7-Fmaj7），三角波 + 超低音。音量 ~0.035。

### 游戏音乐（game，降级）
85 BPM lo-fi 节奏：kick（0.06）+ hi-hat（0.025）+ 正弦波贝斯（0.04）+ 电话风铃旋律（0.025）。

### 视觉特效
- **蛇身发光**：`shadowBlur=8`，金色光晕，拖尾残影（5帧）
- **死亡震动**：CSS `@keyframes shake`，300ms 屏幕抖动
- **蛇身消散**：死亡后蛇身逐节淡出（600ms）

## 大厅布局

单栏居中布局（`index.html` `.lobby-left`），响应式适配移动端（<768px）：

**标题行** `.lobby-header`：左「贪 吃 蛇」+ 右玩家卡片
**顶栏** `.top-row`（flex 横排）：🏆 排行榜按钮 | 🎵 播放器（歌名/控制/进度） | 👥 好友按钮 | 得分+最高分

- 🏆 打开 `lbModalBg` 弹窗 → 全局排行榜 + 重置排行榜
- 🎵 播放器：⏮ 上一首 │ ▶/⏸ 播放/暂停 │ ⏭ 下一首。歌名+歌手居中显示。进度条可点击跳转。
- 👥 打开 `friendsModalBg` 弹窗 → 好友排名 + 添加好友按钮
- 玩家卡片在标题行右上角，点击打开个人资料 + 历史战绩 + 成就

## 难度系统

三档难度选择（`DIFFICULTY` 对象，`index.html`），登录后显示选择器，存 `localStorage.snakeDifficulty`：

| 难度 | 初始速度 | 极速 | 障碍组 | 特殊 |
|------|---------|------|--------|------|
| 🐣 休闲 | 180ms | 100ms | 3 | 穿墙 |
| 🐍 经典 | 130ms | 50ms | 8 | 无 |
| 💀 地狱 | 100ms | 35ms | 12 | 高速曲线 |

- 穿墙模式：蛇撞墙后从对面穿出（`head.x = ((head.x % COLS) + COLS) % COLS`）
- 加速曲线：每 N 分加速一次，各档独立参数（`startSpeed/minSpeed/speedStep/speedEvery`）

## 登录系统

两种身份模式，存储在 `localStorage.snakeAuth`：

| 字段 | 说明 |
|------|------|
| `platform` | `'guest'`（匿名）或 `'qq'`（QQ 登录） |
| `qqInfo.openid` | QQ 用户的唯一标识，用作 Firebase 提交的 uid |
| `qqInfo.avatar` | QQ 头像 URL |
| `qqInfo.nickname` | QQ 昵称 |

- **游客**：Firebase Anonymous Auth，自填昵称，数据用 Firebase anonymous uid
- **QQ 登录**：加载 QQ JS SDK（`connect.qq.com`），QC.Login() 弹窗授权 → 获取 openid + token → 拉取头像昵称
- **数据合并**：游客绑定 QQ 时，检测本机 `snakeGameHistory`，弹窗确认后迁移到 QQ openid 下
- `getAuthToken()` 优先使用 QQ openid 作为 `currentUid`，确保提交时 uid 一致
- QQ SDK 动态加载（`loadQQSDK()`），仅在点击 QQ 登录时请求

QQ 登录 APP_ID: `1904073755`（`index.html` `QQ_APP_ID` 常量）。

## 部署

```bash
git add index.html && git commit -m "update" && git push
```

推送后 GitHub Pages 自动部署，30 秒内生效。

**站点地址**：https://solecithovallenato-netizen.github.io/snake-game/

## 排行榜

Firebase Realtime Database 全局排行榜（`snake-leaderboard-c6832`）。
- 每人仅保留一条最高分记录（uid 作为 key，PUT 写入）
- 提交失败时存入 localStorage pending 队列，下次打开排行榜自动重试同步
- 离线时显示本地记录，状态行提示连接状态
- `submitToFirebase` 超时 5 秒，失败不阻塞游戏

## 好友系统

Firebase 数据路径：

| 路径 | 结构 | 说明 |
|------|------|------|
| `/meta/nextId` | `number` | 自增 ID 计数器，初始 1 |
| `/userIdIndex/<id>` | `{uid, name, avatar}` | 数字 ID → 用户信息 |
| `/friendRequests/<toUid>/<fromUid>` | `{fromName, fromAvatar, time}` | 待处理好友请求 |
| `/friends/<uid>/<friendUid>` | `{name, avatar, addedAt}` | 好友关系 |

- 好友弹窗内搜索 ID 或昵称 → 发送好友请求 → 对方在玩家信息弹窗中确认/拒绝
- 玩家卡片红点提醒待处理请求
- 好友榜从 `/friends/<myUid>` 过滤

## ID 系统

- 首次进入自动获取 `000001` 格式 ID，存 localStorage `snakeUserId`
- `ensureUserId()` **不需要 Firebase Auth**——`/meta` 和 `/userIdIndex` 路径使用公开读写规则
- Firebase RTDB Rules 分层：`/meta`、`/userIdIndex` 公开写；`/scores`、`/friends` 仍需 auth
- 管理员 `ADMIN_USER_IDS = ['000001']`，好友榜显示全体玩家

## 踩坑警示

- 桌面端代理（XxYun/Clash `127.0.0.1:7892`）会拦截 Google 服务；Clash bypass 在国内无效——Google 域名直连反而被墙
- **不要** bypass `*.googleapis.com` 和 `*.firebaseio.com`——这些必须走代理，否则 Firebase Auth 失败
- Firebase Auth 不可用时，ID 分配、排行榜读取仍正常（公开规则），但好友系统和排行榜提交需 VPN
- Cloudflare `*.workers.dev` 域名在国内被 GFW 墙，需绑定自定义域名
- jsdelivr CDN 同步 `<script>` 阻塞页面加载导致白屏 → 核心依赖放 `vendor/` 本地引用，MediaPipe 动态加载

## 手势物理沙盒 (gesture-sandbox.html)

单文件 Three.js + Cannon-es + MediaPipe Hands 应用，~1050 行。手势捏合抓取/扔出 3D 物体。

### 控制方式
- **FPS 相机**：点击画面锁定鼠标指针（准星出现），WASD 移动、空格上升、Ctrl 下降、滚轮调速度
- **退出锁定**：快速连按 3 次 Esc 确认退出（防止误触）；单次 Esc 后点击画面即可重锁
- **双手交互**：两只手都能独立捏合抓取不同物体；每只手有金色光标环+亮点指示捏合位置
- **物体生成**：键盘 1-6 或底部工具栏「生成」按钮

### 技术架构
- **相机-手部投射**：手势骨架实时投射在 FPS 相机前方 2.2m 的交互平面上（7×5.5 单位），随视角移动
- **弹簧力抓取**：抓取物体时用弹簧力（刚度 18）跟随而非瞬移，物体在指尖下方自然悬挂，释放后以手部速度扔出
- **接近光晕**：手靠近物体 0.65 单位内时物体发橙金色光，光标环放大
- **物理引擎**：Cannon-es，6 种材质，重力 -12，地面 Z=-2.0
- **手势追踪**：MediaPipe Hands 动态加载（不阻塞页面初始化），2 手 21 关键点，5 种手势（pinch/fist/open/relaxed）
- **依赖**：Three.js + Cannon-es 本地 vendor/ 副本（避免 jsdelivr CDN 在国内阻塞页面加载）
- **UI**：Apple Liquid Glass 风格 + AnimKit 弹簧动画 + 粒子特效
- **启动**：`python -m http.server 8080` → `http://localhost:8080/gesture-sandbox.html`

### gesture-photo.html

照片→3D 场景重建。上传照片后，Qwen-VL（百炼 API）识别物体类型/颜色/大小/位置，自动生成对应 3D 几何体（盒子/球体/圆柱/平面）。深度图由 Depth Anything V2（PyTorch，~25MB，VPN 下载）生成，用于 3D 高度场曲面。手势追踪可选（默认关闭，避免 jsdelivr CDN 耗尽浏览器连接）。FPS 视角 + WASD 移动。

**技术栈**：Three.js + Cannon-es + MediaPipe Hands（可选）+ AnimKit

**后端依赖**：FastAPI、PyTorch、torchvision、OpenCV、Pillow、Qwen-VL API（阿里云百炼）

```bash
# 启动后端（端口 8765，含 CORS）
python worker/photo_backend.py
# 前端由 HTTP server 托管（端口 8080）或直接打开 gesture-photo.html
```

设计文档：`docs/superpowers/specs/2026-05-27-gesture-physics-photo-design.md`

## 博客 + 花园部署

虞舍博客 + 数字苔藓部署在校内服务器 `10.42.78.75`：

```bash
ssh root@10.42.78.75                                    # 免密登录
scp yushe-blog.html moss.html root@10.42.78.75:/opt/blog/nginx/  # 部署前端
scp wall_api.py root@10.42.78.75:/opt/blog/nginx/       # 部署后端
scp -r moss-assets/ root@10.42.78.75:/opt/blog/nginx/   # 部署花园素材
ssh root@10.42.78.75 "kill \$(pgrep -f wall_api.py); cd /opt/blog/nginx && nohup python3 wall_api.py &>/dev/null &"  # 重启后端
ssh root@10.42.78.75 "kill -HUP \$(pgrep -f 'nginx.*master')" # 重载 Nginx
```

- **博客**: nginx :80 `/` → `yushe-blog.html`，API `/api/` → proxy `:8089`
- **花园**: `/moss` → proxy `:8089/moss`，`/garden/` → proxy `:8089/garden/`，`/moss-assets/` → proxy `:8089/moss-assets/`
- **后端**: `wall_api.py` on :8089，含博客 CRUD + 花园 state/visit/water
- **数据**: JSON 文件 `/opt/blog/data/blog_articles.json` + `garden.json`
- **Nginx 配置**: `/opt/blog/nginx/nginx.conf`（Podman 容器内）
- 文章 111 篇（2026-06-12 批量创建），花园每访问一次播种一株植物

## 视觉工具 (vision.py)

使用智谱 GLM-4V-Flash 免费视觉模型，API key 存 `settings.local.json` 的 `ZHIPU_API_KEY`。
```bash
python vision.py photo.jpg                              # 默认描述
python vision.py --flash photo.jpg "图里有什么文字？"   # 免费模型 + 自定义 prompt
python vision.py --json photo.jpg                       # JSON 场景描述（给 gesture-photo 用）
```

## CC-Connect 微信桥接

v1.3.3-beta.4，ilink 通道长轮询，Windows schtasks 开机自启。CLI: `cc-connect daemon <status|logs|restart|stop>` / `cc-connect weixin setup`。

## Claude Code 实践

- **会话**: 长会话质量下降 → `/clear`；多文件修改 → Plan Mode；70% 上下文 → `/compact`
- **子代理**: code-reviewer + security-scanner 并行审查代码变更；doc-maintainer 同步文档
- **Hooks**: PreToolUse 拦截危险命令；PostToolUse 自动 git add
- **Skills**: Superpowers 套件——brainstorming（强制门禁）→ writing-plans → subagent-driven / TDD → code-review → finish
