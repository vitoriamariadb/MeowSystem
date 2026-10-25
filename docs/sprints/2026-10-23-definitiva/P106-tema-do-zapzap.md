# P106 — O ZapZap veste o tema do pack (CSS)

**Status: EM VOO em 24/10.** Quem usa (24/10): «Olha, o ZapZap permite alterar o CSS. Lança um Opus pra criar
um tema pra ele, assim como temos do Telegram, qBittorrent, Discord e outros, e já testar.»
Por ordem de quem usa, roda como terceiro bloco junto da P102 e da P103. Os arquivos não se cruzam.

## O que se mediu (24/10)
- ZapZap 7.5.1 (flatpak `com.rtosta.zapzap`). Já existe
  `~/.var/app/com.rtosta.zapzap/data/ZapZap/customizations/global/{css,js}/`, vazia. O ZapZap injeta o CSS dessa
  pasta no WhatsApp Web. O `ZapZap.conf` tem `theme=dark`.
- `scripts/temas-de-apps/zapzap/manifesto.sh` hoje só troca o nome para «WhatsApp» e o ícone (`Icon=meow-whatsapp`).
  Não mexe em cor.
- Os outros apps têm módulo em `scripts/temas-de-apps/<app>/manifesto.sh`, alguns com modelo preenchido pela
  paleta do pack (`telegram.modelo.tdesktop-theme`, `modelo.py`), e alguns com tema dentro do pack
  (`packs/<pack>/temas-de-apps/<app>/`).

## A cura
1. **CSS pela paleta do pack:** o módulo do zapzap gera um CSS a partir da paleta do pack no ar, do mesmo jeito
   que o Telegram. Ele vai para a pasta de customização do ZapZap, com um nome nosso, e só esse arquivo é
   nosso. Trocar de pack troca as cores. O WhatsApp Web usa nomes de classe ofuscados e variáveis CSS:
   prefira as variáveis (a fundação do tema escuro), e confira a fonte de cada uma (procure temas existentes do
   WhatsApp Web, como o Dracula para o WhatsApp, e cite a procedência).
2. **Convergente:** a segunda passada não escreve nada. O `conferir` acusa divergência, e o `reverter` tira só o
   nosso arquivo. Se quem usa já tem um CSS próprio lá, siga a mesma regra de «tema de terceiro» dos outros
   apps (`lib/comum.sh`: perguntar, não escrever por cima).
3. **ZapZap aberto:** se ele precisa reiniciar para ler o CSS, diga isso numa linha (como o OnlyOffice: «vale ao
   abrir o app»). Nunca mate o processo.

## Como se prova
- Teste em `tests/temas-de-apps.sh` (ou no teste certo) com HOME temporário: as cores do CSS vêm da paleta do
  pack (Dracula e meowsystem dão CSS diferentes). Ida e volta de pack. A segunda passada fica quieta. O
  `reverter` só tira o nosso.
- Prova visual: rode o ZapZap com um HOME temporário (`HOME=<tmp> flatpak run com.rtosta.zapzap`, que não
  toca no perfil real). Sem sessão do WhatsApp, a tela de login com o QR já mostra o fundo e as cores. Tire print
  antes e depois e guarde em `.wt-meow/p106-prints/`.
- A prova no perfil real (com as conversas) é de quem coordena, depois da conferência: `meow apps aplicar zapzap`
  na máquina e um print.

## Execução (agente 1, 24/10)
1. `74dfb90` o módulo do zapzap monta `customizations/global/css/MeowSystem.css` do modelo do motor
   (`scripts/temas-de-apps/zapzap/zapzap.modelo.css`) com a paleta do pack no ar, e liga
   `custom/global/css/enabled` no `ZapZap.conf` (de fábrica é false: sem ela o ZapZap não injeta nada).
   Os dois packs declaram `apps.zapzap`. Procedência dos nomes no `packs/dracula/PROCEDENCIA.md`.
2. `7c2a40a` `tests/temas-de-apps.sh`, seção do ZapZap.

**Medido na prova visual (HOME temporário, Xvfb, `FLATPAK_USER_DIR` real só para achar o app):**
- A tela do QR do WhatsApp Web de hoje pinta com cor escrita em classe atômica (`.xe4h88v` dá o creme
  `rgb(252,245,235)`, `.x12peec7` o cartão branco), e não com variável. O tema por variáveis não a alcança, e é
  melhor assim: o QR fica legível. Quem muda na abertura é a tela de carregamento (fundo `crust`, barra
  `surface1`), medida pixel a pixel nos prints.
- Das 71 variáveis do CSS, 63 são lidas pelas regras do próprio WhatsApp Web já na tela do QR; o tema de cor
  dele mora em `:root` (`html.xq05bh1`), e o nosso `!important` em `:root` vence.
- O ZapZap injeta o CSS no fim da carga da página: a abertura pisca a cor de fábrica por um quadro (~0,2 s).

**Fica para quem coordena:** `meow apps aplicar zapzap` na máquina real e o print com as conversas (a tela
logada é a que importa e não se alcança sem sessão).
