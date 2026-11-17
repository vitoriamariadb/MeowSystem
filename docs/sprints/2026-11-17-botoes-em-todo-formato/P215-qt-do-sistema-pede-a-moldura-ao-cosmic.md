# P215 — os apps Qt do sistema (deb) vestem os botões do pack (17/11/2026)

## O que se mediu
- `qt6ct` (Qt 6.4.2 do sistema) e `qt5ct` (Qt 5) no Wayland: barra clara do plugin `bradient`, com `_ □ ×`
  genéricos. Os Qt do runtime flatpak `org.kde.Platform 6.11` (qBittorrent, ghostwriter, ZapZap sem barra própria)
  já saem com a moldura do COSMIC e a arte do pack.
- `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` no qt6ct: a janela fica SEM moldura nenhuma (o Qt 6.4 não pede o modo e o
  compositor responde «cliente desenha»).
- `QT_QPA_PLATFORM=xcb` no qt6ct: XWayland, o COSMIC desenha a moldura com morcego, caixão e ossos (foto).
- Causa: no `cosmic-comp` (`src/wayland/handlers/decoration.rs`), quem não pede modo recebe
  `default_decoration()`, que lê `decoration_preference` da config `com.system76.CosmicComp`; o padrão é
  `ClientSide`. O Qt 6.4 e o Qt 5 não pedem modo; o Qt 6.11 pede servidor.

## A cura na origem
`decoration_preference` = `ServerSide` em `~/.config/cosmic/com.system76.CosmicComp/v1/decoration_preference`, pelo
módulo que já escreve a config do compositor, com conferir e reverter. GTK não fala `xdg-decoration` e não muda;
libcosmic e Chromium pedem o modo e não mudam. Alternativa pior: `QT_QPA_PLATFORM=xcb` na sessão (perde a escala
fracionada e o IME do Wayland).

## Como se prova
- Teste com HOME temporário: aplicar grava `ServerSide`; segunda passada sem escrita; reverter devolve o valor de antes.
- Foto do qt6ct e do qt5ct antes e depois (o compositor relê a chave sem reiniciar; quem coordena muda a chave real).
- Conferir que nenhum app que pede `ClientSide` explícito ganhou duas barras.
