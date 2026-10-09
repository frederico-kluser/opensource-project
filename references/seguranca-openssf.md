# Segurança defensiva e OpenSSF Scorecard

A postura defensiva é medida, auditada e tornada pública. Esta referência cobre
o Scorecard do OpenSSF, menor privilégio em workflows, fixação de dependências,
fluxos perigosos e proteção de segredos. `scripts/oss-doctor.sh` diagnostica,
`scripts/oss-pin-actions.sh` fixa actions e `scripts/oss-gate.sh` aplica os gates.

## O que é o OpenSSF Scorecard

- Auditoria automatizada (~20 checks) de práticas de segurança do repositório:
  workflows, proteções de branch, revisão, dependências e manutenção.
- Cada check devolve 0–10 e o projeto recebe uma nota agregada.
- **Limiar de graduação desta skill: ≥ 7.0** — abaixo disso não há release: o
  `scripts/oss-doctor.sh` acusa o estado e a skill trata-o como bloqueador.

## Como obter a nota

- Badge da API pública: `https://api.securityscorecards.dev/projects/github.com/OWNER/REPO/badge` (sintaxe em `references/identidade-e-telemetria.md`).
- Consulta programática:

```bash
curl -sS "https://api.securityscorecards.dev/projects/github.com/OWNER/REPO" | jq '.score'
```

- Scorecard Action fixada por SHA (publica resultados e permite exportar SARIF):

```yaml
# .github/workflows/scorecard.yml (template em assets/workflows/scorecard.yml)
on:
  schedule: [{ cron: "0 6 * * 1" }]
  push: { branches: [main] }
permissions: read-all
jobs:
  analysis:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      id-token: write
    steps:
      - uses: ossf/scorecard-action@<SHA> # v2.x — fixado por scripts/oss-pin-actions.sh
        with:
          results_file: results.sarif
          publish_results: true
```

- CLI local (reproduz a auditoria antes do push):

```bash
scorecard --repo github.com/OWNER/REPO --format json | jq '.checks[] | {name, score}'
```

## Checks mais severos

| Check | Risco | Ação corretiva |
|---|---|---|
| Token-Permissions | `GITHUB_TOKEN` amplo permite escrever repo/registos a partir de workflows comprometidos | `permissions: contents: read` no topo; elevar só no job/step de publicação |
| Pinned-Dependencies | tags `@v4` são móveis e podem ser reescritas para código malicioso | fixar actions por SHA (`scripts/oss-pin-actions.sh`) e manter lockfiles |
| Dangerous-Workflow | `pull_request_target` com código do PR = execução privilegiada de código alheio | eliminar os padrões proibidos (ver "Fluxos perigosos") |
| Branch-Protection | push/force-push direto contorna revisão e apaga histórico | ruleset com `required_approving_review_count`, `require_code_owner_review`, etc. (`references/governanca-social.md`) |
| Code-Review | código fundido sem segunda leitura introduz backdoors | revisão obrigatória + `dismiss_stale_reviews_on_push` + `require_last_push_approval` |
| Security-Policy | vulnerabilidades divulgadas em issues públicas | `SECURITY.md` + Private Vulnerability Reporting (`references/governanca-social.md`) |
| Maintained | projeto abandonado = CVEs sem patch para sempre | commits nos últimos 90 dias; caso contrário, declarar EOL/arquivar |
| SAST | bugs de segurança chegam a produção sem análise | CodeQL ou Semgrep em CI em cada PR |
| Dependency-Update-Tool | dependências ficam anos com CVEs conhecidas | Dependabot/Renovate (`.github/dependabot.yml`, cadência semanal) |
| Vulnerabilities | CVEs já exploradas no código em uso | Dependabot alerts + `gh api repos/OWNER/REPO/dependabot/alerts`; atualizar/patchar |
| Binary-Artifacts | binários opacos não são auditáveis nem diffáveis | remover binários do git; publicar artefactos em releases |
| Fuzzing | entradas inesperadas causam crashes exploráveis | fuzzers em CI (Atheris, go-fuzz, cargo-fuzz) ou inscrição no OSS-Fuzz |
| License | sem licença clara, adoção e conformidade ficam bloqueadas | `LICENSE` + cabeçalhos SPDX (`references/licenciamento.md`) |

## Menor privilégio em workflows

Declare `permissions: contents: read` no topo de TODOS os workflows e eleve para
`contents: write` apenas no job/step de publicação. `GITHUB_TOKEN` com escopo
mínimo; secrets só no `env:` do step que precisa deles.

