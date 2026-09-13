# ICX Genie Handoff

## Project

- Path: `/Users/firozmondal/Downloads/ICX Genie`
- Repository: `https://github.com/chatwoot/chatwoot.git`
- Branch: `develop`
- Starting commit: `2f1ed80f8 fix(captain): refine overview reporting and design (#15722)`
- Local URL: http://localhost:3000

## Current State

Chatwoot is running locally through Docker Desktop using the official production image. The database was initialized with `db:chatwoot_prepare`.

Running services:

- Rails: `127.0.0.1:3000`
- PostgreSQL: `127.0.0.1:5432`
- Redis: `127.0.0.1:6379`
- Sidekiq background worker

The application responds successfully and Rails/Sidekiq logs show normal activity.

## Local Changes

- Added an ignored `.env` containing local Docker configuration and generated secrets. Do not commit or expose it.
- Updated `docker-compose.production.yaml` so PostgreSQL reads its database name, username, and password from `.env`.
- Added this handoff document.

Check changes with:

```bash
git status --short
git diff -- docker-compose.production.yaml handsoff.md
```

## Docker Commands

Open Docker Desktop before running these commands.

```bash
docker compose -f docker-compose.production.yaml ps
docker compose -f docker-compose.production.yaml up -d
docker compose -f docker-compose.production.yaml down
docker compose -f docker-compose.production.yaml logs -f rails sidekiq
```

If `docker` is not found in the current shell, restart the terminal or use:

```bash
/Applications/Docker.app/Contents/Resources/bin/docker compose -f docker-compose.production.yaml ps
```

The Docker binary path was added to `~/.zshrc` for future shells.

## Database

Re-run setup only when necessary:

```bash
docker compose -f docker-compose.production.yaml run --rm rails bundle exec rails db:chatwoot_prepare
```

Docker named volumes persist PostgreSQL, Redis, and Chatwoot storage data when containers are stopped.

## OpenCode Skills

Global skills were installed under `~/.config/opencode/skills/`:

- `ponytail`
- `ponytail-review`
- `ponytail-audit`
- `ponytail-debt`
- `ponytail-gain`
- `ponytail-help`
- `ui-ux-pro-max`

Ponytail slash commands were installed under `~/.config/opencode/commands/`. Restart OpenCode to load new global skills and commands.

## Project Rules

Read `AGENTS.md` before editing. Key requirements include:

- Prefer the smallest production-ready change.
- Use Vue 3 Composition API with `<script setup>`.
- Use Tailwind utilities only; avoid custom, scoped, or inline CSS.
- Use i18n rather than bare user-facing strings.
- Check corresponding Enterprise files when changing shared behavior.
- Do not write specs unless explicitly requested.

## Notes

- Docker Compose prints a harmless warning that its top-level `version` attribute is obsolete.
