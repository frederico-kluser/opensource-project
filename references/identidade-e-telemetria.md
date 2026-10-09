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

## Anatomia da URL shields.io (sintaxe completa)

- **Estático**: `https://img.shields.io/badge/<label>-<message>-<cor>` — os três
  campos são separados por `-` (use `_` ou `%20` para espaços; `--` descreve um
  travessão). Uma cor nomeada (`blue`, `brightgreen`, `red`, `informational`) ou
  hex sem `#` (`4c1`, `fe2d52`).
- **Endpoint**: `https://img.shields.io/badge/endpoint?url=<json>` — o JSON tem de
  ter `schemaVersion: 1`, `label`, `message` e `color`; serve para telemetria
  própria (ex.: resultado de uma auditoria interna publicada como artefato).
- **Dinâmico por serviço**: `https://img.shields.io/<serviço>/<métrica>/<alvo>`
  (`github/v/release/OWNER/REPO`, `npm/v/PACOTE`, `pypi/v/PACOTE`, `github/actions/workflow/status/OWNER/REPO/ci.yml`).
- **Parâmetros opcionais** (query string): `?style=flat|flat-square|plastic|for-the-badge|social`,
  `?logo=github&logoColor=white&logoSize=auto`, `?label=…`, `?cacheSeconds=…`
  (só para badges estáticos/endpoint; dinâmicos têm cache próprio do shields).

## Quando os badges "não aparecem" (troubleshooting)

1. **Está a ler o ficheiro cru?** Markdown só vira imagem em renderização
   (GitHub, VS Code preview). Num editor de texto vê `[![alt](url)](url)`.
2. **URL partida ou incompleta** — o markdown exige os três segmentos
   `![alt](URL)`: URL vazia ou mal formada mostra só o texto alternativo.
   Teste sempre: `curl -sI "<url>" | head -1` (quer `200` e `image/svg+xml`).
3. **Case e nomes**: `owner/REPO` e `OWNER/repo` não são o mesmo — o GitHub
   redireciona HTML, mas shields.io404 no badge. Copie o `nameWithOwner` real
   (`gh repo view --json nameWithOwner --jq .nameWithOwner`).
4. **Workflow renomeado/apagado**: o badge de build usa o **caminho do ficheiro**
   (`actions/workflows/ci.yml/badge.svg`); renomeou o workflow → badge404
   (imagem quebrada). Atualize o badge junto com o rename.
5. **Repositórios privados**: badges dinâmicos exigem acesso público; num repo
   privado ficam em erro ou a mostrar `unknown` — ou torne o repo público ou use
   badges estáticos.
6. **Cache e proxies**: shields.io e o proxy `camo` do GitHub guardam cache
   (~5 min a 1 h). Um badge acabado de corrigir pode continuar velho um tempo;
   hard-refresh ou `?cacheSeconds=300` em badges estáticos.
7. **OpenSSF Scorecard**: o badge só tem dados quando o workflow publica
   resultados (`publish_results: true` **e** `id-token: write` no job — ver
   `assets/workflows/scorecard.yml`); em repos privados `publish_results` é
   sempre `false`. Atualiza a cada execução do scorecard-action; na primeira
   semana pode mostrar `not found`/nota provisória.
8. **Extensões de browser** (bloqueadores de rastreadores) podem bloquear
   `img.shields.io` — teste em janela anónima antes de concluir que o badge está
   morto.
9. **Empilhados um por linha** (mudança de renderização do GitHub/Camo): o proxy
   Camo pode tratar SVGs externos como `display: block` e forçar cada badge para a
   sua própria linha — o README parece "não ter fila de badges". Correção: um
   bloco HTML único (receita abaixo) e nunca CDNs de ícones frágeis
   (`cdn.simpleicons.org`).
10. **Extensão do ficheiro**: `README.txt` (ou qualquer nome sem `.md`) não
    renderiza markdown — o GitHub mostra `[![alt](url)](url)` em texto cru. Tem de
    ser `README.md` (ou `.markdown`).
