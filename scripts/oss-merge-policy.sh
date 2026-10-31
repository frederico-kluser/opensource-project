#!/usr/bin/env bash
# oss-merge-policy.sh — impõe MERGE, nunca REBASE, no projeto-alvo.
#
# A skill trata rebase como erro de configuração: se o projeto tem pull.rebase,
# branch.*.rebase, allow_rebase_merge ou "rebase" em allowed_merge_methods, este
# script CORRIGE (modo apply) e regista a política em CLAUDE.md/AGENTS.md.
#
# Uso: bash scripts/oss-merge-policy.sh [apply|check] [opções]
#   apply        (predef.) deteta rebase e corrige — idempotente
#   check        só diagnostica; exit 1 se houver rebase
#   --target DIR projeto-alvo (predef.: .)
#   --local      não chama o GitHub (só git + ficheiros versionados)
#   --dry-run    mostra o plano sem escrever
#   --help
#
# O que garante:
#   1. git LOCAL   — pull.rebase=false e branch.*.rebase=false (merge por predefinição)
#   2. GitHub      — allow_rebase_merge=false; se o merge estava desligado,
#                    allow_merge_commit=true (merge em vez de rebase)
#   3. RULESETS    — remove "rebase" de allowed_merge_methods no JSON versionado
#   4. CONTRATOS   — injeta o bloco gerido "merge, nunca rebase" em CLAUDE.md e
#                    AGENTS.md (fonte única: assets/templates/merge-policy.md)
#
# Exit codes: 0 merge em vigor · 1 rebase em falta de correção · 2 uso inválido ·
#             3 ferramenta em falta · 4 não é repositório git
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="apply"; TARGET="."; LOCAL=0; DRY=0
OK=0; FIX=0; BAD=0; WARN=0; REBASE=0

ok()    { printf '  [OK]          %s\n' "$*"; OK=$((OK+1)); }
fixed() { printf '  [CONFIGURADO] %s\n' "$*"; FIX=$((FIX+1)); }
bad()   { printf '  [FALTA]       %s\n' "$*"; BAD=$((BAD+1)); }
warn()  { printf '  [AVISO]       %s\n' "$*"; WARN=$((WARN+1)); }
info()  { printf '  [INFO]        %s\n' "$*"; }
die()   { printf 'Erro: %s — Solução: %s\n' "$1" "$2" >&2; exit "${3:-1}"; }
need_val() { [ "$2" -ge 2 ] || die "falta o valor de $1" "uso: oss-merge-policy.sh [apply|check] [--target DIR] [--local] [--dry-run]" 2; }
is_false() { case "${1:-}" in false|False|FALSE|no|No|NO|off|Off|OFF|0) return 0 ;; *) return 1 ;; esac; }

while [ $# -gt 0 ]; do
  case "$1" in
    apply|check) MODE="$1"; shift ;;
    --target) need_val "$1" "$#"; TARGET="$2"; shift 2 ;;
    --local) LOCAL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "argumento desconhecido: $1" "uso: oss-merge-policy.sh [apply|check] [--target DIR] [--local] [--dry-run]" 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git não está instalado" "instale o git e repita" 3
command -v python3 >/dev/null 2>&1 || die "python3 não está instalado" "instale python3 e repita" 3
[ -d "$TARGET" ] || die "alvo inexistente: $TARGET" "crie a pasta ou corrija --target" 2
TARGET="$(cd "$TARGET" && pwd)"
git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "$TARGET não é repositório git" 'corra `git init` no projeto-alvo' 4

# --- GitHub owner/repo a partir do remoto origin (sem chamar a API) ---
OWNER=""; REPO=""
REMOTE_URL="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
case "$REMOTE_URL" in
  *github.com[:/]*)
    rest="${REMOTE_URL#*github.com[:/]}"; rest="${rest%.git}"
    OWNER="${rest%%/*}"; REPO="${rest#*/}"
    [ -n "$OWNER" ] && [ -n "$REPO" ] && [ "$OWNER" != "$REPO" ] || { OWNER=""; REPO=""; }
    ;;
esac

printf 'oss-merge-policy · merge, nunca rebase — %s (%s)\n' "$TARGET" "$MODE"
[ "$DRY" -eq 1 ] && printf '  MODO DRY-RUN: nada é escrito — só o plano\n'
[ "$MODE" = "check" ] && printf '  MODO CHECK: só diagnóstico — nada é escrito\n'

