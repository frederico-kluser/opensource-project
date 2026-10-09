#!/usr/bin/env bash
# oss-scaffold.sh — scaffolding IDEMPOTENTE da fundação de governança open-source (Gate 0).
# Copia os templates de assets/ para o projeto-alvo, substituindo placeholders.
# NUNCA sobrescreve ficheiro existente sem --force (não-destruição).
#
# Uso: bash scripts/oss-scaffold.sh [opções]
#   --target DIR          projeto-alvo (predef.: .)
#   --owner OWNER         dono/org no GitHub (para CODEOWNERS, badges, links)
#   --repo NOME           nome do repositório (predef.: basename do target)
#   --desc "FRASE"        descrição curta (About/README)
#   --license ID          mit | apache-2.0 | gpl-3.0 | mpl-2.0 (predef.: mit)
#   --holder NOME         titular dos direitos (predef.: owner)
#   --year ANO            ano da licença (predef.: ano atual)
#   --branch NOME         ramificação predefinida (predef.: main)
#   --contact EMAIL       contacto de segurança (predef.: security@<owner>.example)
#   --release-engine X    release-please | semantic-release | none (predef.: release-please)
#   --with-tests          acrescenta o pipeline de testes com matrix (assets/workflows/tests.yml)
#   --install-hook        instala hook git commit-msg que invoca oss-gate.sh
#   --force               sobrescreve ficheiros já existentes
#   --dry-run             mostra o plano sem escrever
#
# Exit codes: 0 sucesso · 2 uso inválido · 3 ferramenta em falta · 5 assets em falta
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"

TARGET="."; OWNER=""; REPO=""; DESC=""; LICENSE="mit"; HOLDER=""; YEAR=""
BRANCH="main"; CONTACT=""; ENGINE="release-please"; FORCE=0; DRY=0; HOOK=0; WITH_TESTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --desc) DESC="$2"; shift 2 ;;
    --license) LICENSE="$2"; shift 2 ;;
    --holder) HOLDER="$2"; shift 2 ;;
    --year) YEAR="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --contact) CONTACT="$2"; shift 2 ;;
    --release-engine) ENGINE="$2"; shift 2 ;;
    --with-tests) WITH_TESTS=1; shift ;;
    --install-hook) HOOK=1; shift ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Erro: argumento desconhecido: %s — Solução: veja --help\n' "$1" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || {
  printf 'Erro: python3 em falta — Solução: instale python3 (substituição de placeholders)\n' >&2; exit 3
}
[ -d "$ASSETS/templates" ] || {
  printf 'Erro: assets/ da skill incompleto (%s) — Solução: reinstale a skill opensource-project\n' "$ASSETS" >&2
  exit 5
}

[ -d "$TARGET" ] || mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
[ -n "$OWNER" ] || OWNER="OWNER"
[ -n "$REPO" ] || REPO="$(basename "$TARGET")"
[ -n "$HOLDER" ] || HOLDER="$OWNER"
[ -n "$YEAR" ] || YEAR="$(date +%Y)"
[ -n "$DESC" ] || DESC="Projeto open-source $REPO"
[ -n "$CONTACT" ] || CONTACT="security@${OWNER}.example"
case "$LICENSE" in mit|apache-2.0|gpl-3.0|mpl-2.0) ;; *)
  printf 'Erro: licença desconhecida: %s — Solução: mit | apache-2.0 | gpl-3.0 | mpl-2.0\n' "$LICENSE" >&2; exit 2 ;;
esac
case "$ENGINE" in release-please|semantic-release|none) ;; *)
  printf 'Erro: release-engine desconhecido: %s — Solução: release-please | semantic-release | none\n' "$ENGINE" >&2; exit 2 ;;
esac

CRIADO=0; IGNORADO=0; SOBRESCRITO=0

