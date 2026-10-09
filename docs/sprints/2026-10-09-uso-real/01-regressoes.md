# Regressões e pedidos que não valem hoje — 09/10/2026

Conferência consolidada, feita só com leitura. Cinco conferentes leram 258 mensagens antigas
de quem usa e conferiram 214 pedidos no estado atual (dev, HEAD `ff02037`). Desses, 63 não
valem hoje. Depois de juntar as repetições, sobram **37 pedidos distintos**.

**Regressões confirmadas: 4.** Os conferentes marcaram 5 linhas como "regrediu". Refiz a prova
de cada uma: duas eram o mesmo pedido em datas diferentes, e as 4 que sobraram se sustentam.
Três delas têm a mesma causa (a chave `ICONES_BASE`).

O que derrubei ou corrigi na prova dos conferentes:

- `85f80a3` **não** desfez as pastas. Depois dele o doctor ainda dizia `ok pastas … derivada de
  'cat-mocha-mauve' com a paleta do pack no ar` (doctor.log:1080).
- `ae18042` também não desfez sozinho. Ele mudou a base para `~/.local/share/icons`, mas só
  quebrou depois que o conf voltou a ter a linha `ICONES_BASE`. O defeito já estava lá antes
  (`BASE_DIR="/usr/share/icons/$BASE"`, de `1db6506`, 04/08). O gatilho foi o conf ser
  regravado em 26/09.
- `6c1c992` não é regressão da "Regra 8". Ele cumpriu a decisão de quem usa em 24/09:
  "Aposentar tudo". A Regra 8, de 23/09, foi substituída por essa decisão.

Estados: **regrediu** (funcionou e voltou a quebrar) · **parcial** · **nunca feito** ·
**não verificável**. "×N" quer dizer que o pedido apareceu em N datas.

---

## Ícones

