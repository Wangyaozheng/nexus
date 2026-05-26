---
name: nexus
version: 1.0.0
description: |
  Nexus — the team collective intelligence engine for Claude Code.
  Automatically assembles project context (Jira/Linear + Slack + Git + Figma),
  enforces code standards in real-time, auto-captures architectural decisions (ADR),
  builds team knowledge graphs, and drives PR autopilot.
  Upgrades Claude Code from a solo AI to a team AI.

  Five core capabilities:
  1. Context Assembly — auto-pull requirements, discussions, designs from external systems
  2. Live Guardrails — intercept known bug patterns and violations before code generation
  3. Decision Logging — auto-detect architectural decisions and generate ADRs
  4. Knowledge Graph — map code dependencies, experts, module hotspots
  5. PR Autopilot — generate PRs with decision context and risk analysis

  Triggers: nexus, context assembly, knowledge graph, guardrails, decision log, pr autopilot, ADR
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - WebFetch
  - WebSearch
  - AskUserQuestion
triggers:
  - nexus
  - 团队智能
  - 自动上下文
  - auto context
  - knowledge graph
  - 知识图谱
  - decision log
  - guardrails
  - pr autopilot
  - ADR
---

# Nexus — Team Collective Intelligence Engine

## Quick Start

When the user invokes "nexus", run the initialization check:

```bash
NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
mkdir -p "$NEXUS_HOME"/{projects,decisions,graphs,guardrails,sessions}
echo "NEXUS_HOME=$NEXUS_HOME"
echo "NEXUS_VERSION=1.0.0"

# Detect current project
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "REPO: $_REPO"

# Load project config
_PROJECT_CONFIG="$NEXUS_HOME/projects/${_REPO}.json"
if [ -f "$_PROJECT_CONFIG" ]; then
  echo "PROJECT_CONFIG: loaded"
else
  echo "PROJECT_CONFIG: not found (run /nexus:init to set up)"
fi

# Check external tool availability
command -v gh >/dev/null 2>&1 && echo "GITHUB_CLI: available" || echo "GITHUB_CLI: missing"
command -v jq >/dev/null 2>&1 && echo "JQ: available" || echo "JQ: missing"
```

---

## Architecture Overview

```
User Request
    │
    ▼
┌─────────────────────────────────────────────────┐
│              Nexus Engine                        │
│                                                  │
│  Phase 1: Context Assembly → gather all context  │
│  Phase 2: Decision Reference → find ADRs/patterns│
│  Phase 3: Guardrails Check → validate rules      │
│  Phase 4: Knowledge Graph → assess impact        │
│  Phase 5: Execute Task → generate code/PR/ADR    │
│  Phase 6: Auto-Persist → save decisions + graph  │
└─────────────────────────────────────────────────┘
```

---

## Phase 1: Context Assembly

### 1.1 Auto-detect task intent

Extract key information from the user's request:

```
User input: "fix the login timeout bug"

Extracted:
  - Keywords: login, timeout, bug
  - Module inference: auth, session, middleware
  - Intent type: bugfix
```

### 1.2 Git context

```bash
# Recent ticket references in commit messages
git log --oneline -20 --grep='#' 2>/dev/null | head -10

# Find files matching keywords (safe pathspec approach)
for kw in auth login session; do
  git ls-files "*${kw}*" 2>/dev/null | head -5
done | sort -u

# File hotspot analysis — top contributors
git log --format="%an" --since="3 months ago" 2>/dev/null | sort | uniq -c | sort -rn | head -5
```

### 1.3 GitHub Issues

```bash
if command -v gh >/dev/null 2>&1; then
  gh issue list --search "$QUERY" --state all --limit 10 \
    --json number,title,state,author 2>/dev/null | \
    jq -r '.[] | "  #\(.number) [\(.state)] \(.title)"' 2>/dev/null
fi
```

### 1.4 Jira (if configured via env vars)

```bash
if [ -n "${JIRA_API_TOKEN:-}" ] && [ -n "${JIRA_DOMAIN:-}" ]; then
  curl -s -H "Authorization: Bearer $JIRA_API_TOKEN" \
    "https://${JIRA_DOMAIN}/rest/api/3/search?jql=text~'${QUERY}'&maxResults=5" 2>/dev/null | \
    jq '{total: .total, issues: [.issues[] | {key, summary: .fields.summary}]}' 2>/dev/null
fi
```

