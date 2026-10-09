# Licenciamento — a base legal que dita a comunidade

A licença é a primeira decisão de design de um projeto open-source: define quem
pode usar, modificar e redistribuir o código e que empresas podem adotá-lo sem
risco. Decida-a ANTES do primeiro commit público. `scripts/oss-scaffold.sh`
planta os ficheiros de licenciamento de forma idempotente (a partir de
`assets/licenses/`) e `scripts/oss-doctor.sh` acusa em falta sem `LICENSE`.

## Porquê decidir a licença primeiro

- Sem `LICENSE`, o código é "todos os direitos reservados": ninguém — nem
  empresas nem comunidade — pode usá-lo, modificá-lo ou redistribuí-lo.
- A escolha determina a comunidade que se forma: corporações afastam-se de
  copyleft forte; hospedeiros SaaS fogem do AGPL; fundações exigem permissivas.
- Mudar de licença depois exige consentimento de TODOS os contribuidores — em
  projetos com dezenas de PRs é prático impossível.
- O GitHub e os registos (npm, PyPI, crates.io) leem a licença automaticamente:
  escolha vaga bloqueia publicações e derruba a check `License` do OpenSSF
  Scorecard (ver `references/seguranca-openssf.md`).

## Categorias de licenças

| Categoria | Licenças | Impacto na adoção comercial | Exigência de partilha de modificações |
|---|---|---|---|
| Permissiva | MIT · Apache-2.0 · BSD-3-Clause | Máximo — incorporam-se em código fechado sem fricção | Nenhuma |
| Copyleft fraco | LGPL-2.1+ · MPL-2.0 | Alto — produtos fechados podem usá-las em contornos definidos | Só as alterações aos ficheiros (MPL) ou à biblioteca (LGPL) |
| Copyleft forte | GPLv2 · GPLv3 | Baixo em contexto proprietário — derivação distribuída herda a GPL | Todo o trabalho derivado distribuído |
| Copyleft de rede | AGPL-3.0 | Muito baixo em SaaS/cloud — fecha a "brecha da rede" | GPLv3 + o código-fonte a quem acede ao serviço por rede |

## Árvore de decisão (5 perguntas)

1. **Queres adoção corporativa máxima?** → **MIT** (simplicidade) ou
   **Apache-2.0** (se a pergunta 2 ou 3 for relevante). Se não, copyleft é
   opção legítima.
2. **O projeto é oferecido como SaaS?** → se queres que hospedeiros comerciais
   devolvam melhorias: **AGPL-3.0**; caso contrário, permissiva.
3. **Há medo de litígios de patentes?** → sim: **Apache-2.0** (concessão de
   patente explícita + cláusula de retaliação).
4. **Queres que derivados fiquem abertos?** → tudo: **GPLv3** (ou **GPLv2** por
   compatibilidade com ecossistemas GPLv2); só por ficheiro/módulo: **MPL-2.0**
   ou **LGPL-3.0**.
5. **É um monorepo misto (lib + app + assets)?** → licença por subpasta +
   `NOTICE` na raiz (ver "Licenças mistas em monorepo").

Recomendação default desta skill: **Apache-2.0** para bibliotecas e ferramentas
com unidade organizacional por trás; **MIT** para utilitários pequenos sem
patentes envolvidas; **AGPL-3.0** para aplicações SaaS que precisam que a
comunidade de hospedeiros contribua de volta.

## MIT vs Apache 2.0

Ambas são permissivas e compatíveis entre si; Apache-2.0 acrescenta proteção de
patentes e formalidades de atribuição.

| Aspeto | MIT | Apache-2.0 |
|---|---|---|
| Extensão | ~170 palavras, trivial | ~11 000 palavras, estruturada |
| Concessão de patente | Implícita (só copyright) | **Explícita**: licença das patentes necessárias à utilização |
| Cláusula de retaliação | Não tem | Sim: quem processa por patente perde a licença de patente |
| Atribuição | Cópia do LICENSE + copyright | Manter `NOTICE` e registar alterações significativas |
| Escolher quando | Utilitários, libs pequenas, máximo alcance | Empresas, standards, qualquer projeto com exposição a patentes |

## Como aplicar no repositório

1. **`LICENSE` na raiz** com o texto integral e a linha de copyright
   (`Copyright (c) 2026 <Nome>`). Sem ele o GitHub não deteta a licença.
2. **Cabeçalho SPDX na primeira linha de cada ficheiro-fonte**:
   - C/C++/Go/Java/JS/TS: `// SPDX-License-Identifier: MIT`
   - Python/Ruby/shell/YAML: `# SPDX-License-Identifier: MIT`
   - HTML/XML/CSS: `<!-- SPDX-License-Identifier: MIT -->`
3. **Campo `license` nos manifests** — é o que a tooling e os registos leem:

```json
// package.json
{ "name": "meu-pacote", "license": "MIT" }
```

```toml
# pyproject.toml (PEP 639)
[project]
license = "MIT"
license-files = ["LICENSE"]
```

```toml
# Cargo.toml
[package]
license = "MIT"
```

4. **Badge + secção final no README** (ver `references/identidade-e-telemetria.md`
   para a tabela completa de badges):

```markdown
![Licença](https://img.shields.io/badge/license-MIT-blue.svg)

## Licença

Distribuído sob a licença MIT — ver [`LICENSE`](LICENSE).
```

## Licenças mistas em monorepo

- `LICENSE` por subpasta com regras diferentes: `libs/core/LICENSE` (MIT),
  `apps/server/LICENSE` (AGPL-3.0), `assets/LICENSE` (CC-BY-4.0 para arte).
- `NOTICE` na raiz que mapeia cada subpasta à sua licença e lista atribuições
  de terceiros (exigência formal do Apache-2.0).
- Cabeçalhos SPDX por ficheiro resolvem ambiguidades quando alguém consome uma
  subpasta isolada (cópia parcial, submodule, vendoring).
- Verifique compatibilidade de derivação: GPLv3 não pode ser importada por um
  módulo MIT; MPL-2.0 é por ficheiro e permite mistura lado a lado; LGPL exige
  que a biblioteca seja substituível (ligação dinâmica).
- `scripts/oss-scaffold.sh --target <subpasta> --license <id>` planta a `LICENSE`
  de cada subpasta (a raiz leva a licença principal); escreva o `NOTICE` à mão e
  use cabeçalhos SPDX sem duplicar ficheiros já cobertos.

## Checklist final do agente

- [ ] Licença escolhida ANTES do primeiro commit público e explicada ao dono.
- [ ] `LICENSE` na raiz com texto integral e copyright correto (ano + nome).
- [ ] `NOTICE` presente se Apache-2.0 ou monorepo misto.
- [ ] Cabeçalho `SPDX-License-Identifier` em todos os ficheiros-fonte novos.
- [ ] Campo `license` preenchido em `package.json`/`pyproject.toml`/`Cargo.toml`.
- [ ] Badge de licença e secção "Licença" no README.
- [ ] Em monorepo: `LICENSE` por subpasta + mapa de licenças no `NOTICE`.
- [ ] `bash scripts/oss-doctor.sh` não acusa `LICENSE` em falta.
- [ ] Utilizador informado da nota jurídica abaixo.

## Nota jurídica

Esta skill NÃO dá aconselhamento jurídico. Documenta práticas de mercado e
padrões técnicos; a decisão final de licenciamento — e as suas consequências
contratuais, fiscais ou de patentes — pertence ao dono do projeto. Em caso de
dúvida real (contribuições de terceiros, mistura de licenças, patentes),
consulte um advogado antes de publicar.
