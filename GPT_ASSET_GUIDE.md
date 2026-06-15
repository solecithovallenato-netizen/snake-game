# 数字苔藓 — GPT 素材生成与部署指南

> 给 Codex/GPT 的完整指令，按顺序执行即可。

---

## 一、素材清单

所有图片放在 `moss-assets/` 目录下。共 **23 张 PNG**（18 植物 + 5 环境）。

### 1.1 植物精灵（18 张）

每种植物 3 个变体（variant 0, 1, 2），命名格式：`{类型}_{变体编号}.png`

| 文件名 | 类型 | 形态描述 | 主色调 |
|--------|------|---------|--------|
| `fern_0.png` | 蕨类 | 卷曲螺旋叶，右侧展开 | 翠绿 `#4a7c3f` |
| `fern_1.png` | 蕨类 | 卷曲螺旋叶，左侧展开，更大 | 深绿 `#3d6b34` |
| `fern_2.png` | 蕨类 | 螺旋叶，中心对称展开 | 嫩绿 `#5a8c4f` |
| `flower_0.png` | 花 | 5 瓣花，圆形簇 | 粉色 `#e8a0b0` |
| `flower_1.png` | 花 | 6 瓣花，层叠 | 白色 `#f5f0e8` |
| `flower_2.png` | 花 | 小花朵簇，3 朵一组 | 黄色 `#f0d878` |
| `mushroom_0.png` | 蘑菇 | 圆顶菌盖，粗柄 | 红色 `#c44b3b` |
| `mushroom_1.png` | 蘑菇 | 扁平菌盖，细柄 | 棕色 `#8b6f4e` |
| `mushroom_2.png` | 蘑菇 | 小圆顶，矮胖 | 白色 `#e8d8c8` |
| `grass_0.png` | 草 | 3 片弯刀形叶片，左倾 | 嫩绿 `#6b8c42` |
| `grass_1.png` | 草 | 4 片叶片，右倾 | 翠绿 `#7a9a4a` |
| `grass_2.png` | 草 | 5 片叶片，扇形散开 | 深绿 `#5a7a32` |
| `succulent_0.png` | 多肉 | 4 层莲座，紧凑 | 灰绿 `#7a9a7a` |
| `succulent_1.png` | 多肉 | 5 层莲座，展开 | 灰绿+紫边 `#8aaa8a` |
| `succulent_2.png` | 多肉 | 3 层莲座，小株 | 浅绿 `#9aba9a` |
| `vine_0.png` | 藤蔓 | S 形蜿蜒，带小圆叶 | 深绿 `#3d6b34` |
| `vine_1.png` | 藤蔓 | 螺旋缠绕，小叶对生 | 翠绿 `#4a7c3f` |
| `vine_2.png` | 藤蔓 | 弧形弯曲，尖端卷须 | 嫩绿 `#5a8c4f` |

### 1.2 环境素材（4 张）

| 文件名 | 描述 | 尺寸 |
|--------|------|------|
| `ground.png` | 暖棕色调土壤纹理，适合平铺 | 800×600 |
| `cloud_0.png` | 蓬松白云，小朵 | 200×100 |
| `cloud_1.png` | 蓬松白云，中朵 | 200×100 |
| `cloud_2.png` | 蓬松白云，大朵拉长 | 200×100 |
| `drop.png` | 水滴形状，半透明蓝色 | 32×32 |

---

## 二、GPT 生成参数（通用）

每张图都用以下通用要求：

```
画风：水彩手绘风格，柔和笔触质感，不是扁平矢量。半透明背景。
色调：暖色调为主，与暖灰米色底(#fbf8f3)协调。
构图：植物居中偏下（根部在画面底部1/3处），上方留白。
边缘：自然毛边，不要硬切边界。
输出：PNG，透明背景。
```

---

## 三、逐张 GPT Prompt（可直接复制使用）

