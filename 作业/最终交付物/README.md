# 虞舍 · 数字苔藓 —— 最终交付物

> 个人独立博客 + 活的网页花园  
> 交付日期：2026-07-05 | 小组：实训第4组  
> 访问：http://10.42.78.75 | http://10.42.78.75/moss

---

## 目录结构

```
最终交付物/
├── README.md
│
├── PPT/
│   ├── 答辩PPT.pptx          ← 13页原生可编辑PPT（暖棕+金配色）
│   ├── 答辩PPT大纲.md        ← 答辩大纲 + 策略 + FAQ
│   └── generate_ppt.py       ← PPT生成脚本（python-pptx）
│
├── 技术文档/
│   ├── 01-项目需求分析.md
│   ├── 02-系统架构设计.md
│   ├── 03-部署实施手册.md
│   └── 04-运维操作手册.md
│
├── 项目管理/
│   ├── 02-策划任务书.md
│   ├── 04-进度计划表.md
│   ├── 07-会议纪要-01-项目启动.md
│   ├── 07-会议纪要-02-基础设施就绪.md
│   ├── 07-会议纪要-03-应用上线.md
│   ├── 07-会议纪要-04-中期复盘.md
│   └── 华为项目管理模板-已填写.xlsx
│
└── 运维脚本/
    ├── docker-compose.yml
    ├── nginx.conf
    ├── prometheus.yml
    ├── deploy.sh
    └── backup.sh
```

---

## 项目简介

**虞舍博客** — 个人独立博客，111 篇原创文章，单文件 HTML 实现全文搜索、标签云、归档、热榜、RSS、时间胶囊、鸟瞰图、海报生成。

**数字苔藓** — 活的网页花园，Canvas 2D 程序化渲染，6 种植物随四季生长枯萎，昼夜循环，浇水互动，萤火虫/蜗牛/蝴蝶生态。

**后端 API** — Python 单文件 HTTP Server，RESTful 设计，JSON 文件持久化，博客 CRUD + 花园状态管理 + 浇水限流。

---

## 技术栈

```
前端    → HTML5 + CSS3 + Canvas 2D，单文件架构，零 JS 框架
后端    → Python http.server (564行)，JSON 文件存储
博客    → yushe-blog.html，111 篇文章，4 分类，RSS
花园    → moss.html，642 行 Canvas，6 种植物，四季昼夜
代理    → Nginx 1.25，反向代理 + 静态文件服务
容器    → Podman，校内 CentOS 服务器
AI      → 智谱 GLM-4V + Qwen-VL + Depth Anything V2
```

---

## 系统访问

| 服务 | 地址 |
|------|------|
| 博客首页 | http://10.42.78.75 |
| 数字苔藓 | http://10.42.78.75/moss |
| 后端 API | http://10.42.78.75:8089 |
| 花园状态 | http://10.42.78.75/garden/state |

---

## 项目亮点

1. **单文件全栈** — 博客 + 后端 + 花园均单文件实现，无框架、无构建工具
2. **活的页面** — 数字苔藓会随时间和互动生长/枯萎，重新定义"网页"
3. **程序化美学** — 6 种植物纯 Canvas 绘制，18 层渲染管线，四季昼夜自然过渡
4. **AI 驱动** — 智谱/通义视觉识别、深度图生成，融入实际功能模块
5. **极致简单** — scp + nohup 部署，零外部依赖，JSON 文件即数据库

---

## 部署方式

```bash
# 上传文件
scp yushe-blog.html moss.html wall_api.py root@10.42.78.75:/opt/blog/nginx/

# 重启后端
ssh root@10.42.78.75 "kill \$(pgrep -f wall_api.py); cd /opt/blog/nginx && nohup python3 wall_api.py &"

# 重载 Nginx
ssh root@10.42.78.75 "kill -HUP \$(pgrep -f 'nginx.*master')"
```
