#!/bin/bash
# ============================================================
# Nexus — PR Autopilot
# Smart PR generation: context assembly, reviewer recs, risk analysis
# ============================================================

set -euo pipefail

NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")

# ── Colors (ANSI, safe across terminals) ──────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Prerequisites ─────────────────────────────────────────

check_prerequisites() {
  local errors=0

  if ! command -v gh >/dev/null 2>&1; then
    printf "${RED}%s${NC}\n" "Error: GitHub CLI (gh) is required"
    echo "  Install: https://cli.github.com/"
    errors=$((errors + 1))
  fi

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf "${RED}%s${NC}\n" "Error: not a git repository"
    errors=$((errors + 1))
  fi

  return "$errors"
}

# ── Cross-platform temp file ──────────────────────────────

temp_file() {
  if [ -d /tmp ] && [ -w /tmp ]; then
    echo "/tmp/nexus-pr-body-$$.md"
  elif [ -n "${TMPDIR:-}" ]; then
    echo "${TMPDIR}/nexus-pr-body-$$.md"
  else
    echo "$NEXUS_HOME/sessions/pr-body-$$.md"
  fi
}

# ── Analyze Changes ───────────────────────────────────────

analyze_changes() {
  local base_branch="${1:-main}"

  echo "Change Analysis"
  echo "==============="

  local files_changed
  files_changed=$(git diff --name-only "$base_branch"..HEAD 2>/dev/null | wc -l | tr -d ' ')

  local insertions
  insertions=$(git diff --stat "$base_branch"..HEAD 2>/dev/null | tail -1 | \
    grep -o '[0-9]* insertion' | grep -o '[0-9]*' || echo 0)

  local deletions
  deletions=$(git diff --stat "$base_branch"..HEAD 2>/dev/null | tail -1 | \
    grep -o '[0-9]* deletion' | grep -o '[0-9]*' || echo 0)

  echo "  Files: $files_changed"
  echo "  Lines: +$insertions / -$deletions"

  echo ""
  echo "  Changed files:"
  git diff --name-only "$base_branch"..HEAD 2>/dev/null | while read -r f; do
    case "$f" in
      *.test.*|*.spec.*|*__tests__*)  printf "    [test]       %s\n" "$f" ;;
      *.ts|*.tsx|*.js|*.jsx)          printf "    [source]     %s\n" "$f" ;;
      *.css|*.scss|*.less)            printf "    [style]      %s\n" "$f" ;;
      *.json|*.yml|*.yaml|*.toml)     printf "    [config]     %s\n" "$f" ;;
      *.md|*.mdx)                     printf "    [docs]       %s\n" "$f" ;;
      *.sql)                          printf "    [database]   %s\n" "$f" ;;
      *)                              printf "    [other]      %s\n" "$f" ;;
    esac
  done

  echo ""
  printf "  Risk level: "
  if [ "$files_changed" -gt 20 ]; then
    printf "${RED}HIGH — %s files changed${NC}\n" "$files_changed"
  elif [ "$files_changed" -gt 10 ]; then
    printf "${YELLOW}MEDIUM — %s files changed${NC}\n" "$files_changed"
  else
    printf "${GREEN}LOW — %s files changed${NC}\n" "$files_changed"
  fi
}

# ── Extract Tickets ───────────────────────────────────────

extract_tickets() {
  local base_branch="${1:-main}"

  echo ""
  echo "Related Tickets"
  echo "==============="

  local tickets
  tickets=$(git log "$base_branch"..HEAD --format="%s" 2>/dev/null | grep -oE '#[0-9]+' | sort -u || true)

  if [ -n "$tickets" ]; then
    echo "$tickets" | while read -r ticket; do
      local num
      num=$(echo "$ticket" | tr -d '#')
      if command -v gh >/dev/null 2>&1; then
        local title
        title=$(gh issue view "$num" --json title -q '.title' 2>/dev/null || echo "unable to fetch")
        echo "  $ticket: $title"
      else
        echo "  $ticket"
      fi
    done
  else
    echo "  (no ticket references found)"
  fi
}

# ── Recommend Reviewers ───────────────────────────────────

recommend_reviewers() {
  local base_branch="${1:-main}"

  echo ""
  echo "Reviewer Recommendations"
  echo "========================"

  git diff --name-only "$base_branch"..HEAD 2>/dev/null | while read -r f; do
    git log --format="%an" -3 -- "$f" 2>/dev/null
  done | sort | uniq -c | sort -rn | head -5 | while read -r count author; do
    echo "  @$author — touched $count files in this diff"
  done

  if [ -f ".github/CODEOWNERS" ]; then
    echo ""
    echo "  CODEOWNERS suggestions:"
    git diff --name-only "$base_branch"..HEAD 2>/dev/null | while read -r f; do
      grep -F "$f" .github/CODEOWNERS 2>/dev/null | sed 's/^/    /'
    done | sort -u | head -5
  fi
}

# ── Decision Context ──────────────────────────────────────