| # | pedido (palavras e datas) | estado | prova | commit que desfez |
|---|---|---|---|---|
| I1 | ICONES_BASE: **"Tirar a linha do conf"** (a base vem do pack, pinada), 24/09. Também **"o pack traz a base"** (24/09) e a cor das pastas `ICONES_PASTAS="cat-dracula-${ACCENT}"` no "módulo completo do dracula" (16/09). ×3 | **regrediu** | `~/.config/meow/meow.conf:399` diz `# ICONES_BASE saiu em 24/09 (P41)`, e a `:1841` traz `ICONES_BASE="MeowSystem-Icons-Base"` com o comentário do exemplo. Os três backups de 24/09 só têm a linha antiga, `:399` `Dracula-Icones`. O manifesto registra a última escrita do conf em `2026-09-26T00:49:47`. No disco, `/usr/share/icons/MeowSystem-Icons-Base` não existe e `~/.local/share/icons/MeowSystem-Icons-Base` existe. | Não foi um commit. Foram dois passos sobre a linha comentada. (1) `scripts/migrar_conf.py` (`30f395b`) devolve toda chave do exemplo que esteja ausente (`blocos_faltando`), e linha comentada conta como ausente. O exemplo ainda traz `ICONES_BASE="Papirus-Dark"  # tema herdado como fallback` (meow.conf.exemplo:499). (2) O painel regravou só o valor e manteve o comentário, porque `meow_conf_texto_definir` troca o valor na linha. O valor gravado é a opção que o painel oferece como "a base do pack" (app/servidor.py:1462-1482, desde `e639f4d`/`85f80a3`). Antes disso tudo, `ae18042` mudou a base de lugar sem atualizar quem a procura. |
| I2 | Pastas coloridas do pack (efeito de I1), 16/09 | **regrediu** | Em `~/.local/state/meowsystem/doctor.log`, a linha 1080 é a última `ok pastas`. Da 1163 até a 1877, em 7 passadas seguidas (28/09 a 09/10, pelo journal do `meow-doctor.service`), sai `-- pastas` com `MeowSystem-Icons-Base não está instalado — pastas coloridas puladas`. A causa está em `scripts/construir_pastas.sh:107-108`, que lê a chave crua e monta `/usr/share/icons/$BASE`. A regra "MeowSystem-Icons-Base = a base do pack" mora só em `pack.py:_base_escolhida` (pack.py:2080-2088), e só `construir_icones.sh` e `bin/meow` a consultam. | o mesmo de I1 |
| I3 | P21: **"Usar o programa não pode sujar o repositório"** (21/09). O painel gravava a curadoria dentro do clone. | **regrediu** | `git status` mostra ` M packs/dracula/icones/apps.map`, e o diff é `+org.kde.ghostwriter : apps/org.gnome.gitlab.somas.Apostrophe.svg   # ghostwriter — escolhido no painel`. Quem grava é `app/servidor.py:8914-8971` (`_escolher_do_pack`). A tela diz: "A escolha fica guardada no projeto: vale em toda máquina que instalar daqui" (app.js:3131). O spec da P21 (docs/sprints/2026-09-21-packs-modulares.md, P21 item 2) só permitia gravar no pack "por gesto explícito, não por uso". | `171dedb` (25/09, "a escolha mora no mapa dele"), refinado em `b7afe73` (P64) |
| I4 | **"centralizar os SVGs, e alterando lá alteraremos o resto"** (23/09). **"os svgs… mais de 300 do tema dracula… não estão no pack"** (23-24/09). **«Nosso pack de 300 icons aparece pro user pra que ele possa escolher um deles?»** (25/09, P60). ×3 | parcial | O encanamento funciona (`tests/fonte-unica.sh`, `meow icones fonte`), e o pack tem 72 + 295 + 22 desenhos. Mas `_api_glifos` corta em `limite = 60` (servidor.py ~9174). O print `ux/06` mostra só 60 no grupo Dracula, sem a biblioteca, e a busca "firefox" acha um desenho de traço (`ux/07`; achados 1, 2 e 24 de 00-achados). | — |
| I5 | **"centralizemos todos eles dentro das pastas packs… tudo tem que ficar lá"** e **"Alterar o desenho no pack deve alterar todos os derivados"** (21/09, ×2) | parcial | `assets/icones/` ainda tem 205 SVG e 13 mapas `.map`. O `_nota_apps` de `packs/catppuccin/pack.json` admite que as escolhas de ícone ficam nos mapas do motor. | — |
| I6 | **"centralizarmos todos os svgs e pngs do meu pop os original pra que tenhamos um antes e depois"** e **"separarmos o meu tema de icons antigo"** (12/09, ×2) | parcial | No repo só está a folha `ANTES-E-DEPOIS.png`. O `e789d74` admite "12 dos 21 PNG de origem fora do disco". O `apps-resgatados.map` aponta para `~/.local/share/icons/Dracula-Icones`, que não existe mais. | — |
| I7 | Pastas a partir do Nautilus: **"que os agentes gerem as demais variações de pastas"** (16/09) | parcial | `packs/dracula/icones/pastas/` tem 7. Faltam `folder`, `user-home` e `user-desktop`, que hoje vêm do Papirus. | — |
| I8 | **"Syncthing eu ia pedir pra refazer…"** / **"os novos tão aprovados. manda ver"** (16/09) | parcial | `apps.map:415` está como `# syncthing : ?`. O `assets/icones/resgatados/syncthing.svg` está fora dos mapas, e spotify e discord também. | — |
| I9 | **"precisa usar um svg pra cada logo do theme pack, o icon do menu de lançamento"** (21/09) | parcial | O ícone do lançador é `meowsystem-painel-$FLAVOR.svg` (completar_icones.sh:204), não o `logo.svg` do pack. docs/PACKS.md:1967 admite: "O ícone do lançador ainda não é o logo." | — |
| I10 | P69: com MODO=claro, o traço do dock e as pastas usam a paleta do lado que a tela veste (26/09) | nunca feito | Não há branch nem commit. `lib/comum.sh:727` (`meow_flavor`) não olha o MODO. | — |
| I11 | Artifact de curadoria com 5 botões (16/09) | não verificável | Era um artifact de sessão. Restam `docs/folhas/meow-icones-curadoria.html` e o rascunho `.trabalho-icones/`. | — |

## Doctor e status

