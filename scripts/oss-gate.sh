#!/usr/bin/env bash
# oss-gate.sh — Gates de governança open-source por ação de ciclo de vida.
# Nenhum pedido do utilizador ("push", "muda a versão", "publica") contorna um gate.
#
# Uso: bash scripts/oss-gate.sh <ação> [opções]
#   commit-msg <ficheiro|mensagem>   valida Commits Convencionais (para hook commit-msg)
#   push       [--branch B]          sem push a main, histórico convencional, sem segredos
#   pr         [--title T] [--base B] título convencional, ramificação efémera, base main
#   merge      [--title T]           squash merge: mensagem convencional, sem merge commits
#   release    [--version X.Y.Z]     SemVer coerente com os commits, changelog, tag livre
#   publish    [--version X.Y.Z]     tudo do release + manifesto coerente + confirmação --yes
#
# Exit codes: 0 PASS · 1 gate BLOQUEADO · 2 uso inválido · 3 ferramenta em falta · 4 não é repo git
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TYPES_REGEX='(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)'
HEADER_REGEX="^${TYPES_REGEX}(\([^)]*\))?!?: .+"
PASS=0; FAIL=0; WARN=0

ok()   { printf '  [OK]   %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  [AVISO] %s\n' "$*"; WARN=$((WARN+1)); }
info() { printf '  [INFO] %s\n' "$*"; }
die()  { printf 'Erro: %s — Solução: %s\n' "$1" "$2" >&2; exit "${3:-1}"; }

need_git() {
  command -v git >/dev/null 2>&1 || die "git não está instalado" "instale o git e repita" 3
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "não está dentro de um repositório git" 'corra `git init` ou mude para a pasta do projeto' 4
}

default_branch() {
  local b
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')" || true
  if [ -z "${b:-}" ] && command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
    b="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null)" || true
  fi
  printf '%s' "${b:-main}"
}

has_license() {
  [ -f LICENSE ] || [ -f LICENSE.md ] || [ -f LICENSE.txt ] || [ -f COPYING ]
}

# ---------------------------------------------------------------------------
# Varredura de segredos (heurística defensiva; o Secret Scanning do GitHub reforça)
# ---------------------------------------------------------------------------
STRONG_SECRETS='-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}|glpat-[A-Za-z0-9_-]{20,}|tvly-[A-Za-z0-9-]{16,}|npm_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|SG\.[A-Za-z0-9_-]{22,}'
WEAK_SECRETS='[Aa][Pp][Ii][_-]?[Kk][Ee][Yy][[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}|[Ss][Ee][Cc][Rr][Ee][Tt][[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}|[Tt][Oo][Kk][Ee][Nn][[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}'

scan_blob() { # $1 = ficheiro com texto (diff); $2 = rótulo
  local f="$1" label="$2" hits
  hits="$(grep -nE "$STRONG_SECRETS" "$f" 2>/dev/null | head -5)" || true
  if [ -n "$hits" ]; then
    bad "segredo(s) suspeito(s) em ${label} (Gate 6 — nunca commitar credenciais):"
    printf '%s\n' "$hits" | sed 's/^/         /' | cut -c1-160
  else
    ok "sem segredos fortes em ${label}"
  fi
  hits="$(grep -niE "$WEAK_SECRETS" "$f" 2>/dev/null | head -3)" || true
  [ -n "$hits" ] && warn "possíveis credenciais genéricas em ${label} — verifique:"
  [ -n "$hits" ] && printf '%s\n' "$hits" | sed 's/^/         /' | cut -c1-160
  return 0
}

scan_range() { # $1 = revspec do git diff; $2 = rótulo
  local tmp; tmp="$(mktemp)"
  git diff "$1" > "$tmp" 2>/dev/null || true
  if [ -s "$tmp" ]; then scan_blob "$tmp" "$2"; else ok "sem alterações para varrer em $2"; fi
  rm -f "$tmp"
}