```yaml
name: ci
on: [pull_request, push]
permissions:
  contents: read           # default de todos os jobs
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA> # v4 — fixado por oss-pin-actions.sh
      - run: make test
  publish:
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: write      # elevação mínima, só neste job
    steps:
      - uses: actions/checkout@<SHA> # v4
      - run: make publish
```

## Fixação de dependências por hash SHA

- **Porquê**: tags como `@v4` são móveis e podem ser reescritas por quem detém a
  action; o commit SHA de 40 hex é prova matemática do código exato que corre.
- **Formato**: `owner/repo@<sha40> # v4` — o comentário preserva a versão e a
  legibilidade para upgrades futuros.
- **Ferramenta desta skill** (idempotente, só reescreve o que falta):

```bash
bash scripts/oss-pin-actions.sh          # converte em .github/workflows/ (--check só audita)
# owner/repo@v4 → owner/repo@11bd71901bbe5b1630ceea73d27597364c9af683 # v4
```

- Vale também para imagens de container (`image@sha256:...`) e lockfiles (`package-lock.json`, `go.sum`, `Cargo.lock`).
- `scripts/oss-pin-actions.sh --check` e `scripts/oss-doctor.sh` acusam qualquer
  `uses:` que ainda venha por tag móvel.

## Fluxos perigosos: padrões proibidos

`pull_request_target` corre com os segredos e o `GITHUB_TOKEN` privilegiado do
repositório base. Se o workflow também correr código do PR (checkout do head,
build, `npm install`), o atacante controla o código que corre com privilégios:
exfiltra segredos, publica releases, altera branches.

Padrões proibidos — rejeitar sempre em revisão:

1. `pull_request_target` + `actions/checkout` do `github.event.pull_request.head.sha`
   + build/test do código do PR.
2. Interpolar `${{ github.event.* }}` (títulos de PR/issue, corpos) diretamente em
   `run:` — injeta shell; passe via `env:` e cite `"$VAR"`.
3. `workflow_run` que descarrega ou executa artefactos de workflows de PRs com
   permissões elevadas.
4. Self-hosted runners públicos a correr workflows de forks.
5. `pull_request` com `permissions: write-all` ou secrets disponíveis a forks.

Alternativa segura: testar PRs em `pull_request` (sem segredos) e reservar
`pull_request_target` apenas a labels/comentários, sem executar código do PR.

## Secret Scanning + Push Protection

```bash
# ativar secret scanning e push protection (exige admin do repo):
gh api -X PATCH repos/OWNER/REPO \
  -f security_and_analysis.secret_scanning.status=enabled \
  -f security_and_analysis.secret_scanning_push_protection.status=enabled
# ou apenas a push protection:
gh api -X PUT repos/OWNER/REPO/secret-scanning/push-protection -f enabled=true
```

- Varredura local ANTES do push: `scripts/oss-gate.sh push` corre heurísticas
  (padrões `AKIA*`, `gh[pousr]_*`, `github_pat_*`, `glpat-*`, `npm_*` e
  `BEGIN PRIVATE KEY`) e bloqueia o push com exit code ≠ 0.
- Complementos: `gitleaks detect --source . --redact`; `.gitignore` com `.env`,
  `.env.*`, `*.pem`, `id_rsa*`, `.secrets`; Dependabot para alertas de CVE.
- Regra dura: segredo que chegou ao git está comprometido — rotar/revogar
  PRIMEIRO, depois limpar o histórico (`git filter-repo`) e só então divulgar.

## Divulgação coordenada

- Todo o incidente segue `SECURITY.md` (prazos e contactos) — ver
  `references/governanca-social.md`.
- Registe o advisory no repo (GHSA) e peça CVE; divulgue em conjunto com quem
  reportou, dentro do prazo negociado; nunca culpe o reporter.
- `scripts/oss-doctor.sh` audita o badge Scorecard e o Push Protection;
  `scripts/oss-gate.sh publish` exige varredura de segredos limpa e `--yes`.

## Checklist final do agente

- [ ] Nota OpenSSF Scorecard ≥ 7.0 e badge no README.
- [ ] Todos os workflows com `permissions: contents: read` no topo; elevação mínima.
- [ ] Todas as actions fixadas por SHA (`scripts/oss-pin-actions.sh` corrido).
- [ ] Zero padrões perigosos de `pull_request_target`/`workflow_run`/injeção.
- [ ] Secret Scanning + Push Protection ativos; `scripts/oss-gate.sh push` limpo.
- [ ] `.gitignore` cobre `.env`/chaves; gitleaks e Dependabot ativos.
- [ ] `SECURITY.md` coerente com a política de divulgação coordenada.
