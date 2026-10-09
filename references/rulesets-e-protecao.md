# GitHub Rulesets — o cofre imutável da main

`main` não é uma convenção: é um cofre. Os GitHub Rulesets são a API moderna que
torna as regras auditáveis, portáveis e aplicáveis por código — o último gate entre
a história do projeto e quem tentar reescrevê-la.

## Rulesets vs Branch Protections clássicas

| | Branch Protections (clássicas) | Rulesets |
|---|---|---|
| Modelo | uma proteção por padrão de branch, sem composição | **regras em camadas**: vários rulesets incidem sobre a mesma ref |
| Alvo | só branches | `branch`, `tag` ou `repository` |
| Padrões | glob simples | **refs completas**: `refs/heads/**`, `refs/tags/**` + tokens `~ALL`, `~DEFAULT_BRANCH` |
| Estado | UI/API antiga (`gh ruleset list --legacy`) | JSON exportável, versionável, aplicável via `gh api` |
| Sobreposições | conflitos opacos | **coalescência por interseção mais restritiva** |

Na coalescência, quando várias regras incidem sobre o mesmo ref, vence o mais
restritivo: a maior contagem de aprovações, a interseção dos bypasses, a união dos
checks obrigatórios. Nenhum ruleset consegue *alargar* o que outro apertou.

## As 6 regras imperativas para `main`

1. **PR obrigatório com aprovações** — regra `pull_request` com
   `required_approving_review_count: 1` (ou mais) e `require_code_owner_review: true`:
   quem é dono do código (CODEOWNERS) aprova o que é seu.
2. **Histórico linear / squash** — `allowed_merge_methods: ["squash"]` +
   `required_linear_history`; merge commits ficam proibidos.
3. **Status checks obrigatórios** — `required_status_checks` com
   `strict_required_status_checks: true` (a branch tem de estar atualizada).
4. **Sem force push** — `non_fast_forward` bloqueia reescrita de história.
5. **Sem delete** — `deletion` impede apagar `main`.
6. **Commits assinados (opcional)** — `required_signatures` quando a equipa já assina;
   ativar por fases, nunca primeiro que tudo.

## Envelope JSON — completo e válido

Este é o corpo de `POST /repos/{owner}/{repo}/rulesets`, igual a
`assets/rulesets/regras-main.json`. **JSON não admite comentários** — nada de `//`:

```json
{
  "name": "Governança Principal Restrita",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH", "refs/heads/release/**"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "require_extra_approval_for_unattributed_changes": false,
        "required_review_thread_resolution": false,
        "required_reviewers": [],
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "build" }
        ],
        "do_not_enforce_on_create": false
      }
    }
  ],
  "bypass_actors": []
}
```

Notas sobre o envelope (validadas contra a API real):

- **Padrões são refs completas** — `refs/heads/release/**`, `refs/tags/v*`. Um padrão
  solto (`release/**`, `v*`, `main`) é rejeitado com `422 Invalid target patterns`.
  Os únicos tokens sem prefixo são `~ALL` e `~DEFAULT_BRANCH`.
- **`~DEFAULT_BRANCH`** — o prefixo `~` é um token dinâmico: corresponde à branch
  predefinida do repositório *hoje* e continua a corresponder se ela for renomeada.
  Nunca escrevas `main` em claro nas condições.
- **`parameters` tem de vir COMPLETO** — o schema exige todas as chaves do objeto
  (`required_approving_review_count`, `dismiss_stale_reviews_on_push`,
  `require_code_owner_review`, `require_last_push_approval`,
  `require_extra_approval_for_unattributed_changes`,
  `required_review_thread_resolution`, `required_reviewers`,
  `allowed_merge_methods`). Um subconjunto — ou `parameters: {}` — devolve
  `422 Invalid property /rules/N: data matches no possible input`.
- **Armadilha `params`** — a chave `params` (sem `-eters`) passa na validação e é
  **silenciosamente ignorada**: o ruleset fica criado com os valores por omissão.
  Confirme sempre com um `GET /rulesets/{id}` que os valores persistiram.
- **Regras sem parâmetros são só o tipo**: `{ "type": "deletion" }` — nada de
  `"parameters": {}` (isso também é rejeitado).
