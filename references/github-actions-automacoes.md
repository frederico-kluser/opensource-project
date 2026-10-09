# GitHub Actions — automação, pipelines de testes e governança de CI/CD

O CI/CD é onde a governança deixa de ser documento e vira comportamento: o que
`main` aceita, o que o release exige e o que a segurança permite está tudo
escrito em workflows. Esta referência cobre a anatomia completa do GitHub
Actions, os pipelines de testes (o núcleo), reuso, identidade, segurança,
runners, custo, observabilidade e manutenção. Os templates prontos vivem em
`assets/workflows/` (`tests.yml`, `reusable-ci.yml`, `codeql.yml`,
`dependency-review.yml`, mais `ci.yml`, `scorecard.yml`, `release-please.yml`).

## Anatomia de um workflow

Hierarquia: **workflow** (um ficheiro `.github/workflows/*.yml`) → **`on:`**
(gatilhos) → **`jobs`** (executam em paralelo por omissão) → **`steps`**
(sequenciais dentro do job) → **`runs-on`** (a máquina que executa).

```yaml
name: tests
on: { push: { branches: ["{{DEFAULT_BRANCH}}"] }, pull_request: }

permissions:            # SEMPRE no topo: menor privilégio por omissão
  contents: read

concurrency:            # 1 run por ref; o novo cancela o obsoleto
  group: tests-${{ github.ref }}
  cancel-in-progress: true

env:                    # variáveis comuns a todos os jobs
  CI: "true"

defaults:               # omissões (ex.: shell e working-directory)
  run:
    shell: bash

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 30   # SEMPRE: um teste pendurado não come a quota mensal
    steps:
      - uses: actions/checkout@<PIN_SHA> # v4.2.2
      - run: npm ci
```

- **`env` vs `secrets` vs `vars`**: `env` é visível no run; `vars` (Variables) é
  configuração não-sensível versionada na plataforma; `secrets` nunca aparece em
  logs (o GitHub redige valores conhecidos — mesmo assim, nunca os imprima).
- **`if`** em jobs/steps: `if: github.event_name == 'pull_request'`,
  `if: success()`, `if: always()`, `if: failure()`, `if: cancelled()`.
  **`continue-on-error: true`** num job marca-o como tolerado (verde com aviso) —
  use só para experimentos, nunca para o gate principal.
- **`strategy.matrix`**: produto cartesiano de dimensões; `include`/`exclude`
  ajustam combinações; **`fail-fast: false`** para ver todas as falhas de uma vez;
  **matriz dinâmica**: um job "plan" escreve JSON em `$GITHUB_OUTPUT` e o job de
  teste lê `matrix: <campo>: ${{ fromJSON(needs.plan.outputs.<campo>) }}`.
- **`services`**: containers paralelos ao job (ex.: `postgres:16` com `ports` e
  `options: --health-cmd ...`) — perfeito para testes de integração.

### Expressões e contexts

`$ {{ ... }}` (sem espaço) lê contexts. Os que interessa conhecer:

| Context | O que traz | Exemplo de uso |
|---|---|---|
| `github.*` | `event_name`, `ref`, `sha`, `actor`, `repository`, `run_id`, `event` | `if: github.ref == 'refs/heads/main'` |
| `needs.*` | `result` e `outputs` dos jobs anteriores | `if: needs.build.result == 'success'` |
| `steps.*` | `outcome`/`outputs` de steps anteriores | `if: steps.cache.outputs.cache-hit != 'true'` |
| `env` / `vars` / `secrets` | variáveis, configuration vars, segredos | `env: TOKEN: ${{ secrets.NPM_TOKEN }}` |
| `inputs` | entradas de `workflow_call`/`workflow_dispatch` | `if: inputs.run-tests` |
| `runner.*` | `os`, `arch`, `temp`, `tool_cache` | paths de cache |
| `matrix` | valores da combinação atual | `name: test (${{ matrix.os }})` |
| `hashFiles('**/lockfile')` | hash de ficheiros (chaves de cache) | `key: npm-${{ hashFiles('**/package-lock.json') }}` |

**Outputs**: um step exporta com `echo "nome=valor" >> "$GITHUB_OUTPUT"` e lê-se
com `steps.<id>.outputs.nome`; um job exporta com `jobs.<id>.outputs` a partir do
output de step e lê-se como `needs.<id>.outputs.nome` (só entre jobs ligados por
`needs`).

## Gatilhos (`on:`) — quando usar cada um

