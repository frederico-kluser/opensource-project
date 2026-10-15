# GitHub Rulesets — o cofre imutável da main

`main` não é uma convenção: é um cofre. Os GitHub Rulesets são a API moderna que
torna as regras auditáveis, portáveis e aplicáveis por código — o último gate entre
a história do projeto e quem tentar reescrevê-la. E o cofre não se limita a `main`:
**nomes de branch e mensagens de commit também são impostos no servidor** — o
utilizador errado não chega a empurrar o erro para o repositório.

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

## As 8 regras imperativas para `main`

1. **PR obrigatório com aprovações** — regra `pull_request` com
   `required_approving_review_count: 1` (ou mais) e `require_code_owner_review: true`:
   quem é dono do código (CODEOWNERS) aprova o que é seu. **É esta regra que proíbe
   commits diretos**: sem PR, o push é recusado pelo GitHub.
2. **Histórico linear / squash** — `allowed_merge_methods: ["squash"]` +
   `required_linear_history`; merge commits ficam proibidos.
3. **Status checks obrigatórios** — `required_status_checks` com
   `strict_required_status_checks_policy: true` (a branch tem de estar atualizada).
4. **Sem force push** — `non_fast_forward` bloqueia reescrita de história.
5. **Sem delete** — `deletion` impede apagar `main`.
6. **Commits assinados (opcional)** — `required_signatures` quando a equipa já assina;
   ativar por fases, nunca primeiro que tudo.
7. **Nomes de ramificação impostos** — `branch_name_pattern` (ruleset
   "Convenção de Nomes de Ramificação"): um push para branch fora de `<tipo>/<slug>`
   é **recusado na criação/atualização do ref**. Não é convenção escrita: é parede.
8. **Mensagens convencionais impostas** — `commit_message_pattern` (ruleset
   "Convenção de Mensagens de Commit"): o que entra em ramos protegidos (incluindo o
   commit de squash) tem de começar por `tipo(escopo)!: descrição` ou `Revert `/`Reapply `.

## Os 5 rulesets da skill (governança como código)

| Ficheiro | Nome do ruleset | O que tranca |
|---|---|---|
| `regras-main.json` | Governança Principal Restrita | PR obrigatório + squash-only + status checks strict + linear history + sem force-push + sem delete em `~DEFAULT_BRANCH`, `main`, `master`, `develop`, `release/**` |
| `regras-release.json` | Ramos de Release Protegidos | `release/**` sem reescrita, PR com 1 aprovação |
| `regras-tags.json` | Tags de Release Imutáveis | `refs/tags/v*` sem `update` nem `deletion` |
| `regras-nomes-de-branch.json` | Convenção de Nomes de Ramificação | branches fora de `<tipo>/<slug>` **rejeitadas** (exceções: `dependabot/`, `renovate/`, `release-please--*`, `gh-readonly-queue/`; longevos `main`/`master`/`develop`/`gh-pages`/predefinido isentos do naming e protegidos de commits diretos) |
| `regras-commits.json` | Convenção de Mensagens de Commit | mensagens fora de Conventional Commits **rejeitadas** em `~DEFAULT_BRANCH`, `main`, `master`, `develop`, `release/**` |

O regex do ruleset de nomes e o regex do gate local são a **mesma política** — a fonte
única vive em `scripts/oss-branch-policy.sh`; nunca alterar um sem o outro.

## Regras de padrão: `negate` decide o sentido

As regras `branch_name_pattern`, `commit_message_pattern`, `commit_author_email_pattern`,
`committer_email_pattern` e `tag_name_pattern` partilham os parâmetros
`operator` (`starts_with` | `ends_with` | `contains` | `regex`), `pattern` e `negate`,
com a semântica oficial (**documentação REST do GitHub**):

> `negate` boolean — **If true, the rule will fail if the pattern matches.**

Ou seja:

