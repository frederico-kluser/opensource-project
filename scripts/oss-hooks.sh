#!/usr/bin/env bash
# oss-hooks.sh — regras LOCAIS em qualquer projeto: nomes de branch `<tipo>/<slug>`,
# ZERO commits diretos em ramos protegidos e Commits Convencionais — via hooks git
# (`pre-push` + `commit-msg`). Nada disto depende do GitHub: funciona offline, em
# qualquer remoto ou sem remoto nenhum.
#
# Uso: bash scripts/oss-hooks.sh <install|check|uninstall> [opções]
#   install   [--target DIR] [--global] [--only pre-push|commit-msg] [--force]
#   check     [--target DIR] [--global]
#   uninstall [--target DIR] [--global]
#
#   --target DIR  projeto (predef.: .) → instala em <repo>/.git/hooks e, se o projeto
#                 usar husky, também em .husky/ (o core.hooksPath do husky manda lá).
#   --global      instala em ~/.config/opensource-project/hooks e aponta o
#                 `core.hooksPath` GLOBAL do git para lá — passa a valer em QUALQUER
#                 projeto da máquina. Os hooks locais do repositório são encadeados
#                 primeiro (nunca substituem nada). Opt-out por repositório:
#                 `git config oss.policy off` (auditável no .git/config).
#   --only X      instala/verifica só `pre-push` ou `commit-msg`.
#   --force       sobrescreve mesmo hooks que não são nossos (com aviso).
#
# Os hooks geridos levam a marca "# oss-hooks:" — são atualizados quando a política
# muda; hooks alheios NUNCA são tocados (apenas [IGNORADO] + aviso).
# Os hooks são standalone: sem a skill instalada usam a política embutida no próprio
# ficheiro (a fonte única `scripts/oss-branch-policy.sh` é usada quando existe).
#
# Exit codes: 0 ok · 1 hooks em falta/desatualizados (apenas `check`) · 2 uso
#             inválido · 3 ferramenta em falta · 4 não é repositório git
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$SKILL_DIR/assets/templates/hooks"
GLOBAL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opensource-project/hooks"

PASS=0; FAIL=0; WARN=0; CRIADOS=0; ATUALIZADOS=0
ok()   { printf '  [OK]       %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  [FALTA]    %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  [AVISO]    %s\n' "$*"; WARN=$((WARN+1)); }
info() { printf '  [INFO]     %s\n' "$*"; }
die()  { printf 'Erro: %s — Solução: %s\n' "$1" "$2" >&2; exit "${3:-1}"; }

ACTION="${1:-}"; shift || true
case "$ACTION" in install|check|uninstall) ;; *)
  sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

TARGET="."; GLOBAL=0; ONLY=""; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || die "falta o valor de --target" "uso: oss-hooks.sh $ACTION --target DIR" 2
              TARGET="$2"; shift 2 ;;
    --only)   [ $# -ge 2 ] || die "falta o valor de --only" "uso: oss-hooks.sh $ACTION --only pre-push|commit-msg" 2
              ONLY="$2"; shift 2
              case "$ONLY" in pre-push|commit-msg) ;; *) die "--only desconhecido: $ONLY" "use pre-push ou commit-msg" 2 ;; esac ;;
    --global) GLOBAL=1; shift ;;
    --force)  FORCE=1; shift ;;
    *) die "argumento desconhecido: $1" "uso: oss-hooks.sh $ACTION [--target DIR] [--global] [--only X] [--force]" 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git não está instalado" "instale o git e repita" 3
command -v python3 >/dev/null 2>&1 || die "python3 não está instalado" "instale python3 e repita" 3
[ -d "$TEMPLATES" ] || die "templates de hooks em falta ($TEMPLATES)" "reinstale a skill opensource-project" 3

HOOKS="pre-push commit-msg"
[ -n "$ONLY" ] && HOOKS="$ONLY"

render_template() { # $1=src $2=dst
  OSS_SKILL_ROOT="$SKILL_DIR" python3 - "$1" "$2" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read().replace("{{SKILL_ROOT}}", os.environ.get("OSS_SKILL_ROOT", ""))
open(dst, "w", encoding="utf-8").write(text)
PY
}

hook_state() { # $1=dst — imprime: missing | ours-same | ours-stale | foreign
  local dst="$1" rendered
  [ -e "$dst" ] || { echo "missing"; return 0; }
  rendered="$(mktemp)"
  render_template "$TEMPLATES/$(basename "$dst")" "$rendered"
  if ! grep -q "# oss-hooks:" "$dst" 2>/dev/null; then
    rm -f "$rendered"; echo "foreign"; return 0
  fi
  if cmp -s "$dst" "$rendered"; then rm -f "$rendered"; echo "ours-same"; else rm -f "$rendered"; echo "ours-stale"; fi
}

install_hook() { # $1=dst
  local dst="$1" name state
  name="$(basename "$dst")"
  state="$(hook_state "$dst")"
  case "$state" in
    ours-same)
      ok "hook em vigor: $dst" ;;
    missing)
      mkdir -p "$(dirname "$dst")"
      render_template "$TEMPLATES/$name" "$dst"
      chmod +x "$dst"
      ok "hook CRIADO: $dst"
      CRIADOS=$((CRIADOS+1)) ;;
    ours-stale)
      render_template "$TEMPLATES/$name" "$dst"
      chmod +x "$dst"
      ok "hook ATUALIZADO (política nova): $dst"
      ATUALIZADOS=$((ATUALIZADOS+1)) ;;
    foreign)
      if [ "$FORCE" -eq 1 ]; then
        render_template "$TEMPLATES/$name" "$dst"
        chmod +x "$dst"
        warn "hook alheio SOBRESCRITO por --force: $dst"
        ATUALIZADOS=$((ATUALIZADOS+1))
      else
        warn "hook alheio preservado (não é nosso): $dst"
        info "Solução: encadeie manualmente: bash $SKILL_DIR/scripts/oss-hooks.sh install --force --only $name (se quiser a política aqui)"
      fi ;;
  esac
}

