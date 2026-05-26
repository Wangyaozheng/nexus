#!/bin/bash
# ============================================================
# Nexus — Context Assembler
# Auto-pulls relevant context from external systems for a task
# ============================================================

set -euo pipefail

NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
SESSION_ID="$$-$(date +%s)"
OUTPUT_FILE="$NEXUS_HOME/sessions/context-${SESSION_ID}.json"

mkdir -p "$NEXUS_HOME/sessions"

QUERY="${1:-}"
if [ -z "$QUERY" ]; then
  echo "Usage: context-assembler <query>"
  echo "Example: context-assembler 'login timeout bug'"
  exit 1
fi

echo "Nexus: Assembling context for \"$QUERY\""
echo "========================================"

# Extract keywords for search
KEYWORDS=$(echo "$QUERY" | tr ' ' '\n' | grep -v '^\s*$' | tr '\n' '|' | sed 's/|$//')
echo "Keywords: $KEYWORDS"

# ── 1. Git Context ────────────────────────────────────
echo ""
echo "[Git Context]"

echo "  Related ticket references:"
git log --oneline -20 --grep='#' 2>/dev/null | grep -iE "$KEYWORDS" | head -5 || echo "  (none)"

echo "  Related files:"
for kw in $(echo "$QUERY" | tr ' ' '\n'); do
  git ls-files "*${kw}*" 2>/dev/null | head -3
done | sort -u | head -10

echo "  Recent contributors to related areas:"
for kw in $(echo "$QUERY" | tr ' ' '\n'); do
  git ls-files "*${kw}*" 2>/dev/null
done | sort -u | head -5 | while read -r f; do
  git log --format="  %an (%ar)" -1 -- "$f" 2>/dev/null
done | sort -u

# ── 2. GitHub Issues ─────────────────────────────────
echo ""
echo "[GitHub Issues]"
if command -v gh >/dev/null 2>&1; then
  gh issue list --search "$QUERY" --state all --limit 10 \
    --json number,title,state,author 2>/dev/null | \
    jq -r '.[] | "  #\(.number) [\(.state)] \(.title) (@\(.author.login))"' 2>/dev/null || echo "  (no results)"
else
  echo "  (gh CLI not installed)"
fi

# ── 3. Jira (env-var driven, no config file) ─────────
echo ""
echo "[Jira]"
if [ -n "${JIRA_API_TOKEN:-}" ] && [ -n "${JIRA_DOMAIN:-}" ]; then
  curl -s -H "Authorization: Bearer $JIRA_API_TOKEN" \
    "https://${JIRA_DOMAIN}/rest/api/3/search?jql=text~'${QUERY}'&maxResults=5" 2>/dev/null | \
    jq -r '.issues[]? | "  \(.key) [\(.fields.status.name)] \(.fields.summary)"' 2>/dev/null || echo "  (no results)"
else
  echo "  (not configured — set JIRA_API_TOKEN and JIRA_DOMAIN env vars)"
fi

# ── 4. ADR History ──────────────────────────────────────
echo ""
echo "[Architecture Decisions]"
DECISIONS_DIR="$NEXUS_HOME/decisions/${REPO}"
if [ -d "$DECISIONS_DIR" ] && [ -n "$(ls -A "$DECISIONS_DIR" 2>/dev/null)" ]; then
  grep -ril "$QUERY" "$DECISIONS_DIR" 2>/dev/null | head -5 | while read -r adr; do
    printf "  ADR: %s\n" "$(basename "$adr" .md)"
  done || echo "  (no matching ADRs)"
else
  echo "  (no ADRs yet — create one with /nexus:decision)"
fi

# ── 5. Impact Analysis ──────────────────────────────────
echo ""
echo "[Impact Analysis]"
RELATED_FILES=$(git ls-files 2>/dev/null | grep -iE "$KEYWORDS" | head -5 || true)
if [ -n "$RELATED_FILES" ]; then
  echo "  Directly related files:"
  echo "$RELATED_FILES" | while read -r f; do
    imports=$(grep -cE "^import.*from" "$f" 2>/dev/null || echo 0)
    printf "    %s (%s imports)\n" "$f" "$imports"
  done
else
  echo "  (no directly matching files found)"
fi

# ── Output structured JSON ────────────────────────────
echo ""
echo "========================================"
echo "Context assembly complete"
echo "Output: $OUTPUT_FILE"

cat > "$OUTPUT_FILE" << JSONEOF
{
  "session_id": "$SESSION_ID",
  "query": "$QUERY",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repo": "$REPO",
  "branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
  "adr_count": $(find "$DECISIONS_DIR" -name 'ADR-*.md' 2>/dev/null | wc -l || echo 0)
}
JSONEOF

if command -v jq >/dev/null 2>&1; then
  jq '.' "$OUTPUT_FILE"
else
  cat "$OUTPUT_FILE"
fi
