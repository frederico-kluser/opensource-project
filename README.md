# opensource-project — agent skill de governança open-source de ciclo de vida total

<p align="center">
  <a href="https://github.com/frederico-kluser/opensource-project/actions/workflows/ci.yml"><img src="https://github.com/frederico-kluser/opensource-project/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://securityscorecards.dev/viewer/?uri=github.com/frederico-kluser/opensource-project"><img src="https://api.securityscorecards.dev/projects/github.com/frederico-kluser/opensource-project/badge" alt="OpenSSF Scorecard"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/frederico-kluser/opensource-project/releases"><img src="https://img.shields.io/github/v/release/frederico-kluser/opensource-project" alt="GitHub release"></a>
  <img src="https://img.shields.io/badge/commits-Conventional-fe2d52.svg" alt="Conventional Commits">
  <img src="https://img.shields.io/badge/version-SemVer-2ea44f.svg" alt="SemVer">
</p>

**Telemetria — o que cada badge promete e mostra:**

| Badge | O que mostra | Onde clicar |
|---|---|---|
| CI | estado do pipeline de testes (workflow `ci`, job `build`) em `main` | [runs do workflow](https://github.com/frederico-kluser/opensource-project/actions/workflows/ci.yml) |
| OpenSSF Scorecard | nota de segurança defensiva (limiar de graduação **≥ 7**) | [relatório Scorecard](https://securityscorecards.dev/viewer/?uri=github.com/frederico-kluser/opensource-project) |
| License | enquadramento legal (MIT) | [LICENSE](LICENSE) |
| GitHub release | última versão SemVer publicada | [releases](https://github.com/frederico-kluser/opensource-project/releases) |
| Conventional Commits · SemVer | contrato de mensagens e de versionamento | [SKILL.md](SKILL.md) |

Os badges são **telemetria viva**: o `bash scripts/oss-doctor.sh` valida cada URL
(HTTP 200 + `image/svg+xml`) e compara a nota do Scorecard com o limiar. Um badge
quebrado é corrigido ou removido — nunca fica a fingir.

Uma **agent skill** que faz de arquiteto de governança para agentes de código: cada
pedido do utilizador — *commit, push, mudar a versão, fazer release, publicar* —
atravessa **gates** que forçam os padrões do open-source profissional, da mensagem
de commit à publicação da versão, sem deixar espaço ao arbítrio humano.

> A excelência de um repositório open-source não é altruísmo: é um sistema coercivo
> e metodológico. Esta skill é o elo entre convenções rigorosas e as proteções de
> plataforma que as tornam invioláveis.

## O que governa

| Gate | Pedido do utilizador | Padrão imposto |
|---|---|---|
| 0 · Fundação | "cria/prepara repo" | LICENSE · README+badges · CONTRIBUTING · CODEOWNERS · SECURITY · templates |
| 1 · Commit | "commita" | Commits Convencionais (`tipo(escopo)!: descrição`) |
| 2 · Push/PR | "push", "abre PR" | GitHub Flow: ramificação efémera, PR, sem segredos |
| 3 · Merge | "faz merge" | Squash merge · histórico linear · status checks |
| 4 · Versão | "muda a versão" | SemVer **calculado** dos commits · changelog **gerado** |
| 5 · Release | "faz release/publica" | Tag `vX.Y.Z` · release notes · publicação via CI |
| 6 · Segurança | sempre | OpenSSF Scorecard ≥ 7 · least privilege · actions fixadas por SHA |

## Instalação

```bash
bash scripts/link-skill-global.sh   # liga nos 12 skill roots da máquina (--check/--dry-run/--unlink)
```

## Uso rápido (como skill de agente)

```bash
bash scripts/oss-doctor.sh                                  # diagnóstico da governança
bash scripts/oss-scaffold.sh --target . --owner acme --license mit
bash scripts/oss-gate.sh commit-msg "$1"                    # Gate 1 (hook)
bash scripts/oss-gate.sh push                               # Gate 2
python3 scripts/oss-version.py next                         # Gate 4: SemVer calculado
python3 scripts/oss-changelog.py --write                    # changelog gerado
bash scripts/oss-gate.sh publish --version 1.4.0 --yes      # Gate 5
```

## Estrutura

```
SKILL.md                    # instruções da skill (núcleo operacional)
scripts/                    # ferramentas coercivas (doctor, gate, scaffold, semver, changelog, pin-actions)
references/                 # 9 guias: licenças, identidade, governança social, commits,
                            # branching, releases, rulesets, segurança OpenSSF, gh CLI
assets/                     # templates, workflows pinnados, rulesets JSON, licenças
```

## Dogfooding

Este repositório obedece aos próprios gates: licença MIT, changelog Keep a Changelog,
commits em Conventional Commits e releases derivadas do histórico (`scripts/oss-version.py`).

## Licença

[MIT](LICENSE) © 2026 ondokai. Documento informativo — para decisões jurídicas de
licenciamento consulte um profissional qualificado.
