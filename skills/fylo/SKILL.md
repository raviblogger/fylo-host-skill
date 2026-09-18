---
name: fylo
description: Publish HTML pages and static sites to the web with Fylo.Host and get a live public URL back (yoursite.fylo.dev), then update them in place. Use this whenever the user wants to publish, deploy, host, share, put online, or "get a link for" anything you built or they gave you — a landing page, portfolio, calculator, dashboard, prototype, artifact, or any HTML file — even if they do not name Fylo. Also use it when the user says "fylo", "fylo.host", "fylo.dev", or asks to update a site that was published with Fylo before.
---

# Fylo.Host — publish a site, get a URL

Fylo.Host hosts static sites on Cloudflare's edge (330+ cities, ~100 ms TTFB). One API call turns an HTML file into a live website at `https://<subdomain>.fylo.dev`; a second call updates it in place. Sites need no account to view.

## 1. Get the API key

Read `FYLO_API_KEY` from the environment. If it is not set, stop and ask the user for one — do not guess or search for it in files:

> I need a Fylo.Host API key. Create one at https://fylo.host/dashboard/settings/api, then either `export FYLO_API_KEY=fylo_live_...` or paste it here.

Keys look like `fylo_live_` followed by 32 characters. Never print the key back to the user or write it into project files. A pasted key can be used for the current session only.

## 2. Prepare the site

Two shapes are accepted:

- **Single page** — `{"html": "<complete document>"}`. Inline the CSS and JS; images as `https://` URLs or data URIs. Max 10 MB. Works on every plan for both create and update.
- **Multi-file site** — `{"files": [{"path": "index.html", "content": "..."}, {"path": "css/app.css", "content": "..."}, {"path": "img/logo.png", "content": "<base64>", "encoding": "base64"}]}`. Text files as strings, binaries (png/jpg/webp/woff2/pdf…) as base64 with `"encoding": "base64"`. Paths are relative to the site root, no leading `/` or `..`. Must include at least one `.html`; `index.html` is the entry page. Up to 2,000 files and 20 MB per request. Creating works on every plan; **updating** a site with `files` needs a paid plan (free accounts get `402 plan_limit` — use `html` for single-page updates there).

Prefer `files` whenever the project has more than one file: relative links, stylesheets and images then work exactly as they do locally. Use `scripts/publish-dir.sh <dir>` to build the payload from a folder (skips `.git`, `node_modules`, dotfiles, `.fylo.json`).

React / JSX / anything needing a build step: run the build first and publish the output folder (`dist`, `build`, `out`). Never publish source that the browser cannot run.

Sites over 20 MB: tell the user to upload a ZIP at https://fylo.host instead.

## 3. Publish (new site)

```bash
curl -s https://fylo.host/api/v1/sites \
  -H "Authorization: Bearer $FYLO_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @payload.json
```

where `payload.json` is `{"html": ..., "subdomain": "optional-slug"}` or `{"files": [...], "subdomain": "optional-slug"}`. Build the JSON with a real serializer (`jq -Rs`, Python `json.dumps`, Node `JSON.stringify`) — never by string concatenation. Helpers: `scripts/publish.sh index.html [subdomain]` for one file, `scripts/publish-dir.sh <dir> [subdomain]` for a folder.

- `subdomain` is optional: 1–40 lowercase letters, digits and hyphens. Omit it and Fylo picks one. Suggest a short, relevant slug derived from the page title when the user has not given one.
- Success is `201` with `{ "id", "subdomain", "url", "status", "created_at", "expires_at" }`. Show the user the `url` and open it if you can.

Save the returned `id` and `url` into `.fylo.json` in the project directory (`{"id": "...", "url": "...", "subdomain": "..."}`) so future publishes update the same site. Add `.fylo.json` to `.gitignore` only if the user asks; it contains no secrets.

## 4. Update (existing site)

If `.fylo.json` exists, or the user names an existing site, update it instead of creating a new one — a new publish would consume a project slot and change the URL:

```bash
curl -s -X PUT https://fylo.host/api/v1/sites/<id> \
  -H "Authorization: Bearer $FYLO_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @payload.json
```

Same body shapes as create. Returns `200` with the site object; the URL stays the same and the edge cache is rebuilt automatically.

To find sites when there is no `.fylo.json`: `GET /api/v1/sites` returns `{ "sites": [...] }` for the key's account.

## 4b. Version history (undo a bad publish)

Every update saves the previous site as a version (free 3, starter 5, pro 20, business 24). Versions count against the plan's storage; the oldest are removed automatically when a new one needs room, so publishing is never blocked by them. If a publish broke something, roll back instead of re-uploading:

```bash
curl -s https://fylo.host/api/v1/sites/<id>/versions -H "Authorization: Bearer $FYLO_API_KEY"
# → {"limit":20,"versions":[{"id":"v_...","created_at":1758000000,"source":"api","files":12,"bytes":348112,"pages":3}, ...]}
curl -s -X POST https://fylo.host/api/v1/sites/<id>/restore -H "Authorization: Bearer $FYLO_API_KEY" \
  -H "Content-Type: application/json" -d '{"version_id":"v_..."}'
```

Restore keeps the URL, rebuilds the cache and saves the current content as a new version first, so it is reversible. Tell the user which version you restored (time + source).

## 5. Errors and what to do

| Status | code | Do this |
|---|---|---|
| 401 | `unauthenticated` | Key missing, wrong, or revoked → step 1 |
| 400 | `missing_html` / `invalid_subdomain` | Fix the payload; check the slug rule |
| 409 | `subdomain_taken` | Try another slug (append a short suffix), or omit `subdomain` |
| 402 | `plan_limit` | Project limit reached, or a `files` update on the free plan. Update an existing site with `html`, or tell the user to delete a site / upgrade at https://fylo.host/#pricing. Do not retry unchanged. |
| 413 | `too_large` | Page over 10 MB — strip inlined images |
| 429 | `rate_limited` | 30 requests/min per key; wait 60 s |
| 400 | `invalid_path` / `duplicate_path` / `invalid_content` | Fix the `files` entry named in the message |
| 422 | `rejected` | A file was blocked by moderation (executables, pirated-media names). Remove it |
| 502 | `partial_publish` | Site exists with only its entry page; the response includes `site`. Retry the same `files` with `PUT /sites/<site.id>` |

Errors are JSON: `{ "error": { "code", "message" } }`.

## Reference

- Base URL `https://fylo.host/api/v1`, JSON in and out, `Authorization: Bearer <key>`.
- `GET /me` → `{ id, email, name, plan }` — quick way to verify a key.
- `GET /sites`, `POST /sites`, `GET /sites/:id`, `PUT /sites/:id`.
- Docs: https://fylo.host/docs/api · machine-readable: https://fylo.host/llms.txt
- After publishing, the user can add a custom domain, contact forms, analytics and performance toggles from https://fylo.host/dashboard.