### 1.5 Assembled context output

```json
{
  "task": "fix login timeout",
  "related_tickets": ["#3421", "#2891"],
  "related_files": ["src/auth.ts", "src/session.ts"],
  "recent_contributors": [
    {"name": "alice", "commits": 47},
    {"name": "bob", "commits": 12}
  ],
  "related_decisions": ["ADR-0042: JWT vs Redis session storage"],
  "risk_modules": ["src/session.ts (12 historical bugs)"]
}
```

---

## Phase 2: Decision Reference

### 2.1 Find related ADRs

```bash
NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
_DECISIONS_DIR="$NEXUS_HOME/decisions/${_REPO}"

if [ -d "$_DECISIONS_DIR" ] && [ -n "$(ls -A "$_DECISIONS_DIR" 2>/dev/null)" ]; then
  echo "=== Historical Architecture Decisions ==="
  grep -rl "$QUERY" "$_DECISIONS_DIR" 2>/dev/null | while read -r adr; do
    printf "  ADR: %s\n" "$(basename "$adr" .md)"
  done
fi
```

### 2.2 Team learnings

```bash
_LEARN_FILE="$NEXUS_HOME/projects/${_REPO}/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  echo "=== Team Learnings ==="
  grep -i "$QUERY" "$_LEARN_FILE" 2>/dev/null | tail -5
fi
```

---

## Phase 3: Guardrails Engine

### 3.1 Rule categories

| Category | Pattern | Severity |
|----------|---------|----------|
| SQL Injection | String concatenation in SQL | error |
| XSS Risk | innerHTML / dangerouslySetInnerHTML | error |
| Hardcoded Secrets | API key / password in plaintext | error |
| N+1 Queries | forEach + await + find | warning |
| Unhandled Promise | async without try/catch | warning |
| Excessive `any` | TypeScript `: any` | warning |
| Debug Logs | console.log in production code | info |

### 3.2 Execution flow

1. **Pre-check**: Analyze user intent, load relevant guardrail rules
2. **In-flight check**: After each code block generation, validate immediately
3. **Post-check**: After all modifications, run full validation

### 3.3 Running guardrails

```bash
# Check only changed files
~/.claude/skills/nexus/scripts/guardrails-check.sh diff

# Full project scan
~/.claude/skills/nexus/scripts/guardrails-check.sh full

# Single file
~/.claude/skills/nexus/scripts/guardrails-check.sh file src/auth.ts
```

---

## Phase 4: Knowledge Graph

### 4.1 Module dependency analysis

```bash
NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
_GRAPH_DIR="$NEXUS_HOME/graphs/${_REPO}"
mkdir -p "$_GRAPH_DIR"

# TypeScript/JavaScript import analysis
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) \
  ! -path "*/node_modules/*" ! -path "*/dist/*" 2>/dev/null | \
  xargs grep -h "^import.*from" 2>/dev/null | \
  sed -E 's/.*from ["'"'"'](.+)["'"'"'].*/\1/' | \
  grep -v '^\.' | sort | uniq -c | sort -rn | head -20
```

### 4.2 Expert map

```bash
for dir in src app lib components pkg internal; do
  [ -d "$dir" ] || continue
  find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | \
  while read -r file; do
    _expert=$(git log --format="%an" -1 -- "$file" 2>/dev/null || echo "unknown")
    _count=$(git log --oneline -- "$file" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${_count:-0}" -gt 5 ]; then
      printf "  %-50s -> %s (%s commits)\n" "$file" "$_expert" "$_count"
    fi
  done
done | head -30
```

### 4.3 Hotspot & fragility analysis

```bash
# Hotspots: most-changed files in last 3 months
git log --format="%s" --since="3 months ago" --name-only 2>/dev/null | \
  grep -E '\.(ts|tsx|js|py|go|rs)$' | \
  grep -v -E '(node_modules|\.d\.ts|\.test\.|\.spec\.)' | \
  sort | uniq -c | sort -rn | head -15

# Fragility: files most often in bug-fix commits
git log --format="%s" --since="6 months ago" --name-only 2>/dev/null | \
  grep -iE 'fix|bug|hotfix|crash' -A100 | \
  grep -E '^(src|app|lib|pkg|internal)/' | \
  grep -v node_modules | sort | uniq -c | sort -rn | head -10
```

