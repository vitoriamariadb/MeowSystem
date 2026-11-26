# P303 — o glifo do pack virava código no ZapZap (25/11/2026)

Achado na conferência do bloco `cli-e-bandeja`, antes de integrar. Já existia no `master`.

## O que se mediu
- `scripts/icones_tray_zapzap.sh` veste a bandeja do ZapZap trocando o texto do `_SYMBOLIC = """…"""` dentro do
  `tray_icon.py` do app (no deploy do flatpak). O miolo do SVG do pack entrava ali como texto, por regex, entre as
  aspas triplas.
- Um pack de fora, em `MEOW_PACKS`, com `<title>"""` + `import os; os.system(…)` + `_x = """</title>` no glifo:
  o `tray_icon.py` saiu com a linha do `os.system` como código, o `compile()` do script aceitou, e o
  `meow pack validar` do pack não viu nada. O ZapZap rodaria a linha ao abrir.
- No `master` o mesmo vale pelo `whatsapp.svg` de qualquer pack que declare `icones.bandeja`; o bloco só tornou o
  caminho oficial (`zapzap_tray.svg`, forma cheia entrando sem passar pelo `sed` do traço).
- A barra invertida no fim do miolo também passava: ela come a quebra de linha seguinte e muda o texto que o app
  desenha.
- Nos outros scripts que escrevem a partir de arquivo de pack não há a mesma colagem: o prompt (`pack.py prompt`)
  e o `theme.js` do Spotify (`_spot_injetar_js`) só aceitam pack do repositório; o molde de app de pack de fora cai
  no molde do pack-base (`molde_que_vale`), fora os arquivos que são dado (`color.ini`, `user.css`, `.qbtheme`); o
  `modelo.py` só põe cor `#RRGGBB` e nome sem caractere de controle (o `validar` recusa); o `fzf.sh` só exporta
  cor conferida. O glifo da Steam vai para o `rsvg-convert` e sai PNG: é desenho, não código.

## A causa
O texto de um arquivo de pack era montado dentro de fonte Python por concatenação. Nada separava dado de código:
qualquer byte do SVG podia mudar a forma do arquivo gerado.

## A cura na origem
- O `tray_icon.py` é lido pela `ast`: acha-se a única atribuição de texto a `_SYMBOLIC`, e só aquele nó é trocado,
  pelo `repr()` do SVG montado, gerado pelo Python. O SVG nunca é colado como fonte.
- Antes de escrever, o arquivo novo é lido de novo pela `ast` e comparado ao de fábrica com a constante trocada:
  se qualquer outra coisa mudou, nada se escreve.
- O glifo só é aceito se for traçado (`scripts/glifo_tracado.py`, `recusa(texto)` para quem importa e
  `glifo_tracado.py <glifo.svg>` na linha de comando, rc=2 com o motivo): XML bem formado, sem `DOCTYPE`/`ENTITY`,
  só os elementos de forma (`svg`, `g`, `path`, `circle`, `rect`, `ellipse`, `line`, `polyline`, `polygon`,
  `title`, `desc`), só atributos de traçado e sem `url(`. Chave solta continua recusada, porque o ZapZap faz
  `format` no texto.
- Glifo que é link, ou que pelo caminho real sai do pack, é recusado no ZapZap e na Steam.
- Efeito colateral: o `tray_icon.py` vestido de agora em diante traz o `_SYMBOLIC` como literal de uma linha
  (`'…\n…'`) e não mais entre aspas triplas. Um arquivo já vestido no formato antigo, com o mesmo desenho, dá
  «já estava aplicado» e não é reescrito.

## Como se prova
`tests/bandeja-por-pack.sh`, num pack de fora em `MEOW_PACKS`:
- Três glifos que tentam sair da string: com `"""`, com `\` no fim e com `'''` misturado a aspas duplas. Depois do
  conserto o texto entra como dado no `_SYMBOLIC`, a `ast` do arquivo é a de fábrica tirando a constante, e
  nenhuma chamada nova aparece. Com o script de antes (`fa1248c`), os casos de `"""` e de `\` ficam vermelhos.
- Chave solta, atributo que não é de traçado (`url(`, `onload`), elemento que não é traçado (`image`, `script`)
  e glifo que é link para fora: rc=2, e o arquivo do app fica byte a byte o de fábrica.
- `icones.bandeja.desenhos` com `../`, caminho absoluto ou link: o pack inteiro é recusado e nada de fora entra.

## Na integração
O glifo da Steam passa pela mesma checagem de traçado (`scripts/glifo_tracado.py`, chamada em `scripts/icones_tray_steam.sh`): sem ela, um
`<image>` no glifo de um pack de fora embutia no PNG da bandeja um arquivo vizinho do SVG temporário. Um caso em
`tests/bandeja-por-pack.sh`, vermelho antes (rc=1, PNG escrito) e verde depois (rc=2, nada escrito).
