# Versionamento Semântico e releases automatizadas

A versão não é um palpite: é um **cálculo derivado da história**. Esta skill impõe
SemVer (`<https://semver.org/>`), bump automático a partir dos commits desde a última
tag, changelog gerado e publicação por CI — nunca versão escrita à mão.

## SemVer: MAJOR.MINOR.PATCH

Formato `vMAJOR.MINOR.PATCH` — um contrato público com o consumidor:

- **MAJOR** — mudanças incompatíveis: APIs removidas, assinaturas alteradas,
  comportamento que quebra consumidores existentes.
- **MINOR** — funcionalidade nova em retrocompatibilidade.
- **PATCH** — correções retrocompatíveis.

Porquê a promessa importa: o consumidor fixa `^1.2.0` e o gestor de dependências
atualiza sozinho. Uma quebra silenciosa num PATCH contamina o ecossistema inteiro —
CI de terceiros a arder, cadeias de dependências partidas, confiança perdida. Um
MAJOR anunciado dói uma vez; um PATCH traiçoeiro dói para sempre.

## Tabela de decisão: tipo de commit → bump

| Commits desde a última tag | Bump | Exemplo |
|---|---|---|
| `BREAKING CHANGE` / `tipo!:` (qualquer tipo) | **MAJOR** | `feat(api)!: remove os endpoints v1` |
| `feat` sem breaking | **MINOR** | `feat(cli): adiciona --json` |
| `fix` sem breaking | **PATCH** | `fix(auth): corrige expiração do cookie` |
| `docs`/`style`/`refactor`/`perf`/`test`/`chore`/`revert` | nenhum | `docs: corrige exemplo do README` |

Sem commits que justifiquem bump, **não há release**. O `revert` de um BREAKING
força novo MAJOR (ver "O dilema da reversão").

## Derivação automática do bump (contrato dos scripts desta skill)

Nunca decidas a versão "de cabeça": deriva-a dos commits desde a última tag `vX.Y.Z`:

```bash
python3 scripts/oss-version.py next           # v1.4.0
python3 scripts/oss-version.py next --json    # {"next_version":"1.4.0","bump":"minor","counts":{...},...}
```

Contrato de `scripts/oss-version.py next`:

1. lê a tag `vX.Y.Z` mais recente (`git describe --tags --abbrev=0`);
2. analisa os commits desde essa tag com a gramática Conventional Commits;
3. calcula o próximo version e **lista os commits que o justificam** (`--json`
   devolve os grupos `breaking`/`features`/`fixes`/`other`, `non_conventional` e
   as contagens; cada entrada traz sujeito, tipo, escopo e flag de breaking);
4. sem commits releasáveis devolve `bump: "none"` (exit 0) — um bump manual só com
   `--bump` e justificação explícita do utilizador; o `oss-changelog.py` recusa-se
   nesse caso com exit 5, e `oss-gate.sh release` bloqueia o lançamento.

`scripts/oss-changelog.py` consome a mesma análise e gera a secção do CHANGELOG no
formato Keep a Changelog:

```bash
python3 scripts/oss-changelog.py --write      # insere "## [1.4.0] - <data>" no CHANGELOG.md
python3 scripts/oss-changelog.py             # imprime a secção (para release notes)
python3 scripts/oss-changelog.py --json      # para agentes; --include-all traz o resto
```

## Três filosofias de release automatizado

| Ferramenta | Automação | Intervenção humana | Monorepo | Reversões | Quando usar |
|---|---|---|---|---|---|
| semantic-release | total: versão, tag, release e publish no pós-merge | nenhuma (só aprovar o PR) | por config/pacote extra | tag imutável; publica-se o MAJOR seguinte | "merge = release" sem fricção |
| release-please | alta, mas o release é um PR vivo | aprovar o Release PR | nativo (manifesto, tags `comp@vX.Y.Z`) | reverts entram no changelog do PR | OSS que exige auditoria antes de publicar |
| git-cliff / changesets | parcial: só changelog e versão | decidir quando publicar | git-cliff por config; changesets nativo | trivial (changelog regenera-se) | determinismo e publicação manual |

## semantic-release em detalhe