| Gatilho | Para quê | Notas |
|---|---|---|
| `push` | validar o que entrou em `main`/tags | `branches`/`tags` com padrões (`v*`, `release/**`) |
| `pull_request` | o gate de contribuição (lint/test/build) | correr no merge ref; sem acesso a secrets de produção |
| `workflow_dispatch` | execução manual (botão) | `inputs` tipados: `string`, `boolean`, `choice`, `environment` |
| `schedule` | rotinas (nightly, dependabot merges) | cron **em UTC**; `schedule` em **repos privados** é suspenso após ~60 dias de inatividade e workflows desativados por inatividade de 60/90 dias |
| `workflow_call` | reusable workflows | ver secção de reuso |
| `workflow_run` | reagir ao fim de outro workflow | **perigoso** com código não-confiável (ver Segurança) |
| `release` | publicação quando há release (`published`, `created`) | combina-se com release-please/semantic-release |
| `issues`, `issue_comment`, `pull_request_review` | triagem/bots | cuidado com injeção via títulos/comentários |
| `pull_request_target` | runs privilegiados em PRs de forks | **não corra código do PR** (ver Segurança) |

Regras: **nunca misture `paths` e `paths-ignore` no mesmo gatilho** (o GitHub
rejeita); prefira `paths` por allow-list (`src/**`, `package-lock.json`); lembre
que `paths` num `pull_request` filtra ficheiros alterados, não o conteúdo.

## Pipelines de TESTES (o núcleo)

Padrão canónico em quatro estágios — cada um pode ser job próprio (paralelismo)
ou steps do mesmo job (latência menor):

1. **lint/format** — rápido, falha cedo (`eslint`, `ruff`, `cargo fmt --check`).
2. **test** — matriz de SO/versões; JUnit/XML para relatórios e annotations.
3. **build** — artefato única (`upload-artifact`), semeada para deploy.
4. **coverage** — relatório enviado ao Codecov/Coveralls ou guardado como artefato.

Boas práticas que decidem se o pipeline é sustentável:

- **Matriz enxuta**: teste as versões que suporta (ex.: LTS atual + anterior), não
  todas; `fail-fast: false` em PRs, `true` em main se quiser poupar minutos.
- **Cache**: `actions/cache@<PIN_SHA>` (ou `cache: npm`/`pip` dos `setup-*`) com
  chave `ecossistema-${{ hashFiles('**/lockfile') }}` e `restore-keys` prefixados.
  Cache **nunca acerta** quando a chave muda a cada run — chaves têm de derivar
  do lockfile, não do `github.sha`.
- **Artefactos**: `actions/upload-artifact@<PIN_SHA>` com **nome único por
  combinação de matriz** (`test-results-${{ matrix.os }}-${{ matrix.runtime-version }}`)
  — desde a v4 os nomes são imutáveis no run e colidir devolve erro; use
  `if: always()` para subir relatórios mesmo com falha e `retention-days` curto
  (7–14) para poupar armazenamento.
- **Relatórios e annotations**: publique JUnit e use um reporter (ex.:
  `dorny/test-reporter`) para transformar XML em annotations inline; erros
  aparecem no diff do PR em vez de num log.
- **Cobertura**: `codecov/codecov-action` (com token em PRs de forks via
  `pull_request_target`? não — use o modo público/tokenless ou artefato) ou
  simplesmente `upload-artifact` de `coverage/` + badge do serviço.
- **Sharding/paralelismo**: divida a suíte (`--shard=1/4` no Playwright, `pytest-xdist`)
  em jobs de matriz; para retentativas use `retries` da framework (mais barato que
  repetir o job inteiro) e reserve `timeout-minutes` realista.
- **Testes seletivos**: em monorepo, `paths` por pacote ou um job "changes" que
  deteta pastas alteradas (`tj-actions/changed-files` ou `git diff --name-only`)
  e expõe outputs para condicionar jobs — minutos poupados em PRs pequenos.
- **Latência**: jobs críticos primeiro (`needs` em cadeia curta), cache de
  toolchain (rustup/go cache), `concurrency` para cancelar runs obsoletos.

## Reuso: reusable workflows vs composite actions vs starters

| | Reusable workflow (`workflow_call`) | Composite action (`action.yml`) | Starter workflow |
|---|---|---|---|
| Unidade | workflow inteiro (jobs) | sequência de steps | template copiado |
| Chamada | `uses: OWNER/REPO/.github/workflows/x.yml@ref` | `uses: OWNER/REPO/path@ref` | copiar para `.github/workflows/` |
| Secrets/inputs | `secrets:`, `inputs:`, `outputs:` | `inputs:` (sem secrets) | n/a |
| Permissões | herdadas **por interseção** (o caller não consegue elevar) | do job chamador | do projeto |
| Quando usar | pipelines-standards de equipa (ci, release, deploy) | pequenas receitas (setup+cache+lint) | arranque de novos repos |

