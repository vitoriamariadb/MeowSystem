# A validação no painel de verdade — 24/09/2026

**O pedido:** *"abrir cada aba como user. E vai aba a aba. Botão a botão, usa
todos os menus, todas as configs, tudo certinho e veja o antes e depois do
desktop e valida cada feature. [...] Importante ser via navegador tudo."*

Feito em 24/09/2026, no painel de verdade (`./app/run.sh`), por um Chromium
dirigido pelo protocolo de depuração, com um vigia gravando console e rede
(nenhum erro de JavaScript, nenhuma resposta 4xx/5xx na sessão inteira), e com
foto do desktop antes e depois de cada ajuste que muda a tela. As 14 abas, o
topo e o desktop. **O que funciona de ponta a ponta:** trocar de pack (ida e
volta, medido no pixel do dock), claro e escuro, exportar e importar pack e
.conf, conferir, consertar, próxima imagem, «Usar» da galeria, recarregar o
painel, gravar as áreas, ouvir o som, os ensaios, e as ações destrutivas pedem
confirmação.

Os 46 achados estão no fim deste arquivo, pelo número. As sprints abaixo os
dividem por território, e cada uma cita os números que são dela.

**Decisões de 24/09:** consertar os 46; as ações de jogos que aplicam todas as
marcas pendentes passam a pedir confirmação.

**O gate:** toda sprint desta onda termina com o `tests/app-completo.py`
verde, e o controle novo que ela criar entra no inventário dele.

---

# P48 — O tema pronto e a cor de destaque aplicam de verdade

Achados **30** e **31**. São os dois mais graves.

1. **«Trocar de tema» lista os temas prontos dos packs** — a mesma fonte do
   `meow tema` (que lista os cinco); o painel lê só `assets/temas/capturados`
   desde que as capturas foram para dentro dos packs (P27). Uma regra só,
   chamada pelos dois lados.
2. **A captura `original` é da máquina de outra pessoa** (P30 mediu: a linha
   `origem:` dela é o home de quem a capturou). O `meow tema original` passa a
   recusar numa máquina que não é a dela, pela MESMA guarda que o
   `meow desfazer` já tem; e o painel não a oferece como tema pronto.
3. **A cor de destaque aplica com qualquer valor da lista.** Hoje, com o
   Dracula, só o mauve tem captura (`dracula-mauve`); escolher pink grava o
   conf, gera o `.ron` e NÃO aplica — o instalador manda importar o `.ron` na
   GUI e rodar `meow tema capturar` à mão. A regra do projeto é que nenhuma
   feature manda consertar à mão. Meça o que difere entre duas capturas do
   mesmo flavor com acentos diferentes (há `mocha-mauve` e `mocha-pink`), e
   derive a captura do acento novo a partir da do flavor, trocando só o que o
   acento pinta — o precedente é o `gerar_tema_v1.py`, que já deriva a v1 da
   paleta. Se houver chave que não se deriva sem a GUI, diga qual, e a tela
   oferece só os acentos que aplicam, dizendo por quê.
4. **A tela não diz «aplicou» quando o tema não foi aplicado** — o instalador
   sai divergente, e o painel mostra a pendência.

Prova: no desktop de brinquedo do teste, trocar o acento muda o
`com.system76.CosmicTheme.Dark/v1/accent`; e o `tests/app-completo.py` cobra a
lista de temas prontos.

---

# P49 — Trocar de pack não deixa vestígio que quebra, e "instalado" é uma regra só

Achados **12** e **45**.

1. **`MEOW_FAMILIA_PALETA`** sobra da troca de pack (vestígio), não tem cartão
   no painel, e com o flavor novo o btop-bat procura «Dracula Mocha», que não
   existe. Ou a família sai do pack no ar (e a chave deixa de existir), ou a
   chave ganha cartão e o vestígio é tratado como os outros (a regra da P3).
   Meça quem lê a chave e escolha o menor.
