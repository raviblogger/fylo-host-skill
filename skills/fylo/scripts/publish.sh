#!/usr/bin/env bash
# Publish or update a single HTML file on Fylo.Host.
#   scripts/publish.sh index.html            # new site (or update if .fylo.json exists)
#   scripts/publish.sh index.html my-slug    # new site with a chosen subdomain
# Needs: FYLO_API_KEY, curl, and either jq or python3.
set -euo pipefail
FILE="${1:?usage: publish.sh <file.html> [subdomain]}"
SUB="${2:-}"
: "${FYLO_API_KEY:?FYLO_API_KEY is not set — create one at https://fylo.host/dashboard/api}"
API="https://fylo.host/api/v1"
STATE="$(dirname "$FILE")/.fylo.json"

if command -v jq >/dev/null 2>&1; then
  PAYLOAD=$(jq -Rs --arg sub "$SUB" '{html: .} + (if $sub == "" then {} else {subdomain: $sub} end)' "$FILE")
else
  PAYLOAD=$(python3 -c 'import json,sys; d={"html":open(sys.argv[1]).read()}; s=sys.argv[2]; d.update({"subdomain":s} if s else {}); print(json.dumps(d))' "$FILE" "$SUB")
fi

if [ -f "$STATE" ] && [ -z "$SUB" ]; then
  ID=$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE")
  RES=$(printf '%s' "$PAYLOAD" | curl -s -X PUT "$API/sites/$ID" -H "Authorization: Bearer $FYLO_API_KEY" -H "Content-Type: application/json" --data-binary @-)
else
  RES=$(printf '%s' "$PAYLOAD" | curl -s "$API/sites" -H "Authorization: Bearer $FYLO_API_KEY" -H "Content-Type: application/json" --data-binary @-)
fi

echo "$RES"
if printf '%s' "$RES" | grep -q '"url"'; then
  URL=$(printf '%s' "$RES" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  ID=$(printf '%s' "$RES" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  SUBD=$(printf '%s' "$RES" | sed -n 's/.*"subdomain"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  printf '{"id":"%s","url":"%s","subdomain":"%s"}\n' "$ID" "$URL" "$SUBD" > "$STATE"
  echo "live: $URL"
fi
