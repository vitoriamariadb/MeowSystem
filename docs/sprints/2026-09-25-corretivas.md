# Leva D — as corretivas do uso como usuário (25/09/2026)

Em 25/09, entre 11:38 e 11:55, o painel real foi usado como uma pessoa usaria:
escolher no cartão, «Salvar e aplicar», esperar a gaveta, fotografar o painel e
o desktop antes e depois. De 15 ações, 14 fizeram o que prometem. Esta leva
fecha o que falhou e o que as reconferências da leva C deixaram anotado.
Decisão (25/09): «lança as sprints corretivas de tudo».

---

# P58 — O vidro segue o COSMIC instalado

### O que medi

- O `alpha_map` ao vivo (`~/.config/cosmic/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map`,
  gravado em 17/09 pelo COSMIC atualizado) dá `very_high_2: 0.52615` (alpha 86).
- A captura `packs/dracula/temas/capturados/dracula-mauve` traz o mapa antigo:
  `very_high_2: 0.6662` (alpha AA), e `transparent_background` `#383A4CAA`.
  O `frosted` é `VeryHigh2` nos dois.
- O tema aplica a cor da captura e deixa o `alpha_map` da GUI: na tela o vidro
  fica em AA (67 %), com o nível escolhido pedindo 86 (52 %).
- O `doctor` (`scripts/vidro.sh`, `conferir_receita`) diz «a captura existe e
  traz os dois coerentes: meow tema dracula-mauve» — e a captura já está
  aplicada (189 arquivos conferem): o conselho é circular.

### O que fazer

1. Ao aplicar um tema, as cores que carregam o alpha do vidro saem do
   `alpha_map` INSTALADO para o nível `frosted` da receita. Quais campos são
   esses, meça no `ThemeBuilder` do libcosmic, como a P48 fez com o acento (o
   oráculo dela está descrito no commit ea048f9). O mapa da máquina é a verdade
   da versão do COSMIC; o da captura é fotografia de outra versão.
2. Com um COSMIC cujo mapa é o da captura, o resultado é byte a byte o de hoje.
3. O `doctor` diz o que de fato resolve, e para de mandar reaplicar o que já
   está aplicado.

### Como conferir

Numa casa de brinquedo com o `alpha_map` novo, aplicar `dracula-mauve` grava o
`transparent_background` com alpha 86 para `VeryHigh2`, e o `vidro.sh` confere
sem aviso. Com o mapa da captura, os bytes são os de hoje.

### Território

`scripts/aplicar_tema.sh` (ou um passo que ele chame), `scripts/vidro.sh`, o
derivador de cores (`scripts/derivar_acento.py` ou irmão), `tests/`.

---

# P59 — Toda variante aplica

### O que medi

- Com `FLAVOR=alucard` e «Salvar e aplicar», a gaveta disse «APLICOU, COM
  PENDÊNCIA»: «não há captura para 'alucard-mauve'». O desktop não mudou nada.
- A prévia «Como fica» (Cor e tela) desenhou uma tela CLARA antes de salvar.
- Depois de aplicar, o painel se vestiu de claro, e o desktop continuou escuro.
- A gaveta terminou com «algumas dessas precisavam de root: `sudo -v &&
  ./install.sh`» — a tela de login pulou porque o tema pulou (sem captura), não
  por root.
- A P48 registrou o mesmo caso para `frappe` e `macchiato` (Catppuccin) e
  `alucard` (Dracula): nenhuma captura de que derivar.

### O que fazer

1. A captura de um flavor sem captura sai de uma captura do MESMO LADO (claro de
   claro, escuro de escuro), trocada cor por cor pelas paletas dos dois
   flavors, slot a slot — o caminho da P56 nas pastas e da P48 no acento. O
   `alucard` sai do `latte`; `frappe` e `macchiato`, do `mocha`. Meça, com o
   oráculo do libcosmic, o que o `ThemeBuilder` deriva além da paleta (as
   neutras, o vidro) e diga o que não se deriva.
