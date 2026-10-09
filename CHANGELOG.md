# Changelog

Todas as datas notáveis deste projeto — [Keep a Changelog](https://keepachangelog.com/pt-BR/).
O versionamento segue [SemVer](https://semver.org/lang/pt-BR/); os números são
calculados dos Commits Convencionais com `scripts/oss-version.py` e as entradas são
geradas com `scripts/oss-changelog.py`.

## [Unreleased]

### Added
- **Comportamento embutido por projeto**: `oss-scaffold.sh` planta `CLAUDE.md` +
  `AGENTS.md` (contrato operacional carregado automaticamente pelos harnesses) e a
  secção "Procedimentos de desenvolvimento" no README — os agentes seguem os gates
  sem invocar a skill. Template `assets/templates/CLAUDE.md.tpl` com as regras
  obrigatórias, a tabela pedido→procedimento, o checklist de fecho e a semântica
  de erros.
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
