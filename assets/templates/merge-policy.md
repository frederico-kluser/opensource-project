<!-- oss:merge-policy:begin -->
## Política de integração: merge, nunca rebase

A integração é **merge**; rebase é proibido. Merge commit e squash merge são
merges — rebase não é.

- **Sincronizar a ramificação**: `git fetch origin && git merge origin/main` (ou
  `git pull`, que faz merge). **Nunca** `git rebase`, `git pull --rebase` nem
  `git rebase origin/main`.
- **Integrar o PR**: `gh pr merge --squash --delete-branch` no cofre (`main` é
  squash-only por ruleset; squash é merge e mantém o histórico linear). Onde o
  ruleset permitir, `gh pr merge --merge` também é merge; **rebase-merge nunca**.
- **PR desatualizado**: `gh pr update-branch` (merge) ou merge de `origin/main` na
  ramificação; depois `gh pr checks --watch`. Sem rebase e sem force-push.
- **Configuração imposta**: `oss-enforce.sh` deteta rebase no projeto
  (`pull.rebase`, `branch.*.rebase`, `allow_rebase_merge`, `allowed_merge_methods`)
  e corrige — `[CONFIGURADO]` — sem perguntar. Diagnóstico dedicado:
  `oss-merge-policy.sh check` (na instalação da skill).
<!-- oss:merge-policy:end -->