2. A prévia «Como fica» só promete o que o instalador aplica.
3. A frase do fim do instalador só manda a um comando quando o motivo do pulo é
   root de verdade. Pulo por falta de captura diz isso, sem terminal.
4. Com a captura derivada, painel e desktop combinam; se ainda sobrar variante
   sem tema, a página avisa em vez de se vestir sozinha.

### Como conferir

Numa casa de brinquedo, `FLAVOR=alucard` aplica o tema do COSMIC (e a tela de
login, com o sudo falso pulando por root, dito como root); `frappe` e
`macchiato` idem; com `dracula`, `mocha` e `latte`, os bytes são os de hoje.

### Território

O derivador (`scripts/derivar_acento.py` ou um irmão), a busca da captura
derivada em `scripts/aplicar_tema.sh`, a frase do fim do `install.sh` e a
`etapa_tema`, a prévia de Cor e tela em `app/pagina/`, a lista do que aplica no
`app/servidor.py`, `tests/`.

---

# P60 — Os desenhos do pack no seletor de ícone

### O que medi

- A ficha de um programa (Ícones › Um ícone por programa) busca em
  `assets/icones/{arcticons-apps, autorais, convertidos-apps, catppuccin-apps}`
  (`app/servidor.py`, `_api_glifos`).
- O pack Dracula tem 396 desenhos: `apps/` 72, `autorais/` 22, `pastas/` 7 e
  `biblioteca/` 295 (alien, arcade, astronaut, magic, witch…). O `apps.map` usa
  52 da biblioteca; os outros 243 não aparecem em lugar nenhum.
- Na ficha do Google Chrome, a busca «chrome» oferece uma opção só, o traço do
  Arcticons. O desenho do Dracula aplicado hoje não é escolhível.
- Com o Dracula no ar, o grupo «Catppuccin» continua no acervo da busca.

### O que fazer

1. A busca oferece os desenhos do PACK NO AR (biblioteca, programas, autorais),
   lidos do pack — do `pack.json` e das pastas dele, não de uma lista —, num
   grupo com o nome do pack.
2. O acervo de um pack que não está no ar não entra (o grupo Catppuccin só com o
   Catppuccin no ar).
3. Escolher um desenho do pack grava a escolha num lugar que vença o `apps.map`
   do pack e não vaze para outro pack (meça o molde: o `apps-arcticons.map` do
   repositório guarda a escolha do traço).
4. A miniatura mostra o desenho na cor que ele terá no tema.

### Como conferir

Numa casa de brinquedo com o Dracula no ar, a busca «alien» acha o desenho da
biblioteca; escolhê-lo para um programa o põe no tema instalado; trocar para o
Catppuccin não carrega a escolha do Dracula.

### Território

`app/servidor.py` (`_api_glifos`, `_api_app_icone`), a ficha em
`app/pagina/app.js`, o script que monta os desenhos do pack no tema
(`icones_apps_dracula.sh` ou o que ler o `apps.map`), `tests/`.

---

# P61 — As regras que sobraram

1. **VS Code conta só pack válido.** `_meow_vscode_icones_de_todos`
   (`assets/temas-de-apps/vscode/manifesto.sh:743`) conta toda pasta com um
   `pack.json`, sem o `validar`: um pack inválido que declare
   `apps.vscode-icones.esquema` faz o aplicar reescrever o `iconTheme` (P55,
   reconferência). É a regra que a P55 levou ao Obsidian.
2. **Obsidian sem pasta vazia.** Sem rede, o `aplicar` cria
   `~/.local/share/meowsystem/temas-de-apps/obsidian/` vazia (o `mkdir` vem
   antes do download) e o desfazer diz «já estava sem o Dracula» e a deixa; uma
   sobra de descida velha sobrevive a um aplicar que desce (P55, nota 6).
