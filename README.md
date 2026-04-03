# Pulse Monitor

Personal uptime/healthcheck monitor built with Rails 8.1, Solid Queue, Solid Cache, and SQLite in WAL mode. The architecture is designed to stay lightweight for self-hosting while preparing for multi-user and micro-SaaS evolution.

## Onboarding

New to Ruby/Rails or coming from TypeScript? See [docs/COMO_RODAR.md](docs/COMO_RODAR.md) for a practical run guide.

## Stack

- Ruby on Rails 8.1
- ActiveRecord + SQLite3
- Solid Queue + recurring jobs
- Solid Cache
- Ferrum-ready Chrome sidecar
- Discord bot (separate container)

## Services (Docker Compose)

The project runs with 4 services:

1. `web` - Rails app (dashboard + API + public status page)
2. `worker` - Solid Queue scheduler and job workers
3. `chrome` - Headless Chrome for synthetic checks (Ferrum)
4. `discord-bot` - alert/command bot process

## Quick Start (Local Ruby)

1. Install dependencies:

	```bash
	bundle install
	```

2. Prepare DBs and seed check types:

	```bash
	bin/rails db:prepare
	bin/rails pulse:prepare_runtime_schemas
	bin/rails db:seed
	```

3. Run web app:

	```bash
	bin/rails server
	```

4. Run worker in another terminal:

	```bash
	bin/jobs start
	```

## Quick Start (Docker Compose)

1. Copy environment template:

	```bash
	cp .env.example .env
	```

2. Fill required secrets in `.env`:

	- `RAILS_MASTER_KEY`
	- `JWT_SECRET`
	- `GITHUB_CLIENT_ID`
	- `GITHUB_CLIENT_SECRET`
	- `DISCORD_BOT_TOKEN` (if bot enabled)

3. Start stack:

	```bash
	docker compose up --build
	```

## Current Implemented Foundation

- Core data model for services, checks, results, incidents, channels, heartbeat, API tokens, settings, and audit logs
- HTTP check runner with status/body/regex/JSONPath validation, timeout, and latency classification
- Scheduler and execution jobs via Solid Queue
- Incident engine with open/resolved transitions and heartbeat incident handling
- Notification dispatcher scaffolding (Discord/Webhook/Email)
- Heartbeat endpoint: `POST /api/heartbeat/:token`
- Versioned management API scaffold: `/api/v1/services`, `/api/v1/incidents`
- GitHub OAuth login scaffold for dashboard sessions

## Useful Commands

- Issue API token for bot/client:

  ```bash
  bin/rails "pulse:issue_api_token[user@example.com,discord-bot]"
  ```

- Run recurring/scheduled workers:

  ```bash
  bin/jobs start
  ```

- Repair local runtime schemas if `bin/jobs start` complains about missing `solid_queue_*` tables:

	```bash
	bin/rails pulse:prepare_runtime_schemas
	```

- Override the SQLite connection pool if you customize worker thread counts:

	```bash
	SQLITE_MAX_CONNECTIONS=24 bin/jobs start
	```
