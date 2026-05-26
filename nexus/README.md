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
