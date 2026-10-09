# Assets — skill `opensource-project`

Índice dos **assets** (templates e configurações modelo) copiados para os projetos-alvo pelo
`scripts/oss-scaffold.sh`. Todos os ficheiros desta pasta são **modelos com placeholders**: o
scaffold substitui os placeholders (por `sed`) e escreve o resultado no destino indicado abaixo.

Regras gerais do scaffold (garantidas pelo `oss-scaffold.sh`):

1. **Substituição por `sed`** — cada ocorrência de `{{PLACEHOLDER}}` é substituída pelo valor
   passado ao scaffold (ver tabela de placeholders). O `sed` atua apenas nos placeholders da
   tabela; texto que pareça placeholder mas não conste dela (ex.: `{{ version }}` do Tera no
   `cliff.toml`) **não** é tocado.
2. **Nunca sobrescreve sem `--force`** — se o ficheiro de destino já existir, o scaffold
   aborta essa cópia e regista um aviso; só com `--force` é que o destino é substituído.
3. **Sufixo `.tpl` removido** — `templates/README.md.tpl` → `README.md`, `templates/CODEOWNERS.tpl`
   → `.github/CODEOWNERS`, etc. Os restantes ficheiros mantêm o nome.
4. **Ficheiros sem destino fixo** — `package-husky-fragment.json` não é copiado tal como está:
   é um fragmento para colar/mergear no `package.json` (ver abaixo). Os `rulesets/*.json` não são
   copiados para o repositório: são aplicados via API do GitHub (ver `rulesets/README.md`).

## Placeholders

| Placeholder          | Significado                          | Exemplo de valor                          |
| -------------------- | ------------------------------------ | ----------------------------------------- |
| `{{PROJECT_NAME}}`   | Nome legível do projeto              | `Acme SDK`                                |
| `{{DESCRIPTION}}`    | Pitch de uma frase                   | `A tiny SDK for shipping widgets.`        |
| `{{OWNER}}`          | Organização/utilizador dono no GitHub| `acme`                                    |
| `{{REPO}}`           | Nome do repositório                  | `acme-sdk`                                |
| `{{LICENSE}}`        | SPDX da licença                      | `MIT`                                     |
| `{{YEAR}}`           | Ano do copyright                     | `2026`                                    |
| `{{HOLDER}}`         | Titular do copyright                 | `Acme Inc.`                               |
| `{{DEFAULT_BRANCH}}` | Ramo padrão do repositório           | `main`                                    |
| `{{CONTACT}}`        | Contacto para reporte de segurança   | `security@acme.dev`                       |

## Índice de assets

