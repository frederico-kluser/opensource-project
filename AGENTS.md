# CLAUDE.md — contrato operacional do opensource-project

> Este projeto é governado pela skill **opensource-project**. Estas instruções são
> **automáticas e obrigatórias**: qualquer agente de código que abra este repositório
> segue-as SEM precisar de invocar a skill. Os comandos abaixo vivem na instalação da
> skill (`/home/ondokai/Agent-Skills/opensource-project`) e são suficientes para todo o ciclo de vida.

## Regras obrigatórias em TODO o desenvolvimento

1. **Nunca escrever diretamente em `main`** — ramificação efémera
   (`feat/*`, `fix/*`, `chore/*`, `docs/*`) → PR com título Convencional → checks
   verdes → **squash merge** → delete branch. Sem exceções.
2. **Commits Convencionais**: `tipo(escopo)!: descrição` — imperativo, ≤ 72 chars.
   Tipos: `feat fix docs style refactor perf test build ci chore revert`.
   `!` ou rodapé `BREAKING CHANGE:` → versão MAJOR.
3. **A versão é cálculo, nunca digitação**:
   `python3 /home/ondokai/Agent-Skills/opensource-project/scripts/oss-version.py next` (`feat`→MINOR, `fix`→PATCH,
   `!`→MAJOR). Bump manual só com justificação explícita do utilizador.
4. **CHANGELOG gerado, nunca reescrito**:
   `python3 /home/ondokai/Agent-Skills/opensource-project/scripts/oss-changelog.py --write`.
5. **Zero segredos** no código ou no histórico:
   `bash /home/ondokai/Agent-Skills/opensource-project/scripts/oss-gate.sh push --scan-only` antes de submeter;
   credenciais entram apenas via `echo "$X" | gh secret set --env production`.
6. **Workflows seguros**: actions fixadas por SHA
   (`bash /home/ondokai/Agent-Skills/opensource-project/scripts/oss-pin-actions.sh`), `permissions` mínimos e
   `timeout-minutes` em todos os jobs; o `context` do ruleset é o **nome do job**.
7. **Nunca contornar um gate**: se `oss-gate.sh` bloquear, corrija a CAUSA e repita.
   Nunca `--no-verify`, nunca force-push, nunca reescrever histórico partilhado.

## Procedimento por pedido do utilizador (executar sem pedir estes passos)

| Pedido | Procedimento |
|---|---|
| "commita" / "faz commit" | `bash /home/ondokai/Agent-Skills/opensource-project/scripts/oss-gate.sh commit-msg "<msg>"` → `git commit` (o hook `commit-msg` revalida) |
| "push" / "sobe" | branch ≠ `main` → `oss-gate.sh push` → `git push -u origin <branch>` |
| "abre PR" / "faz merge" | título Convencional = mensagem do squash → `gh pr create --base main` → `gh pr checks --watch` → `gh pr merge --squash --delete-branch` |
| "muda/sobe a versão" | `oss-version.py next` → aplicar o valor nos manifestos → `oss-changelog.py --write` |
| "faz release" / "publica" | `oss-gate.sh release --version X.Y.Z` → commit de release → `git tag -a vX.Y.Z` → `gh release create vX.Y.Z --verify-tag --notes-file` → publicação via CI com secrets em Environment |
| "muda CI/workflows" | editar `.github/workflows/` → `oss-pin-actions.sh` → confirmar que o nome do job bate certo com o `context` do ruleset |
| "adiciona/atualiza dependências" | lockfile atualizado + testes + `oss-gate.sh push --scan-only` (sem segredos, sem pins quebrados) |

## Antes de fechar qualquer tarefa

- `bash /home/ondokai/Agent-Skills/opensource-project/scripts/oss-doctor.sh` sem nenhuma linha `[FALTA]` (avisos
  aceitáveis; faltas não — corrigir antes de submeter).
- Commits Convencionais; versão e changelog coerentes com o que mudou.
- Reportar ao utilizador: o que mudou, gates cumpridos e URLs criadas (PR/release).
- Qualquer erro no formato `Erro: <o quê> — Solução: <o que fazer>`.

## Cofre desta versão

`main` é protegida por ruleset (PR obrigatório, squash-only, status
checks strict, sem force-push, sem delete) e as tags `v*` são imutáveis. Releases
nunca retrocedem: reverter um `BREAKING CHANGE` publicado exige um novo MAJOR.

## Semântica de erro

Formato obrigatório: `Erro: <o quê aconteceu> — Solução: <o que fazer a seguir>`.
Exit codes dos gates: `0` pass · `1` bloqueado (corrigir causa) · `2` uso inválido ·
`3` ferramenta em falta · `4` não é repositório git.