2. **`meow apps` diz qBittorrent e Discord «não instalado»**, e os dois estão
   (flatpak do usuário). A detecção de "instalado" vira UMA regra, que a
   tabela e os módulos chamam.

---

# P50 — O rótulo diz o que a ação fez

Achados **11, 14, 15, 16, 17, 32, 33, 36**.

1. **O fim de cada ação tem o rótulo que ela merece** (achado 17, sistêmico):
   hoje o texto sai só do código de saída — «Recarregar o painel» reciclou e
   disse «JÁ ESTAVA CERTO»; «Próxima imagem» disse «MEXEU E CONSERTOU»;
   «Consertar» disse «MEXEU E APLICOU» sem mudar nada; «Ouvir o som» disse
   «JÁ ESTAVA CERTO». Cada ação declara o que ela é (conferir, aplicar,
   trocar, tocar…), e o rótulo sai da natureza + código.
2. **Esperar o próximo login não é divergência** (14): os patches do
   compositor à espera da sessão nova saem como aviso, não como «há
   divergências — rode consertar».
3. **O resumo do ENSAIO não diz «aplicado»** (11).
4. **A linha do vidro não se contradiz** (15).
5. **«Pôr um gato no dock» no modo Hora** (33) vem desabilitada com o motivo,
   ou oferece fixar — hoje responde «já estava certo» sem trocar.
6. **As áreas** (32): «Gravar as áreas» sem alfinete faz o alfinete antes (ou
   a tela conduz a ordem); a gaveta não cita botão que não existe.
7. **O raio** (36): o deslizante diz o teto que vale e por quê; valor que o
   instalador recusa não é gravado como se valesse, e a tela não diz
   «aplicou».

---

# P51 — O Catppuccin que sobrou, de novo

Achados **2, 19, 20, 24, 25, 26, 27, 28, 34, 39, 40, 42**.

Tudo o que a tela diz tem de vir do pack no ar. Reconte com o Dracula no ar,
aba por aba (o método da P31): Terminal (as cores, o TERMINAL_CURSOR e o prompt), Cor e tela
(a ilustração que diz que FLAVOR=dracula «não é aceito», os rótulos dos
flavors, os nomes das cores de destaque, a prévia do lado a lado, a versão do
ponteiro), o cabeçalho do instalador, a ação do Spotify, «Tema de onde
herdar» (a base que vale é a do pack), a ilustração do Modo de leitura.

O achado 40 é também função: o esquema Dracula do cosmic-term fica instalado
e não selecionado, e o instalador manda escolher à mão. Meça se o valor de hoje
(Catppuccin Mocha/Latte) foi escrito pelo MeowSystem ou pela pessoa: se foi
pelo MeowSystem, a troca de pack o troca; se foi pela pessoa, a tela oferece
um botão, não um caminho de menu.

---

# P52 — O que a tela mostra ou exporta não traz nome nem casa de ninguém

Achados **10, 13, 21, 22**.

1. Os comandos mostrados na tela (caixas, «ver comando», gaveta) usam `meow …`
   e caminhos com `~`, nunca `/home/<usuário>/…` (10).
2. **O produto fala com a pessoa, não dela** (13): «o config.jsonc dela», «é o
   que ela vê» e toda frase de tela na terceira pessoa viram «seu/você»; a
   chave `WALLPAPER_FONTES_DELA` ganha um nome neutro, com a migração do
   `meow.conf` de quem já a tem (o antigo continua lido).
3. O `.conf` exportado não abre com o caminho do home (21).
4. A página exportada («Esta tela num arquivo») não leva caminhos absolutos
   nem o valor efetivo de chaves com caminho (22).

---

# P53 — A Início e os packs

Achados **1, 3, 4, 5, 6, 7, 8, 9, 29**.

1. favicon (1); a pendência do qBittorrent sem saída (3) e a do OnlyOffice que
   manda ir ao terminal (4) — a escolha vira botões no painel; os vãos da
   coluna da esquerda (5).