# ---------------------------------------------------------------------------
# 1. git local — pull.rebase / branch.*.rebase
# ---------------------------------------------------------------------------
PULL_VAL="$(git -C "$TARGET" config --get pull.rebase 2>/dev/null || true)"
PULL_REBASE=0
if [ -n "$PULL_VAL" ] && ! is_false "$PULL_VAL"; then PULL_REBASE=1; fi

if [ "$PULL_REBASE" -eq 1 ]; then
  REBASE=1
  if [ "$MODE" = "check" ]; then
    bad "git local: pull.rebase=$PULL_VAL — rebase é proibido (política: merge)"
    info "Solução: git config --local pull.rebase false"
  elif [ "$DRY" -eq 1 ]; then
    info "[CONFIGURARIA] git local: pull.rebase $PULL_VAL → false"
  elif git -C "$TARGET" config --local pull.rebase false 2>/dev/null; then
    fixed "git local: pull.rebase=false (merge por predefinição)"
  else
    bad "git local: não consegui escrever pull.rebase=false — Solução: git -C \"$TARGET\" config --local pull.rebase false"
  fi
else
  [ "$MODE" = "check" ] && ok "git local: pull.rebase é merge (${PULL_VAL:-predefinição})"
fi

BRANCH_REBASE=()
while IFS= read -r b; do
  [ -n "$b" ] || continue
  val="$(git -C "$TARGET" config --get "branch.$b.rebase" 2>/dev/null || true)"
  [ -n "$val" ] || continue
  is_false "$val" && continue
  BRANCH_REBASE+=("$b")
  REBASE=1
  if [ "$MODE" = "check" ]; then
    bad "git local: branch.$b.rebase=$val — rebase é proibido"
    info "Solução: git config --local branch.$b.rebase false"
  elif [ "$DRY" -eq 1 ]; then
    info "[CONFIGURARIA] git local: branch.$b.rebase $val → false"
  elif git -C "$TARGET" config --local "branch.$b.rebase" false 2>/dev/null; then
    fixed "git local: branch.$b.rebase=false"
  else
    bad "git local: não consegui escrever branch.$b.rebase=false — Solução: git -C \"$TARGET\" config --local branch.$b.rebase false"
  fi
done < <(git -C "$TARGET" for-each-ref refs/heads --format='%(refname:short)' 2>/dev/null)

# Qualquer rebase local detetado (pull ou branch) pede pull.rebase=false explícito:
# garante merge mesmo que um pull.rebase global volte a ser true no futuro.
if [ "${#BRANCH_REBASE[@]}" -gt 0 ] && [ "$PULL_REBASE" -eq 0 ]; then
  if [ "$MODE" = "check" ]; then
    info "pull.rebase não está false; por predefinição o git faz merge — confirme após corrigir as branches"
  elif [ "$DRY" -eq 1 ]; then
    info "[CONFIGURARIA] git local: pull.rebase=false (defesa contra um pull.rebase global)"
  elif git -C "$TARGET" config --local pull.rebase false 2>/dev/null; then
    fixed "git local: pull.rebase=false (defesa contra um pull.rebase global)"
  else
    bad "git local: não consegui escrever pull.rebase=false — Solução: git -C \"$TARGET\" config --local pull.rebase false"
  fi
fi

# ---------------------------------------------------------------------------
# 2. GitHub — allow_rebase_merge (e allow_merge_commit quando o merge está desligado)
# ---------------------------------------------------------------------------
GH_REBASE=""; GH_MERGE=""; GH_SQUASH=""
if [ "$LOCAL" -eq 1 ]; then
  info "GitHub: omitido (--local)"
