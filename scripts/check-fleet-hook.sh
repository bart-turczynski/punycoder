#!/bin/sh
# Warn when this clone's git pre-push hook is not fleet-ci's (the
# `fleet-ci-hook-installed` hook in .pre-commit-config.yaml).
#
#   sh scripts/check-fleet-hook.sh
#
# The containerized gate (.fleet-ci/gate) runs only from the hook that
# `.fleet-ci/pre-push --install` writes. Without it, a push runs pre-commit's
# hygiene hooks alone. This looks for the marker line that hook carries in
# `hooks/pre-push`, or in `hooks/pre-push.legacy` under pre-commit's migration
# mode (fleet-ci README, "The local gate"). It never runs the gate: the fleet
# standard forbids a pre-commit hook that does.
#
# Warn-only by decision: it always exits 0 until the hook is installed
# fleet-wide, then it becomes a failure.
set -u

marker='# fleet-ci pre-push hook (.fleet-ci/pre-push --install)'

hooks=$(git rev-parse --git-path hooks 2>/dev/null) || hooks=""
if [ -n "$hooks" ]; then
  for f in "$hooks/pre-push" "$hooks/pre-push.legacy"; do
    if [ -f "$f" ] && grep -qF -- "$marker" "$f"; then
      exit 0
    fi
  done
fi

cat >&2 <<'EOF'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! WARNING: the containerized gate is not installed in this clone, so
!! this push ran only the hygiene hooks: no R CMD check, lintr, docs
!! drift or spelling. Install it once, from the package root:
!!
!!     .fleet-ci/pre-push --install
!!
!! then push again.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
exit 0