- **`context` dos status checks = nome do job**, não `workflow / job`: um job
  `name: build` num workflow `ci` produz o check `build` (confirme com
  `gh api repos/OWNER/REPO/commits/HEAD/check-runs --jq '.check_runs[].name'`).
  `strict_required_status_checks` chama-se, na API, `strict_required_status_checks_policy`.
- **`bypass_actors`** — só **bots** (uma GitHub App do tipo `Integration`, com o seu
  `actor_id` numérico) podem saltar regras, e com `bypass_mode` explícito
  (`always` ou `pull_request`). **Humanos nunca entram aqui**, nem mantenedores:
  a exceção chama-se PR.
- `required_signatures` é a regra opcional (6.ª): acrescenta-a só quando o projeto
  já assina commits; as restantes cinco são imperativas.

## Aplicar

```bash
gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/OWNER/REPO/rulesets --input assets/rulesets/regras-main.json
```

## Gerir

```bash
gh ruleset list                                   # rulesets ativos (e --legacy para os clássicos)
gh ruleset view <id|nome>                         # regras e condições
gh ruleset check "main"                           # simula: um ref passaria nas regras?
gh api --method PUT /repos/OWNER/REPO/rulesets/<id> --input assets/rulesets/regras-main.json
gh api --method DELETE /repos/OWNER/REPO/rulesets/<id>
```

`enforcement` tem três estados: `active` (aplica e bloqueia), `disabled` (não faz
nada) e `evaluate` (aplica mas não bloqueia — útil para medir impacto antes de ativar).

## Tags imutáveis

A release não se reescreve. Ruleset com `"target": "tag"`, condições `refs/tags/v*` e
regras `update` + `deletion` bloqueadas (+ `required_signatures` se assinares):

```json
{
  "name": "Tags de Release Imutáveis",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [
    { "type": "update" },
    { "type": "deletion" }
  ],
  "bypass_actors": []
}
```

## `refs/heads/release/**` — manutenção com prazos diferentes

Os ramos de manutenção recebem o mesmo envelope com `required_approving_review_count`
menor (1), lista de checks mais curta e `dismiss_stale_reviews_on_push: false` —
backports urgentes não podem esperar pelas mesmas travagens do desenvolvimento
normal. Nunca `bypass_actors` para humanos, nem aqui.

## Erros comuns

| Sintoma | Causa | Correção |
|---|---|---|
| `404` a criar/ler ruleset | token sem escopo `administration:read/write` | `gh auth refresh -s administration:write` ou PAT fine-grained com *Administration: write* |
| `422 Invalid target patterns` | padrão sem prefixo de ref (`release/**`, `v*`, `main`) | usar `refs/heads/...` / `refs/tags/...` (ou `~ALL`/`~DEFAULT_BRANCH`) |
| `422 data matches no possible input` | `parameters` incompleto (ou `parameters: {}`) | enviar o objeto `parameters` COMPLETO (todas as chaves) |
| `422 Unprocessable` (outro) | parâmetro inválido ou tipo de regra inexistente | validar o JSON contra o schema da API; o erro nomeia o campo |
| Regra criada mas sem efeito | chave `params` usada em vez de `parameters` (aceite e ignorada) | recriar com `parameters` e confirmar com `GET /rulesets/{id}` |
| `409` / "already exists" | ruleset com o mesmo nome ou regra duplicada | atualizar com `PUT` no `id` em vez de `POST` |
| Regra não bloqueia | ruleset sobreposto em `disabled`/`evaluate` | `gh ruleset list` e subir tudo para `active` |
| Bot de release bloqueado | `bypass_actors` sem o `Integration` certo | adicionar `actor_type: Integration` com o `actor_id` da app |

## Ordem de instalação recomendada

1. **Repositório** — `scripts/oss-scaffold.sh` (LICENSE, README, CONTRIBUTING, CODEOWNERS).
2. **Rulesets** — envelope `main` + ruleset de tags `refs/tags/v*` (o cofre fecha-se primeiro).
3. **CI** — workflows com `permissions` mínimas e actions fixadas por SHA
   (`scripts/oss-pin-actions.sh`); só depois os status checks são exigíveis.
4. **Contribuições** — templates de issue/PR, SECURITY.md, abertura a forks.

Nunca abras o repo a contribuições antes de 2 e 3: um repo público sem cofre recebe
exatamente o histórico que não queres.
