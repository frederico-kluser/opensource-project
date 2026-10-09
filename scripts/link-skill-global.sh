#!/usr/bin/env bash
# link-skill-global.sh — liga esta skill em ~/.dsh/skills e ~/.agents/skills (symlink).
# Uso: bash scripts/link-skill-global.sh [--unlink] [--name NOME]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="$(basename "$HERE")"
UNLINK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --unlink) UNLINK=1; shift ;;
    --name) NAME="$2"; shift 2 ;;
    --help|-h) sed -n '2,3p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Erro: argumento desconhecido: %s — Solução: use --unlink ou --name\n' "$1" >&2; exit 2 ;;
  esac
done

for dest in "$HOME/.dsh/skills" "$HOME/.agents/skills"; do
  [ -d "$(dirname "$dest")" ] || continue
  mkdir -p "$dest"
  link="$dest/$NAME"
  if [ "$UNLINK" -eq 1 ]; then
    if [ -L "$link" ]; then rm "$link" && echo "removido: $link"; else echo "não existia: $link"; fi
    continue
  fi
  if [ -L "$link" ]; then
    echo "já ligado: $link -> $(readlink "$link")"
  elif [ -e "$link" ]; then
    printf 'Erro: %s já existe e não é symlink — Solução: remova-o manualmente se quiser substituir\n' "$link" >&2
  else
    ln -s "$HERE" "$link" && echo "ligado: $link -> $HERE"
  fi
done
exit 0