| # | pedido | estado | prova | commit que desfez |
|---|---|---|---|---|
| D1 | **"nenhuma feature pode mandar o usuário consertar à mão"** (21/09, P2, ×2) e **"no feature may send the user to fix things by hand"** (24/09). ×3 | **regrediu** | Em `ux/19-conferir-saida.txt`, a mesma passada imprime `!! completar MeowSystem-Icons-Base não está instalado` + `sudo apt install papirus-icon-theme`, depois `instale com: sudo apt install papirus-icon-theme`, e termina em `ok nada a consertar`. A receita está **errada**, porque `/usr/share/icons/Papirus` existe. Até a linha 1080 do doctor.log, o completar dizia `ok … 4 autorais e 1 apelido(s)`. Hoje ele diz `!!`, e o auto-reparo de 28/09 marcou `~~ completar` sem conseguir consertar. | O texto é antigo (completar_icones.sh:474, construir_pastas.sh:431). Ele voltou a aparecer com I1. |
| D2 | **Tela que mente**: "o que a tela diz é o que o código faz" (23/09). P48: "a tela não diz «aplicou» quando o tema não foi aplicado" (24/09). P70 item 2: "o status nomeia o tema errado" (26/09). P70 item 3: "o status não chama de divergência o que foi pulado" (26/09). ×4 | parcial; P70 nunca feito | `meow status` diz `ativo alucard-mauve (o alvo é dracula-mauve)`, e o doctor diz `tema 'dracula-mauve' já aplicado (189 arquivos conferem)`. Isso acontece porque `tema_ativo` (bin/meow:304) fica com a primeira captura que confere. O status lista só linhas `--` como divergência e manda rodar `--consertar`, mas o doctor diz "nada a consertar". | — |
| D3 | Comparação com Dracula_OS-Theme: **"Aposentar tudo"** (24/09). A Regra 8 de 23/09 ("mostra a divergência e espera o gesto") foi substituída por essa decisão. | parcial | Nada lê mais o Dracula_OS-Theme. Mas o verbo `meow pack sincronizar` continua (bin/meow:4454), e o doctor o chama em toda passada (bin/meow:2425). | O `6c1c992` foi **derrubado** como "desfez": ele cumpriu a decisão de quem usa. |

## Packs e temas

| # | pedido | estado | prova | commit |
|---|---|---|---|---|
| T1 | O pack Dracula veste tudo, sem Catppuccin. **"onde o nosso faltar preciso que vc crie"** (19/09). **"aqui deveria ter tudo do theme dracula"** (22/09). "Catppuccin que sobrou" (23/09). Aba Terminal sem Catppuccin (24/09, P51). **"Tudo do tema foi aplicado? ao resetar o pc terei tudo conforme o tema dracula?"** (26/09). ×5 | parcial | `~/.config/starship.toml:94` tem `palette = 'catppuccin_mocha'` com `PACK="dracula"`. O doctor diz `preset catppuccin-powerline` e `123 tipos de arquivo já vestidos de Catppuccin macchiato`. `scripts/prompt.sh` não conhece pack. servidor.py:3846, 7218, 7494 e 10884 ainda caem em `mocha`. | — |
| T2 | Temas dentro dos apps vêm do pack no ar, com Obsidian em Dracula (pedido dela de 08/09, retomado em 25/09) | parcial; **oscila** | O doctor.log registra 10 vezes `cssTheme='Catppuccin' -> 'Dracula Official'`, com backups em 28/09, 30/09, 02/10, 07/10 e 09/10. O cofre é git e tem `"Catppuccin"` no HEAD. | — |
| T3 | **"aqui pros sons"** (tema de som Dracula, 16/09) | parcial | Só entrou o sino sintetizado. Os 25 `.oga` ficaram fora, e scripts/som.sh:59-70 explica o motivo. | — |
| T4 | qBittorrent: **"pq ou não aplicou ou pq o log mentiu?"** (21/09). Ritual da Aurora: **"mesma coisa do spellbook"** (23/09). ×2 | parcial | `qbittorrent/manifesto.sh:147-191` ainda depende do escritor da Aurora (`MEOW_QBT_AURORA_FONTE` vazio → `MEOW_SEM_DEPENDENCIA`). O pack não traz o tema. | — |
| T5 | Temas de kitty, gnome-terminal, Telegram, Discord, OnlyOffice e os 30 overrides de .desktop: **"Migrar para o pack"** (24/09) | parcial | Os 5 temas entraram. Os 30 overrides não (`_nota_modelos`: "desvio da decisão de 23/09"). | — |
| T6 | **"instalar o Vesktop para o Discord também vestir o Dracula"** (26/09) | parcial | O Vesktop está instalado e o `.theme.css` existe. Mas o `settings.json` não tem `enabledThemes`, então o tema não foi ligado. | — |
| T7 | **"papéis de parede 4k feitos em .svg"** no tulip-orchid (15/09) | parcial | `pack.json` `origens.wallpapers` traz `"ignorar": ["svg"]`, e não há rasterização. | — |

