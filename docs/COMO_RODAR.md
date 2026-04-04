# Como Rodar o Projeto

Guia rapido para subir o Pulse Monitor localmente, pensado para quem vem de TypeScript/Node.

## TL;DR

Opcao recomendada para iniciar sem dor: Docker Compose.

```bash
cp .env.example .env
# preencher RAILS_MASTER_KEY e, se for usar Discord, DISCORD_BOT_TOKEN no .env
docker compose up --build
```

Aplicacao: http://localhost:3000

## Pre requisitos

- Git
- Docker + Docker Compose (recomendado)
- OU Ruby 3.2.11 para rodar sem Docker

Versao Ruby do projeto: `3.2.11` (arquivo `.ruby-version`).

## Opcao 1: Rodar com Docker (recomendado)

Se a ideia e desenvolver com reload de codigo sem rebuild a cada alteracao, prefira o compose de desenvolvimento mais abaixo. Esta secao e mais proxima de um ambiente fechado/imutavel.

1. Copiar o template de ambiente:

```bash
cp .env.example .env
```

2. Preencher no `.env`:

- `RAILS_MASTER_KEY` com o conteudo de `config/master.key`

O compose local ja vem preparado para subir o Keycloak com realm importado, entao os defaults de `KEYCLOAK_*` do template ja funcionam para desenvolvimento.

3. Subir stack completa:

```bash
docker compose up --build
```

Isso sobe:

- keycloak (OIDC e RBAC local)
- web (Rails)
- worker (Solid Queue)
- chrome (browserless)
- discord-bot

4. Acessar no navegador:

- http://localhost:3000

5. Parar ambiente:

```bash
docker compose down
```

## Opcao 1B: Rodar com Docker Compose de desenvolvimento

Esse e o fluxo para editar codigo e ver o app atualizar sem rebuild a cada alteracao de controller, model, view, CSS ou service Rails.

1. Copiar o template de ambiente:

```bash
cp .env.example .env
```

2. Garantir no `.env` pelo menos:

- `RAILS_MASTER_KEY`
- `KEYCLOAK_WEB_CLIENT_SECRET`
- `KEYCLOAK_BOT_CLIENT_SECRET`

Observacao: o compose de desenvolvimento ja assume defaults para `KC_BOOTSTRAP_ADMIN_USERNAME` e `KC_BOOTSTRAP_ADMIN_PASSWORD` (`admin`/`admin`) se voce nao sobrescrever.

Observacao: o bot Discord agora usa apenas client credentials do Keycloak para falar com a API; nao existe mais `PULSE_API_TOKEN` nesse fluxo.

3. Subir a stack de desenvolvimento:

```bash
docker compose -f docker-compose.dev.yml up --build
```

4. Acessar:

- app Rails: http://localhost:3000
- Keycloak: http://localhost:8081

Usuario seed do Keycloak:

- email: `operator@example.com`
- senha: `pulse-dev-password`

5. Se quiser incluir o bot Discord no mesmo fluxo:

```bash
docker compose -f docker-compose.dev.yml --profile discord up --build
```

6. Derrubar o ambiente:

```bash
docker compose -f docker-compose.dev.yml down
```

### Quando precisa rebuild no compose dev

Nao precisa rebuild para:

- controllers
- models
- views
- helpers
- assets CSS
- arquivos de configuracao lidos em runtime

Precisa rebuild para:

- `Gemfile` / `Gemfile.lock`
- `Dockerfile.dev`
- dependencias de sistema

Comando:

```bash
docker compose -f docker-compose.dev.yml up --build web worker discord-bot
```

### Quando precisa restart no compose dev

O web recarrega bem em `development`. Se voce mexer em fluxo do worker ou do bot e quiser garantir processo limpo, reinicie explicitamente:

```bash
docker compose -f docker-compose.dev.yml restart worker
docker compose -f docker-compose.dev.yml restart discord-bot
```

## Opcao 2: Rodar local com Ruby

1. Garantir Ruby 3.2.11.

```bash
rbenv local 3.2.11
ruby -v
```

