#!/usr/bin/env bash
# oss-doctor.sh — diagnóstico READ-ONLY da governança open-source de um repositório.
# Corre sempre antes da primeira ação de governança numa sessão (Gate 0/6).
#
# Uso: bash scripts/oss-doctor.sh [--local] [--help]
#   --local   não consulta o GitHub (sem gh api) — só estado local
#
# Exit codes: 0 sem FAIL · 1 há FAIL (governança em falta) · 4 não é repo git
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { printf '  [OK]     %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  [FALTA]  %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  [AVISO]  %s\n' "$*"; WARN=$((WARN+1)); }
info() { printf '  [INFO]   %s\n' "$*"; }
head_() { printf '\n== %s ==\n' "$*"; }

LOCAL_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_ONLY=1 ;;
    --help|-h) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Erro: argumento desconhecido: %s — Solução: use --local ou --help\n' "$arg" >&2; exit 2 ;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  printf 'Erro: não está dentro de um repositório git — Solução: corra na pasta do projeto\n' >&2
  exit 4
}

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 4

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/oss-branch-policy.sh
source "$SKILL_DIR/scripts/oss-branch-policy.sh" 2>/dev/null || true

has() { [ -e "$1" ]; }

check_file() { # $1=caminho $2=etiqueta $3=severidade (fail|warn)
  if has "$1"; then
    ok "$2 — $1"
  elif [ "${3:-fail}" = "warn" ]; then
    warn "$2 em falta — $1"
  else
    bad "$2 em falta — $1"
  fi
}

printf 'oss-doctor · governança de %s\n' "$ROOT"

head_ "Ferramentas"
for cmd in git python3; do
  command -v "$cmd" >/dev/null 2>&1 && ok "$cmd instalado" || bad "$cmd em falta"
done
if command -v gh >/dev/null 2>&1; then
  ok "gh CLI instalado ($(gh --version 2>/dev/null | head -1 | sed 's/.*version //;s/ (.*//'))"
else
  warn "gh CLI em falta — rulesets, PRs e releases exigem-no (instale: https://cli.github.com)"
fi

head_ "Fundação legal e documentação (Gate 0)"
LICENSE_FOUND=""
for cand in LICENSE LICENSE.md LICENSE.txt COPYING; do
  if has "$cand"; then LICENSE_FOUND="$cand"; break; fi
done
if [ -n "$LICENSE_FOUND" ]; then
  kind="desconhecida"
  grep -qim1 'MIT License\|Permission is hereby granted, free of charge' "$LICENSE_FOUND" && kind="MIT"
  grep -qim1 'Apache License' "$LICENSE_FOUND" && kind="Apache-2.0"
  grep -qim1 'GNU GENERAL PUBLIC LICENSE' "$LICENSE_FOUND" && kind="GPL"
  grep -qim1 'Mozilla Public License' "$LICENSE_FOUND" && kind="MPL-2.0"
  ok "LICENSE — $LICENSE_FOUND ($kind)"
else
  bad "LICENSE em falta — sem licença OSI não há projeto open-source (oss-scaffold.sh --license mit)"
fi
check_file README.md "README"
check_file CONTRIBUTING.md "CONTRIBUTING"
check_file SECURITY.md "SECURITY"
check_file CHANGELOG.md "CHANGELOG"
check_file CODE_OF_CONDUCT.md "Código de conduta" warn
if has CODEOWNERS || has .github/CODEOWNERS || has docs/CODEOWNERS; then
  ok "CODEOWNERS presente"
else
  bad "CODEOWNERS em falta — sem ele não há revisão obrigatória dos responsáveis"
fi
check_file .github/PULL_REQUEST_TEMPLATE.md "Template de PR" warn
if has .github/ISSUE_TEMPLATE; then ok "templates de issues"; else warn "templates de issues em falta (.github/ISSUE_TEMPLATE)"; fi

head_ "Regras locais — hooks git (Gate 1/2)"
HOOKS_DIR="$(git rev-parse --git-common-dir 2>/dev/null)/hooks"
for h in pre-push commit-msg; do
  f="$HOOKS_DIR/$h"
  if [ -x "$f" ]; then
    if grep -q "# oss-hooks:" "$f" 2>/dev/null; then ok "hook $h instalado (nomes de branch · ramos protegidos · commits)"
    else warn "hook $h alheio (fora da governança): $f — a política local não corre aqui"; fi
  elif [ -x ".husky/$h" ]; then
    ok "hook $h instalado (.husky — husky)"
  else
    bad "hook $h em falta — sem ele a regra local não corre nesta máquina — Solução: bash $SKILL_DIR/scripts/oss-hooks.sh install"
  fi
done
if has commitlint.config.js || has commitlint.config.cjs || has .commitlintrc.json; then
  ok "commitlint configurado"
else
  warn "commitlint em falta (em repos Node); alternativa: oss-gate.sh commit-msg no hook"
