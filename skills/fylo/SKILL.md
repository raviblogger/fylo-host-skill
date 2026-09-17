---
name: fylo
description: Publish HTML pages and static sites to the web with Fylo.Host and get a live public URL back (yoursite.fylo.dev), then update them in place. Use this whenever the user wants to publish, deploy, host, share, put online, or "get a link for" anything you built or they gave you — a landing page, portfolio, calculator, dashboard, prototype, artifact, or any HTML file — even if they do not name Fylo. Also use it when the user says "fylo", "fylo.host", "fylo.dev", or asks to update a site that was published with Fylo before.
---

# Fylo.Host — publish a site, get a URL

Fylo.Host hosts static sites on Cloudflare's edge (330+ cities, ~100 ms TTFB). One API call turns an HTML file into a live website at `https://<subdomain>.fylo.dev`; a second call updates it in place. Sites need no account to view.

## 1. Get the API key

Read `FYLO_API_KEY` from the environment. If it is not set, stop and ask the user for one — do not guess or search for it in files:

> I need a Fylo.Host API key. Create one at https://fylo.host/dashboard/api, then either `export FYLO_API_KEY=fylo_live_...` or paste it here.

Keys look like `fylo_live_` followed by 32 characters. Never print the key back to the user or write it into project files. A pasted key can be used for the current session only.

## 2. Prepare the page

v1 publishes **one self-contained HTML file**. Before publishing:

- Inline all CSS and JavaScript into the HTML (`<style>` and `<script>` blocks). External `https://` links to CDNs and Google Fonts are fine; relative `./style.css` or `./app.js` references are not — they will 404.
- Images: use absolute `https://` URLs or data: URIs. Local image files are not uploaded.
- React / JSX / anything needing a build step: build it first, then inline the output, or rewrite it as plain HTML+JS.
- Keep the file under 10 MB.

If the project is genuinely multi-file (several pages, an assets folder) tell the user: "Fylo's API currently takes a single HTML file. I can inline everything into one page, or you can upload the folder as a ZIP at https://fylo.host." Do not try to zip and upload yourself.

## 3. Publish (new site)

```bash
curl -s https://fylo.host/api/v1/sites \
  -H "Authorization: Bearer $FYLO_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @payload.json
```

where `payload.json` is `{"html": "<the whole file as a JSON string>", "subdomain": "optional-slug"}`. Build the JSON with a real serializer (`jq -Rs`, Python `json.dumps`, Node `JSON.stringify`) — never by string concatenation. Helper: `scripts/publish.sh index.html [subdomain]`.

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

Same body shape (`html` only). Returns `200` with the site object; the URL stays the same and the edge cache is rebuilt automatically.

To find sites when there is no `.fylo.json`: `GET /api/v1/sites` returns `{ "sites": [...] }` for the key's account.

## 5. Errors and what to do

| Status | code | Do this |
|---|---|---|
| 401 | `unauthenticated` | Key missing, wrong, or revoked → step 1 |
| 400 | `missing_html` / `invalid_subdomain` | Fix the payload; check the slug rule |
| 409 | `subdomain_taken` | Try another slug (append a short suffix), or omit `subdomain` |
| 402 | `plan_limit` | The account's project limit is reached. Update an existing site (step 4) or tell the user to delete one / upgrade at https://fylo.host/#pricing. Do not retry. |
| 413 | `too_large` | Page over 10 MB — strip inlined images |
| 429 | `rate_limited` | 30 requests/min per key; wait 60 s |
| 501 | `multi_file_not_supported` | See step 2 |

Errors are JSON: `{ "error": { "code", "message" } }`.

## Reference

- Base URL `https://fylo.host/api/v1`, JSON in and out, `Authorization: Bearer <key>`.
- `GET /me` → `{ id, email, name, plan }` — quick way to verify a key.
- `GET /sites`, `POST /sites`, `GET /sites/:id`, `PUT /sites/:id`.
- Docs: https://fylo.host/docs/api · machine-readable: https://fylo.host/llms.txt
- After publishing, the user can add a custom domain, contact forms, analytics and performance toggles from https://fylo.host/dashboard.
