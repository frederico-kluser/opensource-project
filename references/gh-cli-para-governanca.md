# GitHub CLI — orquestração de governança no terminal

O `gh` é a API do GitHub com ergonomia de shell. Esta referência mapeia as
operações de **governança** para comandos concretos; os padrões que eles impõem
estão nas restantes referências desta skill, e as operações genéricas delegam-se
à skill irmã `github-agent-skill`.

## Premissas

```bash
gh auth status                      # conta, host e escopos — nunca o valor do token
gh auth refresh -s repo,administration:write,workflow
export GH_REPO=OWNER/REPO           # fixa o alvo; alternativa: -R OWNER/REPO por comando
```

Escopos mínimos para governar: `repo`, `administration:write` (rulesets),
`workflow` (workflows), `read:org` (equipas/CODEOWNERS). Tokens fine-grained:
*Contents: write*, *Administration: write*, *Secrets: write*, *Metadata: read*.

## Operações de governança → comando

| Operação | Comando |
|---|---|
| Criar repo | `gh repo create OWNER/REPO --public --description "CLI de exemplo" --add-topic oss --add-topic go` |
| Editar About | `gh repo edit OWNER/REPO --description "..." --homepage "https://acme.dev" --add-topic cli` |
| Private Vulnerability Reporting | `gh api --method PUT /repos/OWNER/REPO/vulnerability-alerts` |
| Secret Scanning + Push Protection | `gh api --method PATCH /repos/OWNER/REPO -f 'security_and_analysis[secret_scanning][status]=enabled' -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'` |
| Secrets (env) | `echo "$VALOR" \| gh secret set NPM_TOKEN --env production` |
| Variables | `gh variable set RELEASE_CHANNEL --body "stable"` |
| Rulesets | `gh api --method POST /repos/OWNER/REPO/rulesets --input assets/rulesets/regras-main.json` |
| Labels | `gh label create "breaking" --color B60205 --description "Mudança incompatível"` |
| Release | `gh release create v1.4.0 --verify-tag --notes-file CHANGELOG.md` |
| Workflows | `gh workflow list` · `gh workflow enable ci.yml` · `gh workflow disable old.yml` |
| Runs | `gh run list --limit 5` · `gh run watch <id>` · `gh run rerun <id> --failed` |

**Segredos nunca em claro**: `--body "$VALOR"` na linha de comandos deixa o valor no
histórico da shell e no `ps`. Usa sempre stdin (`echo "$VALOR" | gh secret set ...`)
ou `--body-file` num ficheiro temporário apagado de seguida.

## Ciclo de PR completo

```bash
gh pr create --base main \
  --title "feat(core): adiciona cache de parse" \
  --body "Motivação, plano de teste, Refs: #412"
gh pr checks --watch
gh pr merge --squash --delete-branch
```

Complementos obrigatórios:

```bash
gh pr update-branch                        # PR desatualizado, sem conflitos
gh pr view <n> --json state,mergeable,statusCheckRollup,reviewDecision
bash scripts/oss-gate.sh pr --title "..."  # valida o título como commit convencional
```

O título do PR é a mensagem final do squash merge — tem de seguir a Conventional
Commits (ver `commits-convencionais.md`).

## Inspeção e auditoria

```bash
gh api --paginate /repos/OWNER/REPO/commits --jq '.[].commit.message' | head -30
gh api /repos/OWNER/REPO/rulesets --jq '.[] | {id, name, enforcement}'
gh api /repos/OWNER/REPO/stats/contributors --jq '.[] | {total, login: .author.login}'
gh search prs --repo OWNER/REPO --state open --label release --json number,title
gh run list --workflow ci.yml --limit 10 --json displayTitle,conclusion,headBranch
```

Preferir `--json`/`--jq` a parsear tabelas coloridas; para leituras repetidas,
`python3 scripts/gh-run.py` (da `github-agent-skill`) envolve o `gh` com saída estável.

## Environments e publicação

Os tokens de publicação vivem em GitHub Environments — com revisores e `wait_timer`
quando a release exige dupla chave:

```bash
gh api --method PUT /repos/OWNER/REPO/environments/production
echo "$NPM_TOKEN" | gh secret set NPM_TOKEN --env production
gh variable set REGISTRY_URL --env production --body "https://registry.npmjs.org"
```

O workflow só lê `secrets.*` no job que usa o Environment `production`; os restantes
jobs ficam com `permissions` mínimas e zero acesso a segredos.

## Aliases e extensões

```bash
gh alias set prx 'pr create --fill'          # título e corpo a partir dos commits
gh alias set logs 'run list --limit 10 --json displayTitle,conclusion'
gh extension install dlvhdr/gh-dash          # dashboard de PRs/runs
gh extension list
```

Aliases vivem na config do `gh` e não apanham `GH_REPO` a mais — mantém-nos simples
e documentados no CONTRIBUTING.

## Integração com a skill irmã `github-agent-skill`

Esta skill define os **padrões** (commits, fluxo, versão, rulesets); a
`github-agent-skill` executa operações GitHub genéricas — auth, issues, Actions,
troubleshooting, `gh api` avançado. Delega nela tudo o que for fora do âmbito da
governança, mas os gates desta skill (`oss-gate.sh commit-msg|push|pr|merge|release|publish`)
continuam a ser lei: nenhuma operação genérica os contorna.

## Erros rápidos

| Erro | Causa provável | Correção |
|---|---|---|
| `401` | token expirado ou inválido | `gh auth login` / `gh auth refresh` |
| `403` | escopo em falta, SSO de organização por autorizar, permissão de repo | `gh auth refresh -s repo,administration:write,workflow`; autorizar SSO a partir de `gh auth status` |
| `404` | repo inexistente, sem permissão, ou `GH_REPO` mal definido | confirmar `GH_REPO`/`-R`; PAT fine-grained com acesso ao repo |
| `409` | ruleset ou recurso já existe / estado conflituante | `PUT` no `id` do ruleset em vez de `POST`; repetir a operação |
| `422` | corpo inválido (regra, PR, label) | validar o JSON contra o schema; o erro nomeia o campo inválido |

Formato de qualquer erro desta skill:
`Erro: <o quê aconteceu> — Solução: <o que fazer a seguir>`.