| Ficheiro                                          | Propósito                                                                                          | Como é usado pelo `oss-scaffold.sh`                                                                 |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `templates/README.md.tpl`                         | README público profissional (badges, features, instalação, quick start, contribuição, segurança).   | Placeholders substituídos → `README.md` na raiz.                                                     |
| `templates/CONTRIBUTING.md.tpl`                   | Guia de contribuição EN (Conventional Commits, branch naming, quality gates, processo de PR).       | Placeholders substituídos → `CONTRIBUTING.md` na raiz.                                               |
| `templates/CODEOWNERS.tpl`                        | Revisão obrigatória por donos de código por caminho (`*`, `/src/`, `*.md`, `/.github/`).            | Placeholders substituídos → `.github/CODEOWNERS`.                                                    |
| `templates/SECURITY.md.tpl`                       | Política de segurança (versões suportadas, reporte privado, SLA, disclosure coordenado).           | Placeholders substituídos → `SECURITY.md` na raiz (o GitHub passa a servir `/security/policy`).      |
| `templates/CODE_OF_CONDUCT.md`                    | Código de conduta Contributor Covenant v2.1 (EN), com contactos de reporte.                        | Placeholders substituídos → `CODE_OF_CONDUCT.md` na raiz.                                            |
| `templates/PULL_REQUEST_TEMPLATE.md`              | Checklist de PR (título convencional, issues, testes, docs, breaking changes).                      | Placeholders substituídos → `.github/PULL_REQUEST_TEMPLATE.md`.                                      |
| `templates/ISSUE_TEMPLATE/bug_report.md`          | Formulário de bug reproduzível.                                                                     | Placeholders substituídos → `.github/ISSUE_TEMPLATE/bug_report.md`.                                  |
| `templates/ISSUE_TEMPLATE/feature_request.md`     | Formulário de pedido de funcionalidade.                                                             | Placeholders substituídos → `.github/ISSUE_TEMPLATE/feature_request.md`.                             |
| `templates/ISSUE_TEMPLATE/config.yml`             | Desliga issues em branco e liga o reporte privado de segurança (`SECURITY.md`).                     | Placeholders substituídos → `.github/ISSUE_TEMPLATE/config.yml`.                                     |
| `templates/CHANGELOG.md.tpl`                      | CHANGELOG no formato Keep a Changelog + cabeçalho SemVer, com `## [Unreleased]` de exemplo.        | Placeholders substituídos → `CHANGELOG.md` na raiz.                                                   |
| `templates/commitlint.config.js`                  | Regras commitlint (`@commitlint/config-conventional` + tipos, case e 72 colunas).                   | Copiado → `commitlint.config.js` na raiz (só faz sentido em projetos Node/JS).                       |
| `templates/cliff.toml`                             | Configuração do `git-cliff` para gerar o CHANGELOG a partir de Conventional Commits.                | Copiado → `cliff.toml` na raiz.                                                                      |
| `templates/.releaserc.json`                       | Configuração do `semantic-release` (branches main + canais `next`/`beta`/`alpha`, plugins).         | Placeholders substituídos → `.releaserc.json` na raiz.                                               |
| `templates/release-please-config.json`            | Configuração do release-please (release-type `simple` — o tipo genérico —, `include-component-in-tag`, `changelog-sections`). | Copiado → `.github/release-please-config.json`.                                                      |
| `templates/release-please-manifest.json`          | Manifesto de versões do release-please (`"." : "0.1.0"`).                                           | Copiado → `.github/release-please-manifest.json`.                                                    |
| `templates/package-husky-fragment.json`           | Fragmento JSON (`scripts.prepare: "husky"` + devDependencies de commitlint/husky/lint-staged).      | **Não é copiado para um ficheiro próprio**: o agente faz merge das chaves no `package.json` do projeto (e corre `npm install`). |
| `workflows/ci.yml`                                | CI com lint + test, least privilege, concorrência e actions fixadas por SHA.                        | Placeholders substituídos → `.github/workflows/ci.yml`.                                              |
| `workflows/release-please.yml`                    | Workflow de release via `googleapis/release-please-action` com permissões mínimas.                  | Placeholders substituídos → `.github/workflows/release-please.yml`.                                  |
| `workflows/scorecard.yml`                         | Análise OpenSSF Scorecard (SARIF + `publish_results: true`).                                        | Placeholders substituídos → `.github/workflows/scorecard.yml`.                                       |
| `workflows/semantic-release.yml`                  | Alternativa de release pós-merge com `npx semantic-release` e environment `production`.             | Placeholders substituídos → `.github/workflows/semantic-release.yml`.                                |
| `rulesets/regras-main.json`                       | Ruleset de governança do ramo padrão e `release/**` (2 aprovações, squash, status checks).          | **Não copiado**: aplicado via `gh api --method POST ... --input` (ver `rulesets/README.md`).          |
| `rulesets/regras-tags.json`                       | Ruleset que torna as tags `v*` imutáveis (sem update/sem delete).                                   | **Não copiado**: aplicado via `gh api` (ver `rulesets/README.md`).                                    |
| `rulesets/regras-release.json`                    | Ruleset dos ramos `release/**` (1 aprovação, sem force-push, sem delete).                           | **Não copiado**: aplicado via `gh api` (ver `rulesets/README.md`).                                    |
| `rulesets/README.md`                              | Instruções (pt-PT) de aplicação/listagem/ordem dos rulesets.                                        | Não é copiado para o projeto-alvo; serve o agente que executa o scaffold.                             |
| `licenses/MIT.txt`                                | Texto integral da licença MIT com `{{YEAR}}`/`{{HOLDER}}`.                                          | Placeholders substituídos → `LICENSE` na raiz.                                                        |
| `licenses/README.md`                              | Instruções (pt-PT) para obter Apache-2.0/GPL-3.0/MPL-2.0 a partir do SPDX.                          | Não é copiado para o projeto-alvo; serve o agente que executa o scaffold.                             |

## Notas de uso

- **Workflows**: todos os `uses:` vêm no formato `owner/repo@<PIN_SHA> # vX.Y.Z`. Antes do primeiro
  push, correr `bash scripts/oss-pin-actions.sh` para substituir `<PIN_SHA>` pelo SHA real da tag
  indicada no comentário — um workflow com `<PIN_SHA>` literal não corre.
- **`package-husky-fragment.json`**: as chaves `scripts.prepare` e `devDependencies` devem ser
  fundidas no `package.json` existente (sem colidir com outros scripts); depois correr
  `npm install` e criar o hook `commit-msg` referido no `CONTRIBUTING.md.tpl` (husky v9: escrever
  `.husky/commit-msg` com o conteúdo `npx --no -- commitlint --edit $1`).
- **Release**: escolher **um** dos dois caminhos (`release-please` **ou** `semantic-release`) — nunca
  ambos em simultâneo sobre a mesma branch, ou haverá releases duplicados.
- **Rulesets**: aplicar depois do primeiro push (os rulesets de `required_status_checks` bloqueiam o
  merge enquanto os checks não existirem); ver ordem recomendada em `rulesets/README.md`.