**Platform engineering**: mantenha os reusable workflows num repo central
(ex.: `ORG/.github`) e obrigue os projetos a chamá-los — os padrões (timeouts,
permissões, pins) atualizam-se num sítio só. É a base para os templates
`assets/workflows/reusable-ci.yml` e `ci.yml` desta skill.

## Ambientes, secrets e identidade

- **`environment:`** num job liga-o a um Environment do repositório com
  *required reviewers*, janelas de deploy e secrets próprios. Produção exige
  environment; staging não.
- **`secrets` vs `vars`**: tokens vão em `secrets`; nomes de registos, flags e
  URLs vão em `vars` (visíveis, versionáveis sem risco).
- **`GITHUB_TOKEN`**: efémero por run; declare sempre `permissions:` — o default
  do repositório pode ser `write-all` (revise em Settings → Actions → General).
- **OIDC/federação**: em vez de chaves AWS/Azure/GCP longas, peça um token OIDC
  (`permissions: id-token: write` **só no job de deploy**) e configure a trust
  policy da cloud para o `sub` exato — ex. AWS:
  `"token.actions.githubusercontent.com:sub": "repo:ORG/REPO:environment:production"`.
  Chaves longas não existem para roubar; o token dura minutos.
- **Injetar secrets**: `echo "$MINHA_CHAVE" | gh secret set NPM_TOKEN --env production`
  — stdin, nunca argumento de linha de comandos (fica no histórico/shell).

## Segurança (a parte que não é opcional)

1. **Menor privilégio**: `permissions: contents: read` no topo; eleva
   `contents: write`/`id-token: write` **só no step/job de publicação**.
2. **Actions fixadas por SHA**: `owner/repo@<sha40> # vX.Y.Z` — tags móveis podem
   ser reescritas. `bash scripts/oss-pin-actions.sh` converte e
   `--check` vigia (ver `references/seguranca-openssf.md`).
3. **`pull_request_target` e `workflow_run`**: correm com privilégios sobre
   `main`. Se usarem `actions/checkout` do PR ou executarem código do contribuidor,
   é execução de código privilegiado. Regra: ou estes gatilhos, ou código do PR —
   nunca os dois.
4. **Injeção via `${{ github.event.* }}`**: títulos de issue/PR, nomes de branch e
   mensagens de commit chegam ao `run:` como código shell. **Nunca interpole
   `${{ }}` dentro de `run:`** — passe por `env:` (`env: TITLE: ${{ github.event.pull_request.title }}`
   e use `"$TITLE"`).
5. **`persist-credentials: false`** no checkout de workflows que não fazem push.
6. **Ferramentas**: `actionlint` (lint de workflows), Dependabot para
   `github_actions` (atualiza versões), CodeQL/SAST (`codeql.yml`),
   dependency review em PRs (`dependency-review.yml`), e provenance/SLSA
   (`--provenance` no npm/gh attestation) para artefactos auditáveis.

## Runners

| Tipo | Exemplos | Quando |
|---|---|---|
| Hosted Linux | `ubuntu-latest`, `ubuntu-24.04`, `ubuntu-24.04-arm` | predefinição; ARM é grátis em repos públicos |
| Hosted Windows/macOS | `windows-latest`, `macos-14` | 2×–10× mais caros por minuto |
| Larger runners | `ubuntu-latest-4-cores`, GPU, ARM 2–32 vCPU | builds pesados; faturados mesmo em repos públicos |
| Self-hosted | labels próprias (`[self-hosted, linux, gpu]`) | hardware especial, custo fixo, rede interna — **risco**: um self-hosted exposto a PRs de forks executa código desconhecido na vossa máquina |

Minutos grátis por plano (privados; confirme em Settings → Billing): Free 2.000,
Team 3.000, Enterprise 50.000 — repos **públicos** não consomem minutos hosted.

## Custo e performance

- `concurrency` + `cancel-in-progress: true` é a maior poupança em PRs (cancela
  o run anterior do mesmo ref).
- Jobs condicionais: `if: github.event_name == 'push'` para builds pesados;
  `paths` para não correr tudo a cada typo em docs.
- Matriz enxuta + cache quente + `timeout-minutes` = minuto contado só quando é
  preciso. Cada minuto de Windows/macOS multiplica a fatura.
- Divida "fast feedback" (< 5 min: lint + unit) de "slow lane" (integration/e2e)
  em workflows/jobs distintos — o PR tem veredito rápido e detalhe depois.

## Observabilidade e governança

- **Badge**: `![tests](https://github.com/OWNER/REPO/actions/workflows/tests.yml/badge.svg)`
  (ver `references/identidade-e-telemetria.md` para a receita de renderização).
