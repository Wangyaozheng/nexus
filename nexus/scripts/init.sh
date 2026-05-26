#!/bin/bash
# ============================================================
# Nexus — Initialization Script
# Sets up Nexus configuration for a new project
# ============================================================

set -euo pipefail

NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
SKILLS_DIR="$HOME/.claude/skills/nexus"

echo "Nexus — Project Initialization"
echo "=============================="

# Detect project root
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: not a git repository"
  echo "  Run: git init"
  exit 1
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel)
REPO=$(basename "$PROJECT_ROOT")

echo "Project root: $PROJECT_ROOT"
echo "Project name: $REPO"

# ── Create directories ────────────────────────────────────

mkdir -p "$NEXUS_HOME"/{projects,decisions/${REPO},graphs/${REPO},guardrails,sessions}
mkdir -p "$PROJECT_ROOT/.claude"

echo ""
echo "Creating directory structure..."

# ── Copy config template ──────────────────────────────────

CONFIG_SRC="$SKILLS_DIR/templates/nexus.yml"
CONFIG_DEST="$PROJECT_ROOT/.claude/nexus.yml"

if [ -f "$CONFIG_DEST" ]; then
  echo "Config already exists: $CONFIG_DEST"
else
  if [ -f "$CONFIG_SRC" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DEST"
    echo "Config created: $CONFIG_DEST"
  else
    echo "Warning: template not found at $CONFIG_SRC"
    echo "  A minimal config will be created automatically."
  fi
fi

# ── Detect tech stack ─────────────────────────────────────

detect_language() {
  if   find "$PROJECT_ROOT" -maxdepth 3 -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1 | grep -q .; then echo "typescript"
  elif find "$PROJECT_ROOT" -maxdepth 3 -name "*.js" -o -name "*.jsx" 2>/dev/null | head -1 | grep -q .; then echo "javascript"
  elif find "$PROJECT_ROOT" -maxdepth 3 -name "*.py" 2>/dev/null | head -1 | grep -q .; then echo "python"
  elif find "$PROJECT_ROOT" -maxdepth 3 -name "*.go" 2>/dev/null | head -1 | grep -q .; then echo "go"
  elif find "$PROJECT_ROOT" -maxdepth 3 -name "*.rs" 2>/dev/null | head -1 | grep -q .; then echo "rust"
  elif find "$PROJECT_ROOT" -maxdepth 3 -name "*.java" 2>/dev/null | head -1 | grep -q .; then echo "java"
  else echo "unknown"
  fi
}

detect_framework() {
  if [ -f "$PROJECT_ROOT/package.json" ]; then
    local deps
    deps=$(cat "$PROJECT_ROOT/package.json" 2>/dev/null)
    if echo "$deps" | grep -q '"next"'; then echo "nextjs"
    elif echo "$deps" | grep -q '"react"'; then echo "react"
    elif echo "$deps" | grep -q '"vue"'; then echo "vue"
    elif echo "$deps" | grep -q '"svelte"'; then echo "svelte"
    elif echo "$deps" | grep -q '"express"'; then echo "express"
    elif echo "$deps" | grep -q '"fastify"'; then echo "fastify"
    elif echo "$deps" | grep -q '"nestjs"'; then echo "nestjs"
    else echo "node"
    fi
  elif [ -f "$PROJECT_ROOT/go.mod" ]; then echo "go"
  elif [ -f "$PROJECT_ROOT/Cargo.toml" ]; then echo "rust"
  elif [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/pyproject.toml" ]; then echo "python"
  else echo "unknown"
  fi
}

LANG=$(detect_language)
FRAMEWORK=$(detect_framework)

echo ""
echo "Tech stack detection:"
echo "  Language: $LANG"
echo "  Framework: $FRAMEWORK"

# ── Save project state ────────────────────────────────────

PROJECT_STATE="$NEXUS_HOME/projects/${REPO}.json"
cat > "$PROJECT_STATE" << STATEEOF
{
  "name": "$REPO",
  "root": "$PROJECT_ROOT",
  "language": "$LANG",
  "framework": "$FRAMEWORK",
  "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_context_sync": null,
  "last_graph_update": null,
  "adr_count": 0,
  "settings": {
    "auto_context": true,
    "auto_guardrails": true,
    "auto_decisions": true,
    "auto_pr": false
  }
}
STATEEOF

echo "Project state saved: $PROJECT_STATE"

# ── Check external tools ──────────────────────────────────

echo ""
echo "External tools:"

check_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "  [OK]    %-20s %s\n" "$2" "$(command -v "$1")"
    return 0
  else
    printf "  [MISS]  %-20s (not installed)\n" "$2"
    return 1
  fi
}

check_tool gh  "GitHub CLI"
check_tool jq  "jq (JSON)"

# ── Set up Git hooks ──────────────────────────────────────

echo ""
echo "Git hooks:"

HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
POST_COMMIT="$HOOKS_DIR/post-commit"

if [ ! -f "$POST_COMMIT" ]; then
  cat > "$POST_COMMIT" << 'HOOKEOF'
#!/bin/bash
# Nexus: auto-update knowledge graph on commit
"$HOME/.claude/skills/nexus/scripts/knowledge-graph.sh" full --quiet 2>/dev/null || true
HOOKEOF
  chmod +x "$POST_COMMIT"
  echo "  [OK] post-commit hook installed (auto-updates knowledge graph)"
else
  echo "  [SKIP] post-commit hook already exists"
fi

# ── Done ──────────────────────────────────────────────────

echo ""
echo "======================================"
echo "Nexus initialized successfully!"
echo ""
echo "Quick start:"
echo "  /nexus:context <query>       Assemble project context"
echo "  /nexus:graph                 Generate knowledge graph"
echo "  /nexus:guardrails            Run guardrails check"
echo "  /nexus:decision <title>      Create an ADR"
echo "  /nexus:pr preview            Preview a PR"
echo ""
echo "Config:  $CONFIG_DEST"
echo "State:   $PROJECT_STATE"
echo "Data:    $NEXUS_HOME"
