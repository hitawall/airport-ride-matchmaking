#!/usr/bin/env bash
# Writes the owner-supplied build settings to app-defines.json (in the current
# directory) for `flutter build --dart-define-from-file=app-defines.json`.
# Only variables that are set and non-empty are included, so the app's built-in
# defaults still apply to the rest. Values come from GitHub repository variables
# (Settings > Secrets and variables > Actions > Variables); see
# docs/OWNER_INPUTS.md. jq handles quoting, so values may contain spaces.
set -euo pipefail

json="{}"
for name in APP_NAME OPERATOR_NAME SUPPORT_EMAIL GRIEVANCE_OFFICER LEGAL_JURISDICTION WEB_APP_URL LEGAL_REVIEWED GOOGLE_CLIENT_ID; do
  value="${!name:-}"
  if [ -n "$value" ]; then
    json=$(printf '%s' "$json" | jq --arg k "$name" --arg v "$value" '. + {($k): $v}')
  fi
done

# Release identifier attached to crash reports and usage events, e.g. 1.0.0+3.
version=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | tr -d '\r')
if [ -n "$version" ]; then
  json=$(printf '%s' "$json" | jq --arg v "$version" '. + {APP_VERSION: $v}')
fi

printf '%s\n' "$json" > app-defines.json
echo "Wrote app-defines.json with: $(printf '%s' "$json" | jq -r 'keys | join(", ")')"