---

## Phase 5: PR Autopilot

### 5.1 Workflow

```
1. git diff → analyze changes
2. git log → extract ticket references
3. ADR directory → find related decisions
4. Knowledge graph → calculate impact scope
5. git blame → recommend reviewers
6. Generate PR description (with context + risk analysis)
```

### 5.2 Reviewer recommendation

```bash
git diff --name-only "main"..HEAD 2>/dev/null | while read -r f; do
  [ -f "$f" ] && git log --format="%an" -3 -- "$f" 2>/dev/null
done | sort | uniq -c | sort -rn | head -5 | awk '{print $2}' | sort -u | sed 's/^/@/'
```

### 5.3 Generate PR

See `scripts/pr-autopilot.sh` for the full PR generation workflow.

---

## Phase 6: Decision Auto-Logging

### 6.1 Detection triggers

Nexus auto-detects when to create an ADR:

- User mentions "choose", "decide", "approach", "architecture"
- Changes span 3+ files
- New dependency or pattern introduced
- User explicitly says "remember this decision" or "/nexus:decision"

### 6.2 ADR template

```bash
NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
_DECISIONS_DIR="$NEXUS_HOME/decisions/${_REPO}"
mkdir -p "$_DECISIONS_DIR"

_ADR_NUM=$(($(find "$_DECISIONS_DIR" -name 'ADR-*.md' 2>/dev/null | wc -l) + 1))
_ADR_FILE="$_DECISIONS_DIR/ADR-$(printf '%04d' "$_ADR_NUM")-$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g').md"

cat > "$_ADR_FILE" << ADRTEMPLATE
# ADR-$(printf '%04d' "$_ADR_NUM"): $TITLE

| Field | Value |
|-------|-------|
| **Date** | $(date +%Y-%m-%d) |
| **Status** | proposed |
| **Author** | $(git config user.name 2>/dev/null || echo "unknown") |
| **Related Ticket** | ${TICKET:-N/A} |

## Context
${CONTEXT:-[To be filled]}

## Decision
${DECISION:-[To be filled]}

## Alternatives
| # | Option | Pros | Cons | Outcome |
|---|--------|------|------|---------|
| 1 | [Option A] | ... | ... | Selected |
| 2 | [Option B] | ... | ... | Rejected |
| 3 | [Option C] | ... | ... | Rejected |

## Impact
${IMPACT:-[To be filled]}

## Risks & Mitigations
| Risk | Severity | Mitigation |
|------|----------|------------|

## Related Links
- PR:
- Slack discussion:
- Related ADRs:

---
*Generated by Claude Code + Nexus | $(date -u +%Y-%m-%dT%H:%M:%SZ)*
ADRTEMPLATE
```

---

## Command Reference

| Command | Function |
|---------|----------|
| `/nexus:context <query>` | Trigger context assembly |
| `/nexus:guardrails [diff\|full\|file]` | Run guardrails check |
| `/nexus:decision <title>` | Create an ADR |
| `/nexus:graph [deps\|experts\|hotspots\|full]` | Generate knowledge graph |
| `/nexus:pr [preview\|create\|draft]` | PR autopilot |
| `/nexus:init` | Initialize project config |
| `/nexus:dashboard` | Show team analytics dashboard |

---

## Project Configuration

Create `.claude/nexus.yml` in your project root:

```yaml
# Nexus project configuration
project:
  name: "my-project"
  type: "web"

context:
  sources:
    github_issues:
      enabled: true
    jira:
      enabled: false
    linear:
      enabled: false
    slack:
      enabled: false
      channels: ["#engineering"]
    figma:
      enabled: false

guardrails:
  enabled_rules:
    - security/no-sql-injection
    - security/no-xss
    - security/no-hardcoded-secrets
    - quality/no-n-plus-1
    - quality/no-unhandled-promise
    - style/no-excessive-any

knowledge_graph:
  auto_update: true
  update_on_commit: true
  expert_threshold: 5

decisions:
  auto_detect: true
  template: "detailed"

pr:
  auto_reviewer: true
  include_decision_context: true
  include_risk_analysis: true
```
