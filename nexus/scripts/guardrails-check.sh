#!/bin/bash
# ============================================================
# Nexus — Guardrails Engine
# Checks code against team standards and security rules
# Pure bash — no python3/yaml dependency
# ============================================================

set -euo pipefail

NEXUS_HOME="${NEXUS_HOME:-$HOME/.nexus}"
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
mkdir -p "$NEXUS_HOME/guardrails"

GLOBAL_RULES="$NEXUS_HOME/guardrails/global.txt"

# ── Initialize built-in rules (simple key=pattern format) ──

if [ ! -f "$GLOBAL_RULES" ]; then
  cat > "$GLOBAL_RULES" << 'RULESEOF'
# Nexus Guardrails — one rule per line: SEVERITY|ID|PATTERN|MESSAGE

error|security/no-sql-injection|`.*\$\{.*\}.*`|SQL injection: string interpolation in query. Use parameterized queries.
error|security/no-sql-injection|query\s*=\s*".*".*\+|SQL injection: string concatenation in query. Use parameterized queries.
error|security/no-xss|innerHTML\s*=|XSS risk: innerHTML assignment. Use textContent or safe HTML.
error|security/no-xss|dangerouslySetInnerHTML|XSS risk: dangerouslySetInnerHTML. Use safe alternatives.
error|security/no-xss|document\.write\(|XSS risk: document.write(). Avoid this pattern.
error|security/no-xss|eval\(|Security risk: eval(). Never use eval with user input.
error|security/no-hardcoded-secrets|(api_?key|apikey|secret|password|token)\s*[:=]\s*["'][A-Za-z0-9_-]{20,}["']|Hardcoded secret detected. Use environment variables.
error|security/no-hardcoded-secrets|(API_KEY|SECRET|PASSWORD|TOKEN)\s*=\s*["'][^"']{10,}["']|Hardcoded secret detected. Use environment variables.

warning|quality/no-n-plus-1|\.forEach\(.*await.*\.find|N+1 query pattern. Use batch queries or joins.
warning|quality/no-n-plus-1|for\s*\(.*\).*\{\s*\n\s*await.*\.find|N+1 query pattern. Use batch queries or joins.
warning|quality/no-unhandled-promise|async\s+function(?!.*try|.*catch|.*\.catch)|Unhandled async operation. Add try/catch or .catch().

info|style/no-todo-without-ticket|//\s*TODO\s*$|TODO without ticket reference. Use: // TODO(#123): description
info|style/no-todo-without-ticket|//\s*FIXME\s*$|FIXME without ticket reference. Use: // FIXME(#123): description
info|quality/no-console|console\.(log|debug|warn)\(|Debug log detected. Use structured logging in production.
RULESEOF
  echo "  [nexus] Created default guardrails: $GLOBAL_RULES"
fi

# ── Check a single file ──────────────────────────────────

check_file() {
  local file="$1"
  local found=0

  while IFS='|' read -r severity id pattern message; do
    # Skip empty lines and comments
    [ -z "$severity" ] && continue
    case "$severity" in
      \#*) continue ;;
    esac

    # Run grep, capture matches
    local matches
    matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
    [ -z "$matches" ] && continue

    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local lineno=$(echo "$line" | cut -d: -f1)
      local content=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//')

      case "$severity" in
        error)
          printf "  [ERROR] %s L%s: %s\n" "$id" "$lineno" "$message"
          printf "          -> %s\n" "$content"
          found=$((found + 3))
          ;;
        warning)
          printf "  [WARN]  %s L%s: %s\n" "$id" "$lineno" "$message"
          printf "          -> %s\n" "$content"
          found=$((found + 1))
          ;;
        info)
          printf "  [INFO]  %s L%s: %s\n" "$id" "$lineno" "$message"
          ;;
      esac
    done <<< "$matches"
  done < "$GLOBAL_RULES"

  return "$found"
}

# ── Main ──────────────────────────────────────────────────

MODE="${1:-diff}"

echo "Nexus Guardrails Check"
echo "======================"

case "$MODE" in
  diff)
    echo "Mode: changed files only"
    FILES=$(git diff --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java)$' || true)
    ;;
  full)
    echo "Mode: full project scan"
    FILES=$(git ls-files 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java)$' || true)
    ;;
  file)
    FILES="${2:-}"
    if [ -z "$FILES" ] || [ ! -f "$FILES" ]; then
      echo "Error: file not found: ${2:-}"
      exit 1
    fi
    ;;
  *)
    echo "Usage: guardrails-check.sh [diff|full|file <path>]"
    exit 1
    ;;
esac

if [ -z "$FILES" ]; then
  echo "No files to check."
  exit 0
fi

# Use process substitution to avoid subshell variable loss
total_issues=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue

  echo ""
  echo "Checking: $file"

  check_file "$file"
  file_issues=$?
  total_issues=$((total_issues + file_issues))
done <<< "$(echo "$FILES")"

echo ""
echo "======================"
echo "Guardrails check complete — $total_issues issue points found"
echo "(error=3pts, warning=1pt, info=0pt)"
