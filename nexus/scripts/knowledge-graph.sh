#!/bin/bash
# ============================================================
# Nexus — Knowledge Graph Builder
# Analyzes code dependencies, expert maps, hotspots, fragility
# ============================================================

set -euo pipefail

NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
GRAPH_DIR="$NEXUS_HOME/graphs/${REPO}"
GRAPH_FILE="$GRAPH_DIR/knowledge-graph.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$GRAPH_DIR"

# ── Language Detection ────────────────────────────────────

detect_language() {
  if   find . -maxdepth 3 -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1 | grep -q .; then echo "typescript"
  elif find . -maxdepth 3 -name "*.js" -o -name "*.jsx" 2>/dev/null | head -1 | grep -q .; then echo "javascript"
  elif find . -maxdepth 3 -name "*.py" 2>/dev/null | head -1 | grep -q .; then echo "python"
  elif find . -maxdepth 3 -name "*.go" 2>/dev/null | head -1 | grep -q .; then echo "go"
  elif find . -maxdepth 3 -name "*.rs" 2>/dev/null | head -1 | grep -q .; then echo "rust"
  elif find . -maxdepth 3 -name "*.java" 2>/dev/null | head -1 | grep -q .; then echo "java"
  else echo "unknown"
  fi
}

LANG=$(detect_language)

# ── 1. Dependency Analysis ────────────────────────────────

analyze_dependencies() {
  echo "Module Dependencies"
  echo "==================="

  case "$LANG" in
    typescript|javascript)
      find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
        ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/.next/*" 2>/dev/null | \
        xargs grep -h "^import.*from" 2>/dev/null | \
        sed -E 's/.*from ["'"'"'](.+)["'"'"'].*/\1/' | \
        grep -v '^\.' | sort | uniq -c | sort -rn | head -20 | \
        awk '{printf "  %3d imports  %s\n", $1, $2}'
      ;;
    python)
      find . -type f -name "*.py" ! -path "*/__pycache__/*" ! -path "*/.venv/*" 2>/dev/null | \
        xargs grep -hE "^from|^import" 2>/dev/null | \
        awk '{print $2}' | sed 's/\..*//' | sort | uniq -c | sort -rn | head -20 | \
        awk '{printf "  %3d imports  %s\n", $1, $2}'
      ;;
    go)
      find . -type f -name "*.go" ! -path "*/vendor/*" 2>/dev/null | \
        xargs grep -hE '^\s+"[^"]*"' 2>/dev/null | \
        sed 's/.*"\(.*\)".*/\1/' | grep -v '^\.' | sort | uniq -c | sort -rn | head -20 | \
        awk '{printf "  %3d imports  %s\n", $1, $2}'
      ;;
    *)
      echo "  (unsupported language: $LANG)"
      ;;
  esac
}

# ── 2. Expert Map ─────────────────────────────────────────

build_expert_map() {
  local threshold="${1:-5}"

  echo ""
  echo "Module Expert Map (>=${threshold} commits)"
  echo "=========================================="

  for dir in src app lib components pkg internal; do
    [ -d "$dir" ] || continue

    find "$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" \) 2>/dev/null | \
    while read -r file; do
      expert=$(git log --format="%an" -1 -- "$file" 2>/dev/null || echo "unknown")
      commits=$(git log --oneline -- "$file" 2>/dev/null | wc -l | tr -d ' ')
      last_change=$(git log --format="%ar" -1 -- "$file" 2>/dev/null || echo "unknown")

      if [ "${commits:-0}" -ge "$threshold" ] 2>/dev/null; then
        printf "  %-50s -> %-20s (%s commits, %s)\n" \
          "$(echo "$file" | cut -c1-48)" "$expert" "$commits" "$last_change"
      fi
    done
  done | head -30
}

# ── 3. Hotspots ───────────────────────────────────────────

analyze_hotspots() {
  echo ""
  echo "Module Hotspots (last 3 months)"
  echo "================================"

  git log --format="%s" --since="3 months ago" --name-only 2>/dev/null | \
    grep -E '\.(ts|tsx|js|jsx|py|go|rs|java)$' | \
    grep -v -E '(node_modules|\.d\.ts|\.test\.|\.spec\.|dist/)' | \
    sort | uniq -c | sort -rn | head -15 | \
    awk '{printf "  %3d changes  %s\n", $1, $2}'
}

# ── 4. Fragility ──────────────────────────────────────────

analyze_fragility() {
  echo ""
  echo "Fragile Modules (bug-fix frequency, last 6 months)"
  echo "==================================================="

  git log --format="%s" --since="6 months ago" --name-only 2>/dev/null | \
    grep -iE 'fix|bug|hotfix|crash|issue' -A100 | \
    grep -E '^(src|app|lib|pkg|internal)/' | \
    grep -v node_modules | sort | uniq -c | sort -rn | head -10 | \
    awk '{printf "  %3d bug-fixes  %s\n", $1, $2}'
}

# ── 5. Collaboration Network ──────────────────────────────

analyze_collaboration() {
  echo ""
  echo "Team Collaboration Network"
  echo "=========================="

  git log --format="%an" --since="3 months ago" --name-only 2>/dev/null | \
    awk '{
      if ($0 ~ /^(src|app|lib|pkg|internal)\//) {
        file = $0
      } else if ($0 != "" && $0 !~ /^ /) {
        author = $0
        if (file != "") {
          key = author "|" file
          pairs[key]++
          file = ""
        }
      }
    }
    END {
      for (pair in pairs) {
        if (pairs[pair] >= 3) {
          split(pair, parts, "|")
          printf "  %-20s -> %s (%s changes)\n", parts[1], parts[2], pairs[pair]
        }
      }
    }' 2>/dev/null | head -20
}

# ── 6. Generate JSON ──────────────────────────────────────

generate_graph_json() {
  echo ""
  echo "Generating knowledge graph: $GRAPH_FILE"

  cat > "$GRAPH_FILE" << JSONEOF
{
  "repo": "$REPO",
  "language": "$LANG",
  "updated_at": "$TIMESTAMP",
  "branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
  "total_files": $(git ls-files 2>/dev/null | grep -cE '\.(ts|tsx|js|jsx|py|go|rs|java)$' || echo 0),
  "total_contributors": $(git log --format="%an" --since="6 months ago" 2>/dev/null | sort -u | wc -l | tr -d ' ' || echo 0),
  "adr_count": $(find "$NEXUS_HOME/decisions/${REPO}/" -name 'ADR-*.md' 2>/dev/null | wc -l | tr -d ' ' || echo 0)
}
JSONEOF

  echo "Graph saved ($(wc -c < "$GRAPH_FILE" 2>/dev/null || echo 0) bytes)"
}

# ── Main ──────────────────────────────────────────────────

COMMAND="${1:-full}"
QUIET="${2:-}"

[ "$QUIET" != "--quiet" ] && {
  echo "Nexus Knowledge Graph"
  echo "====================="
  echo "Project: $REPO"
  echo "Language: $LANG"
  echo ""
}

case "$COMMAND" in
  deps)          analyze_dependencies ;;
  experts)       build_expert_map "${2:-5}" ;;
  hotspots)      analyze_hotspots ;;
  fragility)     analyze_fragility ;;
  collaboration) analyze_collaboration ;;
  full|*)
    analyze_dependencies
    build_expert_map 5
    analyze_hotspots
    analyze_fragility
    analyze_collaboration
    generate_graph_json
    ;;
esac

[ "$QUIET" != "--quiet" ] && {
  echo ""
  echo "====================="
  echo "Knowledge graph analysis complete"
}
