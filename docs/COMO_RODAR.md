# Como Rodar o Projeto

Guia rapido para subir o Pulse Monitor localmente, pensado para quem vem de TypeScript/Node.

## TL;DR

Opcao recomendada para iniciar sem dor: Docker Compose.

```bash
cp .env.example .env
# preencher RAILS_MASTER_KEY e JWT_SECRET no .env
docker compose up --build
```

Aplicacao: http://localhost:3000

## Pre requisitos

- Git
- Docker + Docker Compose (recomendado)
- OU Ruby 3.2.11 para rodar sem Docker

Versao Ruby do projeto: `3.2.11` (arquivo `.ruby-version`).

## Opcao 1: Rodar com Docker (recomendado)

1. Copiar o template de ambiente:

```bash
cp .env.example .env
```

2. Preencher no `.env`:

- `RAILS_MASTER_KEY` com o conteudo de `config/master.key`
- `JWT_SECRET` com um valor longo e aleatorio

Exemplo para gerar segredo:

```bash
openssl rand -hex 32
```

3. Subir stack completa:

```bash
docker compose up --build
```

Isso sobe:

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
- `JWT_SECRET`: gere com `openssl rand -hex 32`
- `SQLITE_MAX_CONNECTIONS`: opcional, so ajuste se quiser um pool diferente do padrao local `20`

Para login web com GitHub, tambem precisa definir:

- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`

Observacao: agora o modo Ruby local carrega `.env` automaticamente no `bin/rails` e `bin/jobs`.

Se essas duas variaveis nao estiverem presentes no boot da aplicacao, a rota `/auth/github` nao sera registrada pelo OmniAuth e o login web ficara indisponivel.

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
bin/rails "pulse:issue_api_token[user@example.com,discord-bot]"
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

`JWT_SECRET is missing`

- Defina no `.env`, por exemplo:

```bash
JWT_SECRET=gere_com_openssl_rand_-hex_32
```

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