check_commit_subject() { # $1 = subject; devolve 0 se válido
  printf '%s' "$1" | grep -Eq "$HEADER_REGEX"
}

validate_message() { # $1 = mensagem completa
  local subject="$1" problems=0
  subject="$(printf '%s' "$1" | head -1)"
  if printf '%s' "$subject" | grep -Eq '^(Merge |Merge branch|Merge pull request|Revert "|fixup!|squash!)'; then
    warn "mensagem gerada automaticamente (permitida): '$subject'"
    return 0
  fi
  if [ -z "$subject" ]; then
    bad "mensagem vazia"; return 1
  fi
  if ! check_commit_subject "$subject"; then
    bad "cabeçalho fora do padrão Convencional: '$subject'"
    info "formato exigido: tipo(escopo)!: descrição — ex.: fix(auth): corrige validação de token"
    problems=1
  fi
  [ "${#subject}" -gt 72 ] && { bad "cabeçalho com ${#subject} chars (máx. 72)"; problems=1; }
  if printf '%s' "$1" | grep -qiE '^BREAKING[ -]CHANGE: .+'; then
    info "BREAKING CHANGE detetado → próximo release será MAJOR"
  fi
  [ "$problems" -eq 0 ] && ok "mensagem convencional: '$subject'"
  return "$problems"
}

# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------
gate_commit_msg() {
  local msg="$1"
  if [ -f "$1" ]; then msg="$(cat "$1")"; fi
  echo "Gate 1 · Commit — Commits Convencionais"
  validate_message "$msg"
}

gate_push() {
  local branch="${1:-}"
  need_git
  local db; db="$(default_branch)"
  [ -z "$branch" ] && branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "Gate 2 · Push — fronteiras de ramificação e integridade"
  if [ "$branch" = "$db" ]; then
    if git remote get-url origin >/dev/null 2>&1; then
      bad "push direto para '$db' é proibido (Gate 2 — GitHub Flow)"
      info "Solução: git switch -c feat/<nome> && git push -u origin feat/<nome> e abra um PR"
    else
      warn "sem remoto: push a '$db' tolerado localmente; configure um remoto e use PRs"
    fi
  else
    ok "ramificação efémera '$branch' (base '$db')"
  fi

  local range=""
  if git rev-parse --verify --quiet '@{u}' >/dev/null 2>&1; then
    range='@{u}..HEAD'
  elif git rev-parse --verify --quiet "$db" >/dev/null 2>&1 && [ "$branch" != "$db" ]; then
    range="$db..HEAD"
  fi

  if [ -n "$range" ]; then
    local bad_msgs=0 total=0
    while IFS= read -r subj; do
      [ -z "$subj" ] && continue
      total=$((total+1))
      if ! check_commit_subject "$subj" && ! printf '%s' "$subj" | grep -Eq '^(Merge |Revert "|fixup!|squash!)'; then
        bad "commit fora do padrão: '$subj'"; bad_msgs=$((bad_msgs+1))
      fi
    done < <(git log --pretty=format:'%s' "$range" 2>/dev/null)
    if [ "$total" -eq 0 ]; then
      info "nada para enviar acima da base"
    elif [ "$bad_msgs" -eq 0 ]; then
      ok "$total commit(s) com mensagens convencionais"
    else
      info "Solução: reescreva as mensagens (git rebase -i) ou use o título convencional no squash do PR"
    fi
    scan_range "$range" "commits a enviar"
  else
    scan_range 'HEAD' "árvore atual"
  fi
  scan_blob <(git diff --cached 2>/dev/null) "alterações staged" 2>/dev/null
  command -v gh >/dev/null 2>&1 || warn "gh CLI não instalado — a governança remota (rulesets, PRs) exige-o"
}

