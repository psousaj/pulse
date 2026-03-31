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
2. Instalar gems:

```bash
bundle install
```

3. Preparar banco:

```bash
bin/rails db:prepare
bin/rails db:seed
```

4. Subir app (terminal 1):

```bash
bin/rails server
```

5. Subir worker (terminal 2):

```bash
bin/jobs start
```

6. Acessar app:

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
- `.env` continua sendo o ponto de configuracao

## Problemas comuns

`RAILS_MASTER_KEY missing`

- Ajuste `RAILS_MASTER_KEY` no `.env`.

`JWT_SECRET is missing`

- Defina `JWT_SECRET` no `.env`.

Banco SQLite bloqueado (intermitente)

- Verifique se nao existem processos duplicados de app/worker rodando ao mesmo tempo.