## Interface (painel)

| # | pedido | estado | prova | commit |
|---|---|---|---|---|
| U1 | P7: **teto de 220 caracteres; a legenda "desenho, não é a sua tela" vira UMA frase** (21/09). **"A interface é moderna estilo show dont Tell"** (09/10). ×2 | parcial | As legendas longas estão nos prints 03, 12 e 13 (cerca de 380 caracteres). O cartão do pack tem um bloco monoespaçado "Próprio / herdado / do motor" (01). Logo do sistema tem seis controles para um gato, e a prévia "No terminal" é um contorno vazio (13). `tests/app-acessibilidade.py` isenta as "12 legendas de desenho (231 a 545 caracteres)". | — |
| U2 | **"Deixa dois botões: «Restaurar ao Padrão» e «Aplicar»"** (21/09) | parcial | `app.js:1916` ainda tem `— deixar como está —` e `app.js:1933` o placeholder `Deixar como está`. | — |
| U3 | **"botão impossível de clicar devido à largura da imagem"**: balão que não cobre o vizinho (21/09) | parcial | `mostrarBalao` (app.js:681) não ancora no menu lateral. No print 11, o balão cobre o item «Ícones». | — |
| U4 | "ela/dela" vira "você" (24/09, achado 13) | parcial | Ainda aparece em onlyoffice/manifesto.sh:220, kitty:254 e gnome-terminal:111 ("trocar é decisão dela"), em app.js:2958 e em prompt.sh:272. | — |
| U5 | Dia e noite: os pares de horário não apontam um para o outro (24/09, achado 38) | parcial | Continuam três agendas para o mesmo conceito (achado 25 de hoje). | — |
| U6 | «Versão do tema do ponteiro» não confunde com o ponteiro do pack (24/09, achado 20) | parcial | O campo continua na tela, agora com uma nota explicando. | — |
| U7 | **"abrir cada aba como user… e colocar como gate"** (24/09). **"faça como user… tira prints antes e depois"** (25/09). **"consertos: Todos, agora"** (24/09). ×3 | parcial | `tests/todos.sh:106-117` usa o `app-completo.py` como gate. Mesmo assim, o uso real de hoje achou 30 defeitos que ele não pegou. Os prints de 25/09 não estão no disco. | — |
| U8 | **"tem esse erro quando não estamos tocando nada na interface"** (19/09) | não verificável | O print original não existe. O `/api/pulso` só falha quando o servidor troca de porta. | — |
| L1 | Jogos: «1 jogos», grade vazia, lista que faça sentido (24/09, achado 43) | parcial | A aba diz "Nenhum jogo instalado" e "2 jogos têm atalho", e conta a própria Steam como jogo. | — |

## Produto, segurança, sistema e documentação

| # | pedido | estado | prova | commit |
|---|---|---|---|---|
| S1 | A senha do sudo dada no chat **não vai para arquivo, log ou commit** (23/09 e 24/09, ×2) | parcial | O MeowSystem está limpo. `Migração-OS/RETOMAR.md:44` tem a senha em texto puro (o arquivo é de 19/09 e nunca foi limpo). `~/.config/zsh/.aurora-askpass-secret` foi criado em 30/09, **depois** da regra. Não sei qual sessão o criou. | — |
| S2 | **"quando ela fez ela fez pra ela. mas temos que transformar em produto oficial. e utilizável por qualquer um. os meus tambem. até em documentação."** (24/09, ×2) | parcial | Ainda há 362 linhas com `/mnt/Apate`, `captura.txt:3` com `/home/<outra conta>`, o cartão «Logo própria do Hefesto» de fábrica (meow.conf.exemplo:549-565), `__LOGO_DELA__` (completar_icones.sh:213) e `INTOCAVEIS=(fogstripper hefesto…)` (icones_apps.sh:179). | — |
| S3 | **"atualiza a documentação como um todo"** (P71) e SPRINTS.md como índice de P1 a P72 (P72), 26/09 | nunca feito | `docs/SPRINTS.md` ainda diz "Última atualização: 21/09/2026". Os READMEs não mudam desde 24-25/09. | — |
| S4 | P70 item 1: a ponte para de recusar a tela de login, ou diz o motivo (26/09) | nunca feito | `scripts/greeter.sh:266-271` ainda manda a saída para `/dev/null`. | — |
| S5 | **"Atualizar e compilar o menu"** (cosmic-files, 24/09) | parcial | O pacote e o estado estão certos, mas a linha `files_menu` do doctor sai vazia. | — |
| S6 | Os miúdos da P34 (2 testes de navegador vermelhos etc.), 23/09 | parcial | Os miúdos valem. A suíte não foi rodada, porque usa sudo, que escreve no sistema real. | — |
| S7 | Processo: **"todas as nossas soluções precisam estar comentadas"** (17/09), decisões por AskUserQuestion (23/09 e 24/09), "restaurar desktop: Não" (24/09), **"relança reaproveitando o que foi concluído"** (25/09) | não verificável | São regras de conduta das sessões e não deixam rastro medível. | — |