Pipeline que corre em `main` após o merge: analisa commits → calcula a versão → gera
release notes → publica no registos → faz push da tag e do bump. Config em
`.releaserc`, com plugins:

| Plugin | Papel |
|---|---|
| `@semantic-release/commit-analyzer` | determina o bump a partir dos commits |
| `@semantic-release/release-notes-generator` | gera as notas da release |
| `@semantic-release/npm` / `@semantic-release/pypi` | publica nos registos |
| `@semantic-release/git` | commita `package.json`/CHANGELOG de volta |
| `@semantic-release/github` | cria a GitHub Release e comenta nos issues |

Pré-lançamentos via canais — `beta` (`1.5.0-beta.1`), `next`, `rc` — publicam sem
tocar em `latest` e absorvem o atrito das quebras. Fixa as actions por SHA
(`bash scripts/oss-pin-actions.sh`) e declara `permissions` mínimas no workflow.

## release-please em detalhe

Cada merge em `main` atualiza um **Release PR** vivo (ramo
`release-please--branches--main`) que acumula CHANGELOG + bump; o humano revê e faz
merge — e só esse merge dispara tag e publicação.

- Config: `release-please-config.json` na raiz (`release-type`, `packages`,
  `bump-minor-pre-major`, regras de monorepo) — alinhe os inputs `config-file`/
  `manifest-file` do workflow com os caminhos reais (o scaffold planta-os na raiz).
- Manifesto: `.release-please-manifest.json` — versão atual por pacote.
- Workflow: `googleapis/release-please-action@v5` (nunca as `@v3` antigas).
- Monorepo: tags `componente@v1.2.0` e changelog por pacote, escopo alinhado com os
  commits convencionais.
- Fronteira humana: nada é publicado sem merge explícito do Release PR.

## git-cliff: changelog determinístico sem publicar

`git-cliff` gera o CHANGELOG a partir de `cliff.toml`: templates Tera, regex de
agrupamento por tipo de commit, ordenação estável — sem rede, sem registos, sem
tags. Ideal para publicação manual ou para diff de changelog dentro do PR. O
changesets (ecossistema JS) inverte a lógica: cada PR traz um ficheiro `.changeset/`
que descreve o bump; o release consolida-os — ótimo em monorepo JS.

## O dilema da reversão

O SemVer não retrocede: `v1.4.0` publicado não se apaga nem se reutiliza. Se uma
release introduziu um BREAKING acidental:

1. `git revert` do commit **não** gera PATCH — o revert altera a API pública de novo
   e força um novo **MAJOR** (`v2.0.0`) ou, no mínimo, o menor bump que repõe o
   contrato anterior de forma anunciada.
2. Os canais de pré-lançamento (`beta`/`rc`) e o Release PR absorvem o atrito: a
   quebra deteta-se antes de chegar a `latest`.
3. As tags imutáveis (ruleset para `v*`, ver `rulesets-e-protecao.md`) impedem
   "remendar a tag": a história não se reescreve, comunica-se.

## Tags, GitHub Releases e registos

- Tags **anotadas**, nunca leves: `git tag -a v1.4.0 -m "chore(release): v1.4.0"` —
  a anotação guarda autor, data e mensagem que o changelog lê. Assina-as (`-s`,
  SSH ou GPG) sempre que possível.
- Formato `vX.Y.Z` com `v` — é o que `scripts/oss-version.py` e os registos esperam.
- GitHub Release a partir da tag já publicada:

```bash
gh release create v1.4.0 --verify-tag --notes-file CHANGELOG.md
```

`--verify-tag` falha se a tag não existir no remoto — ordem correta: push, tag,
release; nunca o inverso.

- Registos — npm (`npm publish --access public`), PyPI (preferir OIDC com
  `pypa/gh-action-pypi-publish`), crates.io (`cargo publish`) — sempre em CI, com
  tokens em GitHub Environments:

```bash
echo "$NPM_TOKEN" | gh secret set NPM_TOKEN --env production   # nunca o valor em claro
```

- CHANGELOG no formato Keep a Changelog: `## [1.4.0] - 2026-02-11` com grupos
  `Added`/`Changed`/`Fixed`/`Removed` — gerado por `scripts/oss-changelog.py`,
  nunca reescrito à mão.
