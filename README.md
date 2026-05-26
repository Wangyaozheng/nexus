[README.md](https://github.com/user-attachments/files/28275750/README.md)
# Nexus —— Claude Code 团队集体智能引擎

Nexus 将 Claude Code 从单兵 AI 升级为团队 AI。它能自动整合项目上下文、强制执行代码规范、记录架构决策、构建知识图谱，并驱动 PR 自动化。

## 为什么需要 Nexus？

每次 Claude Code 会话开始时都会失忆——你需要手动花费 10-20 分钟输入上下文。Nexus 通过以下方式解决这个问题：

- **自动整合上下文**：在你提问之前，就从 Jira、Linear、Slack、Git 和 Figma 中拉取信息
- **记住团队决策**：以架构决策记录（ADR）的形式保存知识，让经验超越个人而留存
- **强制执行护栏**：将团队来之不易的经验教训编码为自动化检查
- **映射你的代码库**：谁拥有什么、什么依赖什么、bug 集中在哪些地方
- **生成有实质内容的 PR**：不仅仅是差异对比，还包括决策背景、风险分析和审阅者建议

## 快速开始

```bash
# 在你的项目根目录下
/nexus:init

# 为某个任务整合上下文
/nexus:context "修复登录超时 bug"

# 对照团队规范检查代码
/nexus:guardrails

# 生成知识图谱
/nexus:graph

# 创建架构决策记录
/nexus:decision "将会话管理从 Redis 迁移到 JWT"

# 生成带有完整背景的 PR
/nexus:pr preview
/nexus:pr create
```

## 安装

1. 将 `nexus` 目录复制到 `~/.claude/skills/nexus/`
2. 重启 Claude Code（或等待它自动发现新技能）
3. 在任何项目中运行 `/nexus:init`

```bash
git clone https://github.com/user/nexus.git /tmp/nexus
cp -r /tmp/nexus ~/.claude/skills/nexus
```

## 功能

### 1. 上下文整合
在你开始工作前，自动从已连接的系统拉取上下文：

- **Git**：最近的贡献者、相关文件、工单引用
- **GitHub Issues**：通过 `gh` CLI 自动搜索相关问题
- **Jira/Linear**：拉取工单详情（需配置环境变量）
- **Slack**：搜索团队讨论（需配置 webhook）
- **ADR 历史**：查找相关的历史架构决策

### 2. 实时护栏

在代码进入代码评审之前就发现问题：

| 规则 | 严重级别 | 捕获内容 |
|------|----------|-----------|
| `no-sql-injection` | error | SQL 查询中的字符串拼接 |
| `no-xss` | error | `innerHTML`、`dangerouslySetInnerHTML`、`eval()` |
| `no-hardcoded-secrets` | error | 源码中的 API 密钥、密码、令牌 |
| `no-n-plus-1` | warning | `forEach` + `await find()` 模式 |
| `no-unhandled-promise` | warning | 缺少错误处理的异步函数 |
| `no-console` | info | 遗留的 `console.log` 语句 |
| `no-todo-without-ticket` | info | 没有工单引用的 TODO 注释 |

可通过 `.claude/nexus.yml` 扩展自定义规则。

### 3. 架构决策记录

Nexus 会自动检测你何时在做架构决策，并生成结构化的 ADR：

- 触发关键词如“选择”、“决定”、“方案”、“架构”
- 触发跨越 3 个以上文件的变更
- 生成包含背景、替代方案、影响和风险的完整 ADR 模板

### 4. 知识图谱

构建代码库的活地图：

- **依赖图**：哪些模块引入了什么
- **专家地图**：谁最了解每个模块（基于 Git 历史）
- **热点**：变更最频繁的文件
- **脆弱性分析**：最常出现在 bug 修复中的文件
- **协作网络**：哪些人共同修改相同文件

### 5. PR 自动驾驶

生成能完整讲述故事的 PR：

- 从提交信息中自动提取关联工单
- 基于文件归属历史推荐审阅者
- 包含相关的 ADR 背景
- 添加风险评估（文件数量、模块影响）
- 检查 CODEOWNERS 中要求的必要审阅者

## 项目配置

在项目根目录下创建 `.claude/nexus.yml`：

```yaml
project:
  name: "my-project"
  type: "web"

context:
  sources:
    github_issues:
      enabled: true
    jira:
      enabled: false  # 需设置 JIRA_API_TOKEN 和 JIRA_DOMAIN 环境变量
    slack:
      enabled: false
      channels: ["#engineering"]

guardrails:
  enabled_rules:
    - security/no-sql-injection
    - security/no-xss
    - quality/no-n-plus-1

knowledge_graph:
  auto_update: true
  expert_threshold: 5

decisions:
  auto_detect: true

pr:
  auto_reviewer: true
  include_decision_context: true
```

## 命令

| 命令 | 功能 |
|------|------|
| `/nexus:init` | 初始化项目配置 |
| `/nexus:context <query>` | 整合项目上下文 |
| `/nexus:guardrails [diff\|full\|file]` | 运行护栏检查 |
| `/nexus:decision <title>` | 创建架构决策记录（ADR） |
| `/nexus:graph [deps\|experts\|hotspots\|full]` | 生成知识图谱 |
| `/nexus:pr [preview\|create\|draft]` | PR 自动驾驶 |
| `/nexus:dashboard` | 显示团队分析仪表板 |

## 环境要求

- **必需**：Git、Bash 4+
- **推荐**：[GitHub CLI](https://cli.github.com/)（`gh`）、[jq](https://jqlang.github.io/jq/)
- **可选**：Jira API 访问、Linear API 访问、Slack webhook

## 贡献指南

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

MIT — 详见 [LICENSE](LICENSE)。
# Nexus — Team Collective Intelligence Engine for Claude Code

Nexus upgrades Claude Code from a solo AI to a team AI. It automatically assembles project context, enforces code standards, captures architectural decisions, builds knowledge graphs, and drives PR automation.

## Why Nexus?

Every Claude Code session starts with amnesia — you spend 10-20 minutes feeding context manually. Nexus solves this by:

- **Auto-assembling context** from Jira, Linear, Slack, Git, and Figma before you even ask
- **Remembering team decisions** as Architecture Decision Records (ADRs) so knowledge survives beyond individuals
- **Enforcing guardrails** that encode your team's hard-won lessons as automated checks
- **Mapping your codebase** — who owns what, what depends on what, where the bugs cluster
- **Generating PRs with substance** — not just a diff, but decision context, risk analysis, and reviewer recommendations

## Quick Start

```bash
# In your project root
/nexus:init

# Assemble context for a task
/nexus:context "fix login timeout bug"

# Check code against team standards
/nexus:guardrails

# Generate a knowledge graph
/nexus:graph

# Create an architecture decision record
/nexus:decision "Migrate from Redis to JWT for sessions"

# Generate a PR with full context
/nexus:pr preview
/nexus:pr create
```

## Installation

1. Copy the `nexus` directory to `~/.claude/skills/nexus/`
2. Restart Claude Code (or it auto-discovers new skills)
3. Run `/nexus:init` in any project

```bash
git clone https://github.com/user/nexus.git /tmp/nexus
cp -r /tmp/nexus ~/.claude/skills/nexus
```

## Capabilities

### 1. Context Assembly
Automatically pulls context from connected systems before you start working:

- **Git**: Recent contributors, related files, ticket references
- **GitHub Issues**: Auto-searches for related issues via `gh` CLI
- **Jira/Linear**: Pulls ticket details (when configured via env vars)
- **Slack**: Searches team discussions (when webhook configured)
- **ADR History**: Finds related past architectural decisions

### 2. Live Guardrails

Catches issues *before* they reach code review:

| Rule | Severity | What It Catches |
|------|----------|-----------------|
| `no-sql-injection` | error | String interpolation in SQL queries |
| `no-xss` | error | `innerHTML`, `dangerouslySetInnerHTML`, `eval()` |
| `no-hardcoded-secrets` | error | API keys, passwords, tokens in source |
| `no-n-plus-1` | warning | `forEach` + `await find()` patterns |
| `no-unhandled-promise` | warning | Async functions without error handling |
| `no-console` | info | Leftover `console.log` statements |
| `no-todo-without-ticket` | info | TODO comments without ticket references |

Extend with custom rules in `.claude/nexus.yml`.

### 3. Architecture Decision Records

Nexus auto-detects when you're making architectural decisions and generates structured ADRs:

- Triggers on keywords like "choose", "decide", "approach", "architecture"
- Triggers on changes spanning 3+ files
- Generates a complete ADR template with context, alternatives, impact, and risks

### 4. Knowledge Graph

Builds a living map of your codebase:

- **Dependency graph**: Which modules import what
- **Expert map**: Who knows each module best (based on git history)
- **Hotspots**: Most actively changed files
- **Fragility analysis**: Files most often involved in bug fixes
- **Collaboration network**: Who works on the same files

### 5. PR Autopilot

Generates PRs that tell a complete story:

- Auto-extracts related tickets from commit messages
- Recommends reviewers based on file ownership history
- Includes relevant ADR context
- Adds risk assessment (file count, module impact)
- Checks CODEOWNERS for required reviewers

## Project Configuration

Create `.claude/nexus.yml` in your project root:

```yaml
project:
  name: "my-project"
  type: "web"

context:
  sources:
    github_issues:
      enabled: true
    jira:
      enabled: false  # Set JIRA_API_TOKEN + JIRA_DOMAIN env vars
    slack:
      enabled: false
      channels: ["#engineering"]

guardrails:
  enabled_rules:
    - security/no-sql-injection
    - security/no-xss
    - quality/no-n-plus-1

knowledge_graph:
  auto_update: true
  expert_threshold: 5

decisions:
  auto_detect: true

pr:
  auto_reviewer: true
  include_decision_context: true
```

## Commands

| Command | Function |
|---------|----------|
| `/nexus:init` | Initialize project configuration |
| `/nexus:context <query>` | Assemble project context |
| `/nexus:guardrails [diff\|full\|file]` | Run guardrails check |
| `/nexus:decision <title>` | Create an ADR |
| `/nexus:graph [deps\|experts\|hotspots\|full]` | Generate knowledge graph |
| `/nexus:pr [preview\|create\|draft]` | PR autopilot |
| `/nexus:dashboard` | Show team analytics dashboard |

## Requirements

- **Required**: Git, Bash 4+
- **Recommended**: [GitHub CLI](https://cli.github.com/) (`gh`), [jq](https://jqlang.github.io/jq/)
- **Optional**: Jira API access, Linear API access, Slack webhook

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
