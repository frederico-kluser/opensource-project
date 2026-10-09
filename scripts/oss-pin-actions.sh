#!/usr/bin/env bash
# oss-pin-actions.sh — fixa as GitHub Actions por hash SHA (pinned dependencies, OpenSSF).
# Uma tag móvel (v4) pode ser reescrita por um invasor; o SHA do commit é prova
# matemática do conteúdo. Converte `uses: owner/repo@v4` em `uses: owner/repo@<sha> # v4`.
#
# Uso: bash scripts/oss-pin-actions.sh [--check] [--dir .github/workflows]
#   --check   só reporta (exit 1 se houver referências por tag); não escreve
#
# Exit codes: 0 tudo fixado (ou fixado com sucesso) · 1 --check com pendências ·
#             2 uso inválido · 3 gh/ferramenta em falta · 4 sem workflows
set -uo pipefail

CHECK=0
DIR=".github/workflows"
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --dir) DIR="$2"; shift 2 ;;
    --help|-h) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Erro: argumento desconhecido: %s — Solução: use --check ou --dir\n' "$1" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { printf 'Erro: git em falta — Solução: instale o git\n' >&2; exit 3; }
command -v gh >/dev/null 2>&1 || {
  printf 'Erro: gh CLI em falta (necessário para resolver SHAs) — Solução: instale https://cli.github.com\n' >&2
  exit 3
}
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  printf 'Erro: não está dentro de um repositório git — Solução: corra na pasta do projeto\n' >&2; exit 4
}
[ -d "$DIR" ] || {
  printf 'Erro: %s não existe — Solução: crie workflows (assets/workflows/ desta skill)\n' "$DIR" >&2
  exit 4
}

resolve_sha() { # $1=owner/repo $2=ref (tag ou branch) -> imprime sha ou vazio
  local repo="$1" ref="$2" obj
  obj="$(gh api "repos/$repo/git/ref/tags/$ref" --jq '.object.type + " " + .object.sha' 2>/dev/null)" || obj=""
  if [ -z "$obj" ]; then
    obj="$(gh api "repos/$repo/git/ref/heads/$ref" --jq '.object.type + " " + .object.sha' 2>/dev/null)" || obj=""
  fi
  [ -n "$obj" ] || return 1
  local type="${obj%% *}" sha="${obj##* }"
  if [ "$type" = "tag" ]; then
    # tag anotada: resolver para o commit subjacente
    sha="$(gh api "repos/$repo/git/tags/$sha" --jq '.object.sha' 2>/dev/null)" || sha=""
  fi
  printf '%s' "$sha"
}

TOTAL=0; FIXED=0; FAILED=0
for wf in "$DIR"/*.yml "$DIR"/*.yaml; do
  [ -e "$wf" ] || continue
  # matches: uses: owner/repo[/path]@ref   (ignora ações locais ./ e templates)
  refs="$(grep -nE 'uses:[[:space:]]*[^ #]+@[^ #]+' "$wf" \
    | grep -vE '@\{\{' \
    | grep -vE 'uses:[[:space:]]*\./' \
    | grep -vE '@[0-9a-f]{40}([[:space:]]|#|$)' || true)"
  [ -z "$refs" ] && continue

  printf '== %s ==\n' "$wf"
  printf '%s\n' "$refs" | while IFS= read -r line; do
    printf '  %s\n' "$line" | cut -c1-140
  done

  if [ "$CHECK" -eq 1 ]; then
    n="$(printf '%s\n' "$refs" | wc -l)"
    TOTAL=$((TOTAL+n))
    continue
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    TOTAL=$((TOTAL+1))
    uses="$(printf '%s' "$line" | sed -n 's/.*uses:[[:space:]]*//p' | awk '{print $1}')"
    ref="${uses##*@}"
    slug="${uses%@*}"
    repo="$(printf '%s' "$slug" | cut -d/ -f1-2)"
    if sha="$(resolve_sha "$repo" "$ref")" && [ -n "$sha" ]; then
      sed -i "s|uses:[[:space:]]*${slug}@${ref}|uses: ${slug}@${sha} # ${ref}|" "$wf"
      echo "  fixado: ${slug}@${sha} # ${ref}"
      FIXED=$((FIXED+1))
    else
      echo "  FALHOU resolver ${repo}@${ref} (ref desconhecida ou sem acesso)"
      FAILED=$((FAILED+1))
    fi
  done <<< "$refs"
done

echo
if [ "$CHECK" -eq 1 ]; then
  if [ "$TOTAL" -gt 0 ]; then
    printf 'Erro: %d action(s) por tag móvel — Solução: bash scripts/oss-pin-actions.sh\n' "$TOTAL" >&2
    exit 1
  fi
  echo "Todas as actions estão fixadas por SHA."
  exit 0
fi

printf '%d referência(s) processadas · %d fixadas · %d falhadas\n' "$TOTAL" "$FIXED" "$FAILED"
[ "$FAILED" -gt 0 ] && {
  printf 'Erro: %d SHA(s) não resolvidos — Solução: confirme as refs (gh api repos/OWNER/REPO/tags) e repita\n' "$FAILED" >&2
  exit 1
}
exit 0