decision_context() {
  echo ""
  echo "Related Decision Context"
  echo "========================"

  local decisions_dir="$NEXUS_HOME/decisions/${REPO}"
  if [ -d "$decisions_dir" ] && [ -n "$(ls -A "$decisions_dir" 2>/dev/null)" ]; then
    local keywords
    keywords=$(git diff --name-only "main"..HEAD 2>/dev/null | \
      sed 's|.*/||' | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | \
      tr '\n' '|' | sed 's/|$//')

    grep -rilE "$keywords" "$decisions_dir" 2>/dev/null | head -3 | while read -r adr; do
      echo "  $(basename "$adr" .md)"
    done || echo "  (no matching ADRs)"
  else
    echo "  (no ADRs yet — run /nexus:decision for major decisions)"
  fi

  # Include learnings
  local learn_file="$NEXUS_HOME/projects/${REPO}/learnings.jsonl"
  if [ -f "$learn_file" ]; then
    echo ""
    echo "  Recent learnings:"
    tail -3 "$learn_file" 2>/dev/null | while read -r line; do
      echo "    $line"
    done
  fi
}

# ── Generate PR Body ──────────────────────────────────────

generate_pr_body() {
  local base_branch="${1:-main}"

  local commits
  commits=$(git log "$base_branch"..HEAD --format="- %s" 2>/dev/null)

  local tickets
  tickets=$(git log "$base_branch"..HEAD --format="%s" 2>/dev/null | \
    grep -oE '#[0-9]+' | sort -u | sed 's/^/- /' || echo "- N/A")

  local author
  author=$(git config user.name 2>/dev/null || echo "unknown")

  local files_count
  files_count=$(git diff --name-only "$base_branch"..HEAD 2>/dev/null | wc -l | tr -d ' ')

  local test_files
  test_files=$(git diff --name-only "$base_branch"..HEAD 2>/dev/null | grep -cE '\.(test|spec)\.' || echo 0)

  local has_tests="[OK] ${test_files} test files changed"
  if [ "${test_files:-0}" -eq 0 ]; then
    has_tests="[WARN] No test files detected in this change"
  fi

  cat << PRBODY
## Summary

$commits

## Related

$tickets

## Stats

- Files changed: $files_count
- Test coverage: $has_tests

## Risk Assessment

- Modules affected: $(git diff --name-only "$base_branch"..HEAD 2>/dev/null | sed 's|/[^/]*$||' | sort -u | wc -l | tr -d ' ')
- Changed files:
$(git diff --name-only "$base_branch"..HEAD 2>/dev/null | head -10 | sed 's/^/  - /')

## Diff

$(git diff --stat "$base_branch"..HEAD 2>/dev/null | tail -1)

## Checklist

- [ ] Code review approved
- [ ] Tests passing
- [ ] Guardrails check passing
- [ ] Documentation updated
- [ ] ADR updated (if needed)

---
Generated by [Claude Code](https://github.com/anthropics/claude-code) + [Nexus](https://github.com/anthropics/claude-code)
Author: @$author
Date: $(date +%Y-%m-%d)
PRBODY
}

# ── Create PR ─────────────────────────────────────────────

create_pr() {
  local base_branch="${1:-main}"
  local draft="${2:-false}"

  printf "${BLUE}%s${NC}\n" "Nexus PR Autopilot"
  echo "===================="

  check_prerequisites || exit 1

  # Verify there are changes
  if ! git diff --quiet "$base_branch"..HEAD 2>/dev/null; then
    echo "[OK] Changes detected"
  else
    printf "${RED}%s${NC}\n" "Error: no changes detected (vs $base_branch)"
    exit 1
  fi

  # Analysis
  analyze_changes "$base_branch"
  extract_tickets "$base_branch"
  recommend_reviewers "$base_branch"
  decision_context

  # Generate
  local pr_title
  pr_title=$(git log --format="%s" "$base_branch"..HEAD 2>/dev/null | head -1)
  if [ "${#pr_title}" -gt 70 ]; then
    pr_title="${pr_title:0:67}..."
  fi

  local pr_body
  pr_body=$(generate_pr_body "$base_branch")

  local pr_body_file
  pr_body_file=$(temp_file)
  echo "$pr_body" > "$pr_body_file"

  echo ""
  echo "===================="
  printf "${GREEN}%s${NC}\n" "PR Preview Ready"
  echo "  Title: $pr_title"
  echo "  Body:  $pr_body_file"
  echo ""

  if [ "$draft" != "true" ]; then
    if gh pr create --title "$pr_title" --body "$pr_body" --base "$base_branch" 2>/dev/null; then
      printf "${GREEN}%s${NC}\n" "PR created successfully"
    else
      printf "${YELLOW}%s${NC}\n" "PR creation failed. Manual command:"
      echo "  gh pr create --title \"$pr_title\" --body-file \"$pr_body_file\" --base \"$base_branch\""
    fi
  else
    echo "Draft mode — run 'gh pr create' manually to submit"
  fi
}

# ── Preview PR (no creation) ──────────────────────────────

preview_pr() {
  local base_branch="${1:-main}"

  printf "${BLUE}%s${NC}\n" "Nexus PR Preview"
  echo "===================="

  analyze_changes "$base_branch"
  extract_tickets "$base_branch"
  recommend_reviewers "$base_branch"
  decision_context

  echo ""
  echo "===================="
  printf "${GREEN}%s${NC}\n" "PR Body Preview:"
  echo "---"
  generate_pr_body "$base_branch"
}

# ── Main ──────────────────────────────────────────────────

COMMAND="${1:-preview}"
BASE_BRANCH="${2:-main}"

case "$COMMAND" in
  create)  create_pr "$BASE_BRANCH" "false" ;;
  draft)   create_pr "$BASE_BRANCH" "true" ;;
  preview|*) preview_pr "$BASE_BRANCH" ;;
esac