2. «Mais sobre este pack»: a descrição longa em Markdown cru (6) e a tabela
   que diz «próprio» para gerador, prompt, fastfetch e gatos (7) — a mesma
   conta do `meow pack info`.
3. **Remover um pack importado** (8): o cartão de um pack que não vem com o
   MeowSystem ganha «Remover», com confirmação; o `meow pack remover <id>`
   existe; o pack no ar não se remove.
4. O título da caixa de importar (9); «Theme pack» como escolha entre os
   packs instalados, e não campo de texto (29).

---

# P54 — Os restos das outras abas, e a confirmação dos jogos

Achados **18, 35, 37, 38, 41, 43, 44, 46**, e a decisão dos jogos.

1. Os chips de «mudados por você» levam até o ajuste e o destacam (18).
2. Textos e visual: «acima» que está abaixo (35), rótulos cortados na
   ilustração do papel de parede (37), os dois horários de noite que se
   apontam (38), ids técnicos crus na lista do lançador (41), «1 jogos» e a
   grade vazia (43), o appid sem nome (44), o `meow status` do logo (46).
3. **Jogos — decisão de 24/09:** «Tirar do lançador» e «Tirar da lista»
   pedem confirmação, e a caixa diz quais atalhos saem e quais entram, com
   «Ver o que faria».

---

# Os 46 achados, como foram anotados na validação