gate_pr() {
  local title="" base=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --base)  base="$2"; shift 2 ;;
      *) die "argumento desconhecido: $1" "uso: oss-gate.sh pr [--title T] [--base B]" 2 ;;
    esac
  done
  need_git
  local db; db="$(default_branch)"
  [ -z "$base" ] && base="$db"
  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "Gate 2 · PR — submissão por Pull Request"
  [ "$branch" != "$db" ] && ok "ramificação de trabalho '$branch'" || bad "não abra PR a partir de '$db'"
  printf '%s' "$branch" | grep -Eq '^(feat|fix|chore|docs|refactor|perf|test|release|hotfix)/' \
    && ok "nome de ramificação com prefixo de tipo" \
    || warn "nome de ramificação sem prefixo (use feat/<nome>, fix/<nome>, …)"
  [ "$base" = "$db" ] && ok "base '$base' (ramificação predefinida)" || warn "base '$base' difere da predefinida '$db'"
  if [ -n "$title" ]; then
    validate_message "$title" || info "Solução: titule o PR como feat(escopo): descrição — vira a mensagem do squash"
  else
    warn "sem título para validar; o título do PR DEVE ser Convencional (vira o commit do squash)"
  fi
  gate_push "$branch"
  [ "$FAIL" -eq 0 ] && ok "PR pronto para submissão (gh pr create --title \"…\" --base $base)"
}

gate_merge() {
  local title=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      *) die "argumento desconhecido: $1" "uso: oss-gate.sh merge [--title T]" 2 ;;
    esac
  done
  echo "Gate 3 · Merge — squash merge e histórico linear"
  if [ -n "$title" ]; then
    validate_message "$title" || true
  else
    warn "sem título de squash; exija um título Convencional (gh pr merge --squash)"
  fi
  info "política: SOMENTE squash merge + delete-branch (gh pr merge --squash --delete-branch)"
  info "confirme que os status checks estão verdes: gh pr checks --watch"
}

gate_release() {
  local want="" ; local extra=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) want="$2"; shift 2 ;;
      --from-tag|--bump) extra+=("$1" "$2"); shift 2 ;;
      *) die "argumento desconhecido: $1" "uso: oss-gate.sh release [--version X.Y.Z]" 2 ;;
    esac
  done
  need_git
  echo "Gate 4/5 · Release — SemVer derivado dos commits"
  if has_license; then
    ok "licença presente (fundação legal — Gate 0)"
  else
    bad "LICENSE em falta — sem licença OSI não há release open-source"
    info "Solução: bash scripts/oss-scaffold.sh --license mit (Gate 0)"
  fi
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    bad "árvore de trabalho suja — releases partem de um estado limpo"
    info "Solução: git status · commit ou stash antes do release"
  else
    ok "árvore de trabalho limpa"
  fi

  command -v python3 >/dev/null 2>&1 || die "python3 não instalado" "instale python3 (necessário para SemVer/changelog)" 3
  local vjson; vjson="$(python3 "$SKILL_DIR/scripts/oss-version.py" next --json "${extra[@]+"${extra[@]}"}" 2>&1)" \
    || die "falha ao calcular o SemVer: $vjson" "corra python3 scripts/oss-version.py next para o detalhe" 3
  local next bump nonconv
  next="$(printf '%s' "$vjson" | python3 -c 'import json,sys; print(json.load(sys.stdin)["next_version"])')"
  bump="$(printf '%s' "$vjson" | python3 -c 'import json,sys; print(json.load(sys.stdin)["bump"])')"
  nonconv="$(printf '%s' "$vjson" | python3 -c 'import json,sys; print(json.load(sys.stdin)["counts"]["non_conventional"])')"

  [ "$bump" != "none" ] && ok "bump calculado: $bump → $next" \
    || { bad "nenhum commit com impacto em versão desde a última tag"; \
         info "Solução: nada a lançar, ou use --bump com justificação do utilizador"; }
  [ "$nonconv" -eq 0 ] && ok "todos os commits seguem Conventional Commits" \
    || { bad "$nonconv commit(s) fora do padrão contaminam o changelog e o SemVer"; \
         info "Solução: git rebase -i para reescrever, ou corrija as mensagens"; }

  if [ -n "$want" ]; then
    [ "v${want#v}" = "v$next" ] && ok "versão pedida ($want) coerente com os commits" \
      || { bad "versão pedida ($want) diverge do cálculo ($next)"; \
           info "Solução: use $next ou justifique --bump ao utilizador"; }
  fi

  if [ -f CHANGELOG.md ]; then
    grep -q "\[$next\]" CHANGELOG.md && ok "CHANGELOG.md tem entrada para [$next]" \
      || { bad "CHANGELOG.md sem entrada para [$next]"; \
           info "Solução: python3 scripts/oss-changelog.py --write (changelog GERADO, nunca reescrito)"; }
  else
    bad "CHANGELOG.md inexistente"
    info "Solução: python3 scripts/oss-changelog.py --write"
  fi

  if git rev-parse -q --verify "refs/tags/v$next" >/dev/null 2>&1; then
    bad "a tag v$next já existe — versões publicadas nunca retrocedem"
  else
    ok "tag v$next livre para criação (git tag -a v$next)"
  fi
}

