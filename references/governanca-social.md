# Governança social — CONTRIBUTING, CODEOWNERS, SECURITY e community files

A governança social é o que transforma um repositório num projeto: contratos
explícitos entre donos e comunidade, revisão por responsáveis e canais seguros
para vulnerabilidades. `scripts/oss-scaffold.sh` cria-os de forma idempotente a
partir de `assets/templates/` e `scripts/oss-gate.sh pr` valida os PRs.

## CONTRIBUTING.md — o contrato social

Seis pontos OBRIGATÓRIOS, por esta ordem:

1. **Bootstrapping reproduzível** — clone + um comando único que deixa o ambiente
   pronto, com toolchain versionada (`.tool-versions`, `mise.toml`, `go.mod`).
2. **Proibição de push direto a `main`** — todo o trabalho via PR (fork para
   externos); `main` protegida por ruleset (ver CODEOWNERS).
3. **Linters e formatadores obrigatórios antes do commit** — hooks locais que
   repetem exatamente o que a CI corre.
4. **Convenção de commits** — Conventional Commits, com exemplos aceites e
   rejeitados (ver abaixo).
5. **Como testar localmente** — um comando único, idêntico ao da CI.
6. **Como reportar bugs e propor features** — ligações aos issue templates;
   vulnerabilidades NUNCA em issues públicas (vão para `SECURITY.md`).

Bloco de comandos que deve existir no CONTRIBUTING:

```bash
git clone https://github.com/OWNER/REPO.git && cd REPO
make setup    # toolchain + hooks + dependências
make test     # exatamente o que a CI corre
```

Hooks de lint/format — fluxo moderno; NUNCA `npx husky add` (deprecated no
husky v9): escreva o ficheiro do hook diretamente.

```bash
npx husky init                                   # cria .husky/pre-commit (v9)
echo "npm run lint && npm run format:check" > .husky/pre-commit
pip install pre-commit && pre-commit install     # alternativa multi-linguagem
```

Convenção de commits — inclua estes exemplos:

```bash
# Aceites
git commit -m "fix(api): corrige race condition no cache de sessão"
git commit -m "feat(cli): adiciona --dry-run ao comando release"
# Rejeitados
git commit -m "fix stuff"       # sem tipo/escopo
git commit -m "WIP"             # sem mensagem útil
git commit -m "correcao bug"    # fora da gramática Conventional Commits
```

## CODEOWNERS — revisão obrigatória por donos

- Sintaxe: `padrão @dono` (globs estilo gitignore), um por linha, `#` comentários.
- Localização (a primeira vence): `CODEOWNERS` na raiz, `.github/CODEOWNERS` ou `docs/CODEOWNERS`.
- Tem de ter **menos de 3 MB** — acima disso o GitHub ignora-o silenciosamente.
- Só tem efeito com a revisão dos owners ativa (`require_code_owner_review: true`).

```text
# .github/CODEOWNERS
*              @org/core
/src/api/      @org/api-equipa
*.md           @org/docs
/docs/         @org/docs
```

Proteção de `main` por rulesets (base `assets/rulesets/regras-main.json`, mais
detalhe em `references/rulesets-e-protecao.md`) — `POST /repos/{owner}/{repo}/rulesets`:

```bash
gh api -X POST repos/OWNER/REPO/rulesets --input - <<'JSON'
{
  "name": "protecao-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 1, "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true, "require_last_push_approval": true,
        "required_status_checks": [{ "context": "ci" }],
        "strict_required_status_checks": true,
        "allowed_merge_methods": ["squash", "rebase"] } },
    { "type": "non_fast_forward" },
    { "type": "deletion" }
  ]
}
JSON
```

## SECURITY.md — divulgação responsável

Estrutura obrigatória (template em `assets/templates/SECURITY.md.tpl`):

1. **Versões suportadas** — tabela; fonte única: o README/About liga aqui.
2. **Como reportar em silêncio** — Private Vulnerability Reporting do GitHub
   (Security → Report a vulnerability), nunca issues públicas.
3. **Divulgação coordenada** — acusação em 3 dias úteis, avaliação em 14 dias,
   divulgação até 90 dias (120 para bugs complexos), embargo negociável.
4. **Contacto** — canal privado (email/formulário) e tempo de resposta esperado.
5. **Recompensas** — bug bounty se existir; caso contrário, crédito no advisory.

| Versão | Suportada |
|---|---|
| 2.x | ✅ |
| 1.x | ❌ (EOL — corrigir apenas para clientes com contrato) |

Ativar/verificar o relatório privado (exige admin do repo):

```bash
gh api -X PUT repos/OWNER/REPO/private-vulnerability-reporting   # ativar
gh api repos/OWNER/REPO/private-vulnerability-reporting          # {"enabled":true}
```

O fluxo de deteção de segredos fica em `references/seguranca-openssf.md`; este
ficheiro é o contrato humano.

## Community health files em `.github/`

```text
.github/
├── CODEOWNERS
├── FUNDING.yml
├── PULL_REQUEST_TEMPLATE.md
├── SUPPORT.md
└── ISSUE_TEMPLATE/   (bug_report.md · feature_request.md · config.yml)
```

- **ISSUE_TEMPLATE/** — `bug_report.md` (passos de reprodução, esperado, versão/
  ambiente) e `feature_request.md` (problema, proposta, alternativas).
- **config.yml** — fecha issues em branco e redireciona suporte:

```yaml
blank_issues_enabled: false
contact_links:
  - name: Perguntas e suporte
    url: https://github.com/OWNER/REPO/blob/main/.github/SUPPORT.md
    about: Use as discussions para dúvidas — issues são para bugs e features.
```

- **PULL_REQUEST_TEMPLATE.md** com checklist (o gate `scripts/oss-gate.sh pr`
  exige título convencional, ramificação efémera e base `main`):

```markdown
## Checklist
- [ ] `make test` passa localmente
- [ ] Linters/formatadores OK (`pre-commit run --all-files`)
- [ ] Commits seguem Conventional Commits
- [ ] Docs/CHANGELOG atualizados (se aplicável)
- [ ] Sem segredos ou dados sensíveis no diff
```

- **CODE_OF_CONDUCT.md** — Contributor Covenant 2.1, com contacto para denúncias
  e consequências definidas (aviso → ban temporário → ban permanente).
- **SUPPORT.md** — onde pedir ajuda (discussions/chat) e o que NÃO é suporte.
- **FUNDING.yml** — `github: [NOME]` e/ou `custom: ["https://..."]` para o botão
  "Sponsor".

## Governança de decisão (resumo)

- **Quem decide**: os maintainers (o conjunto do CODEOWNERS); empates caem no
  maintainer lead; decisões rotineiras seguem "lazy consensus" no PR.
- **RFCs para mudanças grandes** — breaking changes, arquitetura, licença,
  descontinuar APIs: abrir uma discussion (RFC) com a proposta, discutir ≥ 7
  dias e registar a decisão no próprio RFC.
- **Ladder de maintainers**: Contributor → Reviewer → Maintainer → Lead/Emeritus.
- **Como se tornar maintainer**: contribuições consistentes + revisões úteis +
  indicação de maintainer existente + consenso dos maintainers + convite formal;
  saída graciosa com estatuto emeritus.
