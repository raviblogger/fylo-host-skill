#!/usr/bin/env bash
# Publish a folder as a multi-file site on Fylo.Host (or update it if .fylo.json exists in the folder).
#   scripts/publish-dir.sh ./dist            # create (or update)
#   scripts/publish-dir.sh ./dist my-slug    # create with a chosen subdomain
# Needs: FYLO_API_KEY, curl, python3. Skips .git, node_modules, dotfiles and .fylo.json.
set -euo pipefail
DIR="${1:?usage: publish-dir.sh <dir> [subdomain]}"; SUB="${2:-}"
: "${FYLO_API_KEY:?FYLO_API_KEY is not set — create one at https://fylo.host/dashboard/settings/api}"
API="https://fylo.host/api/v1"; STATE="$DIR/.fylo.json"; TMP="$(mktemp)"
python3 - "$DIR" "$SUB" > "$TMP" << 'PY'
import json, os, sys, base64
root, sub = sys.argv[1], sys.argv[2]
TEXT = {'.html','.htm','.css','.js','.mjs','.json','.txt','.md','.svg','.xml','.webmanifest','.map','.csv','.ics'}
files = []
for dp, dns, fns in os.walk(root):
    dns[:] = [d for d in dns if not d.startswith('.') and d != 'node_modules']
    for fn in fns:
        if fn.startswith('.'): continue
        p = os.path.join(dp, fn); rel = os.path.relpath(p, root).replace(os.sep, '/')
        ext = os.path.splitext(fn)[1].lower()
        with open(p, 'rb') as fh: data = fh.read()
        if ext in TEXT:
            try: files.append({'path': rel, 'content': data.decode('utf-8')}); continue
            except UnicodeDecodeError: pass
        files.append({'path': rel, 'content': base64.b64encode(data).decode('ascii'), 'encoding': 'base64'})
if not any(f['path'].lower().endswith(('.html', '.htm')) for f in files): sys.exit('no .html file in ' + root)
body = {'files': files}
if sub: body['subdomain'] = sub
print(json.dumps(body))
PY
if [ -f "$STATE" ] && [ -z "$SUB" ]; then
  ID=$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE")
  RES=$(curl -s -X PUT "$API/sites/$ID" -H "Authorization: Bearer $FYLO_API_KEY" -H "Content-Type: application/json" --data-binary @"$TMP")
else
  RES=$(curl -s "$API/sites" -H "Authorization: Bearer $FYLO_API_KEY" -H "Content-Type: application/json" --data-binary @"$TMP")
fi
rm -f "$TMP"; echo "$RES"
if printf '%s' "$RES" | grep -q '"url"'; then
  URL=$(printf '%s' "$RES" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  ID=$(printf '%s' "$RES" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  SUBD=$(printf '%s' "$RES" | sed -n 's/.*"subdomain"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  printf '{"id":"%s","url":"%s","subdomain":"%s"}\n' "$ID" "$URL" "$SUBD" > "$STATE"; echo "live: $URL"
fi