## Início
1. Console: GET /favicon.ico 404 no carregamento (cosmético, mas o console não fica limpo).
2. Nome: o cartão diz «Dracula»; o retrato «Como a máquina está vestida» diz «Drácula».
3. Pendência do qBittorrent: «não há comando meu que resolva» — beco sem saída; o qBittorrent já está vestido pelo tema escolhido (dracula.qbtheme).
4. Pendência do OnlyOffice: manda «rodar o aplicar deste app de um terminal» — a escolha (tema do pack × o meu) devia ter botões no painel.
5. Layout: vãos grandes na coluna da esquerda (as linhas acompanham a altura da coluna de pendências).
6. «Mais sobre este pack»: a descrição longa aparece em Markdown cru (#, ##, **).
7. «Mais sobre este pack» (Dracula): a tabela diz «próprio» para traço do gerador, prompt, fastfetch e gatos — são do motor, não declaráveis (o `meow pack info` diz isso).
8. Pack importado não tem como ser removido: nem botão no cartão, nem rota, nem verbo do meow. A dica do claro manda importar de novo com outro nome — cria um segundo pack que também não sai.
9. Título da caixa de importar: «Importar o Tinta De Teste?» — o «De» capitalizado pelo nome do arquivo.
10. A caixa de «Usar este pack» mostra o comando com o caminho absoluto (/home/<usuário>/Desenvolvimento/MeowSystem/bin/meow ...) — bastaria «meow pack usar catppuccin».
11. O resumo do ENSAIO diz «Nada foi deixado pela metade — cada etapa é independente, e o resto foi aplicado.» — num ensaio nada é aplicado.
12. DEFEITO: trocar para o Catppuccin deixa MEOW_FAMILIA_PALETA="dracula" valendo (vestígio), e com o flavor mocha o btop-bat procura «Dracula Mocha.tmTheme» e «dracula_mocha.theme», que não existem — a etapa apps falha. E essa chave «não tem cartão no painel»: a pessoa não a vê nem a corrige pela tela.
13. Textos do produto falam da pessoa usuária na terceira pessoa do feminino («o config.jsonc dela», «morcego-dia <- NO DOCK (é o que ela vê)»; e a chave WALLPAPER_FONTES_DELA, que a tela mostra em «casa pelo nome no arquivo») — herança de quando o projeto era de uma pessoa só.
14. «Consertar o que estiver fora» rotula «MEXEU E APLICOU» quando nada mudou: a única divergência (patches esperando o próximo login) não tem conserto, e o próprio doctor diz «não há comando a rodar». O «Conferir» ainda manda «rode: meow doctor --consertar». Esperar login não devia contar como divergência.
15. A linha do vidro se contradiz: «vidro já conforme» e, logo abaixo, «o vidro na tela não é o que você escolheu: 'VeryHigh2' pede alpha 86, está gravado AA».
16. «Próxima imagem» termina com o rótulo «MEXEU E CONSERTOU» — é uma troca pedida, não um conserto.
17. SISTÊMICO: o rótulo do fim de uma ação sai só do código de saída — «Recarregar o painel» reciclou o painel (PID mudou) e disse «JÁ ESTAVA CERTO»; somado ao 14 e ao 16, o texto não conversa com o que a ação fez.
18. Os chips de «mudados por você» levam à aba, mas não rolam até o ajuste nem o destacam — o cartão do ponteiro fica a 1084 px, fora da tela, e a pessoa tem de procurar.
19. Catppuccin que sobrou: o ajuste TERMINAL_CURSOR do terminal, com o Dracula no ar, oferece «Do Catppuccin» e explica «a que o Catppuccin escolheu».
20. «Versão do tema do ponteiro» (v2.0.0) é a do catppuccin/cursors e aparece mesmo com o ponteiro do Dracula, que vem pinado pelo pack — confunde.
21. O .conf de «Exportar › Meus ajustes» abre com «# Origem: /home/<usuário>/.config/meow/meow.conf» — num arquivo feito para levar a outra máquina, expõe o nome de usuário (a classe da P30).
22. «Exportar › Esta tela num arquivo» embute o esquema inteiro em JSON, com caminhos absolutos (/home/<usuário>/.config/meow/meow.conf, a raiz do repositório, o valor efetivo de cada chave) — uma página feita para compartilhar leva o nome de usuário e a configuração da máquina.
23. (CORRIGIDO na hora: eu li cedo demais.) «Salvar e aplicar» sem nada pendente roda o instalador inteiro («Aplicando o que está salvo»). Funciona; a torrada só chega depois de ~2 s, e não há caixa dizendo que não havia nada a salvar — ele aplica o que já está salvo.
24. Catppuccin que sobrou: o cabeçalho do instalador na gaveta diz «MeowSystem — Catppuccin para o COSMIC» com o Dracula no ar.
25. «Variante do tema» oferece «Drácula» (com acento) e «alucard» (minúscula) — os rótulos dos dois flavors não seguem a mesma regra.
26. «Cor de destaque» nomeia as cores pelos slots do Catppuccin em inglês (mauve, sapphire, teal, maroon…) com o Dracula no ar (nos rótulos acessíveis).
27. A prévia do lado a lado diz «Uma tela em mocha escuro, com destaque mauve» com o Dracula no ar.
28. DEFEITO: a ilustração do topo de Cor e tela diz que «o valor de FLAVOR não é um dos aceitos» com FLAVOR=dracula, e desenha mocha — o desenho só conhece os flavors do Catppuccin.
29. «Theme pack» é um campo de texto livre (é preciso digitar «dracula»); devia ser a escolha entre os packs instalados.
30. GRAVE: a ação «Trocar de tema» só oferece «original», pré-selecionada — os temas prontos dos packs (dracula-mauve, latte-mauve, mocha-mauve, mocha-pink) sumiram da lista, porque o painel lê só assets/temas/capturados, e as capturas foram para dentro dos packs (P27). E `meow tema original` NÃO recusa: aplicaria o tema de fábrica da máquina de outra pessoa (a guarda existe no `meow desfazer`, não no `meow tema`). Um clique em «Executar» troca o tema dela pelo de outra máquina.
31. GRAVE: «Cor de destaque» oferece 12 cores, e com o Dracula só o mauve funciona. Escolher pink e «Salvar e aplicar»: o conf grava ACCENT="pink", o instalador gera o .ron, e o tema do COSMIC NÃO é aplicado — não há captura 'dracula-pink'. O instalador manda «importe o .ron uma vez na GUI e depois rode: meow tema capturar dracula-pink» (passo manual). Medido no desktop: o destaque continua #BD93F9 (o mauve). E o painel mostrou «MEXEU E APLICOU · Pronto, nada mais a escrever» — sucesso na tela, nada no desktop.
32. «Gravar as áreas» sai PULADO sem «Criar a primeira área» antes, e a gaveta manda «ou o botão «Resolver» no painel», que não existe ali. Duas ações que só funcionam numa ordem, sem a tela conduzir.
33. «Pôr um gato no dock» (Coquinha) com o modo Hora não troca nada: responde «JÁ ESTAVA CERTO — logo já no lugar: morcego-dia». O dock ficou igual (medido). A ação devia vir desabilitada com o motivo (como «Tirar uma área») ou oferecer fixar.
34. Tela que mente: «Tema de onde herdar» mostra Papirus-Dark e a legenda da ilustração diz «o que faltar vem do Papirus-Dark» — a base que vale é a do pack Dracula (MeowSystem-Icons-Base, m4thewz), desde a P41.
35. Texto fora de ordem: o topo da aba Ícones fala do «Tema de onde herdar» «acima», e o campo está abaixo.
36. «Canto arredondado — dock» aceita 0–32 no deslizante; 16 grava FORMA_RAIO_DOCK="16" no conf, o instalador RECUSA aplicar (com razão: no compositor sem o patch, raio acima de 0 derruba painel e dock juntos) e só avisa com «!!»; o COSMIC continua com border_radius 0 (medido) e o painel diz «MEXEU E APLICOU». O deslizante devia dizer o teto que vale e por quê.
37. Visual: na ilustração da aba Papel de parede, o rótulo «5 min» é cortado pelo círculo da seta, e o «30 min» pelo balão da notificação.
38. Dia e noite: dois pares de horário da noite que se apontam — «A noite começa às» vazio herda «do papel de parede», e «Imagem escura a partir das» diz «Vazio usa o horário geral da noite». Para quem lê, é um círculo.
39. Modo de leitura: a legenda do desenho diz que LEITURA_TEMPERATURA «tem valor que o ajuste não aceita», com 3500 no conf (válido: 1000–6500). O desenho parece ler o valor vivo da máquina («Na máquina agora: 0» — o controle desligado de dia) e o acusa. E «0» como temperatura em K não diz nada: é «desligado agora».
40. Aba Terminal toda em Catppuccin com o Dracula no ar («as dezesseis cores do terminal vêm do Catppuccin», «Do Catppuccin», «O prompt oficial do Catppuccin»). E o instalador avisa que o esquema Dracula do cosmic-term fica instalado mas NÃO selecionado, e manda escolher à mão (cosmic-term › Ajustes › Cores) — passo manual.
41. «Quais programas o lançador esconde» lista ids técnicos crus (org.gnome.Evince, org.gnome.baobab, gnome-language-selector…), sem nome nem ícone.
42. «Baixar o tema do Spotify» diz que baixa «o tema catppuccin do spicetify» — com o Dracula no ar, e o Spotify já em Sleek/Dracula.
43. «1 jogos instalados na Steam» (concordância), e a grade de jogos fica vazia; o instalador diz «nenhum jogo instalado tem manifesto».
44. «Decisões já executadas» mostra «appid 4046520», sem o nome do jogo.
45. DEFEITO: «Quais programas estão vestidos» (meow apps) diz qBittorrent e Discord «não instalado» — os dois estão instalados (flatpak do usuário: org.qbittorrent.qBittorrent, com.discordapp.Discord). O módulo do qBittorrent, no mesmo dia, disse «já está vestido». Duas regras de «instalado».
46. O `meow status` («O que está no ar agora») diz «logo coquinha -> (nenhuma)» com o morcego-dia no dock (modo Hora).
