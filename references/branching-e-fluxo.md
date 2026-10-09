# Topologia de ramificações — GitHub Flow sobre trunk-based

A forma da história determina a saúde do projeto. Esta skill impõe **GitHub Flow
sobre base trunk-based**: uma `main` viva e sempre implementável, ramificações
efémeras e squash merge obrigatório — o oposto do GitFlow clássico.

## Porquê o GitFlow é antipadrão em OSS colaborativo

O GitFlow (`develop`, `release/*`, `hotfix/*`, features longas) foi desenhado para
releases cadenciadas e equipas fechadas. Em open-source colaborativo falha:

- **Ramificações longas** — `develop` e `release/*` acumulam semanas de divergência;
  cada integração vira um projeto autónomo.
- **Colisões de integração** — contribuidores esperam meses por release; quando
  finalmente cruzam, os conflitos já são insolúveis.
- **Curva de aprendizagem** — o contribuidor ocasional não domina o modelo, erra a
  ramificação e o mantenedor paga a fatura.
- **Sem resposta ao fork + PR** — o GitHub nasceu à volta do fork; o GitFlow não o prevê.

## Os 5 dogmas do fluxo recomendado

1. **Uma única ramificação longa: `main`** — sempre implementável, sempre releasável;
   o seu HEAD é a verdade do projeto.
2. **Desenvolvimento em ramificações efémeras** — nascem de `main`, vivem horas ou
   dias, morrem no merge.
3. **Contribuição externa via fork + PR** — nunca escrita direta em `main` para
   desconhecidos; o PR é a unidade de revisão.
4. **Squash merge obrigatório** — cada PR vira um único commit convencional em `main`.
5. **Delete branch após merge** — `gh pr merge --squash --delete-branch`; ramificação
   morta é ruído e armadilha para o próximo contribuidor.

## Naming de ramificações

| Padrão | Uso | Exemplo |
|---|---|---|
| `feat/<nome>` | funcionalidade nova | `feat/refresh-token` |
| `fix/<nome>` | correção | `fix/cookie-expiry` |
| `chore/<nome>` | manutenção, dependências, CI | `chore/bump-deps` |
| `docs/<nome>`, `test/<nome>`, `refactor/<nome>` | conforme o tipo de commit dominante | `docs/api-examples` |
| `release/x.y` | **apenas** manutenção de uma release passada | `release/1.4` |

Regras: minúsculas, kebab-case, sem datas nem nomes de pessoas — o nome descreve a
mudança, não o autor. `release/x.y` nunca é linha de desenvolvimento (ver hotfixes).

## Trunk-Based Development vs GitHub Flow

| | Trunk-Based Development | GitHub Flow |
|---|---|---|
| Ramificação longa | `trunk` (= `main`) | `main` |
| Granularidade | commits pequenos, diretos ou branches de < 1 dia | ramificações efémeras com PR |
| Integração | contínua, com feature flags | por PR revisto |
| Revisão | assíncrona ou retroativa | PR obrigatório antes do merge |
| Escala típica | equipas grandes com CI < 5 min | a maioria dos projetos OSS |

Semelhanças: `main` verde a toda a hora, integração frequente, zero ramos de
release longos. Diferença central: o TBD admite push direto para o trunk; aqui o PR
é obrigatório (dogma 3). **Quando escala**: com mais de 10 contribuidores ativos e CI
rápido, adota-se TBD + feature flags mantendo os mesmos gates; abaixo disso, o
GitHub Flow chega e sobra.

## Squash merge: o que condensa e porquê que gera histórico linear

O squash condensa todos os commits da ramificação num único commit em `main`, com a
mensagem do PR. Ganha-se:

- **Histórico linear** — sem nós de merge, o `git bisect` percorre apenas estados
  reais e encontra o commit culpado sem travessias impossíveis.
- **Changelogs limpos** — um commit = uma entrada; `scripts/oss-changelog.py` lê a
  história sem deduplicar fusões.
- **Reverts cirúrgicos** — `git revert <sha>` desfaz o PR inteiro de uma vez.

Custo: perde-se a granularidade dos commits intermédios — daí exigir PRs pequenos e
título convencional (a mensagem final é a do PR).

## Hotfixes em produção e ramos de manutenção `release/**`

Produção é a tag `vX.Y.Z` mais recente nascida de `main`. Para um bug em produção:

1. **Caso normal** — `fix/<nome>` a partir de `main`, PR, squash merge, e a versão
   derivada é PATCH (`python3 scripts/oss-version.py next`).
2. **Consumidores presos a uma versão antiga** — abre `release/x.y` a partir da tag
   `vX.Y.Z`, faz cherry-pick do fix, publica `vX.Y.(Z+1)` e faz forward-port do fix
   para `main`.

Os ramos `release/**` têm ruleset próprio (PR obrigatório, checks mais leves e prazo
de merge diferente — ver `rulesets-e-protecao.md`) e nunca recebem funcionalidades.

## Rebase vs merge

- **Antes do PR**: rebase a ramificação sobre `main` atual
  (`git fetch origin && git rebase origin/main`) — o PR fica linear, sem
  "Merge branch 'main' into feat/x".
- **Nunca reescrever histórico partilhado**: depois do push, nada de `rebase`/`reset`
  em `main` ou `release/**` (o ruleset bloqueia `non_fast_forward`). Em ramificação
  própria, ainda sem revisões, aceita-se `git push --force-with-lease`.
- Predefinição pessoal: `git pull --rebase`; merge de `main` na ramificação só quando
  o rebase é mesmo impossível.

## Fluxo operacional do agente (passo a passo)

```bash
git switch -c feat/refresh-token main
# ... edita e testa — lint e testes verdes são pré-condição de PR ...
git add -A
git commit -m "feat(auth): adiciona refresh token de curta duração"  # hook commit-msg valida
bash scripts/oss-gate.sh push --branch feat/refresh-token
git push -u origin feat/refresh-token
gh pr create --base main \
  --title "feat(auth): adiciona refresh token de curta duração" \
  --body "Motivação, contexto e plano de teste. Refs: #412"
gh pr checks --watch
bash scripts/oss-gate.sh merge --title "feat(auth): adiciona refresh token de curta duração"
gh pr merge --squash --delete-branch
```

Confirma o efeito (`gh pr view <n> --json state,mergedAt,mergeCommit`) e reporte a
URL do PR e o sha do commit de squash.

## PR desatualizado

Quando `main` avança e o GitHub marca o PR como "out of date":

- `gh pr update-branch` — o GitHub atualiza a ramificação pela API (sem conflitos).
- Com conflitos, ou para histórico limpo: `git fetch origin && git rebase origin/main`,
  resolve os conflitos commit a commit e `git push --force-with-lease`.
- Depois de atualizado, `gh pr checks --watch` outra vez: uma atualização pode
  invalidar checks que antes estavam verdes.
