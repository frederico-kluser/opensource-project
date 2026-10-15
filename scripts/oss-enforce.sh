#!/usr/bin/env bash
# oss-enforce.sh — VERIFICA e APLICA toda a governança em falta (local + GitHub).
#
# REGRA DE REENTRY DA SKILL: este script corre SEMPRE que a skill é chamada num
# projeto — mesmo que o projeto já a tenha usado antes. Nada é assumido: audita o
# estado real e COLACA O QUE FALTAR. Idempotente e não-destrutivo (só acrescenta e
# reconcilia regras do GitHub com o mesmo nome; nunca apaga nem sobrescreve
# trabalho do projeto).
#
# Uso: bash scripts/oss-enforce.sh [opções]
#   --target DIR     projeto-alvo (predef.: .)
#   --owner OWNER    dono/org GitHub (predef.: detetado do remoto origin)
#   --repo NOME      repositório GitHub (predef.: detetado do remoto origin)
#   --local          só estado local (sem chamadas ao GitHub)
#   --dry-run        mostra o plano sem escrever nada
#   --help
#
# O que garante (por verificação, sempre):
#   1. Fundação local  — LICENSE, README, CONTRIBUTING, CODEOWNERS, SECURITY,
#      templates de issue/PR, CHANGELOG, contratos CLAUDE.md/AGENTS.md e hook
#      commit-msg (via oss-scaffold.sh: cria o que falta, nunca sobrescreve).
#   2. Rulesets GitHub — os 5 rulesets da governança. AUSENTES → criados (POST);
#      DIVERGENTES do JSON versionado no projeto → reconciliados (PUT):
#        · "Governança Principal Restrita"      — sem commit direto em main/develop/
#          release: PR obrigatório, squash-only, sem force-push, sem delete,
#          histórico linear, status checks strict;
#        · "Ramos de Release Protegidos"         — release/** sem reescrita;
#        · "Tags de Release Imutáveis"           — v* intocáveis;
#        · "Convenção de Nomes de Ramificação"   — branch fora de <tipo>/<slug> é
#          REJEITADA pelo GitHub (não só pelo agente);
#        · "Convenção de Mensagens de Commit"    — Conventional Commits imposto
#          também no servidor, para commits que entram em ramos protegidos.
#   3. Push Protection — ativa a proteção de segredos se estiver desligada.
#   4. Auditoria de nomes — lista branches existentes fora da convenção (a regra
#      nova impede atualizá-las; renomear ou apagar é a cura).
#
# Exit codes: 0 tudo em vigor · 1 há lacunas por aplicar · 2 uso inválido ·
#             3 ferramenta em falta · 4 não é repositório git
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/oss-branch-policy.sh
source "$SKILL_DIR/scripts/oss-branch-policy.sh" 2>/dev/null || {
  printf 'Erro: oss-branch-policy.sh em falta em %s/scripts — Solução: reinstale a skill opensource-project\n' "$SKILL_DIR" >&2
  exit 3
}

PASS=0; FAIL=0; WARN=0; CRIADOS=0; ATUALIZADOS=0
ok()   { printf '  [OK]       %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  [FALTA]    %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  [AVISO]    %s\n' "$*"; WARN=$((WARN+1)); }
info() { printf '  [INFO]     %s\n' "$*"; }
head_() { printf '\n== %s ==\n' "$*"; }
die()  { printf 'Erro: %s — Solução: %s\n' "$1" "$2" >&2; exit "${3:-1}"; }
need_val() { [ "$2" -ge 2 ] || die "falta o valor de $1" "uso: oss-enforce.sh --help" 2; }

TARGET="."; OWNER=""; REPO=""; LOCAL=0; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) need_val "$1" "$#"; TARGET="$2"; shift 2 ;;
    --owner)  need_val "$1" "$#"; OWNER="$2"; shift 2 ;;
    --repo)   need_val "$1" "$#"; REPO="$2"; shift 2 ;;
    --local)  LOCAL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) sed -n '2,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "argumento desconhecido: $1" "uso: oss-enforce.sh [--target DIR] [--owner O] [--repo R] [--local] [--dry-run]" 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git não está instalado" "instale o git e repita" 3
