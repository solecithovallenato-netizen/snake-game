# 数字苔藓 (Digital Moss) — 设计方案

> 一个活着的网页。每次访问都在土壤中长出新生命。访客浇水照料，被爱的植物开花，被遗忘的枯萎。它不依赖多人同时在线——时间本身就是创作。

## 技术栈

- **前端**: 单文件 HTML（`moss.html`），Canvas 2D + requestAnimationFrame
- **后端**: 复用 `wall_api.py`，新增 `/garden/*` 路由
- **持久化**: `/opt/blog/data/garden.json`，最多保留 200 株植物
- **素材**: GPT 生成 PNG 精灵（水彩/手绘风格）+ Canvas 渲染合成

---

## 1. 页面 UI

- **全屏 Canvas** 作为主体，覆盖整个视口
- **顶部半透明栏**: 🌿 数字苔藓 · 访问 N 次 · 季节图标 · 关于
- **关于弹窗**: 解释花园机制（访问播种、浇水照料、季节变化、稀有事件）
- **右下角指示器**: 当前季节 + 植物总数 + 盛开数量
- **浇水**: 点击/触摸 Canvas 降下粒子雨滴，被浇到的植物抖动+发光

---

## 2. 数据模型

```json
{
  "totalVisits": 42,
  "lastVisitAt": 1718400000000,
  "dailyWaterings": {"2026-06-10": 3, "2026-06-11": 5, "2026-06-12": 1},
  "plants": [
    {
      "id": "abc123",
      "type": "fern",
      "x": 0.35,
      "y": 0.72,
      "size": 0.8,
      "health": 65,
      "stage": "growing",
      "variant": 2,
      "createdAt": 1718300000000,
      "lastWateredAt": 1718350000000,
      "wateredBy": ["sess_abc"]
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 唯一标识，时间戳+随机 |
| `type` | string | 植物类型: fern/flower/mushroom/grass/succulent/vine |
| `x, y` | float | 归一化坐标 (0-1)，渲染时映射到 Canvas 像素 |
| `size` | float | 归一化尺寸 (0.3-1.0)，初始随机 |
| `health` | int | 0-100，自然衰减 -0.5/小时，浇水 +20 |
| `stage` | string | seed → sprout → growing → blooming → withered |
| `variant` | int | 同类型形态变体 (0-2) |
| `createdAt` | int | 创建时间戳 ms |
| `lastWateredAt` | int | 最后浇水时间戳 ms |
| `wateredBy` | []string | 浇水者列表（去重引用） |

### 容量控制

- `dailyWaterings`: `{"YYYY-MM-DD": count}` 记录每天浇水次数，用于稀有事件判定，只保留最近 14 天
- 植物上限 200 株
- 超出时移除 `health <= 0` 中最老的
- 如果无枯萎植物，移除最老的非开花植物

---

## 3. 核心机制

### 3.1 访问播种

- 页面加载 → POST `/garden/visit`
- 去重: `sessionStorage._moss_visited`，同一 session 不重复计数
- 播种: 随机位置 (x, y) + 按季节加权随机类型 + 随机变体
- 季节加权: 春(花60% 草20% 其他各5%)、夏(蕨30% 藤蔓20% 草20% 其他各10%)、秋(蘑菇40% 草30% 其他各10%)、冬(多肉40% 草40% 其他各5%)
- 最多每次 1 株（避免刷访问），初始 health=30, stage=sprout（~2.5 天无人照料也保持可见）

### 3.2 浇水照料

- 点击 Canvas → 计算归一化坐标 → POST `/garden/water` body: `{x, y}`
- 后端: 计算点击位置与所有植物的距离（归一化空间，阈值 0.08）
- 被浇到的植物: health += 20（上限 100），stage 自动晋升
- 返回被浇到的植物列表 → 前端触发粒子雨滴 + 植物弹跳动画
- 同一 session 每分钟最多浇水 3 次（防刷）

### 3.3 自然衰减

- 每小时 health -= 0.5
- 衰减在前端计算（取 `lastWateredAt` 和当前时间差），渲染时实时反映
- 健康归零后不删除，stage → withered，变成灰色干枯形态
- 枯萎植物在 Canvas 上显示为灰度 + 低透明度

### 3.4 生长阶段

| stage | health 范围 | 视觉表现 |
|-------|------------|---------|
| seed | 1-19 | 缩放 0.1x，几乎看不见 |
| sprout | 20-39 | 缩放 0.3x，微光 |
| growing | 40-69 | 缩放 0.6x，正常 |
| blooming | 70-100 | 缩放 1x，光晕粒子 |
| withered | 0 | 灰度 + 透明度 0.4，保留在原地 |

> **注意**: health=0 是唯一触发 withered 的条件。health 从高跌落时 stage 会回退（如 blooming→growing），体现植物"变虚弱"的过程。一旦 health=0 则永久枯萎。

---

## 4. 植物类型（6 种）

| 类型 | GPT 素材 | 形态 | 颜色基调 | 适合季节 |
|------|---------|------|---------|---------|
| 🌿 蕨类 `fern` | 3 张变体 PNG | 卷曲螺旋叶子 | 翠绿→深绿 | 夏 |
| 🌸 花 `flower` | 3 张变体 PNG | 圆形花瓣簇 | 粉/白/黄随机 | 春 |
| 🍄 蘑菇 `mushroom` | 3 张变体 PNG | 圆顶菌盖 + 细柄 | 红/棕/白 | 秋 |
| 🌱 草 `grass` | 3 张变体 PNG | 簇状叶片 | 嫩绿→枯黄 | 全年 |
| 🪴 多肉 `succulent` | 3 张变体 PNG | 莲座层叠 | 灰绿/紫边 | 冬 |
| 🌿 藤蔓 `vine` | 3 张变体 PNG | 蜿蜒触须 | 深绿 | 春/夏 |

每张 PNG：200×200，透明背景，水彩/手绘风格。

生长阶段通过 Canvas `scale()` + `opacity` 实现，枯萎通过 `filter: grayscale(100%)` + 透明度降低实现，不需要多阶段素材。

---

## 5. 季节系统

按真实月份自动切换：

| 月份 | 季节 | 天空色 | 环境色 | 特殊效果 |
|------|------|--------|--------|---------|
| 3-5 | 春 | `#d4e8d0` | 嫩绿 | 花 growth ×2 |
| 6-8 | 夏 | `#e8f0d0` | 深翠 | 全部 growth +30% |
| 9-11 | 秋 | `#f0e0c8` | 暖橙 | 蘑菇爆发，草渐黄 |
| 12-2 | 冬 | `#e0e4e8` | 灰褐 | growth -50%，雪花粒子 |

