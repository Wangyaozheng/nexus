#!/bin/bash
# ============================================================
# Nexus — Team Dashboard
# Shows team AI usage, code quality trends, knowledge overview
# ============================================================

set -euo pipefail

NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ── Gather data ───────────────────────────────────────────

total_files=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
contributors=$(git log --format="%an" --since="6 months ago" 2>/dev/null | sort -u | wc -l | tr -d ' ')
recent_commits=$(git rev-list --count --since="1 month ago" HEAD 2>/dev/null || echo 0)
adr_count=$(find "$NEXUS_HOME/decisions/${REPO}/" -name 'ADR-*.md' 2>/dev/null | wc -l | tr -d ' ')

if command -v gh >/dev/null 2>&1; then
  open_prs=$(gh pr list --state open --limit 1000 2>/dev/null | wc -l | tr -d ' ' || echo "N/A")
  merged_prs=$(gh pr list --state merged --limit 1000 2>/dev/null | wc -l | tr -d ' ' || echo "N/A")
else
  open_prs="N/A"
  merged_prs="N/A"
fi

# ── Display ───────────────────────────────────────────────

clear 2>/dev/null || true

echo ""
printf "${BOLD}${CYAN}%s${NC}\n" "  Nexus — Team Intelligence Dashboard"
printf "${BOLD}${CYAN}%s${NC}\n" "  ===================================="
echo ""
printf "  ${BOLD}%-20s${NC} %s\n" "Project:" "$REPO"
printf "  ${BOLD}%-20s${NC} %s\n" "Date:" "$(date +%Y-%m-%d)"
echo ""

# ── Core metrics ──────────────────────────────────────────

printf "${BOLD}%s${NC}\n" "  --- Core Metrics ---"
echo ""

printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}"   "Total files" "$total_files"
printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}\n" "Total commits" "$total_commits"
printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}"   "Contributors (6mo)" "$contributors"
printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}\n" "Monthly commits" "$recent_commits"
printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}"   "Architecture decisions" "$adr_count"
printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}\n" "Open PRs" "$open_prs"
printf "  ${BLUE}%-22s${NC} ${GREEN}%-12s${NC}\n" "Merged PRs (total)" "$merged_prs"

# ── Module hotspots ───────────────────────────────────────

echo ""
printf "${BOLD}%s${NC}\n" "  --- Module Hotspots (3 months) ---"
echo ""

git log --format="%s" --since="3 months ago" --name-only 2>/dev/null | \
  grep -E '\.(ts|tsx|js|jsx|py|go|rs)$' | \
  grep -v -E '(node_modules|\.test\.|\.spec\.|\.d\.ts)' | \
  sort | uniq -c | sort -rn | head -8 | \
  awk '{
    bar = ""
    count = int($1 / 2)
    for (i = 0; i < count && i < 25; i++) bar = bar "#"
    printf "  %-42s %3d  %s\n", $2, $1, bar
  }'

# ── Contributor activity ──────────────────────────────────

echo ""
printf "${BOLD}%s${NC}\n" "  --- Contributor Activity (3 months) ---"
echo ""

git log --format="%an" --since="3 months ago" 2>/dev/null | \
  sort | uniq -c | sort -rn | head -6 | \
  awk '{
    bar = ""
    count = int($1 / 3)
    for (i = 0; i < count && i < 20; i++) bar = bar "#"
    printf "  %-18s %3d commits  %s\n", $2, $1, bar
  }'

# ── Recent ADRs ───────────────────────────────────────────

echo ""
printf "${BOLD}%s${NC}\n" "  --- Recent Architecture Decisions ---"
echo ""

DECISIONS_DIR="$NEXUS_HOME/decisions/${REPO}"
if [ -d "$DECISIONS_DIR" ] && [ -n "$(ls -A "$DECISIONS_DIR" 2>/dev/null)" ]; then
  find "$DECISIONS_DIR" -name 'ADR-*.md' -printf '%T@ %p\n' 2>/dev/null | \
    sort -rn | head -3 | cut -d' ' -f2- | while read -r adr; do
    title=$(head -3 "$adr" | grep '^# ' | sed 's/^# ADR-[0-9]*: //' | head -1)
    status=$(grep '\*\*Status\*\*' "$adr" 2>/dev/null | sed 's/.*| //' | head -1 || echo "unknown")
    printf "  [%s] %s\n" "$status" "$title"
  done
else
  echo "  (no ADRs yet)"
fi

# ── Fragile modules ───────────────────────────────────────

echo ""
printf "${BOLD}%s${NC}\n" "  --- Fragile Modules (bug-fix hotspots) ---"
echo ""

git log --format="%s" --since="6 months ago" --name-only 2>/dev/null | \
  grep -iE 'fix|bug|hotfix|crash' -A100 | \
  grep -E '^(src|app|lib|pkg|internal)/' | \
  grep -v node_modules | sort | uniq -c | sort -rn | head -5 | \
  awk '{
    if ($1 > 15) icon = "[HIGH]  "
    else if ($1 > 8) icon = "[MED]   "
    else icon = "[LOW]   "
    printf "  %s %-42s %3d bug-fixes\n", icon, $2, $1
  }' 2>/dev/null || echo "  (insufficient data)"

# ── Footer ────────────────────────────────────────────────

echo ""
printf "${BOLD}%s${NC}\n" "  ===================================="
echo ""
printf "  ${GREEN}%s${NC}\n" "Quick commands:"
echo "  /nexus:context <query>    Assemble context"
echo "  /nexus:graph              Update knowledge graph"
echo "  /nexus:guardrails         Run guardrails check"
echo "  /nexus:decision <title>   Create decision record"
echo "  /nexus:pr preview         Preview PR"
echo "  /nexus:dashboard          Refresh dashboard"
echo ""