elif [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  info "GitHub: sem remoto GitHub — verificação omitida"
elif ! command -v gh >/dev/null 2>&1; then
  warn "GitHub: gh CLI em falta — allow_rebase_merge não verificado (instale https://cli.github.com)"
elif ! gh auth status >/dev/null 2>&1; then
  warn "GitHub: gh sem autenticação — allow_rebase_merge não verificado (gh auth login)"
else
  GH_REBASE="$(gh api "repos/$OWNER/$REPO" --jq '.allow_rebase_merge // false' 2>/dev/null)" || GH_REBASE=""
  GH_MERGE="$(gh api "repos/$OWNER/$REPO" --jq '.allow_merge_commit // false' 2>/dev/null)" || GH_MERGE=""
  GH_SQUASH="$(gh api "repos/$OWNER/$REPO" --jq '.allow_squash_merge // false' 2>/dev/null)" || GH_SQUASH=""
  if [ -z "$GH_REBASE" ]; then
    bad "GitHub: não consegui ler allow_rebase_merge de $OWNER/$REPO (token sem administração?)"
    info "Solução: gh auth refresh -s administration:write (ou corra com --local para saltar o GitHub)"
  elif [ "$GH_REBASE" = "true" ]; then
    REBASE=1
    if [ "$MODE" = "check" ]; then
      bad "GitHub: allow_rebase_merge=true — rebase merge ligado em $OWNER/$REPO"
      info "Solução: gh api --method PATCH repos/$OWNER/$REPO -F allow_rebase_merge=false -F allow_merge_commit=true"
    elif [ "$DRY" -eq 1 ]; then
      info "[CONFIGURARIA] GitHub: allow_rebase_merge=false e allow_merge_commit=true"
    else
      patch_args=(-F allow_rebase_merge=false)
      [ "$GH_MERGE" != "true" ] && patch_args+=(-F allow_merge_commit=true)
      if gh api --method PATCH "repos/$OWNER/$REPO" "${patch_args[@]}" >/dev/null 2>&1; then
        if [ "$GH_MERGE" = "true" ]; then
          fixed "GitHub: rebase merge DESLIGADO (allow_rebase_merge=false; merge commits mantidos)"
        else
          fixed "GitHub: rebase merge DESLIGADO e merge commits ATIVADOS (allow_merge_commit=true)"
        fi
      else
        bad "GitHub: falha ao desativar o rebase merge — Solução: gh api --method PATCH repos/$OWNER/$REPO -F allow_rebase_merge=false (precisa de admin)"
      fi
    fi
  else
    [ "$MODE" = "check" ] && ok "GitHub: rebase merge desligado (allow_rebase_merge=false)"
    if [ "$GH_MERGE" != "true" ] && [ "$GH_SQUASH" != "true" ]; then
      warn "GitHub: nenhum método de merge ativo — ative merge commits ou squash"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 3. Rulesets versionados — remover "rebase" de allowed_merge_methods
# ---------------------------------------------------------------------------
RULESET_FILES=0
for f in "$TARGET"/.github/rulesets/*.json; do
  [ -e "$f" ] || continue
  RULESET_FILES=$((RULESET_FILES+1))
  out="$(python3 - "$f" "$DRY" "$MODE" <<'PY'
import json, re, sys

path, dry, mode = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
text = open(path, encoding="utf-8").read()
pattern = re.compile(r'("allowed_merge_methods"\s*:\s*\[)(.*?)(\])', re.S)
found = False


def remove_rebase(match):
    global found
    inner = match.group(2)
    if '"rebase"' not in inner:
        return match.group(0)
    found = True
    # remove "rebase" e a vírgula que a acompanha, sem reformatar o JSON
    inner = re.sub(r'\s*"rebase"\s*,\s*', '', inner, count=1)
    while '"rebase"' in inner:
        if re.search(r',\s*"rebase"\s*', inner):
            inner = re.sub(r',\s*"rebase"\s*', '', inner, count=1)
        else:
            inner = inner.replace('"rebase"', '"squash"', 1)
    return match.group(1) + inner + match.group(3)


new_text = pattern.sub(remove_rebase, text)
if not found:
    print("NONE")
    sys.exit(0)
try:
    json.loads(new_text)
except Exception as exc:  # noqa: BLE001
    print("ERROR " + str(exc))
    sys.exit(0)
if mode == "check":
    print("FOUND")
elif dry:
    print("WOULD")
else:
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(new_text)
    print("CHANGED")
PY
)" || { bad "ruleset $(basename "$f"): JSON inválido — Solução: corrija o ficheiro antes de aplicar a política"; continue; }
  case "$out" in
    CHANGED) REBASE=1; fixed "ruleset $(basename "$f"): removido \"rebase\" de allowed_merge_methods" ;;
    WOULD)   REBASE=1; info "[CONFIGURARIA] ruleset $(basename "$f"): remover \"rebase\" de allowed_merge_methods" ;;
    FOUND)   REBASE=1; bad "ruleset $(basename "$f"): allowed_merge_methods permite rebase"; info "Solução: bash $SKILL_DIR/scripts/oss-merge-policy.sh apply --target \"$TARGET\"" ;;
    NONE)    : ;;
    ERROR*)  bad "ruleset $(basename "$f"): a remoção de rebase quebraria o JSON (${out#ERROR })" ;;
    *)       bad "ruleset $(basename "$f"): $out" ;;
  esac
done
if [ "$RULESET_FILES" -eq 0 ]; then
  info "rulesets: sem .github/rulesets/*.json — nada a verificar"
elif [ "$MODE" = "apply" ] && [ "$REBASE" -eq 0 ]; then
  ok "rulesets versionados: allowed_merge_methods sem rebase"
fi

# ---------------------------------------------------------------------------
# 4. Contratos — CLAUDE.md e AGENTS.md declaram a política (só se rebase detetado)
# ---------------------------------------------------------------------------
if [ "$REBASE" -eq 1 ]; then
  SNIPPET="$SKILL_DIR/assets/templates/merge-policy.md"
  if [ ! -e "$SNIPPET" ]; then
    bad "assets/templates/merge-policy.md em falta — Solução: reinstale a skill opensource-project"
  else
    for f in "$TARGET/CLAUDE.md" "$TARGET/AGENTS.md"; do
      [ -e "$f" ] || { info "$(basename "$f") ausente — oss-scaffold.sh cria-o com a política"; continue; }
      out="$(python3 - "$f" "$SNIPPET" "$SKILL_DIR" "$DRY" "$MODE" <<'PY'
import re, sys

path, snippet_path, skill_dir, dry, mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5]
raw = open(path, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
text = raw.replace("\r\n", "\n")
snippet = open(snippet_path, encoding="utf-8").read().replace("{{SKILL_ROOT}}", skill_dir).strip("\n")
begin = "<!-- oss:merge-policy:begin -->"
end = "<!-- oss:merge-policy:end -->"

if begin in text and end in text:
    match = re.search(re.escape(begin) + r".*?" + re.escape(end), text, re.S)
    if match and match.group(0).strip() == snippet.strip():
        print("OK")
        sys.exit(0)
    if not match:
        print("ERROR marcadores desequilibrados")
        sys.exit(0)
    new = text[:match.start()] + snippet + text[match.end():]
else:
    anchor = "## Regras obrigatórias em TODO o desenvolvimento"
    if anchor not in text:
        anchor = "## Regra de reentry"
    if anchor in text:
        new = text.replace(anchor, snippet + "\n\n" + anchor, 1)
    else:
        new = text.rstrip("\n") + "\n\n" + snippet + "\n"

if mode == "check":
    print("FOUND")
elif dry:
    print("WOULD")
else:
    if crlf:
        new = new.replace("\n", "\r\n")
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(new)
    print("CHANGED")
PY
)" || { bad "$(basename "$f"): falha ao atualizar o contrato — Solução: verifique permissões de escrita"; continue; }
      case "$out" in
        OK)      [ "$MODE" = "check" ] && ok "$(basename "$f"): política 'merge, nunca rebase' já registada" ;;
        CHANGED) fixed "$(basename "$f"): política 'merge, nunca rebase' registada" ;;
        WOULD)   info "[CONFIGURARIA] $(basename "$f"): registar a política 'merge, nunca rebase'" ;;
        FOUND)   bad "$(basename "$f"): sem a política 'merge, nunca rebase'"; info "Solução: bash $SKILL_DIR/scripts/oss-merge-policy.sh apply --target \"$TARGET\"" ;;
        ERROR*)  bad "$(basename "$f"): ${out#ERROR }" ;;
        *)       bad "$(basename "$f"): $out" ;;
      esac
    done
  fi
fi

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
if [ "$REBASE" -eq 0 ] && [ "$BAD" -eq 0 ]; then
  ok "sem rebase configurado — política de merge em vigor"
fi
printf '  política de merge: %d ok · %d configurados · %d em falta · %d avisos\n' "$OK" "$FIX" "$BAD" "$WARN"
if [ "$BAD" -gt 0 ]; then
  exit 1
fi
exit 0
