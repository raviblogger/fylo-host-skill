# Fylo.Host skill for AI agents

Teaches Claude Code, Codex, Cursor and any other agent that reads skills how to publish an HTML page to [Fylo.Host](https://fylo.host) and get a live `*.fylo.dev` URL back — and how to update it afterwards.

## Install

```bash
npx skills add raviblogger/fylo-host-skill --skill fylo -g
```

Or copy `skills/fylo/` into your agent's skills directory.

## Use

Get an API key at https://fylo.host/dashboard/api, then:

```bash
export FYLO_API_KEY=fylo_live_...
```

and tell your agent: *"publish this to Fylo"*. It will call `POST https://fylo.host/api/v1/sites`, show you the URL, and remember the site id in `.fylo.json` so the next "publish" updates the same URL.

Manual: `skills/fylo/scripts/publish.sh index.html [subdomain]`.

## API

Docs: https://fylo.host/docs/api · for agents: https://fylo.host/llms.txt

## License

MIT
