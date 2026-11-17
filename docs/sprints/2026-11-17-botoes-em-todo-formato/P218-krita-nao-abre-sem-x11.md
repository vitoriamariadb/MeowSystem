# P218 — o Krita flatpak não abre no Wayland (17/11/2026)

## O que se mediu
`flatpak run org.kde.krita` (runtime `org.freedesktop.Platform 25.08`, Qt 5 só com `xcb`, sem plugin `wayland`):
`qt.qpa.xcb: could not connect to display` e o app morre. Dentro do sandbox `DISPLAY` vem vazio, com `x11` e
`fallback-x11` nos sockets do app e no override global.

## A causa
Com `fallback-x11` presente e o Wayland disponível, o flatpak tira o X11 do sandbox mesmo com `x11` pedido.
O Krita só sabe falar X11.

## A cura na origem
`flatpak override --user --nosocket=fallback-x11 org.kde.krita` pelo manifesto `krita`, com conferir e reverter
(não pelo override global, que vale para todos). Pela XWayland, o COSMIC desenha a moldura com a arte do pack
(o qt6ct pela XWayland provou isso).

## Como se prova
- Teste com HOME temporário e `flatpak` falso: aplicar grava o override; segunda passada sem escrita; reverter tira.
- Foto do Krita aberto, com a moldura do pack.