command -v python3 >/dev/null 2>&1 || die "python3 não está instalado" "instale python3 e repita" 3
[ -d "$TARGET" ] || die "alvo inexistente: $TARGET" "crie a pasta ou corrija --target" 2
TARGET="$(cd "$TARGET" && pwd)"
git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "$TARGET não é repositório git" 'corra `git init` no projeto-alvo' 4

# --- deteção de owner/repo a partir do remoto origin (ou gh) ---
detect_repo() {
  local url o r
  url="$(git -C "$TARGET" remote get-url origin 2>/dev/null)" || return 1
  case "$url" in
    *github.com[:/]*)
      o="${url#*github.com[:/]}"; o="${o%.git}"
      r="${o#*/}"; o="${o%%/*}"
      [ -n "$o" ] && [ -n "$r" ] && [ "$o" != "$r" ] || return 1
      OWNER="$o"; REPO="$r" ;;
    *) return 1 ;;
  esac
}
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  detect_repo || true
fi
if { [ -z "$OWNER" ] || [ -z "$REPO" ]; } && [ "$LOCAL" -eq 0 ] && command -v gh >/dev/null 2>&1; then
  wtr="$(gh repo view --repo "$(git -C "$TARGET" remote get-url origin 2>/dev/null)" --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || wtr=""
  if [ -n "$wtr" ]; then OWNER="${wtr%%/*}"; REPO="${wtr#*/}"; fi
fi

printf 'oss-enforce · verificação e aplicação idempotente da governança em %s\n' "$TARGET"
[ -n "$OWNER" ] && printf '  repositório alvo: %s/%s\n' "$OWNER" "$REPO" || printf '  repositório remoto: não detetado (modo local)\n'
[ "$DRY" -eq 1 ] && printf '  MODO DRY-RUN: nada é escrito — só o plano\n'
printf '  regra de reentry: mesmo que este projeto já use a skill, TUDO é reverificado\n'

# ---------------------------------------------------------------------------
# 1. Fundação local — cria o que falta (oss-scaffold nunca sobrescreve)
# ---------------------------------------------------------------------------
head_ "1 · Fundação local (criar o que falta, preservar o que existe)"
SCAFFOLD_ARGS=(--target "$TARGET" --install-hook)
[ -n "$OWNER" ] && SCAFFOLD_ARGS+=(--owner "$OWNER")
[ -n "$REPO" ] && SCAFFOLD_ARGS+=(--repo "$REPO")
[ "$DRY" -eq 1 ] && SCAFFOLD_ARGS+=(--dry-run)
if bash "$SKILL_DIR/scripts/oss-scaffold.sh" "${SCAFFOLD_ARGS[@]}"; then
  ok "fundação verificada (ficheiros em falta criados; existentes preservados)"
else
  bad "oss-scaffold.sh falhou — Solução: corra bash $SKILL_DIR/scripts/oss-scaffold.sh --target $TARGET e leia o erro"
fi

# ---------------------------------------------------------------------------
# 2. Rulesets GitHub — criar ausentes, reconciliar divergentes
# ---------------------------------------------------------------------------
RULESETS_PROJ="$TARGET/.github/rulesets"
RULESETS_ASSETS="$SKILL_DIR/assets/rulesets"

ruleset_semantic_diff() { # $1=estado atual (GET) $2=desejado (JSON) — 0 se iguais
  python3 - "$1" "$2" <<'PY'
import json, sys
keys = ["name", "target", "enforcement", "conditions", "rules", "bypass_actors"]
def norm(path):
    d = json.load(open(path, encoding="utf-8"))
    out = {}
    for k in keys:
        v = d.get(k)
        if k == "rules" and isinstance(v, list):
            v = sorted(v, key=lambda r: (r.get("type", ""), json.dumps(r.get("parameters", {}), sort_keys=True)))
        if k == "bypass_actors" and isinstance(v, list):
            v = sorted(v, key=lambda r: json.dumps(r, sort_keys=True))
        if k == "conditions" and isinstance(v, dict):
            rn = v.get("ref_name", {})
            v = {"ref_name": {ik: sorted(rn.get(ik, [])) for ik in ("include", "exclude")}}
        out[k] = v
    return out
sys.exit(0 if norm(sys.argv[1]) == norm(sys.argv[2]) else 1)
PY
}

