# CODEOWNERS — {{PROJECT_NAME}}
#
# Review obligation: every change MUST be approved by the owners of the affected paths
# before it can be merged (code owner review is required by repository rulesets).
# The last matching pattern wins; keep the most specific rules at the bottom.
#
# Repository rule note: files larger than 3 MB are rejected by the push ruleset
# (max file size = 3 MB). Do not commit generated artifacts or large binaries.

# Default owners for everything in the repository.
*       @{{OWNER}}/core

# Source code: core maintainers own the runtime and public API surface.
/src/   @{{OWNER}}/maintainers

# Documentation: docs team reviews every markdown change.
*.md    @{{OWNER}}/docs

# CI/CD, workflows, and repository configuration: infrastructure team.
/.github/ @{{OWNER}}/infra