### fern_0.png
```
A single watercolor-style fern plant with a curling spiral frond unfurling to the right. 
Deep green tones (#4a7c3f). Hand-painted brush texture, soft edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### fern_1.png
```
A single watercolor-style fern plant with a curling spiral frond unfurling to the left, 
larger and fuller than typical. Dark green tones (#3d6b34). 
Hand-painted brush texture, soft edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### fern_2.png
```
A single watercolor-style fern plant with symmetrical spiral fronds spreading outward 
from center. Light green tones (#5a8c4f). 
Hand-painted brush texture, soft edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### flower_0.png
```
A single watercolor-style flower with 5 rounded pink petals in a circular cluster.
Pink tone (#e8a0b0), small yellow center. Thin green stem.
Hand-painted brush texture, soft petal edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### flower_1.png
```
A single watercolor-style flower with 6 layered white petals, delicate and airy.
White/cream tone (#f5f0e8), subtle beige center. Thin green stem.
Hand-painted brush texture, soft petal edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### flower_2.png
```
A cluster of 3 small watercolor-style yellow flowers on thin branching stems.
Yellow tone (#f0d878), tiny dark centers.
Hand-painted brush texture, soft edges.
Centered in frame, roots near bottom third. Transparent background.
PNG 200x200.
```

### mushroom_0.png
```
A single watercolor-style mushroom with a rounded dome cap and thick stem.
Red cap (#c44b3b) with a few white spots. Cream-colored stem.
Hand-painted brush texture, soft edges.
Centered in frame, base near bottom third. Transparent background.
PNG 200x200.
```

### mushroom_1.png
```
A single watercolor-style mushroom with a flat wide cap and slender stem.
Brown cap (#8b6f4e), pale stem. Earthy tones.
Hand-painted brush texture, soft edges.
Centered in frame, base near bottom third. Transparent background.
PNG 200x200.
```

### mushroom_2.png
```
A single watercolor-style mushroom, small round cap, short chubby stem.
White/pale cream cap (#e8d8c8), subtle tan gills.
Hand-painted brush texture, soft edges.
Centered in frame, base near bottom third. Transparent background.
PNG 200x200.
```

### grass_0.png
```
A clump of 3 curved blade-like grass leaves leaning left, watercolor style.
Fresh green (#6b8c42). Hand-painted brush strokes, soft tips.
Centered in frame, roots near bottom third. Transparent background.
PNG 200x200.
```

### grass_1.png
```
A clump of 4 curved blade-like grass leaves leaning right, watercolor style.
Vivid green (#7a9a4a). Hand-painted brush strokes, soft tips.
Centered in frame, roots near bottom third. Transparent background.
PNG 200x200.
```

### grass_2.png
```
A clump of 5 curved blade-like grass leaves fanning outward, watercolor style.
Deep green (#5a7a32). Hand-painted brush strokes, soft tips.
Centered in frame, roots near bottom third. Transparent background.
PNG 200x200.
```

### succulent_0.png
```
A compact rosette succulent with 4 layers of overlapping pointed leaves, watercolor style.
Muted grey-green (#7a9a7a). Hand-painted brush texture, soft edges.
Centered in frame, base near bottom third. Transparent background.
PNG 200x200.
```

### succulent_1.png
```
An open rosette succulent with 5 layers of spreading pointed leaves, watercolor style.
Grey-green with subtle purple tips (#8aaa8a). Hand-painted brush texture.
Centered in frame, base near bottom third. Transparent background.
PNG 200x200.
```

### succulent_2.png
```
A small rosette succulent with 3 compact layers, watercolor style.
Light green (#9aba9a). Hand-painted brush texture, soft edges.
Centered in frame, base near bottom third. Transparent background.
PNG 200x200.
```

### vine_0.png
```
A single winding vine tendril in S-curve shape with small round leaves, watercolor style.
Deep green (#3d6b34). Hand-painted brush texture, soft edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### vine_1.png
```
A single spiral-twisting vine tendril with small paired leaves, watercolor style.
Vivid green (#4a7c3f). Hand-painted brush texture, soft edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### vine_2.png
```
A single arching vine tendril with a curling tip tendril, watercolor style.
Light green (#5a8c4f). Hand-painted brush texture, soft edges.
Centered in frame, root near bottom third. Transparent background.
PNG 200x200.
```

### ground.png
```
A seamless-tileable warm brown soil texture, watercolor style.
Earthy brown tones (#8b6f4e, #a08060, #7a6040). Soft brush strokes.
Subtle variation in tone, no hard edges. Suitable for tiling.
800x600 PNG.
```

### cloud_0.png
```
A small fluffy white cloud, watercolor style.
Soft white with subtle grey-blue shadows. Wispy edges.
Transparent background. 200x100 PNG.
```

### cloud_1.png
```
A medium fluffy white cloud, watercolor style.
Soft white with subtle grey-blue shadows. Wispy edges.
Transparent background. 200x100 PNG.
```

### cloud_2.png
```
A large elongated fluffy white cloud, watercolor style.
Soft white with subtle grey-blue shadows. Stretched horizontally.
Wispy edges. Transparent background. 200x100 PNG.
```

### drop.png
```
A small water droplet shape, semi-transparent light blue.
Simple teardrop silhouette. Soft highlight on top edge.
Transparent background. 32x32 PNG.
```

---

## 四、生成后操作

### 4.1 确认数量

23 张 PNG（18 植物 + 5 环境），清单：

```
fern_0.png  fern_1.png  fern_2.png
flower_0.png  flower_1.png  flower_2.png
mushroom_0.png  mushroom_1.png  mushroom_2.png
grass_0.png  grass_1.png  grass_2.png
succulent_0.png  succulent_1.png  succulent_2.png
vine_0.png  vine_1.png  vine_2.png
ground.png
cloud_0.png  cloud_1.png  cloud_2.png
drop.png
```

### 4.2 批量重命名（如果需要）

如果 GPT 输出的文件名不匹配，用以下规则重命名：

```
fern 变体 0/1/2  → fern_0.png / fern_1.png / fern_2.png
flower 变体      → flower_0.png / flower_1.png / flower_2.png
mushroom 变体    → mushroom_0.png / mushroom_1.png / mushroom_2.png
grass 变体       → grass_0.png / grass_1.png / grass_2.png
succulent 变体   → succulent_0.png / succulent_1.png / succulent_2.png
vine 变体        → vine_0.png / vine_1.png / vine_2.png
土壤纹理          → ground.png
云朵              → cloud_0.png / cloud_1.png / cloud_2.png
水滴              → drop.png
```

### 4.2 放入项目

将所有 23 张 PNG 复制到本项目的 `moss-assets/` 目录：
```bash
# 假设 GPT 输出在 ~/Downloads/moss-sprites/
cp ~/Downloads/moss-sprites/*.png moss-assets/
```

### 4.3 验证文件

```bash
ls moss-assets/*.png | wc -l
# 应该输出: 23
```

### 4.4 部署到服务器

```bash
# 上传素材到服务器
scp -r moss-assets/*.png root@10.42.78.75:/opt/blog/nginx/moss-assets/

# 同步到 nginx 容器可访问的路径
ssh root@10.42.78.75 "cp /opt/blog/nginx/moss-assets/*.png /usr/share/nginx/html/moss-assets/ 2>/dev/null; ls /opt/blog/nginx/moss-assets/ | wc -l"
# 应该输出: 23（或 24 含 .gitkeep）

# 重载 nginx
ssh root@10.42.78.75 "kill -HUP \$(pgrep -f 'nginx.*master')"
```

### 4.5 验证部署

打开 http://10.42.78.75/moss-assets/fern_0.png — 应该能看到图片。

然后打开 http://10.42.78.75/moss — 植物应该从程序化形状自动切换为水彩精灵。

---

## 五、效果对比

| 状态 | 植物外观 |
|------|---------|
| 素材缺失 | 程序化 Canvas 绘制的几何形状（彩色块/弧线） |
| 素材就绪 | 水彩手绘风格 PNG 精灵，笔触质感 |

`moss.html` 会自动检测素材是否加载成功，素材缺失时降级为程序绘制，无需改代码。