### 稀有事件

- **发光植物**: 连续 7 天 `dailyWaterings` 每天 ≥ 1 次浇水 → 自动生成 1 株特殊发光植物（type=`glowing`，永久 blooming + 金色粒子）。`dailyWaterings` 只保留最近 14 天记录。
- **蘑菇爆发**: 秋季（9-11月）随机概率 15%/天，触发时额外生成 5 株蘑菇

---

## 6. 渲染架构

### 6.1 Canvas 层级（从下到上）

1. **天空渐变** — 季节色
2. **云/雾气** — GPT 云朵 PNG，缓慢漂移
3. **远山/地平线** — Canvas 路径填充
4. **泥土地面** — GPT 纹理平铺
5. **植物** — PNG 精灵绘制，按 y 坐标排序（高处先画）
6. **粒子雨水** — 浇水时触发，Canvas 粒子从点击位置下落
7. **UI 层** — 顶部栏 + 右下角指示器（HTML DOM overlay）

### 6.2 动画循环

```
requestAnimationFrame → 
  updateClouds(dt) →
  updateRainParticles(dt) →
  updatePlantAnimations(dt) →
  updateSnowParticles(dt, season) →
  drawAll() →
  drawUI()
```

- 植物动画: 浇水后 `scale` 从 1.0 → 1.15 → 1.0（弹簧回弹 400ms）
- 雨滴粒子: 从点击位置向下加速，渐隐消失
- 雪花粒子: 冬季随机飘落，wind + gravity

---

## 7. API 设计

所有端点在 `wall_api.py` 中新增，前缀 `/garden`。

### GET /garden/state

返回全部植物 + 元信息。
```json
{
  "totalVisits": 42,
  "plants": [...],
  "season": "summer",
  "month": 6,
  "rareEvent": null
}
```

### POST /garden/visit

注册访问。后端检查同一 session（`X-Session-Id` header）在 1 小时内是否已计数。

请求: 空 body
响应:
```json
{
  "ok": true,
  "totalVisits": 43,
  "newPlant": { "id": "...", "type": "fern", "x": 0.42, "y": 0.73, ... }
}
```

### POST /garden/water

浇水。后端检查 session 限制（每分钟最多 3 次）。

请求: `{ "x": 0.35, "y": 0.72 }`
响应:
```json
{
  "ok": true,
  "watered": [
    { "id": "abc", "health": 85, "stage": "blooming" },
    { "id": "def", "health": 45, "stage": "growing" }
  ]
}
```

### Session 标识

前端生成随机 session ID 存 `sessionStorage._moss_sid`，每次请求带 `X-Session-Id` header。

---

## 8. 素材清单（GPT 生成）

| 素材 | 数量 | 尺寸 | 格式 | 说明 |
|------|------|------|------|------|
| 蕨类 fern | 3 | 200×200 | PNG 透明 | 水彩风格，不同卷曲形态 |
| 花 flower | 3 | 200×200 | PNG 透明 | 粉色/白色/黄色各一 |
| 蘑菇 mushroom | 3 | 200×200 | PNG 透明 | 红盖/棕盖/白盖 |
| 草 grass | 3 | 200×200 | PNG 透明 | 簇状，不同方向 |
| 多肉 succulent | 3 | 200×200 | PNG 透明 | 莲座状，不同层数 |
| 藤蔓 vine | 3 | 200×200 | PNG 透明 | 蜿蜒曲线，不同弯度 |
| 泥土纹理 ground | 1 | 800×600 | PNG | 暖棕色调土壤 |
| 云朵 cloud | 3 | 200×100 | PNG 透明 | 蓬松白云，不同形状 |
| 雨滴 drop | 1 | 32×32 | PNG 透明 | 水滴形状 |
| 季节图标 | 4 | 64×64 | SVG/PNG | 春🌸夏☀️秋🍂冬❄️ |

**素材风格要求**: 水彩 + 手绘感，柔和暖色调，与博客暖灰底 + 金色强调协调。不要扁平矢量风，要有笔触质感。

---

## 9. 文件规划

| 文件 | 操作 | 说明 |
|------|------|------|
| `moss.html` | 新建 | 单文件前端（~400 行 HTML+CSS+JS） |
| `wall_api.py` | 修改 | 新增 `/garden/*` 路由（~80 行） |
| `moss-assets/` | 新建目录 | 存放 GPT 生成的素材 |

---

## 10. 与现有系统的关系

- 部署到 `10.42.78.75`，nginx 添加 `moss.html` 路由，或直接在首页链接
- 博客顶部可加一句「🌿 去看看花园」链接
- 与博客共享服务器和 Python 进程，无额外部署成本
- 数据文件独立（`garden.json`），不影响博客数据