render() { # $1=src $2=dst-relativo
  local src="$1" dst="$TARGET/$2" existed=0
  [ -e "$dst" ] && existed=1
  if [ "$existed" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
    printf '  [IGNORADO]    %s (existe; use --force)\n' "$2"; IGNORADO=$((IGNORADO+1)); return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    if [ "$existed" -eq 1 ]; then printf '  [SOBRESCREVE] %s\n' "$2"; else printf '  [CRIARIA]     %s\n' "$2"; fi
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  OSS_PROJECT_NAME="$REPO" OSS_DESCRIPTION="$DESC" OSS_OWNER="$OWNER" OSS_REPO="$REPO" \
  OSS_LICENSE="$LICENSE" OSS_YEAR="$YEAR" OSS_HOLDER="$HOLDER" OSS_DEFAULT_BRANCH="$BRANCH" \
  OSS_CONTACT="$CONTACT" python3 - "$src" "$dst" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
keys = ["PROJECT_NAME", "DESCRIPTION", "OWNER", "REPO", "LICENSE", "YEAR",
        "HOLDER", "DEFAULT_BRANCH", "CONTACT"]
text = open(src, encoding="utf-8").read()
for k in keys:
    text = text.replace("{{" + k + "}}", os.environ.get("OSS_" + k, ""))
open(dst, "w", encoding="utf-8").write(text)
PY
  if [ -e "$dst" ]; then
    if [ "$existed" -eq 1 ]; then
      printf '  [SOBRESCRITO] %s\n' "$2"; SOBRESCRITO=$((SOBRESCRITO+1))
    else
      printf '  [CRIADO]      %s\n' "$2"; CRIADO=$((CRIADO+1))
    fi
  fi
}

printf 'oss-scaffold · fundação de governança em %s\n' "$TARGET"
printf '  owner=%s repo=%s licença=%s branch=%s release-engine=%s\n\n' "$OWNER" "$REPO" "$LICENSE" "$BRANCH" "$ENGINE"

echo "-- Fundação legal e documentação --"
LICENSE_SRC="$ASSETS/licenses/MIT.txt"
if [ "$LICENSE" != "mit" ]; then
  LICENSE_SRC="$ASSETS/licenses/$LICENSE.txt"
  if [ ! -e "$LICENSE_SRC" ] && [ "$DRY" -eq 0 ]; then
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "https://raw.githubusercontent.com/spdx/license-list-data/main/text/$(echo "$LICENSE" | tr '[:lower:]' '[:upper:]' | sed 's/APACHE-2.0/Apache-2.0/;s/GPL-3.0/GPL-3.0-only/;s/MPL-2.0/MPL-2.0/').txt" \
        -o "$ASSETS/licenses/$LICENSE.txt" 2>/dev/null || true
    fi
    [ -e "$LICENSE_SRC" ] || {
      printf '  [AVISO] não obtive o texto de %s — veja assets/licenses/README.md\n' "$LICENSE"
      LICENSE_SRC=""
    }
  fi
fi
[ -n "$LICENSE_SRC" ] && [ -e "$LICENSE_SRC" ] && render "$LICENSE_SRC" "LICENSE"
render "$ASSETS/templates/README.md.tpl" "README.md"
render "$ASSETS/templates/CONTRIBUTING.md.tpl" "CONTRIBUTING.md"
render "$ASSETS/templates/SECURITY.md.tpl" "SECURITY.md"
render "$ASSETS/templates/CODE_OF_CONDUCT.md" "CODE_OF_CONDUCT.md"
render "$ASSETS/templates/CHANGELOG.md.tpl" "CHANGELOG.md"
render "$ASSETS/templates/CODEOWNERS.tpl" "CODEOWNERS"

echo "-- Templates de colaboração --"
render "$ASSETS/templates/PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"
render "$ASSETS/templates/ISSUE_TEMPLATE/bug_report.md" ".github/ISSUE_TEMPLATE/bug_report.md"
render "$ASSETS/templates/ISSUE_TEMPLATE/feature_request.md" ".github/ISSUE_TEMPLATE/feature_request.md"
render "$ASSETS/templates/ISSUE_TEMPLATE/config.yml" ".github/ISSUE_TEMPLATE/config.yml"

echo "-- CI e governança como código --"
render "$ASSETS/workflows/ci.yml" ".github/workflows/ci.yml"
if [ "$WITH_TESTS" -eq 1 ]; then
  render "$ASSETS/workflows/tests.yml" ".github/workflows/tests.yml"
  printf '  [INFO] pipeline de testes: ajuste a matrix ao stack e use o job agregador como required status check\n'
fi
render "$ASSETS/workflows/scorecard.yml" ".github/workflows/scorecard.yml"
if [ "$ENGINE" = "release-please" ]; then
  render "$ASSETS/workflows/release-please.yml" ".github/workflows/release-please.yml"
  render "$ASSETS/templates/release-please-config.json" "release-please-config.json"
  render "$ASSETS/templates/release-please-manifest.json" ".release-please-manifest.json"
elif [ "$ENGINE" = "semantic-release" ]; then
  render "$ASSETS/workflows/semantic-release.yml" ".github/workflows/semantic-release.yml"
  render "$ASSETS/templates/.releaserc.json" ".releaserc.json"
fi
if [ "$ENGINE" != "none" ]; then
  render "$ASSETS/templates/cliff.toml" "cliff.toml"
fi
render "$ASSETS/rulesets/regras-main.json" ".github/rulesets/regras-main.json"
render "$ASSETS/rulesets/regras-tags.json" ".github/rulesets/regras-tags.json"
render "$ASSETS/rulesets/regras-release.json" ".github/rulesets/regras-release.json"

echo "-- Filtros de commit --"
if [ -e "$TARGET/package.json" ]; then
  render "$ASSETS/templates/commitlint.config.js" "commitlint.config.js"
  render "$ASSETS/templates/husky-commit-msg" ".husky/commit-msg"
  render "$ASSETS/templates/husky-pre-commit" ".husky/pre-commit"
  [ "$DRY" -eq 0 ] && chmod +x "$TARGET/.husky/commit-msg" "$TARGET/.husky/pre-commit" 2>/dev/null
  printf '  [INFO] acrescente ao package.json: "prepare": "husky" + devDeps (ver assets/templates/package-husky-fragment.json)\n'
elif [ "$HOOK" -eq 1 ]; then
  if [ "$DRY" -eq 1 ]; then
    printf '  [CRIARIA]     .git/hooks/commit-msg (oss-gate.sh commit-msg)\n'
  else
    mkdir -p "$TARGET/.git/hooks"
    printf '#!/bin/sh\nexec bash "%s/scripts/oss-gate.sh" commit-msg "$1"\n' "$SKILL_DIR" > "$TARGET/.git/hooks/commit-msg"
    chmod +x "$TARGET/.git/hooks/commit-msg"
    printf '  [CRIADO]      .git/hooks/commit-msg (não versionado; repita em cada clone ou use husky)\n'
    CRIADO=$((CRIADO+1))
  fi
else
  printf '  [INFO] sem package.json: use --install-hook para o hook git local ou configure husky/commitlint no seu stack\n'
fi

echo
printf 'Resumo: %d criados · %d ignorados · %d sobrescritos\n' "$CRIADO" "$IGNORADO" "$SOBRESCRITO"
cat <<EOF

Passos seguintes (nesta ordem):
  1. Revise os ficheiros gerados (README badges, CODEOWNERS com as equipas reais).
  2. Aplique os rulesets: gh api --method POST repos/$OWNER/$REPO/rulesets --input .github/rulesets/regras-main.json
  3. Fixe as actions por SHA: bash "$SKILL_DIR/scripts/oss-pin-actions.sh"
  4. Diagnóstico: bash "$SKILL_DIR/scripts/oss-doctor.sh"
EOF
[ "$DRY" -eq 1 ] && echo "(modo --dry-run: nada foi escrito)"
exit 0
