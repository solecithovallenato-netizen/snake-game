# QQ 登录 + 游客登录 — 设计规格

## 目标

为贪吃蛇游戏添加 QQ OAuth 登录和游客模式，实现跨设备身份同步和数据持久化。

## 登录流程

### 入口

开始画面提供两个选项：
- **QQ 登录**（金色主按钮）→ 弹出 QQ OAuth 授权窗口
- **游客登录**（次级文字链接）→ 一键进入游戏，使用 Firebase 匿名身份

### QQ 登录流程

```
开始画面 → 点"QQ 登录"
  → 调用 QC.Login() 弹出 QQ 授权窗口
  → 用户在 QQ 页面点"同意"
  → 回调拿到 access_token + openid
  → 调用 QQ API 获取头像 + 昵称
  → 检查本机是否有匿名战绩（snakeGameHistory 非空且 uid 非当前 openid）
    → 有 → 弹窗："检测到本机已有 X 局记录，是否合并到当前账号？"
      → 合并 → 匿名数据迁移到 QQ openid 下，成功后删匿名数据
      → 放弃 → 直接切换到 QQ 身份
    → 无 → 直接登录完成
  → 玩家栏显示 QQ 头像 + 昵称
  → 所有后续操作使用 QQ openid 作为 uid
```

### 游客登录流程

```
开始画面 → 点"游客登录"
  → 保持现有 Firebase Anonymous Auth 流程
  → 玩家自填昵称（和现在一样）
  → 数据用匿名 uid 存储
```

### 游客后期绑定 QQ

```
玩家栏 → 点击 → 历史战绩弹窗 → "绑定 QQ"按钮
  → 触发 QQ 登录流程（同上）
  → 数据自动合并
```

## 技术方案

### QQ 登录：纯前端 QQ JS SDK

- 加载 `https://connect.qq.com/qc_jssdk.js`
- 调用 `QC.Login()` 弹窗授权（window.open + postMessage 回调）
- SDK 返回 `openid` + `access_token`
- 使用 `access_token` 调用 QQ OpenAPI 获取用户昵称和头像：
  - `GET https://graph.qq.com/user/get_user_info?access_token=XXX&oauth_consumer_key=APP_ID&openid=XXX`
- 无后端，纯静态站点兼容

QQ JS SDK 使用 `QC.Login()` 的 popup 模式，回调由 SDK 自动处理，**不需要**额外创建回调页面。

### QQ 互联配置

| 项 | 值 |
|---|---|
| 网站名称 | 贪吃蛇 |
| 网站地址 | https://solecithovallenato-netizen.github.io |
| 回调域 | solecithovallenato-netizen.github.io |
| APP ID | （用户从 QQ 互联获取后填入） |

### 数据模型

```
用户身份（localStorage）:
  snakeAuth   → { platform: 'qq'|'guest', uid, info? }

Firebase RTDB:
  /users/<uid>/displayName  → 显示名
  /users/<uid>/avatar       → QQ 头像 URL
  /users/<uid>/platform     → 'qq' | 'guest'
  /scores/<pushId>/uid      → 身份 uid

localStorage:
  snakeGameHistory  → 战绩数组（本地缓存）
  snakePlayerName   → 当前昵称
  snakeHighScore    → 最高分
```

### 数据合并逻辑

游客数据迁移到 QQ 账号时：
1. 本机 `snakeGameHistory` 通过 `submitToFirebase(uid=qq_openid)` 重新提交到 QQ uid 下
2. 本机 `snakeHighScore` 取 max(本地最高, QQ 云端最高) 写入
3. 迁移成功后清除旧的匿名 auth 信息

## 文件变更

全部改动在 `index.html` 单文件内：

1. **开始画面 HTML** — QQ 登录按钮 + 游客登录链接
2. **QQ SDK 加载** — `<script src="https://connect.qq.com/qc_jssdk.js">`
3. **QQ 登录逻辑** — 新增 `qqLogin()`, `handleQQCallback()`
4. **合并弹窗逻辑** — 新增 `showMergePrompt()`, `migrateData()`
5. **玩家栏更新** — 加载 QQ 头像为 `<img>`
6. **数据模型** — auth 存储增加 platform 字段

## 兼容性

- 现有功能不受影响（排行榜、战绩、游戏核心）
- 现有 Firebase 数据结构不变（scores 表保持通用，uid 字段已有）
- 游客模式行为和当前完全一致
- QQ SDK 仅在用户点击 QQ 登录时才加载

## 配置

代码中使用占位符 `APP_ID`，用户从 QQ 互联获取后填入即可激活。
