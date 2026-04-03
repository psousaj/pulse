# Migracao Monitor-First

Runbook curto para sair do modelo legado baseado em `ServiceCheck` e `CheckResult` e cortar totalmente para `PulseMonitor`, `HealthEvent` e `MonitorSlaRollup`.

## Objetivo

- manter leitura e operacao do produto centradas em monitor
- identificar servicos ainda dependentes do runtime legado
- planejar o momento de desligar scheduler/jobs antigos sem perder cobertura

## Auditoria inicial

Rodar o task abaixo para enxergar onde ainda existe dependencia de `service_checks`:

```bash
bin/rails pulse:audit_legacy_monitoring
```

O task mostra:

- servicos com checks legados ainda ativos
- servicos sem monitores suficientes
- volume de `CheckResult`
- incidentes ainda ligados a `service_check`

## Mapeamento recomendado

Para cada `Service`:

1. listar `service_checks` ainda ativos
2. criar `PulseMonitor` equivalente para cada check critico
3. transferir config relevante para `monitor.config_json`
4. anexar bindings externos ou heartbeat quando a origem nao for polling interno
5. validar que o dashboard e a API nova refletem o estado esperado do monitor

Mapeamento inicial sugerido:

- check HTTP legado -> monitor `http_polling`
- check browser legado -> monitor `synthetic_browser`
- heartbeat legado -> binding `heartbeat` com `HeartbeatToken` vinculado ao monitor
- integracao externa -> binding `integration` apontando para `IntegrationEndpoint`

## Estrategia de cutover

1. manter legado e monitor-first em paralelo por uma janela curta
2. comparar estado atual de servico com pior status entre monitores primarios
3. confirmar que novos incidentes e rollups saem de `HealthEvent` e nao mais de `CheckResult`
4. quando a cobertura estiver completa, remover jobs legados de recorrencia
5. depois disso, iniciar limpeza de codigo e dados antigos com uma migracao dedicada

## Ordem pratica para desligar o legado

1. parar de criar novos `ServiceCheck`
2. garantir que cada origem externa ou heartbeat ja entra pelo pipeline novo
3. remover o scheduler legado de `config/recurring.yml`
4. remover o executor legado e o `Monitoring::IncidentEngine` antigo
5. migrar ou arquivar `CheckResult` e referencias legadas em `Incident`

## Observacoes

- bindings `heartbeat` agora devem sempre apontar para um `HeartbeatToken` real
- se o binding heartbeat for criado sem selecionar token existente, o sistema cria um token dedicado automaticamente
- rotacao de token deve acontecer pela UI do binding heartbeat para manter `HeartbeatToken` e `MonitorSourceBinding` sincronizados