| `negate` | A regra BLOQUEIA quando… | Uso |
|---|---|---|
| `false` (predefinição) | o padrão **não** corresponde | **impor** uma convenção (nomes/mensagens têm de bater certo) |
| `true` | o padrão **corresponde** | **proibir** um formato (ex.: nomes que contenham `temp`) |

Esta skill usa sempre `negate: false` para **impor** convenções. Exemplo real
(`regras-nomes-de-branch.json`):

```json
{
  "type": "branch_name_pattern",
  "parameters": {
    "name": "tipo/slug convencional obrigatório",
    "negate": false,
    "operator": "regex",
    "pattern": "^((feat|fix|docs|style|refactor|perf|test|build|ci|revert|hotfix|release)/[a-zA-Z0-9][a-zA-Z0-9._/-]*|(dependabot|renovate)/[a-zA-Z0-9._/-]+|release-please--.*|gh-readonly-queue/.*)$"
  }
}
```

Cuidados de regex (RE2 — sem lookaround, sem backreferences):

- `^…$` ancoram no nome/mensagem inteira; sem eles o padrão aceitaria prefixos sujos.
- Em mensagens de commit, `.` **não** atravessa linhas: use `[\s\S]*` para consumir o
  corpo da mensagem depois do cabeçalho convencional (no JSON, `"[\\s\\S]*"`).
- As exceções de automação **têm de estar no padrão**: `dependabot`/`renovate` criam
  `<prefixo>/<ecossistema>/<pkg>`, `release-please` cria `release-please--branches--main`
  e a merge queue usa `gh-readonly-queue/...`. Sem elas, a automação morre bloqueada.
- Os ramos longevos (`main`, `master`, `develop`, `gh-pages`, predefinido) não seguem
  `<tipo>/<slug>`: ficam nos `exclude` das condições do ruleset — nunca no regex.

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
      "include": ["~DEFAULT_BRANCH", "refs/heads/main", "refs/heads/master", "refs/heads/develop", "refs/heads/release/**"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "require_extra_approval_for_unattributed_changes": false,
        "required_review_thread_resolution": true,
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

## Aplicar (e REAPLICAR — sempre)

O caminho normal é o **`oss-enforce.sh`**: ele audita o estado real, **cria** os
rulesets ausentes e **reconcilia** (PUT) os divergentes do JSON versionado no
projeto — corre a cada entrada no projeto, mesmo que ele já use a skill:

```bash
bash scripts/oss-enforce.sh            # verifica tudo e aplica o que falta
bash scripts/oss-enforce.sh --dry-run  # mostra o plano sem escrever
```

Aplicação manual (um ruleset de cada vez):

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
| Push de branch recusado (`ref updates cannot be rejected...`) | regra `branch_name_pattern` e o nome fora de `<tipo>/<slug>` | renomear: `git branch -m <tipo>/<slug>` e voltar a dar push |
| Commit recusado no merge/push | regra `commit_message_pattern` e mensagem fora de Conventional Commits | reescrever a mensagem (`git commit --amend`) ou titule o PR Convencionalmente (squash) |
| Bot (dependabot/release-please) bloqueado | nome/mensagem do bot fora do padrão imposto | nomes: prefixos de automação já estão no regex; mensagens: `commit-message: prefix: "chore(deps)"` no `dependabot.yml` |

## Ordem de instalação recomendada

1. **Repositório** — `scripts/oss-scaffold.sh` (LICENSE, README, CONTRIBUTING, CODEOWNERS).
2. **Rulesets** — `scripts/oss-enforce.sh` aplica os 5 rulesets de uma vez
   (cofre `main`/`develop`/`release`, tags `v*`, nomes de branch, mensagens de commit).
3. **CI** — workflows com `permissions` mínimas e actions fixadas por SHA
   (`scripts/oss-pin-actions.sh`); só depois os status checks são exigíveis.
4. **Contribuições** — templates de issue/PR, SECURITY.md, abertura a forks.

Nunca abras o repo a contribuições antes de 2 e 3: um repo público sem cofre recebe
exatamente o histórico que não queres.
