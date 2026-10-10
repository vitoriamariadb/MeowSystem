# P78 — Pack é dado não confiável; o gate volta a ficar verde

**Branch:** `sprint/p78` (a partir de `integracao/leva-g`) · **Fontes:** seções «Segurança» de
`P73-seletor-e-acervo.md` e `P74-pack-dracula-completo.md` (no dev), `ESTADO.md` passo 2,
`03-integracao-onda-1.md` («Aberto» 1 e 2), `02-decisoes.md` (7 e 8).

## Por que
Seis alertas automáticos de segurança nos commits da onda 1: `scripts/pack.py` (×2, caminho e
parser diferencial), `scripts/icones_apps_dracula.sh` (caminho), `scripts/som.sh` (symlink),
`app/servidor.py` (SVG não confiável servido na mesma origem), `bin/meow` (caminho de busca não
confiável / execução de código). Um pack pode ser importado de terceiros: tudo que vem de
`packs/<id>/`, de um `.meowpack` ou do `icones-escolhidos.map` é dado não confiável.

## Tarefas
1. **Varredura**: todo `cp`, `ln`, `install`, `cat`, `tar`, `rsvg-convert`, `open()`, `source`,
   `.`, `bash`, `python3` sobre caminho vindo de pack, mapa, conf, cwd, PATH ou HOME, em `bin/`,
   `lib/`, `scripts/`, `app/`. Para cada um: seguro, ou corrigido.
2. **Regra única** (um helper em shell e um em Python, usados por todos): `realpath` dentro da
   raiz permitida, symlink para fora recusado, nome de destino de conjunto fechado; validar e
   usar a MESMA forma normalizada. Linha ruim é pulada e contada, sem abortar.
3. **Servidor**: SVG/PNG de acervo com `Content-Security-Policy: default-src 'none';
   style-src 'unsafe-inline'; sandbox`, `X-Content-Type-Options: nosniff`, nunca inline no DOM.
4. **`bin/meow`**: nenhum script executado por caminho relativo ao cwd ou achado no PATH quando
   existe o do repositório; nenhum arquivo de pack executado.
5. **Decisão 7**: `doctor_consertar` declara `rede: True`, mostra o selo, sem caixa de pergunta; o
   gate (`tests/app-completo.py`) passa a exigir o selo para reparo e a pergunta só para ação
   opcional que baixa.
6. **Decisão 8**: o gate e qualquer runner de QA recusam subir o painel com o HOME real sem
   `MEOW_QA_HOME_REAL=1`.
7. **Abertos da integração**: teste para `ICONES_DRACULA` ausente no passo do pack;
   `portabilidade.sh` (o `cosmic-vivo.md:198`) e `doctor-so-le.sh` com HOME de brinquedo.

## Prova
- `tests/pack-malicioso.sh` (novo): pack com `../`, caminho absoluto, symlink para `~/.ssh`,
  nome com `/`, SVG com `<script>`/`onload` — nada lido nem escrito fora da raiz, nada executa,
  token não vaza (curl na URL do SVG mostra os cabeçalhos).
- `tests/todos.sh` inteiro verde, inclusive o gate.

## Achados para a próxima leva
- ~~Conteúdo dos temas de app não é filtrado, só o caminho.~~ **Curado na conferência** para os
  dois que viravam comando: o modelo de kitty e o de GNOME Terminal de um pack só levam chave de
  cor (e `visible-name`, e a seção `[/]`); `shell`, `map … launch`, `geninclude`, `include`,
  `custom-command` e outra seção são pulados e contados (`_kitty_so_cor`, `_gt_so_cor`). Telegram,
  Discord e OnlyOffice continuam passando inteiros: nenhum deles executa o que o tema diz, mas o
  CSS do Discord pode buscar na rede (`@import`), como o próprio tema Dracula faz.
- **O VS Code instala a extensão que o pack nomeia** (achado da conferência, gravidade alta). O
  `apps.vscode.origem` traz `extensao`, `url` e `sha256`, e o módulo baixa o `.vsix` e roda
  `--install-extension`; sem `url`, instala pelo id da Marketplace. O sha256 é do próprio pack:
  prova integridade, não confiança. Uma extensão é código que roda com a conta de quem usa a cada
  abertura do editor, então um pack de terceiro escolhe código para rodar. Cura a decidir por quem
  usa: só pack do motor (`packs/` do repositório) instala extensão sozinho, ou uma lista fechada de
  publicadores, ou a pergunta da P46 para esse caso.
- **Mapa com CRLF perde as linhas em silêncio-contado.** Um `pastas.map`/`mimetypes.map` escrito
  no Windows tem `\r` no glifo, e o `meow_nome_seguro` o recusa: a linha é pulada e contada, nada
  sai da raiz, mas o pack inteiro fica sem pastas. O `pack.py` (`splitlines`) aceita o mesmo
  arquivo; o shell não. Tirar o `\r` no leitor de mapa do shell.
- **O `_proibido` do `.meowpack` olha só `.sh` e `#!` no primeiro byte**: um `leia.txt` que começa
  com BOM e `#!` entra (medido). Nada do pack é executado nem fica executável (chmod 644), então
  não é porta; anotado para a régua não prometer mais do que mede.
- **Painel de pé que não é desta leva**: o PID 1985165, `app/servidor.py` do checkout principal,
  de 09/10 18:52, com o HOME em `scratchpad/pp/casa`. Não é desta conferência, e por isso não foi
  derrubado.