check_hook() { # $1=dst
  local dst="$1" name state hint=""
  name="$(basename "$dst")"
  [ "$GLOBAL" -eq 1 ] && hint=" --global"
  state="$(hook_state "$dst")"
  case "$state" in
    ours-same)  ok "hook em vigor: $dst" ;;
    missing)    bad "hook em falta: $dst — Solução: bash $SKILL_DIR/scripts/oss-hooks.sh install$hint" ;;
    ours-stale) bad "hook DESATUALIZADO (política mudou): $dst — Solução: bash $SKILL_DIR/scripts/oss-hooks.sh install$hint" ;;
    foreign)    warn "hook alheio (fora da governança): $dst" ;;
  esac
}

uninstall_hook() { # $1=dst
  local dst="$1" state
  state="$(hook_state "$dst")"
  case "$state" in
    ours-same|ours-stale)
      rm -f "$dst"; ok "hook removido: $dst" ;;
    missing)
      info "já não existe: $dst" ;;
    foreign)
      warn "hook alheio preservado: $dst" ;;
  esac
}

# ---------------------------------------------------------------------------
# Modo projeto
# ---------------------------------------------------------------------------
run_project() {
  local git_common hooks_dir
  git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "$TARGET não é repositório git" "corra git init no projeto-alvo" 4
  git_common="$(git -C "$TARGET" rev-parse --git-common-dir)"
  case "$git_common" in /*) ;; *) git_common="$TARGET/$git_common" ;; esac
  hooks_dir="$git_common/hooks"
  printf 'oss-hooks · %s (projeto: %s)\n' "$ACTION" "$TARGET"
  for h in $HOOKS; do
    "${ACTION}_hook" "$hooks_dir/$h"
  done
  # husky: o core.hooksPath do projeto aponta para .husky/ — instalar também lá
  if [ -f "$TARGET/package.json" ] && [ -d "$TARGET/.husky" ]; then
    for h in $HOOKS; do
      [ "$ACTION" = "install" ] && info "husky detetado — espelhando $h em .husky/"
      "${ACTION}_hook" "$TARGET/.husky/$h"
    done
  fi
}

# ---------------------------------------------------------------------------
# Modo global (QUALQUER projeto da máquina)
# ---------------------------------------------------------------------------
run_global() {
  printf 'oss-hooks · %s (GLOBAL: %s)\n' "$ACTION" "$GLOBAL_DIR"
  mkdir -p "$GLOBAL_DIR"
  case "$ACTION" in
    install)
      for h in $HOOKS; do
        install_hook "$GLOBAL_DIR/$h"
      done
      local prev
      prev="$(git config --global --get core.hooksPath 2>/dev/null || true)"
      if [ -n "$prev" ] && [ "$prev" != "$GLOBAL_DIR" ]; then
        printf '%s' "$prev" > "$GLOBAL_DIR/.previous-core.hooksPath"
        warn "core.hooksPath global já apontava para: $prev (guardado em .previous-core.hooksPath)"
      fi
      git config --global core.hooksPath "$GLOBAL_DIR"
      ok "core.hooksPath global → $GLOBAL_DIR (vale em QUALQUER projeto)"
      info "opt-out por repositório: git config oss.policy off · remover tudo: bash $SKILL_DIR/scripts/oss-hooks.sh uninstall --global" ;;
    check)
      for h in $HOOKS; do
        check_hook "$GLOBAL_DIR/$h"
      done
      local cur
      cur="$(git config --global --get core.hooksPath 2>/dev/null || true)"
      [ "$cur" = "$GLOBAL_DIR" ] && ok "core.hooksPath global aponta para os nossos hooks" \
        || bad "core.hooksPath global não aponta para $GLOBAL_DIR (está: ${cur:-<vazio>}) — Solução: oss-hooks.sh install --global" ;;
    uninstall)
      for h in $HOOKS; do
        uninstall_hook "$GLOBAL_DIR/$h"
      done
      local cur prev
      cur="$(git config --global --get core.hooksPath 2>/dev/null || true)"
      if [ "$cur" = "$GLOBAL_DIR" ]; then
        if [ -f "$GLOBAL_DIR/.previous-core.hooksPath" ]; then
          prev="$(cat "$GLOBAL_DIR/.previous-core.hooksPath")"
          git config --global core.hooksPath "$prev"
          ok "core.hooksPath global restaurado: $prev"
        else
          git config --global --unset core.hooksPath 2>/dev/null || true
          ok "core.hooksPath global removido (volta à predefinição .git/hooks)"
        fi
      fi ;;
  esac
}

if [ "$GLOBAL" -eq 1 ]; then run_global; else run_project; fi

echo
printf 'Resumo: %d ok · %d em falta · %d avisos · hooks: %d criados · %d atualizados\n' \
  "$PASS" "$FAIL" "$WARN" "$CRIADOS" "$ATUALIZADOS"
[ "$ACTION" = "check" ] && [ "$FAIL" -gt 0 ] && exit 1
exit 0
