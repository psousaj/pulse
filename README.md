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
- Keycloak for OIDC login and JWT-based RBAC
- Discord bot (separate container)

## Services (Docker Compose)

The project runs with 5 services:

1. `keycloak` - local OIDC provider with seeded realm, clients, and operator account
2. `web` - Rails app (dashboard + API + public status page)
3. `worker` - Solid Queue scheduler and job workers
4. `chrome` - Headless Chrome for synthetic checks (Ferrum)
5. `discord-bot` - alert/command bot process

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

3. If you want to use the dashboard login locally, provide the Keycloak OIDC settings before booting Rails:

	```bash
	export KEYCLOAK_PUBLIC_BASE_URL=http://localhost:8081
	export KEYCLOAK_INTERNAL_BASE_URL=http://localhost:8081
	export KEYCLOAK_REALM=pulse
	export KEYCLOAK_WEB_CLIENT_ID=pulse-web
	export KEYCLOAK_WEB_CLIENT_SECRET=pulse-web-secret
	export KEYCLOAK_REDIRECT_URI=http://localhost:3000/callback
	```

4. Run web app:

	```bash
	bin/rails server
	```

5. Run worker in another terminal:

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
	- `KEYCLOAK_WEB_CLIENT_SECRET`
	- `KEYCLOAK_BOT_CLIENT_SECRET`
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
- Keycloak OIDC login scaffold for dashboard sessions and JWT RBAC on the API

## Useful Commands

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
