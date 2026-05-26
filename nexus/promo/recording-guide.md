# Nexus 方案 B 录制指南

---

## 🎥 录制准备

```
屏幕分辨率：1920x1080（16:9 竖屏裁切用 1080x1920 安全区）
终端：Windows Terminal（深色主题 + 半透明）
字体：Cascadia Code / Fira Code，字号 14-16
编辑器：VS Code（深色主题）
录制工具：OBS / 系统自带录屏
```

---

## 🎬 逐镜录制清单

### 镜头 1（0-2s）：标题卡

> **不需要录制**，后期加黑底白字

```
第一行：这 是  Claude  Code  最 强 插 件
第二行（小字）：N E X U S
```

---

### 镜头 2（2-5s）：一键初始化

**录制内容**：终端

```bash
# 进入一个演示项目
cd ~/demo-project

# 执行初始化（把输出完整录下来）
/nexus:init
```

**期望画面**：
```
Nexus — Project Initialization
==============================
Project root: /home/user/demo-project
Project name: demo-project

Tech stack detection:
  Language: typescript
  Framework: nextjs

[OK] GitHub CLI: /usr/bin/gh
[OK] jq (JSON): /usr/bin/jq
[OK] post-commit hook installed

======================================
Nexus initialized successfully!
```

**后期叠加**：大字 "1. 一键接入项目"

---

### 镜头 3（5-9s）：上下文装配

**录制内容**：终端

```bash
/nexus:context "login timeout bug"
```

**期望画面**（选最精彩的片段，只留 2-3 秒）：
```
Nexus: Assembling context for "login timeout bug"
========================================

[Git Context]
  Related ticket references:
    f3a2b1c fix(#3421): login timeout in production

[GitHub Issues]
  #3421 [open] Login timeout under high concurrency (@alice)
  #2891 [closed] Session expiry too short (@bob)

[Architecture Decisions]
  ADR: ADR-0042-jwt-vs-redis-session-storage

[Impact Analysis]
  Directly related files:
    src/auth/login.ts (5 imports)
    src/middleware/session.ts (3 imports)
```

**后期叠加**：大字 "2. 上下文自动装配"

---

### 镜头 4（9-13s）：安全校验

**录制内容**：先在 VS Code 里写一段有漏洞的代码，然后运行 guardrails

```bash
/nexus:guardrails file src/bad-example.ts
```

或者直接用 diff 模式：
```bash
/nexus:guardrails diff
```

**期望画面**：
```
Nexus Guardrails Check
======================
Mode: changed files only

Checking: src/api/users.ts
  [ERROR] security/no-sql-injection L23: SQL injection: string interpolation
          -> const query = `SELECT * FROM users WHERE id = ${userId}`
  [ERROR] security/no-hardcoded-secrets L5: Hardcoded secret detected
          -> const API_KEY = "sk-abc123def456ghi789jkl"
  [WARN]  quality/no-n-plus-1 L42: N+1 query pattern
          -> users.forEach(async (u) => { u.posts = await db.find(...) })

======================
Guardrails check complete — 7 issue points found
```

**后期叠加**：大字 "3. 实时拦截安全漏洞"，红框高亮 ERROR 行

---

### 镜头 5（13-18s）：知识图谱

**录制内容**：终端，快速展示几个子命令

```bash
# 先展示热度图（最直观）
/nexus:graph hotspots

# 然后展示专家地图
/nexus:graph experts
```

**期望画面**（截取精华）：
```
Module Hotspots (last 3 months)
================================
   47 changes  src/auth/login.ts        ####################
   38 changes  src/api/middleware.ts     #################
   31 changes  src/components/Form.tsx   ##############

Module Expert Map (>=5 commits)
==========================================
  src/auth/login.ts         -> alice (47 commits, 3 weeks ago)
  src/api/middleware.ts     -> bob   (38 commits, 1 week ago)
  src/components/Form.tsx   -> alice (31 commits, 2 days ago)
```

**后期叠加**：大字 "4. 自动构建知识图谱"，数据行滚动效果

---

### 镜头 6（18-23s）：PR 自动驾驶

**录制内容**：先做一个小改动（比如修个 typo），commit，然后

```bash
# 先预览
/nexus:pr preview

# 展示输出后，如果胆子大可以直接 create
# /nexus:pr create
```

