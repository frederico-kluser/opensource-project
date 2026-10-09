# Changelog

Todas as datas notáveis deste projeto — [Keep a Changelog](https://keepachangelog.com/pt-BR/).
O versionamento segue [SemVer](https://semver.org/lang/pt-BR/); os números são
calculados dos Commits Convencionais com `scripts/oss-version.py` e as entradas são
geradas com `scripts/oss-changelog.py`.

## 1.0.0 (2026-10-09)


### Features

* adiciona automações do GitHub Actions e pipelines de testes ([#5](https://github.com/frederico-kluser/opensource-project/issues/5)) ([eb211c6](https://github.com/frederico-kluser/opensource-project/commit/eb211c671da2cda88b0c25a3df9b58a31eebc68f))
* cria a skill opensource-project de governança de ciclo de vida OSS ([a1cb0d7](https://github.com/frederico-kluser/opensource-project/commit/a1cb0d732396d47348a867cc29cb523a28d45051))
* embute o comportamento da skill em CLAUDE.md e AGENTS.md ([#6](https://github.com/frederico-kluser/opensource-project/issues/6)) ([51febdb](https://github.com/frederico-kluser/opensource-project/commit/51febdbc78de47c75f55d2eaebd8ebe0b89c264d))
* liga a skill nos 12 skill roots globais da máquina ([#3](https://github.com/frederico-kluser/opensource-project/issues/3)) ([bc3d14e](https://github.com/frederico-kluser/opensource-project/commit/bc3d14e60e4d8b88cf75f7018cd1dcf40ecffa2f))


### Bug Fixes

* badges que renderizam sempre e gate de conteúdo no doctor ([#4](https://github.com/frederico-kluser/opensource-project/issues/4)) ([c8c9332](https://github.com/frederico-kluser/opensource-project/commit/c8c93320fcee27375dac5701df5dce908e006da5))
* contrato de agentes só em CLAUDE.md e AGENTS.md ([#7](https://github.com/frederico-kluser/opensource-project/issues/7)) ([2223b3b](https://github.com/frederico-kluser/opensource-project/commit/2223b3b73ab7d18edc2f5156bdd03effc92db164))
* corrige rulesets e release-please com o schema real da API ([28a6022](https://github.com/frederico-kluser/opensource-project/commit/28a6022f27203e2c179e90161df03ff6d5b647d0))
* primeiro release 0.1.0 e regras de maintainer único ([51d8199](https://github.com/frederico-kluser/opensource-project/commit/51d8199575fd4451f8a6679ac4ffdb73fab0f2bf))


### Documentation

* alinha a referência de segurança OpenSSF com os scripts ([c714c51](https://github.com/frederico-kluser/opensource-project/commit/c714c512e11f6d447ab9de3ae3cc9aba11254dcf))

## [Unreleased]

### Added
- **Comportamento embutido por projeto**: `oss-scaffold.sh` planta `CLAUDE.md` +
  `AGENTS.md` (contrato operacional carregado automaticamente pelos harnesses, sem
  tocar no README/Markdown do projeto) — os agentes seguem os gates sem invocar a
  skill. Template `assets/templates/CLAUDE.md.tpl` com as regras obrigatórias, a
  tabela pedido→procedimento, o checklist de fecho e a semântica de erros.
- Guia `references/github-actions-automacoes.md` e templates de pipelines
  (`tests.yml`, `reusable-ci.yml`, `codeql.yml`, `dependency-review.yml`):
  automações do GitHub Actions com pipelines de testes e conhecimento completo.
- Validação de badges no `oss-doctor.sh` (HTTP 200 por badge + nota do OpenSSF
  Scorecard comparada com o limiar ≥ 7) e legenda de telemetria no README.
- Conhecimento de badges em `references/identidade-e-telemetria.md`: anatomia da
  URL shields.io (estática/endpoint/dinâmica + parâmetros), troubleshooting de
  badges invisíveis e regras de higiene (quebrado/velho/vaidade).
- Registo global nos 12 skill roots (`link-skill-global.sh` com `--check`,
  `--dry-run` e `--unlink`).
- Skill `opensource-project`: modelo de gates para o ciclo de vida open-source
  (fundação, commits, push/PR, merge, versão, release e segurança).
- Ferramentas: `oss-doctor.sh`, `oss-scaffold.sh`, `oss-gate.sh`, `oss-version.py`,
  `oss-changelog.py`, `oss-pin-actions.sh`, `link-skill-global.sh`.
- Referências (9 guias) e assets (templates, workflows pinnados, rulesets JSON, licenças).
