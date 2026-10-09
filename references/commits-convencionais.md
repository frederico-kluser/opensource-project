# Commits Convencionais — a sintaxe que a máquina compreende

Um commit não é um diário: é um **evento semântico** consumido por máquinas —
geradores de changelog, cálculo de SemVer, `git bisect`, reverts e revisão de
código. A gramática obrigatória desta skill é a Conventional Commits
(<https://www.conventionalcommits.org/>): aplica-se a **commits**, a **títulos de
PR** (que viram a mensagem final do squash merge) e a **mensagens de revert**.
O gate `scripts/oss-gate.sh commit-msg` rejeita tudo o que se afastar dela.

## Anatomia exata

```
tipo(escopo)!: descrição curta em imperativo

corpo opcional: motivação e contraste — o porquê, não o quê; separado do
cabeçalho por uma linha em branco e envolvido em ~72 colunas.

Refs: #412
BREAKING CHANGE: descrição da incompatibilidade e da migração necessária
```

Exemplo completo, pronto a colar:

```text
feat(auth)!: substitui sessões opacas por JWT de curta duração

Os tokens de sessão não expiravam e exigiam estado no servidor. O JWT de
15 minutos + refresh token elimina a tabela de sessões.

Refs: #412
Reviewed-by: Ana <ana@acme.dev>
BREAKING CHANGE: /login devolve {access_token, refresh_token} em vez de
{token}; os clientes devem migrar antes de atualizar.
```

| Parte | Obrigatória | Regra |
|---|---|---|
| `tipo` | sim | minúsculas, de um conjunto fechado (tabela abaixo) |
| `(escopo)` | não | módulo/pacote em minúsculas: `fix(auth):` |
| `!` | não | imediatamente antes dos `:` — marca BREAKING (MAJOR) |
| `descrição` | sim | imperativo, minúsculas, sem ponto final, cabeçalho ≤ 72 chars |
| corpo | não | porquê da mudança; `Refs: #n` liga ao issue |
| rodapés | não | pares `chave: valor` (`Refs:`, `Reviewed-by:`) e `BREAKING CHANGE:` |

## Tipos e o efeito na versão

| Tipo | Descrição | Incremento SemVer |
|---|---|---|
| `feat` | funcionalidade nova visível ao consumidor | **MINOR** |
| `fix` | correção de bug | **PATCH** |
| `docs` | apenas documentação | nenhum |
| `style` | formatação/whitespace, sem efeito no comportamento | nenhum |
| `refactor` | reestruturação sem mudar comportamento nem corrigir bug | nenhum |
| `perf` | melhoria de desempenho | nenhum |
| `test` | adição ou correção de testes | nenhum |
| `chore` | build, dependências, ferramentas, manutenção | nenhum |
| `revert` | reverte um commit anterior | nenhum (ver reversões em `releases-e-semver.md`) |

Fora desta lista, o commit é rejeitado (`type-enum`). Só `feat` e `fix` movem a
versão — e **qualquer tipo** com `!` ou rodapé `BREAKING CHANGE` força **MAJOR**.

## Regras da descrição

- **Imperativo/presente**: "adiciona suporte a X" — nunca "adicionado suporte a X".
  Teste: "se aplicar este commit, <descrição>" tem de soar natural.
- **50 a 72 caracteres** no cabeçalho completo — o `git log --oneline` corta a
  partir de 72; abaixo de 50 a descrição quase sempre falta ao contexto.
- **Sem ponto final**: a descrição é um rótulo, não uma frase.
- **Minúsculas** na primeira letra; sem "WIP", sem códigos de tarefa, sem gritar.

## BREAKING CHANGE: dois mecanismos, um efeito — MAJOR

1. **`!` no cabeçalho** — `feat(api)!: remove os endpoints v1`.
2. **Rodapé** — `BREAKING CHANGE: <incompatibilidade e migração>` (aceita-se também
   `BREAKING-CHANGE:` como alias).

Ambos implicam incremento **MAJOR**, mesmo num `fix` ou `refactor`. Descreve sempre
a migração: o consumidor lê este rodapé no changelog para saber o que mudar —
`BREAKING CHANGE: a flag --legacy foi removida; usar --compat em alternativa`.

## Escopo: localizar cirurgicamente

O escopo nomeia o módulo ou pacote tocado — `fix(auth):`, `feat(cli):`,
`refactor(core/parser):`. Com ele filtram-se partes da história
(`git log --grep "^(fix(auth))"`), agrupam-se changelogs por área e reverte-se só o
que interessa. Um escopo por commit; em monorepo o escopo é o nome do pacote (ver no fim).

## Exemplos: bons vs maus

Bons — um evento, um rótulo, uma intenção:

```text
feat(parser): suporta literais numéricos em binário
fix(auth): renova o cookie de sessão antes de expirar
refactor(core)!: extrai o pipeline de renderização para pacote próprio
```

Maus — e a razão de cada falha:

```text
correcao de bug                     → sem tipo: a máquina não classifica nem calcula versão
feat: Adicionado suporte a CSV.     → particípio passado, maiúscula inicial e ponto final
fix(auth): corrige o erro intermitente no login quando o utilizador entra de madrugada
                                    → 90+ chars: corta-se no git log e perde-se o essencial
```

## Enforcement local — husky v9 + commitlint (Node)

```bash
npm i -D @commitlint/cli @commitlint/config-conventional husky
npx husky init
```

`npx husky init` cria `.husky/pre-commit` e regista o script `prepare`. Escreve o
hook `.husky/commit-msg` **à mão**, com exatamente:

```sh
npx --no -- commitlint --edit "$1"
```

E no `package.json`:

```json
{ "scripts": { "prepare": "husky" } }
```

> **Nunca `npx husky add`** — deprecated no husky v9 (falha com "husky add is
> deprecated"). O v9 também não injeta shebangs: o hook é executado pelo git como
> shell script, tal como está.

Configuração canónica `commitlint.config.js` (template em
`assets/templates/commitlint.config.js`, instalado por `scripts/oss-scaffold.sh`):

```js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'chore', 'revert']],
    'subject-case': [2, 'always', ['lower-case']],
    'header-max-length': [2, 'always', 72],
  },
};
```

## Enforcement em repositórios não-Node

Sem npm, o hook delega no gate desta skill (instalado por `scripts/oss-scaffold.sh`,
que também aponta `core.hooksPath` para `.husky`):

```sh
#!/usr/bin/env sh
# .husky/commit-msg
bash scripts/oss-gate.sh commit-msg "$1"
```

Ou, em bash puro, a regex mínima que fecha a gramática:

```bash
#!/usr/bin/env bash
msg=$(head -n1 "$1")
grep -Eq '^(feat|fix|docs|style|refactor|perf|test|chore|revert)(\([a-z0-9._/-]+\))?!?: .+$' <<<"$msg" \
  || { echo "Erro: mensagem fora do padrão Conventional Commits — Solução: tipo(escopo)!: descrição em imperativo" >&2; exit 1; }
```

## O título do PR é a mensagem final do commit

Com squash merge, o GitHub grava em `main` o **título do PR** como mensagem e o
corpo do PR como corpo do commit. Um título não convencional polui a história e
parte o changelog — por isso `scripts/oss-gate.sh pr` valida o título como se commit
fosse: `gh pr create --title "feat(core): adiciona cache de parse" --body "..."`.

## Mensagens de `git revert`

Por predefinição `git revert` escreve `Revert "feat(x): ..."` — reescreve para o
tipo `revert`, mantendo o rodapé que liga ao commit original:

```text
revert: feat(auth): substitui sessões por JWT

This reverts commit 3f2c1ab9e0d4.
```

## Monorepo: escopo por pacote

Em monorepo o escopo identifica o pacote — `feat(cli):`, `fix(core):`,
`chore(docs-site):` — alinhado com os diretórios (`packages/core` → `core`) e com as
tags por pacote (`core@v1.2.0`, ver `releases-e-semver.md`). Assim o bump e o
changelog derivam-se por área, e o bisect encontra o dono de cada mudança.