2. Instalar gems:

```
sudo apt install -y \
build-essential \
libssl-dev \
libyaml-dev \
libreadline-dev \
zlib1g-dev \
libffi-dev \
libgdbm-dev \
libncurses5-dev \
libdb-dev \
autoconf \
bison \
libtool
```

```bash
bundle install
```

3. Copiar e preencher o `.env`:

```bash
cp .env.example .env
```

Campos minimos para local:

- `RAILS_MASTER_KEY`: pode usar `cat config/master.key`
- `SQLITE_MAX_CONNECTIONS`: opcional, so ajuste se quiser um pool diferente do padrao local `20`

Campos para login web com Keycloak:

- `KEYCLOAK_PUBLIC_BASE_URL`
- `KEYCLOAK_INTERNAL_BASE_URL`
- `KEYCLOAK_REALM`
- `KEYCLOAK_WEB_CLIENT_ID`
- `KEYCLOAK_WEB_CLIENT_SECRET`
- `KEYCLOAK_REDIRECT_URI`

Observacao: agora o modo Ruby local carrega `.env` automaticamente no `bin/rails` e `bin/jobs`.

4. Preparar banco:

```bash
bin/rails db:prepare
bin/rails pulse:prepare_runtime_schemas
bin/rails db:seed
```

5. Subir app (terminal 1):

```bash
bin/rails server
```

6. Subir worker (terminal 2):

```bash
bin/jobs start
```

7. Acessar app:

- http://localhost:3000

## Comandos uteis

Rodar testes:

```bash
bin/rails test
```

Emitir token API para bot/cliente:

```bash
curl -s \
	-d grant_type=client_credentials \
	-d client_id=pulse-bot \
	-d client_secret=pulse-bot-secret \
	http://localhost:8081/realms/pulse/protocol/openid-connect/token | jq .
```

## Mapa rapido para quem vem de TS

- `npm install` -> `bundle install`
- `npm run dev` -> `bin/rails server`
- worker/fila separado -> `bin/jobs start`
- executaveis locais do projeto -> pasta `bin/` (equivale ao papel do `node_modules/.bin` no Node)
- `.env` tambem e usado no modo Ruby local (carregado no boot da aplicacao)

## O que e a pasta bin

Nao e gambiarra. Em apps Rails, a pasta `bin/` vem por padrao.

- `bin/rails`, `bin/rake`, `bin/setup`: wrappers do projeto para usar as versoes corretas de gems.
- `bin/jobs`: wrapper do Solid Queue para subir scheduler/worker com a config do app.
- Beneficio: os comandos ficam reproduziveis por projeto, igual ao conceito de binarios locais no ecossistema Node.

## Problemas comuns

`RAILS_MASTER_KEY missing`

- Defina no `.env`, por exemplo:

```bash
RAILS_MASTER_KEY=cole_aqui_o_valor_de_config_master_key
```

`Keycloak OIDC is not configured`

- Confira se os `KEYCLOAK_*` do `.env` estao preenchidos.
- No compose, o Keycloak local fica em `http://localhost:8081`.
- O usuario seed do realm importado e `operator@example.com` com senha `pulse-dev-password`.

`Could not find table 'solid_queue_recurring_tasks'`

- Preparar os schemas auxiliares do runtime no banco SQLite atual:

```bash
bin/rails pulse:prepare_runtime_schemas
```

- Isso cria, se necessario, as tabelas do Solid Queue, Solid Cache e Solid Cable no banco unificado de desenvolvimento.

`Solid Queue is configured to use 14 threads but the database connection pool is 5`

- Defina no `.env`:

```bash
SQLITE_MAX_CONNECTIONS=20
```

- O projeto agora usa `20` por padrao no SQLite local. So ajuste esse valor se voce aumentar ou reduzir os threads do worker.

`libsodium not available`

- Aviso do discordrb: nao bloqueia o app/worker.
- So impacta suporte a voz no Discord.

Banco SQLite bloqueado (intermitente)

- Verifique se nao existem processos duplicados de app/worker rodando ao mesmo tempo.