3. **O flavor padrão é uma regra só.** Com `FLAVOR` vazio a página cai no
   flavor padrão do pack no ar (P56), e nove scripts caem em `${FLAVOR:-mocha}`
   (`fzf`, `completar_icones`, `greeter`, `midia`, `construir_icones`, `logo`,
   `icones_apps_arcticons`, `terminal`, `wallpaper`), além do `bin/meow`; o
   `meow status` mostra `pastas cat--mauve`. A regra mora no `lib/comum.sh` e sai
   do pack no ar.
4. **A lixeira dos flavors do Catppuccin.** O `recolorir_lixeiras`
   (`scripts/construir_pastas.sh`) pula só o papel do Mocha: com `latte`,
   `frappe` ou `macchiato`, a lixeira toma o símbolo como tom (latte-mauve:
   `#4C4F69 #7425DB`, em vez de `#7425DB #8839EF`). Consertar muda os bytes
   desses três flavors — é conserto; o `mocha` fica igual.
5. **O corpo das pastas especiais do Dracula na paleta.** As 5 pastas especiais
   (`packs/dracula/icones/pastas/`) têm corpo `#433F4D`/`#534B62`, fora da
   paleta do Dracula. Continuam sem recolorir pelo acento (decisão do pack), mas
   o corpo passa ao slot da paleta mais próximo — meça e diga qual, com linha no
   `PROCEDENCIA.md`.

### Território

Os manifestos de `vscode` e `obsidian`, `lib/comum.sh` e o padrão de flavor dos
scripts listados, `scripts/construir_pastas.sh` (só a lixeira), os desenhos de
`packs/dracula/icones/pastas/` e o `PROCEDENCIA.md`, `tests/`.

---

# P62 — Os textos que ainda mentem

1. **Ensaio que diz «aplicados».** O ensaio do OnlyOffice terminou com «ok
   aplicados: onlyoffice» — a classe do achado 11, que a P50 consertou só no
   instalador. No seco, o resumo do `aplicar_apps.sh` diz «aplicaria».
2. **Terminal onde há botão.** «Vestir os programas agora» sugere «resolve: meow
   apps aplicar onlyoffice», e a Início tem «Trocar pelo tema do pack» / «Manter o
   meu». Na gaveta, a frase aponta o botão (o `--onde` da P50/P57).
3. **Pastas em Catppuccin com o Dracula no ar.** O passo «Pastas especiais em
   Catppuccin» (`install.sh:2417`); «devolvendo as pastas especiais ao mauve» e
   «as pastas seguem mauve» (`scripts/icones_pastas.sh:324` e `:327`); «(pastel
   em scalable/places)» (`scripts/construir_pastas.sh:839`); e o comentário
   velho do `construir_pastas.sh` que a reconferência da P56 apontou (~463).
4. **A tabela do `meow apps`.** O `bin/meow` pinta o código 3 como «--», e o
   `meow apps conferir` diz «sem tema neste pack (Sem Apps)» três vezes (P55, nota
   7); «o módulo grava com o .css» (`bin/meow:874`) não vale para o Dracula.
5. **Docs e comentários.** `docs/PACKS.md:1116` traz `"obsidian": { "herda":
   "catppuccin" }`, e nenhum pack usa `apps.<app>.herda`; o comentário
   incompleto de `scripts/logo.sh` (~316) e os comentários velhos das unidades
   do systemd (P57); o cabeçalho do `lib/noite.sh` diz que o `e_noite` do
   `wallpaper.sh` passou a usar a lib, e ele tem o próprio (P54).

### Território

As frases do `install.sh`, do `scripts/icones_pastas.sh` e do
`scripts/construir_pastas.sh` (só texto e comentário), o resumo do
`scripts/aplicar_apps.sh`, a tabela e os textos do `bin/meow`, `docs/PACKS.md`,
os comentários de `scripts/logo.sh`, de `systemd/` e do `lib/noite.sh`, `tests/`.
