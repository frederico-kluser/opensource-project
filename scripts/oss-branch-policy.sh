# shellcheck shell=bash
# oss-branch-policy.sh — FONTE ÚNICA da política de nomes de ramificação.
# Partilhado por oss-gate.sh, oss-doctor.sh e oss-enforce.sh (nunca duplicar o regex).
#
# Espelha EXATAMENTE o ruleset "Convenção de Nomes de Ramificação"
# (assets/rulesets/regras-nomes-de-branch.json): se mudar aqui, mude lá — e vice-versa.
#
# Convenção (restritiva, sem exceções de cortesia):
#   <tipo>/<slug>  ·  tipos fechados: feat fix docs style refactor perf test build
#                    ci revert hotfix release  ·  slug: [a-zA-Z0-9._/-], começa por
#                    alfanumérico (kebab-case minúsculo recomendado).
# Únicas exceções: prefixos de AUTOMAÇÃO (dependabot/, renovate/, release-please--*,
# gh-readonly-queue/) — criados pelo próprio GitHub/bots, nunca por humanos.

BRANCH_TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|revert|hotfix|release'
BRANCH_REGEX="^(${BRANCH_TYPES})/[a-zA-Z0-9][a-zA-Z0-9._/-]*$|^(dependabot|renovate)/[a-zA-Z0-9._/-]+$|^release-please--.*$|^gh-readonly-queue/.*$"

# Ramos protegidos: commits DIRETOS proibidos (só via PR + squash).
BRANCH_PROTECTED_REGEX='^(main|master|develop|release/.*)$'

# Ramos longevos isentos da convenção de nomes (espelha os `exclude` do ruleset).
BRANCH_NAMING_EXEMPT_REGEX='^(main|master|develop|gh-pages)$'

oss_branch_ok() { # $1=nome — 0 se cumpre a convenção (ou é ramo longevo isento)
  printf '%s' "$1" | grep -Eq "$BRANCH_NAMING_EXEMPT_REGEX" && return 0
  printf '%s' "$1" | grep -Eq "$BRANCH_REGEX"
}

oss_branch_protected() { # $1=nome $2=ramo predefinido — 0 se protegido contra commit direto
  [ "$1" = "${2:-}" ] && return 0
  printf '%s' "$1" | grep -Eq "$BRANCH_PROTECTED_REGEX"
}
