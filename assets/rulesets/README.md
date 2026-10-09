# Rulesets — governança por API do GitHub

Os ficheiros `.json` desta pasta **não são copiados** para o repositório do projeto: são corpos de
pedido para o endpoint `POST /repos/{owner}/{repo}/rulesets` da REST API do GitHub, aplicados pelo
agente depois do primeiro push (os rulesets com `required_status_checks` bloqueiam o merge enquanto
os checks ainda não existirem).

Os nomes dos parâmetros seguem a API oficial de rulesets e foram **validados
empiricamente** contra ela (`required_approving_review_count`, `require_code_owner_review`,
`dismiss_stale_reviews_on_push`, `require_last_push_approval`,
`require_extra_approval_for_unattributed_changes`, `required_review_thread_resolution`,
`required_reviewers`, `allowed_merge_methods`, `required_status_checks` com
`strict_required_status_checks_policy`, `do_not_enforce_on_create` e, opcionalmente,
`integration_id` por check). Três regras duras:

1. **Padrões são refs completas**: `refs/heads/...` para branches, `refs/tags/...` para
   tags. Padrões soltos (`release/**`, `v*`, `main`) são rejeitados com
   `422 Invalid target patterns` — os únicos tokens sem prefixo são `~ALL` e
   `~DEFAULT_BRANCH`.
2. **`parameters` tem de vir COMPLETO** (todas as chaves do objeto); um subconjunto
   ou `parameters: {}` devolve `422 data matches no possible input`. Regras sem
   parâmetros levam só `{ "type": "..." }`.
3. **Nunca usar a chave `params`** (sem `-eters`): a API aceita-a e **ignora-a
   silenciosamente** — o ruleset fica criado com valores por omissão. Confirme com
   `gh api repos/{owner}/{repo}/rulesets/<id>` que os valores persistiram.

Os corpos em JSON não têm comentários — as explicações ficam aqui.

## Ficheiros

| Ficheiro              | Alvo           | O que impõe                                                                                          |
| --------------------- | -------------- | ---------------------------------------------------------------------------------------------------- |
| `regras-main.json`    | `branch`       | `~DEFAULT_BRANCH` e `refs/heads/release/**`: sem delete, sem force-push, PR com **2 aprovações**, code owner review, aprovações caducadas em push novo, merge só por **squash**, status checks obrigatórios (strict). |
| `regras-tags.json`    | `tag`          | Tags `refs/tags/v*` **imutáveis**: proibidos `update` e `deletion`.                                    |
| `regras-release.json` | `branch`       | Ramos `refs/heads/release/**`: sem delete, sem force-push, PR com **1 aprovação**.                     |

Notas:

- `~DEFAULT_BRANCH` é um *placeholder do próprio GitHub* (resolvido para o ramo padrão do
  repositório) — **não** confundir com `{{DEFAULT_BRANCH}}` do scaffold.
- Em `regras-main.json`, o contexto de status check `build` tem de ser o **nome do job**
  tal como o GitHub o reporta (`gh api repos/{owner}/{repo}/commits/HEAD/check-runs
  --jq '.check_runs[].name'`) — e não o par `workflow / job`. Enquanto o contexto não
  existir, o GitHub mostra a check como *expected* e o merge fica bloqueado.
- `integration_id` dentro de `required_status_checks[]` é **opcional**: use-o apenas para exigir o
  check de uma integração específica (GitHub App/Actions); para checks de workflows normais basta o
  `context`.
- A regra `deletion` **proíbe** apagar o ref; `update` proíbe mover/reescrever (tags); `non_fast_forward`
  proíbe force-push. `allowed_merge_methods: ["squash"]` limita o botão de merge ao squash.

## Como aplicar

Com o `gh` CLI autenticado (`gh auth login`) e a partir desta pasta:

```bash
# 1) Regra principal (ramo padrão + refs/heads/release/**) — aplicar PRIMEIRO
gh api --method POST \
  repos/{{OWNER}}/{{REPO}}/rulesets \
  --input regras-main.json

# 2) Proteção dos ramos de release
gh api --method POST \
  repos/{{OWNER}}/{{REPO}}/rulesets \
  --input regras-release.json

# 3) Imutabilidade das tags refs/tags/v*
gh api --method POST \
  repos/{{OWNER}}/{{REPO}}/rulesets \
  --input regras-tags.json
```

Alternativa com `curl` (com um PAT com permissão `administration:write` ou `repo`):

```bash
curl -fsS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/{{OWNER}}/{{REPO}}/rulesets \
  --data @regras-main.json
```

## Como listar / verificar

```bash
# Lista os rulesets do repositório (nomes, IDs, enforcement)
gh ruleset list --repo {{OWNER}}/{{REPO}}

# Equivalente REST
gh api repos/{{OWNER}}/{{REPO}}/rulesets

# Detalhe de um ruleset (pelo id devolvido no list)
gh api repos/{{OWNER}}/{{REPO}}/rulesets/<id>
```

Para atualizar, usa `PUT .../rulesets/<id>` com o mesmo corpo (ou `PATCH` para campos pontuais); para
remover, `DELETE .../rulesets/<id>`.

## Ordem recomendada

1. **`regras-main.json`** — garante desde logo que nada entra em `{{DEFAULT_BRANCH}}` sem revisão.
2. **`regras-release.json`** — protege os ramos de release antes de o primeiro `refs/heads/release/**` existir.
3. **`regras-tags.json`** — fecha a porta à reescrita de tags (aplicar **antes** do primeiro release).

Se o projeto ainda não tem CI, aplique primeiro os rulesets sem `required_status_checks` e adicione a
regra depois do primeiro workflow verde — ou substitua o contexto placeholder pelo nome real do check.

## `bypass_actors`

**Deixar `bypass_actors: []`** (vazio) em todos os rulesets, salvo exceção justificada: bots de
release automatizados que precisem de criar tags/commits (ex.: `github-actions[bot]` ou uma GitHub App
de release). Nesse caso, registe o ator explicitamente e com o modo mais restrito possível:

```json
"bypass_actors": [
  { "actor_id": 1, "actor_type": "Integration", "bypass_mode": "always" }
]
```

Nunca adicionar utilizadores humanos a `bypass_actors`: quem precisa de ultrapassar regras
pontualmente deve usar o bypass temporário da UI (auditado) ou um fluxo de hotfix revisto.