gate_publish() {
  local want="" yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) want="$2"; shift 2 ;;
      --yes) yes=1; shift ;;
      *) die "argumento desconhecido: $1" "uso: oss-gate.sh publish [--version X.Y.Z] --yes" 2 ;;
    esac
  done
  echo "Gate 5 · Publish — publicação com segurança"
  if [ -n "$want" ]; then gate_release --version "$want"; else gate_release; fi
  local v="${want#v}"
  [ -z "$v" ] && v="$(python3 "$SKILL_DIR/scripts/oss-version.py" next --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["next_version"])')"

  for manifest in package.json pyproject.toml Cargo.toml; do
    [ -f "$manifest" ] || continue
    local mv
    mv="$(grep -m1 -E '"?version"?[[:space:]]*[:=][[:space:]]*"?v?[0-9]' "$manifest" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" || true
    if [ -n "${mv:-}" ]; then
      [ "$mv" = "$v" ] && ok "$manifest coerente com v$v" \
        || { bad "$manifest declara $mv mas o release é $v"; \
             info "Solução: atualize o manifesto (ou use semantic-release/release-please)"; }
    fi
  done

  local tmp; tmp="$(mktemp)"
  git grep -nE "$STRONG_SECRETS" -- . 2>/dev/null | grep -vE '^(scripts/|references/|assets/)' > "$tmp" || true
  if [ -s "$tmp" ]; then
    bad "segredos fortes em ficheiros versionados:"
    head -5 "$tmp" | sed 's/^/         /' | cut -c1-160
  else
    ok "varredura de segredos limpa no repositório"
  fi
  rm -f "$tmp"

  if [ "$yes" -eq 1 ]; then
    ok "confirmação --yes registada (operação destrutiva autorizada pelo utilizador)"
  else
    bad "publicar é uma operação destrutiva e irreversível — exige confirmação do utilizador"
    info "Solução: apresente o plano ao utilizador e repita com --yes após o OK"
  fi
  info "publique sempre via CI com secrets em Environments: echo \"\$TOKEN\" | gh secret set NPM_TOKEN --env production"
}

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

main() {
  local action="${1:-}"; shift || true
  case "$action" in
    commit-msg|commit) [ $# -ge 1 ] || die "falta a mensagem ou o ficheiro" "uso: oss-gate.sh commit-msg <ficheiro|mensagem>" 2
                       gate_commit_msg "$1" ;;
    push)              gate_push "${1:-}" ;;
    pr)                gate_pr "$@" ;;
    merge)             gate_merge "$@" ;;
    release)           gate_release "$@" ;;
    publish)           gate_publish "$@" ;;
    *)                 usage ;;
  esac
  echo
  if [ "$FAIL" -gt 0 ]; then
    echo "Resultado: GATE BLOQUEADO — $FAIL falha(s), $PASS ok, $WARN aviso(s)"
    exit 1
  fi
  echo "Resultado: GATE PASS — $PASS ok, $WARN aviso(s)"
  exit 0
}

main "$@"
