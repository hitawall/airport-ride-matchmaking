#!/usr/bin/env bash
# Bootstraps a local dev environment for airport-ride-matchmaking on a new machine.
# Safe to re-run -- every step is idempotent.
#
# Usage: from the repo root, run:
#   bash scripts/setup-dev-environment.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "== airport-ride-matchmaking dev environment setup =="
echo "Repo root: $REPO_ROOT"
echo

missing_tools=()

check() {
  local name="$1" cmd="$2" install_hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [ok] $name ($("$cmd" --version 2>&1 | head -n1))"
  else
    echo "  [MISSING] $name -- $install_hint"
    missing_tools+=("$name")
  fi
}

echo "-- Checking required tools --"
check "Node.js (>=22)" node "install via https://nodejs.org or 'brew install node'"
check "pnpm" pnpm "npm install -g pnpm"
check "Flutter SDK" flutter "brew install --cask flutter"
check "Vercel CLI" vercel "npm install -g vercel@latest"
check "GitHub CLI" gh "brew install gh"
echo

if [ ${#missing_tools[@]} -gt 0 ]; then
  echo "Install the missing tools above, then re-run this script."
  exit 1
fi

echo "-- Checking authentication --"
if gh auth status >/dev/null 2>&1; then
  echo "  [ok] gh authenticated"
else
  echo "  [ACTION NEEDED] Run: gh auth login"
fi

if vercel whoami >/dev/null 2>&1; then
  echo "  [ok] vercel authenticated as $(vercel whoami 2>&1)"
else
  echo "  [ACTION NEEDED] Run: vercel login"
fi
echo

echo "-- Installing TypeScript workspace dependencies (apps/api, packages/db) --"
pnpm install

echo
echo "-- Installing Flutter dependencies (apps/mobile) --"
(cd apps/mobile && flutter pub get)

echo
echo "-- Linking Vercel project and pulling environment variables --"
echo "   (requires 'vercel login' above to have succeeded, and access to the"
echo "    'shubham-arora-s-projects' Vercel team)"
if vercel whoami >/dev/null 2>&1; then
  vercel link --project airport-ride-matchmaking-api --yes
  vercel env pull .env.local
  echo "  [ok] .env.local pulled to repo root"
else
  echo "  [skipped] run 'vercel login' first, then re-run this script"
fi

echo
echo "-- Checking flutter doctor (web target is all that's required for this project) --"
flutter doctor | grep -A1 "Chrome" || true

cat <<'EOF'

== Setup complete (or see ACTION NEEDED items above) ==

Next steps:
  1. Read docs/PROJECT_STATE.md for current status and open items.
  2. Run the API locally:
       cp .env.local apps/api/.env.local   # Next.js reads .env.local from its own dir
       cd apps/api && pnpm dev             # http://localhost:3000
  3. Run the Flutter web app locally (in another terminal):
       cd apps/mobile
       flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
     Login with any phone number, OTP code 000000 (OTP_TEST_MODE is on in prod;
     set OTP_TEST_MODE=true in apps/api/.env.local for local testing too).
  4. If starting a Claude Code session fresh on this machine, ask it to read
     docs/PROJECT_STATE.md and docs/MVP_PLAN.md (or just use the
     "resume-project" skill, if your Claude Code setup picks up .claude/skills/).

Remember: every change goes through an issue -> branch -> PR -> CI -> merge
cycle (see CLAUDE.md). Never push directly to main.
EOF