fi

head_ "Convenção de nomes de ramificação (Gate 2)"
if type oss_branch_ok >/dev/null 2>&1; then
  TOTAL_B=0; VIOL_B=0
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    TOTAL_B=$((TOTAL_B+1))
    if oss_branch_ok "$b"; then :; else
      bad "branch FORA da convenção: $b — o GitHub rejeita updates nesta ref (ruleset de nomes)"
      info "Solução: git branch -m $b <tipo>/<slug> (ou git branch -d $b se já merged)"
      VIOL_B=$((VIOL_B+1))
    fi
  done < <(git for-each-ref refs/heads --format='%(refname:short)' 2>/dev/null)
  [ "$VIOL_B" -eq 0 ] && ok "$TOTAL_B branch(es) locais seguem <tipo>/<slug>"
else
  warn "oss-branch-policy.sh em falta — verificação de nomes omitida (reinstale a skill)"
fi

head_ "Governança como código (rulesets versionados)"
for f in regras-main.json regras-release.json regras-tags.json regras-nomes-de-branch.json regras-commits.json; do
  check_file ".github/rulesets/$f" "Ruleset $f"
done
info "ficheiros em falta são criados por oss-scaffold.sh e aplicados no GitHub por oss-enforce.sh"

head_ "CI e segurança dos workflows (Gate 6)"
WF_COUNT=0; UNPINNED=0; NOPERM=0
if has .github/workflows; then
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    WF_COUNT=$((WF_COUNT+1))
    grep -qE '^permissions:' "$wf" || { NOPERM=$((NOPERM+1)); warn "$wf sem block `permissions:` (menor privilégio)"; }
    unpinned="$(grep -nE 'uses:[[:space:]]*[^ #]+@' "$wf" | grep -vE '@[0-9a-f]{40}([[:space:]]|#)' | grep -vE '@\{\{|uses:[[:space:]]*\./' || true)"
    if [ -n "$unpinned" ]; then
      n="$(printf '%s' "$unpinned" | wc -l)"
      UNPINNED=$((UNPINNED+n))
    fi
  done
  [ "$WF_COUNT" -gt 0 ] && ok "$WF_COUNT workflow(s) em .github/workflows" || warn ".github/workflows vazio"
  [ "$UNPINNED" -eq 0 ] && ok "todas as actions fixadas por SHA (pinned dependencies)" \
    || bad "$UNPINNED referência(s) de action por tag móvel — corra: bash scripts/oss-pin-actions.sh"
  [ "$NOPERM" -eq 0 ] && [ "$WF_COUNT" -gt 0 ] && ok "todos os workflows declaram permissions:" || true
else
  warn "sem .github/workflows — sem CI não há status checks nem releases automatizadas"
fi
grep -rq 'pull_request_target' .github/workflows 2>/dev/null \
  && warn "workflow usa pull_request_target — verifique que NÃO executa código do PR (Dangerous Workflow)" \
  || true

head_ "Identidade e telemetria"
grep -q 'img.shields.io\|badgen.net\|badge.svg' README.md 2>/dev/null \
  && ok "badges de telemetria no README" || warn "README sem badges (build, licença, versão, OpenSSF)"

head_ "Telemetria (badges)"
if [ "$LOCAL_ONLY" -eq 1 ]; then
  info "modo --local: verificação HTTP dos badges omitida"
elif ! command -v curl >/dev/null 2>&1; then
  info "curl indisponível: verificação HTTP dos badges omitida"
