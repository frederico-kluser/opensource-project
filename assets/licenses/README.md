# Licenças — como escolher e obter o texto

O `MIT.txt` desta pasta é o texto integral da licença **MIT**, com os placeholders `{{YEAR}}` (ano do
copyright) e `{{HOLDER}}` (titular), substituídos pelo `oss-scaffold.sh` e copiados para `LICENSE`
na raiz do projeto.

Para **outras licenças**, **não escreva o texto de cor**: copie-o de uma fonte canónica (SPDX ou
choosealicense.com) e só depois ajuste o cabeçalho de copyright. Textos de licenças reescritos à
mão podem ter efeitos jurídicos inesperados.

## Obter a partir do SPDX (recomendado — texto canónico)

O repositório [spdx/license-list-data](https://github.com/spdx/license-list-data) mantém os textos
oficiais em `text/`. Exemplos:

```bash
# Apache-2.0
curl -fsSL https://raw.githubusercontent.com/spdx/license-list-data/main/text/Apache-2.0.txt -o LICENSE

# GPL-3.0 (apenas)
curl -fsSL https://raw.githubusercontent.com/spdx/license-list-data/main/text/GPL-3.0-only.txt -o LICENSE

# GPL-3.0 (ou qualquer versão posterior)
curl -fsSL https://raw.githubusercontent.com/spdx/license-list-data/main/text/GPL-3.0-or-later.txt -o LICENSE

# MPL-2.0
curl -fsSL https://raw.githubusercontent.com/spdx/license-list-data/main/text/MPL-2.0.txt -o LICENSE
```

Outras variantes comuns: `Apache-2.0` (ID SPDX `Apache-2.0`), `LGPL-2.1-only`, `LGPL-3.0-only`,
`AGPL-3.0-only`, `BSD-3-Clause`, `Unlicense`, `ISC`. A lista completa está em
<https://spdx.org/licenses/> e os textos em
<https://github.com/spdx/license-list-data/tree/main/text>.

Depois de descarregar:

1. Verifique se o texto traz um template de copyright (ex.: `Copyright [yyyy] [name of copyright
   owner]` no Apache-2.0) e substitua-o por `{{YEAR}}`/`{{HOLDER}}` (ou pelos valores já resolvidos).
2. Preencha os campos de contacto/declaração quando a licença os pedir (ex.: `NOTICE` do Apache-2.0).
3. Atualize o campo `license` do `package.json`/`pyproject.toml` e o badge do README com o **ID SPDX**
   ex.: `Apache-2.0`, `GPL-3.0-only`, `MPL-2.0`.

## Obter a partir do choosealicense.com (com aviso legal)

O [choosealicense.com](https://choosealicense.com/) ajuda a **escolher** a licença e publica os
mesmos textos (sem as instruções em comentário):

```bash
curl -fsSL https://raw.githubusercontent.com/github/choosealicense.com/gh-pages/_licenses/apache-2.0.txt -o LICENSE
curl -fsSL https://raw.githubusercontent.com/github/choosealicense.com/gh-pages/_licenses/gpl-3.0.txt -o LICENSE
curl -fsSL https://raw.githubusercontent.com/github/choosealicense.com/gh-pages/_licenses/mpl-2.0.txt -o LICENSE
```

## Resumo prático

| Licença      | ID SPDX       | Quando escolher                                            |
| ------------ | ------------- | ---------------------------------------------------------- |
| MIT          | `MIT`         | Máxima permissividade, mínima fricção.                     |
| Apache-2.0   | `Apache-2.0`  | Permissiva + cláusula de patente explícita.                |
| MPL-2.0      | `MPL-2.0`     | Copyleft ao nível do ficheiro; boa para componentes.       |
| GPL-3.0      | `GPL-3.0-only` / `GPL-3.0-or-later` | Copyleft forte; derivações têm de ser livres. |

Regra de ouro: a licença escolhida tem de ser compatível com as dependências do projeto e com a
intenção do titular. Em caso de dúvida, consulte um advogado — este README é orientação técnica,
não aconselhamento jurídico.
