# Contributing to Nexus

## Development Setup

```bash
# Clone and link
git clone https://github.com/user/nexus.git
ln -s "$(pwd)/nexus" ~/.claude/skills/nexus

# Make scripts executable
chmod +x scripts/*.sh
```

## Testing Changes

1. Run `/nexus:init` in a test project
2. Test each command: `context`, `guardrails`, `graph`, `decision`, `pr`, `dashboard`
3. Verify no errors in Claude Code output

## Code Style

- Shell scripts: `#!/bin/bash` with `set -euo pipefail`
- Use `shellcheck` to lint: `shellcheck scripts/*.sh`
- No hardcoded credentials — always use env vars
- Cross-platform: avoid `/tmp/` (use `$TMPDIR` or `$NEXUS_HOME/sessions/`)
- No external dependencies beyond `bash`, `git`, `gh`, `jq`

## Adding Guardrails Rules

Add to `scripts/guardrails-check.sh` in the `RULESEOF` block:

```
severity|id|regex-pattern|message
```

Severities: `error` | `warning` | `info`

## Adding Language Support

1. Add language detection in `detect_language()` (knowledge-graph.sh)
2. Add import parsing in `analyze_dependencies()`
3. Update file extension filters

## PR Guidelines

- Keep PRs focused (single capability or fix)
- Include test evidence in PR description
- Update CHANGELOG.md