else
  mapfile -t BADGES < <(grep -oE 'https://[^)"<> ]+' README.md 2>/dev/null \
    | grep -E 'badge\.svg|img\.shields\.io|shields\.io/|api\.securityscorecards\.dev' | sort -u)
  if [ "${#BADGES[@]}" -eq 0 ]; then
    warn "sem URLs de badge no README — sem telemetria pública"
  else
    for u in "${BADGES[@]}"; do
      code_type="$(curl -s -o /dev/null -w '%{http_code} %{content_type}' -L --max-time 15 "$u" 2>/dev/null)"
      code="${code_type%% *}"
      if [ "$code" = "200" ] && printf '%s' "$code_type" | grep -q 'image/'; then
        ok "badge responde 200 (${code_type#* }) — $u"
        # 200 não quer dizer badge bom: o shields devolve 200 com conteúdo de erro
        rotulo="$(curl -sL --max-time 15 "$u" 2>/dev/null \
          | grep -oE 'aria-label="[^"]*"|<title>[^<]*</title>' | head -1)"
        if printf '%s' "$rotulo" | grep -qiE 'not found|no releases|invalid|inaccessible|unknown|no status'; then
          warn "badge com estado de erro visível: ${rotulo} — $u"
          info "Causas típicas: sem release ainda, repo privado, workflow sem runs ou alvo errado"
          info "(references/identidade-e-telemetria.md — 'Quando os badges não aparecem')"
        fi
      else
        bad "badge quebrado (HTTP ${code:-000}) — $u"
        info "Solução: corrija ou remova o badge (um badge quebrado é pior que nenhum)"
      fi
      if printf '%s' "$u" | grep -q 'securityscorecards.dev'; then
        score="$(curl -sL --max-time 15 "$u" 2>/dev/null \
          | sed -n 's/.*<title>[^:]*: \([0-9][0-9.]*\)<\/title>.*/\1/p' | head -1)"
        if [ -n "$score" ]; then
          if awk -v s="$score" 'BEGIN{exit !(s+0>=7)}'; then
            ok "OpenSSF Scorecard $score ≥ 7 (limiar de graduação do Gate 6)"
          else
            warn "OpenSSF Scorecard $score < 7 — abaixo do limiar (references/seguranca-openssf.md)"
          fi
        fi
      fi
    done
  fi
fi

head_ "Estado remoto (GitHub)"
if [ "$LOCAL_ONLY" -eq 1 ]; then
  info "modo --local: consultas ao GitHub omitidas"
elif ! command -v gh >/dev/null 2>&1; then
  info "gh não instalado: consultas remotas omitidas"
elif ! git remote get-url origin >/dev/null 2>&1; then
  info "sem remoto origin: repositório local apenas (push a main tolerado só até haver remoto)"
else
  if gh auth status >/dev/null 2>&1; then
    ok "gh autenticado (token não é exibido por design)"
  else
    bad "gh sem autenticação — Solução: gh auth login"
  fi
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || REPO=""
  if [ -n "$REPO" ]; then
    ok "repositório remoto: $REPO (ramificação predefinida: $(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null))"
    RULES="$(gh api "repos/$REPO/rulesets?per_page=100" --jq '[.[].name] | join("\n")' 2>/dev/null)" || RULES=""
    if [ -z "$RULES" ]; then
      warn "sem consulta de rulesets (token sem escopo administration ou sem rulesets)"
    else
      MISSING_RS=0
      for n in "Governança Principal Restrita" "Ramos de Release Protegidos" "Tags de Release Imutáveis" \
               "Convenção de Nomes de Ramificação"; do
        if printf '%s\n' "$RULES" | grep -Fxq "$n"; then
          ok "ruleset ativo: $n"
        else
          bad "ruleset EM FALTA no GitHub: $n"
          MISSING_RS=$((MISSING_RS+1))
        fi
      done
      if printf '%s\n' "$RULES" | grep -Fxq "Convenção de Mensagens de Commit"; then
        ok "ruleset ativo: Convenção de Mensagens de Commit (metadata — Enterprise)"
      else
        warn "sem ruleset \"Convenção de Mensagens de Commit\" — regras de metadata são GitHub Enterprise; o equivalente portátil (hook commit-msg + status check 'build') cobre a convenção"
      fi
      [ "$MISSING_RS" -gt 0 ] && info "Solução: bash $SKILL_DIR/scripts/oss-enforce.sh — cria e reconcilia os rulesets automaticamente"
    fi
    VIOL_R=0
    if type oss_branch_ok >/dev/null 2>&1; then
      while IFS= read -r b; do
        [ -z "$b" ] && continue
        oss_branch_ok "$b" && continue
        bad "branch remota FORA da convenção: $b — updates recusados pelo ruleset de nomes"
        info "Solução: renomeie (git push origin :$b $b:<tipo>/<slug>) ou apague se já merged"
        VIOL_R=$((VIOL_R+1))
      done < <(gh api "repos/$REPO/branches?per_page=100" --paginate --jq '.[].name' 2>/dev/null)
      [ "$VIOL_R" -eq 0 ] && ok "branches remotas seguem a convenção de nomes"
    fi
    PUSH_PROT="$(gh api "repos/$REPO/secret-scanning/push-protection" --jq '.enabled' 2>/dev/null)" || PUSH_PROT=""
    case "$PUSH_PROT" in
      true) ok "Secret Scanning Push Protection ativo" ;;
      false) warn "Push Protection desativado — ative: gh api -X PUT repos/$REPO/secret-scanning/push-protection -f enabled=true" ;;
      *) info "Push Protection indisponível neste plano/repositório" ;;
    esac
  else
    warn "não consegui identificar o repositório remoto via gh"
  fi
fi

head_ "Resumo"
printf '  %d ok · %d em falta · %d avisos\n' "$PASS" "$FAIL" "$WARN"
if [ "$FAIL" -gt 0 ]; then
  printf '  Governança INCOMPLETA — corra: bash %s/scripts/oss-enforce.sh (cria e reconcilia tudo o que falta) e repita o doctor.\n' "$SKILL_DIR"
  exit 1
fi
printf '  Governança operável. Continue com os gates por ação (oss-gate.sh).\n'
exit 0