---

## Por que voltou

Os pedidos voltam pelo mesmo padrão: **a regra é cumprida num lugar, e a prova olha esse mesmo
lugar**. Os outros leitores da mesma chave, a migração do conf e o veredito do doctor ficam fora
da prova. Seguem cinco mecanismos, cada um com prova.

1. **Uma regra centralizada, com leitores que continuam lendo o dado cru.** A P41 pôs a regra
   "MeowSystem-Icons-Base = a base do pack" em `pack.py:_base_escolhida`. O próprio comentário
   (pack.py:2069-2072) diz que "a regra mora no `_base_escolhida`, uma vez, e o shell lê a
   resposta do verbo". Mas só `construir_icones.sh` e `bin/meow` chamam `pack.py base-icones`.
   `construir_pastas.sh:107-108` e `completar_icones.sh:149-150` continuam com
   `BASE_DIR="/usr/share/icons/$BASE"`, linha que é de 04/08 (`1db6506`). A sprint mudou a base
   de lugar sem procurar quem a lia (`git grep ICONES_BASE` mostra os dois).
2. **A decisão de quem usa ficou só como comentário, e a migração a desfez.** "Tirar a linha
   do conf" virou um comentário (meow.conf:399), mas a chave continuou no
   `meow.conf.exemplo:499`. O `migrar_conf.py` devolve toda chave do exemplo que estiver
   ausente e só conhece `RENOMEADAS` (migrar_conf.py:72). Ele não tem lista de chaves
   aposentadas. Toda decisão do tipo "a chave sai" volta no próximo `install.sh` ou na
   próxima gravação do painel.
3. **O veredito não depende das linhas que falham.** O doctor fecha com `ok nada a consertar`
   (bin/meow:2437, pelo `pior_rc`) mesmo com `!!` na mesma saída. O auto-reparo diário passou
   7 vezes, de 28/09 a 09/10, com "pastas coloridas puladas", e nada acusou. A regressão só
   apareceu porque uma pessoa leu a saída.
4. **Testes com isenção literal e testes que rodam numa cópia.** `tests/sem-receita-no-log.sh:95-96`
   isenta à mão a frase exata `sudo apt install papirus-icon-theme` (fe1fefd, 22/09). Quando
   a frase voltou, e errada, o teste continuou verde. O mesmo vale para as 12 legendas longas
   isentas em `tests/app-acessibilidade.py`. A regra da P21 tem um teste só,
   `tests/git-limpo.sh`, e ele só exercita o `wallpaper.sh`. O `tests/seletor-do-pack.sh` roda
   numa cópia da árvore (`mktemp`, linhas 58-69), então nunca vê o `git status` do repositório
   real. Por isso o `171dedb` passou gravando no `apps.map` versionado.
5. **A regra mora no documento da sprint, não no código.** O agente da P60 leu a pergunta
   «o pack aparece pro user?» e decidiu, no commit, que "a escolha mora no mapa dele" e "não
   vaza porque o mapa é do pack". Isso contradiz o spec da P21, que só aceita gravar no pack
   "por gesto explícito, não por uso". Nada no código impedia a gravação. O mesmo vale para os
   pedidos repetidos ×4 e ×5 (T1, D2): cada sprint conserta o caso citado (a variante, o
   rótulo, o balão) e deixa a regra geral para trás. Exemplos: o prompt e os mimetypes
   continuam no Catppuccin, e o `tema_ativo` continua pegando a primeira captura.

Um efeito vizinho do mesmo padrão: há **estado de terceiro versionado**. O cofre do Obsidian
tem `"Catppuccin"` no HEAD do git dele, e o auto-reparo o troca de volta para Dracula a cada
passada (10 vezes no doctor.log). O conserto é refeito sempre e nunca fica.
