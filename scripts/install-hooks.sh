#!/usr/bin/env bash
set -euo pipefail

cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
scripts/validate.sh
HOOK

chmod +x .git/hooks/pre-commit
echo "Pre-commit hook installed."
