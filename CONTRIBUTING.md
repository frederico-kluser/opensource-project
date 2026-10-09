# Contributing

Obrigado por ajudar a `opensource-project` — a skill de governança open-source de
ciclo de vida total. Este repositório obedece aos próprios gates: o que ele exige
dos projetos que governa, exige de si próprio.

## Regras

1. **Commits Convencionais** — `tipo(escopo)!: descrição`, imperativo, ≤ 72 chars.
   O hook `.git/hooks/commit-msg` rejeita mensagens inválidas; sem Node, use
   `bash scripts/oss-gate.sh commit-msg "<msg>"`.
2. **Nunca push direto a `main`** — ramificação efémera (`feat/*`, `fix/*`,
   `chore/*`) e PR com título convencional (vira o commit do squash).
3. **Gates antes de submeter**:
   ```bash
   bash scripts/oss-gate.sh pr --title "feat(x): ..."
   bash scripts/oss-doctor.sh --local
   ```
4. **Scripts determinísticos** — Python stdlib e bash portável; qualquer mudança em
   `scripts/` tem de passar nos testes manuais do fluxo (scaffold → gates → release)
   num repositório de rascunho.
5. **Textos das referências** — pt-PT, tabelas onde ajudem, comandos corretos e
   atuais (nada de APIs deprecated, ex.: `npx husky add`).
6. **Assets** — templates com placeholders `{{OWNER}}`, `{{REPO}}`, etc. (ver
   `assets/README.md`); JSON/YAML sempre parseáveis; actions sempre em formato
   `owner/repo@<PIN_SHA> # vX.Y.Z`.

## Estrutura

- `SKILL.md` — instruções carregadas pelo agente (não enfraqueça as regras de ouro).
- `scripts/` — ferramentas coercivas; mantenha o contrato de erros
  (`Erro: <o quê> — Solução: <o que fazer>`) e os exit codes documentados.
- `references/` — 9 guias temáticos; carregados sob demanda (divulgação progressiva).
- `assets/` — templates consumidos por `oss-scaffold.sh`.

## Releases

A versão é calculada dos commits (`python3 scripts/oss-version.py next`) e o
changelog é gerado (`python3 scripts/oss-changelog.py --write`) — nunca escreva
números de versão nem changelog à mão.