apply_rulesets() {
  head_ "2 · Rulesets do GitHub (nome de branch · commits diretos · tags)"
  local list_json f src name rid cur
  if [ "$LOCAL" -eq 1 ]; then
    info "modo --local: aplicação de rulesets omitida"; return 0
  fi
  if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    bad "sem remoto GitHub: rulesets não aplicados — Solução: git remote add origin git@github.com:OWNER/REPO.git (ou corra com --owner/--repo)"
    return 0
  fi
  command -v gh >/dev/null 2>&1 || { bad "gh CLI em falta — Solução: instale https://cli.github.com (rulesets exigem-no)"; return 0; }
  gh auth status >/dev/null 2>&1 || { bad "gh sem autenticação — Solução: gh auth login"; return 0; }

  list_json="$(gh api "repos/$OWNER/$REPO/rulesets?per_page=100" 2>/dev/null)" || list_json=""
  [ -n "$list_json" ] || { bad "não consigo ler os rulesets de $OWNER/$REPO — Solução: confirme que o token tem permissão de administração do repositório"; return 0; }

  # união dos JSON de governança: assets (obrigatórios) + cópias do projeto (personalizadas)
  local files=() seen=" " bn
  for f in "$RULESETS_ASSETS"/*.json; do
    [ -e "$f" ] || continue
    bn="$(basename "$f")"; files+=("$bn"); seen="$seen$bn "
  done
  for f in "$RULESETS_PROJ"/*.json; do
    [ -e "$f" ] || continue
    bn="$(basename "$f")"
    case "$seen" in *" $bn "*) ;; *) files+=("$bn"); seen="$seen$bn " ;; esac
  done
  [ "${#files[@]}" -gt 0 ] || { bad "nenhum ruleset JSON em $RULESETS_ASSETS nem em $RULESETS_PROJ"; return 0; }

  for f in "${files[@]}"; do
    src="$RULESETS_PROJ/$f"
    [ -e "$src" ] || src="$RULESETS_ASSETS/$f"   # cópia do projeto é a verdade; asset cobre o que falta
    name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["name"])' "$src" 2>/dev/null)" || name=""
    [ -n "$name" ] || { bad "$f sem campo \"name\" — ruleset sem identidade não é verificável"; continue; }
    rid="$(printf '%s' "$list_json" | python3 -c '
import json, sys
name = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    data = []
for r in data:
    if r.get("name") == name:
        print(r["id"]); break' "$name")"
    if [ -z "$rid" ]; then
      if [ "$DRY" -eq 1 ]; then
        info "[CRIARIA]     ruleset \"$name\" ($f)"
        CRIADOS=$((CRIADOS+1))
      elif gh api --method POST "repos/$OWNER/$REPO/rulesets" --input "$src" >/dev/null 2>&1; then
        ok "ruleset CRIADO: \"$name\" ($f)"
        CRIADOS=$((CRIADOS+1))
      else
        bad "falha ao criar o ruleset \"$name\" — Solução: gh api --method POST repos/$OWNER/$REPO/rulesets --input $src (precisa de admin no repo)"
      fi
    else
      cur="$(mktemp)"
      if ! gh api "repos/$OWNER/$REPO/rulesets/$rid" > "$cur" 2>/dev/null; then
        rm -f "$cur"; bad "não consigo ler o ruleset \"$name\" (id $rid) — Solução: verifique permissões de administração"; continue
      fi
      if ruleset_semantic_diff "$cur" "$src"; then
        ok "ruleset em vigor: \"$name\" (id $rid)"
      else
        if [ "$DRY" -eq 1 ]; then
          info "[ATUALIZARIA] ruleset \"$name\" (id $rid) diverge de $f"
          ATUALIZADOS=$((ATUALIZADOS+1))
        elif gh api --method PUT "repos/$OWNER/$REPO/rulesets/$rid" --input "$src" >/dev/null 2>&1; then
          ok "ruleset RECONCILIADO: \"$name\" (id $rid) — agora igual a $f"
          ATUALIZADOS=$((ATUALIZADOS+1))
        else
          bad "falha ao reconciliar o ruleset \"$name\" — Solução: gh api --method PUT repos/$OWNER/$REPO/rulesets/$rid --input $src"
        fi
      fi
      rm -f "$cur"
    fi
  done
  info "política de nomes: $(printf '%s' "$BRANCH_REGEX" | cut -c1-72)…"
  info "ramos protegidos (sem commit direto): main, master, develop, release/** e o ramo predefinido"
}

# ---------------------------------------------------------------------------
# 3. Push Protection — ativar se estiver desligada
# ---------------------------------------------------------------------------
enable_push_protection() {
  head_ "3 · Secret Scanning Push Protection"
  if [ "$LOCAL" -eq 1 ]; then
    info "modo --local: verificação omitida"; return 0
  fi
  [ -n "$OWNER" ] && [ -n "$REPO" ] || { info "sem remoto GitHub: verificação omitida"; return 0; }
  command -v gh >/dev/null 2>&1 || { info "gh em falta: verificação omitida"; return 0; }
  local st
  st="$(gh api "repos/$OWNER/$REPO/secret-scanning/push-protection" --jq '.enabled' 2>/dev/null)" || st=""
  case "$st" in
    true) ok "Push Protection ativo" ;;
    false)
      if [ "$DRY" -eq 1 ]; then
        info "[ATIVARIA]    Push Protection (está desligado)"
      elif gh api --method PUT "repos/$OWNER/$REPO/secret-scanning/push-protection" -f enabled=true >/dev/null 2>&1; then
        ok "Push Protection ATIVADO (estava desligado)"
      else
        warn "não consegui ativar o Push Protection — ative na UI: Settings → Code security"
      fi ;;
    *) info "Push Protection indisponível neste plano/repositório" ;;
  esac
}

# ---------------------------------------------------------------------------
# 4. Auditoria de nomes de ramificação (regra nova impede atualizar os violadores)
# ---------------------------------------------------------------------------
audit_branch_names() {
  head_ "4 · Auditoria de nomes de ramificação"
  local b viol=0
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    if oss_branch_ok "$b"; then
      ok "branch local conforme: $b"
    else
      warn "branch local FORA da convenção: $b — o GitHub passa a recusar updates nela"
      info "Solução: git branch -m $b <tipo>/<slug> (ou apague se já foi merged): git branch -d $b"
      viol=$((viol+1))
    fi
  done < <(git -C "$TARGET" for-each-ref refs/heads --format='%(refname:short)' 2>/dev/null)
  if [ "$LOCAL" -eq 0 ] && [ -n "$OWNER" ] && [ -n "$REPO" ] && command -v gh >/dev/null 2>&1; then
    while IFS= read -r b; do
      [ -z "$b" ] && continue
      oss_branch_ok "$b" && continue
      warn "branch remota FORA da convenção: $b"
      info "Solução: git push origin :$b $b:<tipo>/<slug> (apaga+cria renomeada) ou delete se merged"
      viol=$((viol+1))
    done < <(gh api "repos/$OWNER/$REPO/branches?per_page=100" --paginate --jq '.[].name' 2>/dev/null)
  fi
  [ "$viol" -eq 0 ] && ok "todas as branches seguem <tipo>/<slug>"
}

apply_rulesets
enable_push_protection
audit_branch_names

head_ "Resumo"
printf '  %d ok · %d em falta · %d avisos · rulesets: %d criados · %d reconciliados\n' \
  "$PASS" "$FAIL" "$WARN" "$CRIADOS" "$ATUALIZADOS"
if [ "$FAIL" -gt 0 ]; then
  printf '  Governança INCOMPLETA — as lacunas acima ficaram por aplicar. Corrija-as e repita oss-enforce.sh.\n'
  exit 1
fi
printf '  Governança em vigor. Confirme com: bash %s/scripts/oss-doctor.sh\n' "$SKILL_DIR"
exit 0
