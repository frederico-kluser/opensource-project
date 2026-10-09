#!/usr/bin/env bash
# =============================================================================
# link-skill-global.sh — regista esta skill, por SYMLINK, em TODOS os skill roots
# globais desta máquina (qualquer agent code, qualquer cwd). Fonte única, N links.
#
# ROOTS ALVO (padrão verificado desta máquina — ver config-agent-skills):
#   ~/.agents/skills          dsh (user-agents) + opencode (external, auto)
#   ~/.claude/skills          Claude Code (perfil default) + opencode (auto)
#   ~/.claude-*/skills        cada conta do claude-contas (CLAUDE_CONFIG_DIR próprio)
#   ~/.jcode/skills           jcode — root GLOBAL próprio (não lê ~/.agents)
#   ~/.pi/agent/skills        pi-coding-agent — <agentDir>/skills
#   ~/.dsh/skills             dsh (user-dsh — vence o .agents no empate)
#   ~/.config/opencode/skill  opencode (global; diretório no SINGULAR)
#   ~/.codex/skills           codex — preventivo
#
# NÃO É ALVO (deliberado): ~/.agents-test (fixture), roots de projeto
#   (<projeto>/.claude|.agents/skills), ~/.gemini/~/.kimi-code (sem skills em disco).
#
# GARANTIAS:
#   - IDEMPOTENTE: link já correto = nenhuma escrita.
#   - ACRESCENTA, NUNCA DESTRÓI: diretório real ou link divergente é MOVIDO para
#     ~/Agent-Skills/.link-backups/<timestamp>/ antes de religar.
#   - Aceita link INDIRETO: se o realpath já cai na fonte, preserva como está.
#   - Root só é criado se a HOME do agente já existir (não inventa CLI ausente).
#
# Uso: bash scripts/link-skill-global.sh [--check] [--dry-run] [--unlink] [--help]
#   --check    não escreve; sai 1 se algum root estiver fora de conformidade
#   --dry-run  mostra o que faria, sem escrever
#   --unlink   remove os symlinks desta skill (não toca em diretórios reais)
#
# Variáveis: SKILL_NAME (predef.: basename da fonte; deve igualar o `name:` do
# SKILL.md) e SKILL_SRC (predef.: pasta desta skill).
# =============================================================================
set -uo pipefail

SRC="${SKILL_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILL_NAME="${SKILL_NAME:-$(basename "$SRC")}"
BAK_ROOT="${HOME}/Agent-Skills/.link-backups"

MODE=apply
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE=check ;;
    --dry-run) MODE=dryrun ;;
    --unlink)  MODE=unlink ;;
    -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Erro: opção desconhecida: %s — Solução: --check | --dry-run | --unlink\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

[ -f "$SRC/SKILL.md" ] || {
  printf 'Erro: %s/SKILL.md não existe — Solução: confirme SKILL_SRC\n' "$SRC" >&2; exit 2
}
grep -qE "^name:[[:space:]]*${SKILL_NAME}[[:space:]]*$" "$SRC/SKILL.md" || {
  printf 'Erro: name: do SKILL.md não é "%s" — Solução: alinhe SKILL_NAME com o frontmatter\n' "$SKILL_NAME" >&2; exit 2
}

# HOME de cada agente -> roots de skills (só se a HOME do agente existir)
declare -a ROOTS=(
  "$HOME/.agents/skills|dsh user-agents + opencode"
  "$HOME/.claude/skills|Claude Code (default)"
  "$HOME/.claude-azureclaude/skills|conta Claude azureclaude"
  "$HOME/.claude-deepseek/skills|conta Claude deepseek"
  "$HOME/.claude-frederico/skills|conta Claude frederico"
  "$HOME/.claude-k2.frederico/skills|conta Claude k2.frederico"
  "$HOME/.claude-k2.rodrigo/skills|conta Claude k2.rodrigo"
  "$HOME/.jcode/skills|jcode (root global próprio)"
  "$HOME/.pi/agent/skills|pi-coding-agent"
  "$HOME/.dsh/skills|dsh user-dsh"
  "$HOME/.config/opencode/skill|opencode (global, singular)"
  "$HOME/.codex/skills|codex (preventivo)"
)

ALTERADOS=0; CONFORMES=0; PROBLEMAS=0; IGNORADOS=0

for entry in "${ROOTS[@]}"; do
  root="${entry%%|*}"; quem="${entry##*|}"
  agente_home="$(dirname "$root")"
  [ -d "$agente_home" ] || { printf '  SKIP  %s — %s não existe\n' "$root" "$quem"; IGNORADOS=$((IGNORADOS+1)); continue; }
  link="$root/$SKILL_NAME"

  if [ "$MODE" = "unlink" ]; then
    if [ -L "$link" ]; then
      rm "$link"
      printf '  DEL   %s\n' "$link"; ALTERADOS=$((ALTERADOS+1))
    else
      printf '  OK    %s (não é symlink — preservado)\n' "$link"; CONFORMES=$((CONFORMES+1))
    fi
    continue
  fi

  if [ -L "$link" ]; then
    alvo="$(readlink -f "$link" 2>/dev/null)"
    if [ "$alvo" = "$(readlink -f "$SRC")" ]; then
      printf '  OK    %s → %s  [%s]\n' "$link" "$SRC" "$quem"; CONFORMES=$((CONFORMES+1)); continue
    fi
    if [ "$MODE" = "check" ]; then
      printf '  ERRO  %s — link divergente (%s)\n' "$link" "${alvo:-apagado}"; PROBLEMAS=$((PROBLEMAS+1)); continue
    fi
    bdir="$BAK_ROOT/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$bdir"
    mv "$link" "$bdir/" && printf '  MOVIDO %s → %s\n' "$link" "$bdir/"; ALTERADOS=$((ALTERADOS+1))
  elif [ -e "$link" ]; then
    if [ "$MODE" = "check" ]; then
      printf '  ERRO  %s — diretório real no lugar do symlink\n' "$link"; PROBLEMAS=$((PROBLEMAS+1)); continue
    fi
    bdir="$BAK_ROOT/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$bdir"
    mv "$link" "$bdir/" && printf '  MOVIDO %s → %s (real, preservado)\n' "$link" "$bdir/"; ALTERADOS=$((ALTERADOS+1))
  fi

  if [ "$MODE" = "check" ]; then
    printf '  ERRO  %s — em falta\n' "$link"; PROBLEMAS=$((PROBLEMAS+1)); continue
  fi
  if [ "$MODE" = "dryrun" ]; then
    printf '  LIGARIA %s → %s  [%s]\n' "$link" "$SRC" "$quem"; ALTERADOS=$((ALTERADOS+1)); continue
  fi
  mkdir -p "$root"
  ln -s "$SRC" "$link" && printf '  LIGADO %s → %s  [%s]\n' "$link" "$SRC" "$quem"
  ALTERADOS=$((ALTERADOS+1))
done

echo
printf 'Resumo: roots=%d · alterados=%d · conformes=%d · ignorados=%d · problemas=%d\n' \
  "${#ROOTS[@]}" "$ALTERADOS" "$CONFORMES" "$IGNORADOS" "$PROBLEMAS"
if [ "$PROBLEMAS" -gt 0 ]; then
  printf 'Erro: %d root(s) fora de conformidade — Solução: repita sem --check para religar\n' "$PROBLEMAS" >&2
  exit 1
fi
echo "TUDO CONFORME"
exit 0