- **`gh`**: `gh run list --workflow=tests.yml`, `gh run view <id> --log-failed`,
  `gh run watch`, `gh run rerun <id> --failed`, `gh workflow enable/disable tests.yml`.
- **Status checks obrigatórios**: o `context` do ruleset é o **nome do job**
  (ex.: `tests-ok`), não `workflow / job` — confirmado empiricamente; ver
  `references/rulesets-e-protecao.md`. Com matriz, mantenha um job agregador de
  nome estável como `context` (padrão em `assets/workflows/tests.yml`).
- **`$GITHUB_STEP_SUMMARY`**: escreva um resumo legível (resultados, coverage)
  que aparece no sumário do run: `echo "### Testes ✅" >> "$GITHUB_STEP_SUMMARY"`.
- **Annotations**: linhas `::error file=app.ts,line=3::mensagem` viram comentários
  no diff.
- **Debug**: ative os secrets `ACTIONS_STEP_DEBUG` e `ACTIONS_RUNNER_DEBUG`
  (`true`) para traces; remova depois. Correção local: `act` (nektos/act) para
  workflows simples — não cobre services/OIDC.

## Manutenção

- Dependabot (`package-ecosystem: github_actions`, weekly) ou Renovate para
  atualizar versões; com pins por SHA, atualize com
  `bash scripts/oss-pin-actions.sh` e registe o bump num commit `chore(ci):`.
- Revise deprecações (ex.: `upload-artifact@v3` descontinuado) e mantenha
  workflows mínimos — um workflow morto é superfície de ataque e ruído.
- Versionamento de reusable workflows: chame-os por tag (`@v2`) e mantenha um
  `CHANGELOG` de breaking changes no repo central.

## Padrões de pipeline por ecossistema (blocos)

**Node** — `setup-node` com `cache: npm`, `npm ci`, vitest/jest com JUnit:
`npx vitest run --reporter=junit --outputFile=test-results/junit.xml`.

**Python** — `setup-python`, `pip install uv && uv pip install -r requirements.txt`,
`pytest --junitxml=test-results/junit.xml --cov=src`.

**Rust** — `dtolnay/rust-toolchain` + `Swatinem/rust-cache`, `cargo test --workspace`.

**Go** — `setup-go` com `cache: true`, `go test ./... -race -coverprofile=coverage.out`.

Em todos: `timeout-minutes`, cache por hash do lockfile e artefatos nomeados por
combinação de matriz (o resto do padrão está em `assets/workflows/tests.yml`).

## Erros comuns (sintoma → causa → correção)

| Sintoma | Causa | Correção |
|---|---|---|
| Workflow não dispara | `paths` sem alterações nesses paths; Actions desativado (Settings → Actions); `schedule` em repo privado suspenso por inatividade | confirme `on:`, ative Actions, faça um commit ou `workflow_dispatch` |
| `403 Resource not accessible` | `permissions` insuficiente no job | declare `permissions:` com o escopo mínimo necessário (ex.: `pull-requests: write`) |
| Required check nunca passa | `context` do ruleset não bate certo com o nome do job | use o **nome do job** (`gh api repos/…/commits/HEAD/check-runs --jq '.check_runs[].name'`) |
| Matriz não expande | `include`/`fromJSON` mal formado; output vazio | valide o YAML e o JSON do job "plan"; `actionlint` |
| Cache nunca acerta | chave com `github.sha` ou sem `hashFiles` | chave = hash do lockfile + `restore-keys` |
| OIDC `401/403` na cloud | trust policy não cobre o `sub`/`claims` do repo/environment | corrija o `sub` (`repo:ORG/REPO:environment:production`) e `id-token: write` |
| Artefato `409`/em falta | nome duplicado no run (v4 imutável) ou expirado (`retention-days`) | nome por matriz; aumente retenção; `download-artifact` no mesmo run |
| `pull_request_target` correu código do PR | checkout do PR num gatilho privilegiado | separe: gatilho privilegiado só para labels/comentários; código em `pull_request` |
| Minutos a disparar | runs obsoletos não cancelados; matriz grande; macOS/Windows | `concurrency`, `if`/`paths`, matriz enxuta |

## Fontes oficiais

- Workflow syntax: <https://docs.github.com/pt-br/actions/reference/workflow-syntax-for-github-actions>
- Reusable workflows: <https://docs.github.com/pt-br/actions/sharing-automations/reusing-workflows>
- Security hardening: <https://docs.github.com/pt-br/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions>
- OIDC e billing: <https://docs.github.com/pt-br/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect> · <https://docs.github.com/pt-br/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions>