**期望画面**（截取 PR Body 精华）：
```
Nexus PR Preview
====================

Change Analysis
===============
  Files: 3
  Lines: +12 / -3

  Risk level: LOW — 3 files changed

Reviewer Recommendations
========================
  @alice — touched 2 files in this diff
  @bob   — touched 1 files in this diff

Related Decision Context
========================
  ADR-0042-jwt-vs-redis-session-storage
```

**后期叠加**：大字 "5. PR 自动驾驶 + 自动推荐 Reviewer"

---

### 镜头 7（23-28s）：仪表盘

**录制内容**：终端

```bash
/nexus:dashboard
```

**期望画面**（最炫的镜头，全景展示）：
```
  Nexus — Team Intelligence Dashboard
  ====================================
  Project: demo-project

  --- Core Metrics ---
  Total files              247
  Contributors (6mo)       8
  Architecture decisions   4
  Open PRs                 3

  --- Module Hotspots ---
  src/auth/login.ts               47  ####################
  src/api/middleware.ts            38  #################

  --- Contributor Activity ---
  alice                  89 commits  #####################
  bob                    62 commits  ###############
```

**后期叠加**：大字 "6. 团队智能仪表盘，一屏全览"

---

### 镜头 8（28-32s）：GitHub 页面

**录制内容**：浏览器打开 GitHub 项目页

```
https://github.com/用户名/nexus
```

**画面**：README + Star 按钮 + 文件列表

**后期叠加**：大字 "GitHub 开源，免费使用"  
Star 按钮处加动画效果（星星飞入）

---

### 镜头 9（32-35s）：引流页

> 后期制作

```
┌──────────────────────────┐
│                          │
│      🧠  N E X U S      │
│                          │
│     GitHub 搜索           │
│   Nexus Claude Code      │
│                          │
│    链接在评论区 👇        │
│                          │
│    点个收藏，别刷丢了 ⭐   │
│                          │
└──────────────────────────┘
```

---

## ✂️ 剪辑要点

| 要素 | 说明 |
|------|------|
| **转场** | 硬切为主，0.3s 缩放过渡 |
| **字幕** | 每个镜头 1 句大字（白字黑描边），顶部或底部 |
| **BGM** | 电子/科技类，鼓点密集，135-150 BPM |
| **音效** | 键盘敲击声 + 终端打字音效（可选） |
| **速度** | 镜头 2-7 每个 3-5 秒，信息密度要高 |
| **色彩** | 保持终端原色（绿/白/红在深色背景上），字幕用白色 |

---

## 🖥️ 需要提前准备的 Demo 环境

```bash
# 1. 创建一个演示项目（或用一个真实项目）
mkdir ~/demo-project && cd ~/demo-project
git init
npm init -y

# 2. 创建几个有代表性的源文件
mkdir -p src/auth src/api src/components

# 3. 造一些 git 历史（让知识图谱有数据）
echo "export const login = () => {}" > src/auth/login.ts
git add . && git commit -m "feat(#3421): add login module"

echo "export const middleware = () => {}" > src/api/middleware.ts
git add . && git commit -m "fix(#2891): session timeout"

# 4. 造一个有漏洞的示例文件
cat > src/bad-example.ts << 'EOF'
// BAD: hardcoded key
const API_KEY = "sk-abc123def456ghi789jkl";

// BAD: SQL injection
const query = `SELECT * FROM users WHERE id = ${userId}`;

// BAD: N+1 query
users.forEach(async (u) => {
  u.posts = await db.posts.find({ userId: u.id })
});
EOF
git add . && git commit -m "add bad example for demo"

# 5. 创建几个 ADR（让决策系统有内容）
/nexus:decision "Migrate session storage from Redis to JWT"
/nexus:decision "Adopt TypeScript strict mode"

# 6. 初始化 Nexus
/nexus:init
```

---

## ⏱️ 30 秒时间线

```
00:00 ─ 标题卡
00:02 ─ 一键初始化（3s）
00:05 ─ 上下文装配（4s）
00:09 ─ 安全校验（4s）
00:13 ─ 知识图谱（5s）
00:18 ─ PR 自动驾驶（5s）
00:23 ─ 仪表盘（5s）
00:28 ─ GitHub 页面（4s）
00:32 ─ 引流页 + 二维码（3s）
00:35 ─ 结束
```
