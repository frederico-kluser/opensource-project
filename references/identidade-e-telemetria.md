# Identidade e telemetria — README, About e badges

O README é a interface do projeto: é a primeira tela que utilizadores,
contribuidores e potenciais empregadores veem. Os badges são a telemetria
pública — estado de build, cobertura, segurança e releases — e funcionam como
compromisso visível. `scripts/oss-scaffold.sh` planta a estrutura base;
`scripts/oss-doctor.sh` mostra que indicadores estão ligados (apenas leitura).

## README como interface (8 blocos obrigatórios)

Ordem fixa — cada bloco tem exatamente uma missão:

1. **Título + badges** — `# nome-do-projeto` e a linha de badges logo abaixo.
2. **Pitch de 1 frase** — blockquote `> O que faz, para quem, porquê.` sem
   buzzwords; quem não conhece o projeto tem de entender em 5 segundos.
3. **Instalação** — um comando copiável por ecossistema (`npm i`, `pip install`,
   `go install`) com a versão mínima de runtime exigida.
4. **Uso** — exemplo mínimo que funciona ao copiar (hello world), não a API
   completa.
5. **Documentação** — ligação para a URL de docs (a do About) e para `docs/`.
6. **Contribuição** — ligações para `CONTRIBUTING.md` e `CODE_OF_CONDUCT.md`.
7. **Versão e estado** — release atual, estado (`stable`/`beta`/`deprecated`) e
   a tabela de versões suportadas (ou ligação a `SECURITY.md`).
8. **Licença** — badge + ligação a [`LICENSE`](LICENSE).

## Secção About e tópicos

A secção "About" (descrição + tópicos + homepage) decide se o projeto aparece
nas buscas do GitHub. Configure-a com `gh`:

```bash
gh repo edit --repo OWNER/REPO \
  --description "CLI que audita workflows do GitHub Actions contra o OpenSSF Scorecard." \
  --homepage "https://OWNER.github.io/REPO/" \
  --add-topic cli --add-topic github-actions --add-topic security --add-topic openssf

gh repo view --repo OWNER/REPO \
  --json description,homepageUrl,repositoryTopics \
  --jq '{description, homepage: .homepageUrl, topics: [.repositoryTopics[].name]}'
```

Regras: descrição curta (uma frase, ≤ 160 caracteres, começa pelo que faz);
3–6 tópicos em minúsculas com hífens (`machine-learning`, não `Machine Learning`);
`--remove-topic` retira tópicos; confirme sempre com `gh repo view` depois de
editar.

## Badges shields.io — sintaxe Markdown exata

Substitua `OWNER`, `REPO` e `MEU-PACOTE` pelos valores reais antes de colar.

| Badge | Sintaxe Markdown exata |
|---|---|
| Build (GitHub Actions) | `![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)` |
| Cobertura (Coveralls) | `![Cobertura](https://coveralls.io/repos/github/OWNER/REPO/badge.svg?branch=main)` |
| Cobertura (Codecov) | `![Cobertura](https://codecov.io/gh/OWNER/REPO/branch/main/graph/badge.svg)` |
| Licença (estático) | `![Licença](https://img.shields.io/badge/license-MIT-blue.svg)` |
| Versão npm | `![npm](https://img.shields.io/npm/v/MEU-PACOTE.svg)` |
| Versão PyPI | `![PyPI](https://img.shields.io/pypi/v/MEU-PACOTE.svg)` |
| OpenSSF Scorecard | `![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/OWNER/REPO/badge)` |
| Última release | `![release](https://img.shields.io/github/v/release/OWNER/REPO)` |
| Issues abertas | `![issues](https://img.shields.io/github/issues/OWNER/REPO)` |
| Downloads npm (total) | `![downloads](https://img.shields.io/npm/dt/MEU-PACOTE.svg)` |
| Downloads PyPI (por mês) | `![downloads](https://img.shields.io/pypi/dm/MEU-PACOTE.svg)` |

Ligue cada badge ao recurso que representa, para que o clique seja útil:

```markdown
[![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/OWNER/REPO)](https://github.com/OWNER/REPO/releases)
```

## Badges dinâmicos vs estáticos e accountability

- **Estáticos** (`img.shields.io/badge/<label>-<msg>-<cor>`): texto fixo que o
  dono escreve — licença, "stable", versão mínima de runtime. Não refletem
  estado real; use-os só para factos que só mudam com decisão humana.
- **Dinâmicos** (endpoints `github/`, `npm/`, `pypi/`, API do Scorecard): o
  shields.io consulta a fonte a cada render (com cache) e pinta verde/amarelo/
  vermelho consoante o dado atual. São telemetria viva.
- **Efeito psicológico de accountability**: uma fila de badges verdes no topo do
  README é uma promessa pública; a equipa sente a obrigação de os manter e os
  utilizadores detectam degradação no primeiro relance. Um badge vermelho
  persistente é pior que a sua ausência — limpe-o ou corrija a causa.

## Documentação visível

- A URL de docs pertence ao About: `gh repo edit --repo OWNER/REPO --homepage
  "https://OWNER.github.io/REPO/"`.
- **GitHub Pages**: build via Actions (`actions/upload-pages-artifact` +
  `actions/deploy-pages`) a partir de `docs/` ou do site estático gerado.
- **Read the Docs**: `.readthedocs.yaml` na raiz; o build é feito na plataforma
  e a badge/ligação aponta para `https://REPO.readthedocs.io`.
- Mantenha a documentação versionada no repositório e construída na CI — docs
  fora do repo apodrecem.

## Transparência: ROADMAP, suporte e versões

- **ROADMAP.md** público: o que vem, o que NÃO vem, e como influenciar
  (discussions/RFC — ver `references/governanca-social.md`).
- **Estado de suporte** no README (`stable` / `beta` / `deprecated` /
  `archived`) com data da última release.
- **Tabela de versões suportadas**: a fonte única é a tabela de `SECURITY.md`;
  o README apenas liga a ela — nunca mantenha duas tabelas que podem divergir.
- **CHANGELOG** gerado e assinado por release-please
  (`googleapis/release-please-action@v5`) para que cada versão tenha notas.

## Cuidados obrigatórios

- **Badges não substituem CI real**: o badge de build tem de apontar ao workflow
  que corre os testes em PRs e pushes; um badge verde de workflow que não corre
  é teatro. Confirme com `gh run list --workflow=ci.yml`.
- **Placeholders**: todo o `OWNER/REPO` e `MEU-PACOTE` desta página são
  substituídos antes de colar; URLs com placeholders não devem chegar a `main`.
- **Dependência de terceiros**: shields.io, Codecov/Coveralls e o Scorecard têm
  downtime e cache; limite-se a 4–6 badges essenciais e verifique-os após
  renomear o repositório.
- Valide a renderização final do README no GitHub (pré-visualização) e teste
  cada URL de badge com `curl -sI <url>`.
