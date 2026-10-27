# P129 — Um tema do pack para cada app

**Aberta em 27/10.** Depende da P127 (override global limpo).

**Pedido de quem usa (27/10):** «lá teremos a possibilidade de criar um tema ajustado pra cada app de acordo
com o nosso themepack», e na decisão da P127: «tira e vamos criar um tema pra cada app».

## O que se mediu
Tudo está em `relatorios/auditoria-tema-por-app.md` (medido no Nitro). Em resumo:
- Nos apps libadwaita, um `gtk.css` próprio do app (`~/.var/app/<id>/config/gtk-4.0/gtk.css`), com as
  variáveis CSS do libadwaita preenchidas pela paleta do pack, funciona: no Clapper o botão saiu exatamente no
  mauve do pack (`#CBA6F7`, medido no pixel). O app que fixa cor própria precisa de um seletor a mais (o
  Clapper fixa o fundo da tela inicial em `.initialstate`).
- Isso só funciona depois que a P127 tira o `xdg-config/gtk-4.0` do override global. Enquanto ele está lá, o
  app lê o `gtk.css` do COSMIC em vez do dele.
- Apps sem tema nenhum hoje, no Nitro: Clapper, Gradia, BoxBuddy, Warehouse e Upscaler (libadwaita), Waterfox
  (`userChrome.css`), Krita e Ghostwriter (esquema `.colors`) e OBS (tema `.obt`). Na máquina dela: Gradia,
  Upscaler, Calculadora e Flatseal (libadwaita), Krita e OBS. O módulo libadwaita acha os apps pela detecção da
  P127, sem lista de nomes.

## A cura, em ordem
1. **libadwaita:** um modelo de CSS gerado da paleta do pack (fundo, texto, cabeçalho, cartão, popover,
   acento, erro, sucesso), escrito na pasta de cada app libadwaita instalado. Ajuste fino por app num
   arquivo ao lado do modelo, só quando o app fixa cor própria. Começa pelos apps libadwaita que a detecção achar; o Clapper ganha o seletor `.initialstate`.
2. **Qt:** medir antes se o `kdeglobals` exposto já leva as cores ao qBittorrent, ZapZap e Ghostwriter.
   Depois, um esquema `.colors` gerado da paleta para Krita e Ghostwriter, e o tema `.obt` do OBS.
3. **Waterfox:** `userChrome.css` no perfil, gerado da paleta.
- Cada app entra como módulo em `scripts/temas-de-apps/<app>/`, no formato dos que já existem, com o par
  `chk_`/`fix_` no doctor. Trocar de pack ou de flavor reescreve; a segunda passada não escreve; o
  desinstalador apaga o que escreveu.
- Os dois packs (meowsystem e dracula) ganham o tema de cada app, como na P107 (histórico do git).

## Como se prova
- Casa de brinquedo: o módulo escreve o CSS com as cores do pack, trocar de pack troca as cores, a segunda
  passada não escreve, desinstalar apaga.
- Na máquina dela: print headless não pega app Flatpak, então o print de cada app fica na lista do que ela confere
  com a mão; o teste mede o CSS escrito. Print de cada app com a cor do acento conferida no pixel, nos dois packs.
- `tests/todos.sh` verde duas vezes.