- **`rsvg-convert` sobre SVG de pack** (semente de papel de parede, prévias): o librsvg resolve
  `<image href>` relativo ao arquivo; não medi se um symlink dentro do pack o leva para fora.
- **Duas políticas para a linha ruim.** No `validar` (inclusive o silencioso, o do motor), um alvo
  de `apps.map` que sai da raiz recusa o pack INTEIRO (a máquina veste o padrão); nome de destino
  torto e linha de `pastas.map` torta são pulados e contados pelo consumidor. Decidir se o alvo
  também passa a ser pulado e contado.
- **`pack.py sincronizar`** abre os caminhos da coluna `lido de` do `PROCEDENCIA.md` do pack (só
  para comparar sha256, nada sai). Saiu do doctor na P75; continua no verbo manual.
- **O filtro de nome do `_dracula_pares_do_mapa` fica no `awk`**, com o mesmo conjunto do
  `meow_nome_seguro`, porque três testes extraem a função verbatim e a rodam sem o lib/comum.sh.
  Se os testes passarem a carregar o lib, o `awk` pode chamar a regra única.

## Alerta acrescentado em 10/10, 00:20 (revisão automática): injeção de escape de terminal em `bin/meow`

Para o conferente: confirmar que o `68c8ab3` cobre TODO lugar do `bin/meow` (e de `lib/`,
`scripts/`) que imprime texto vindo de pack, mapa, `.meowpack`, nome de arquivo ou conf — nome,
autor, descrição, tags, nome de desenho, linha pulada. Regra: tirar `\x00-\x1f`, `\x7f` e
`\x9b` (CSI de 8 bits) antes de imprimir, num helper só (`meow_texto_seguro`), e teste com um
pack cujo `nome` tem `\e]52;c;…\a` (OSC 52 escreve no clipboard) e `\e[2J`.

**Resposta da conferência (10/10).** Duas portas, e não uma lista de lugares: na ENTRADA, o
`validar` recusa caractere de controle (C0, DEL, C1) em toda chave e valor do `pack.json` e da
paleta, recusa o `pack.json` que não é UTF-8 (o `\x9b` solto), e o `ler_meowpack` recusa nome
de entrada e linha de MANIFESTO com controle — então nome, autor, descrição, tags e flavor de
pack que passa não carregam escape a lugar nenhum. Na SAÍDA, o que imprime texto de pack que
NÃO passou pelo `validar` vai pelo `meow_texto_seguro` (lib/comum.sh): o `meow pack listar`
(nome, id e pasta de todo pack da raiz) e o aviso de linha pulada do `icones_pastas.sh` e do
`icones_mimetypes.sh`. O `_dracula_pares_do_mapa` troca por `?` no próprio `awk`, porque os
testes o extraem sem o lib. Medido com `\e]52;c;…\a`, `\e]0;…\a`, `\e[2J` e `\x9b[2J`:
`validar`, `info`, `listar`, `remover --seco`, `caminho`, `exportar` e `importar` (CLI e
`/api/pack-importar`) — zero ESC cru. O nome de desenho que vai para aviso já passou pelo
`meow_nome_seguro`; as recusas do pack.py citam o valor em `repr`.

## Alertas de 10/10, 00:35 (revisão automática do 208bc89)

1. **`lib/comum.sh` — `meow_texto_seguro` ainda deixa escapar.** O filtro por regex em bytes só
   pega `\x9b` depois de ASCII: `\x9b\x9b`, `\xff\x9b`, `\xe2\x9b` truncado e os outros C1 crus de
   8 bits (`\x90` DCS, `\x9d` OSC, `\x9e`, `\x9f`) passam quando não formam UTF-8 válido. Cura:
   decodificar como UTF-8 com substituição (byte inválido vira `?`) e SÓ ENTÃO tirar C0, DEL e
   C1 por ponto de código (U+0080–U+009F) — p.ex. `python3 -I -c` ou `iconv -c` + `sed`. Teste com
   os quatro casos acima e com `ě` (`\xc4\x9b`), que tem que sobreviver.
2. **`scripts/icones_pastas.sh` — controle que regrediu.** A revisão acusou que uma conferência
   que existia antes da P78 ficou mais fraca no `2e16c94`/`68c8ab3`. Comparar linha a linha com
   `af3159f` e devolver a conferência antiga junto com a regra nova (nada de trocar uma pela outra).

**Resposta da conferência (10/10).**
1. O `meow_texto_seguro` passou a contar por letra: lê o texto como UTF-8, byte que não forma
   UTF-8 vira `?`, e só então saem C0, DEL e C1 por ponto de código. Medido: `\x9b\x9b[2J`,
   `\xff\x9b[2J`, `\xe2\x9b[2J` e `\x90`/`\x9d`/`\x9e`/`\x9f` crus saem como `?`; o `ě`
   (`\xc4\x9b`) e o travessão sobrevivem. A sonda está no `tests/pack-malicioso.sh` (vermelha
   com a versão em `sed`, verde com esta).
2. A conferência que enfraqueceu era a do `icones_mimetypes.sh` (o `[ ! -L ]` da P74, «link não
   entra»), trocada pelo `meow_dentro` no `2e16c94`. Voltou, junto com a regra nova: o desenho
   não pode ser link E o caminho copiado é o realpath conferido. No `icones_pastas.sh` (que no
   `af3159f` não tinha conferência de link nenhuma, só a cópia crua) a mesma régua entrou agora,
   para as duas pastas de desenho valerem igual; nenhum pack publicado tem link.