11. **Preview ≠ publicação**: imagens que aparecem no preview mas não no GitHub
    Pages/Jekyll quase sempre usam URLs `github.com/.../blob/...` em vez de
    `raw.githubusercontent.com/...` (ou caminhos relativos resolvidos contra a
    raiz do site, não do ficheiro).
12. **200 não quer dizer badge bom**: o shields devolve HTTP 200 mesmo quando o
    conteúdo é um erro — `github/v/release` desenha `no releases or repo not
    found` até à primeira release (e sempre em repo privado sem token), e o badge
    de workflow só ganha estado depois do primeiro run na branch default. Leia o
    **texto** do SVG (`curl -s <url> | grep -o 'aria-label="[^"]*"'`), não só o
    status HTTP.

Regras de higiene: um badge **quebrado é pior que nenhum** (mostra descuido);
badges **velhos** (build vermelho há meses) removam-se ou corrige-se a causa;
badges **de vaidade** ("made with ❤️") não informam nada — cada badge tem de
comunicar um facto verificável. Máximo prático: 4–6 badges essenciais.

## Receita robusta: fila de badges que renderiza sempre

Em vez de uma linha markdown por badge (que o Camo pode empilhar), use um bloco
HTML único — é o padrão que sobrevive a todas as causas acima:

```html
<p align="center">
  <a href="https://github.com/OWNER/REPO/actions/workflows/ci.yml"><img src="https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://securityscorecards.dev/viewer/?uri=github.com/OWNER/REPO"><img src="https://api.securityscorecards.dev/projects/github.com/OWNER/REPO/badge" alt="OpenSSF Scorecard"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/OWNER/REPO/releases"><img src="https://img.shields.io/github/v/release/OWNER/REPO" alt="GitHub release"></a>
</p>
```

Regras da receita: tudo dentro de UM `<p>` (sem quebras entre badges); `<img>` com
`alt` sempre; cada badge envolvido pela `<a>` do recurso que representa; `logo=`
só com ícones do próprio shields (`?logo=github`), nunca com CDNs externos.

## Verificação executável (portão com exit code, não prosa)

```bash
# 1) cada URL de badge responde 200?
grep -oE 'https://[^)"< ]+' README.md | grep -iE 'badge|scorecard' | sort -u | while read -r u; do
  printf '%s  %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 15 "$u")" "$u"
done
# 2) o conteúdo mostra o que promete? (deteta "no releases"/"invalid")
curl -s -L "<badge-url>" | grep -oE 'aria-label="[^"]*"|<title>[^<]*</title>' | head -2
# 3) o GitHub renderiza mesmo? (procura <img> no HTML de renderização)
gh api --method POST /markdown -f mode=gfm -f text="$(sed -n '1,10p' README.md)" | grep -c '<img'
```

Fontes consultadas (2026-10): [Discussion #203096](https://github.com/orgs/community/discussions/203096)
(extensão do README), [Discussion #193030](https://github.com/orgs/community/discussions/193030)
(Camo + `display: block`), [Discussion #168186](https://github.com/orgs/community/discussions/168186)
(preview vs publicação), [badges/shields#1598](https://github.com/badges/shields/issues/1598)
(cache/proxy), [badges/shields#10084](https://github.com/badges/shields/issues/10084)
(logos externos) e [SO 76285706](https://stackoverflow.com/questions/76285706/)
(`no releases or repo not found`).

## Validação automática (o gate do doctor)

`scripts/oss-doctor.sh` extrai todos os URLs de badge do README, verifica o
HTTP de cada um (`200 image/svg+xml`) e, para o badge do OpenSSF Scorecard,
lê a nota e avisa se estiver abaixo do limiar de graduação (≥ 7) exigido pelo
Gate 6. Corra-o após qualquer mudança de badges — e sempre antes de um release:

```bash
bash scripts/oss-doctor.sh            # inclui a secção "Telemetria (badges)"
curl -sI "https://img.shields.io/badge/license-MIT-blue.svg" | head -1
```

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
