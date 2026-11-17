# P214 — Qt (o WhatsApp) e os outros formatos vestem os botões do pack (17/11/2026)

## O que se mediu
Quem usa viu o WhatsApp sem os botões do pack: é o ZapZap, flatpak `com.rtosta.zapzap` no runtime
`org.kde.Platform 6.11` (Qt 6). Outros Qt instalados: `org.qbittorrent.qBittorrent`, `org.kde.ghostwriter`
(`org.kde.Platform`), `org.telegram.desktop`, `org.kde.krita`; deb: `org.kde.partitionmanager`. GTK em flatpak
(`io.github.flattool.Warehouse`, `org.bleachbit.BleachBit`, `com.github.rafostar.Clapper`) e em deb
(`gnome-calculator`, `gnome-disks`) ainda sem foto: o tema chega ao sandbox, falta provar que os botões saem.

## Primeiro passo: medir
Um app por toolkit e formato (Qt flatpak, Qt deb, GTK3 e GTK4 flatpak, GTK3 e GTK4 deb, X11/XWayland, AppImage se
houver): abrir, fotografar a barra, fechar só o que você abriu (mesmas regras do P213). Para cada Qt anotar a
plataforma (`QT_QPA_PLATFORM`), o plugin de decoração (`QT_WAYLAND_DECORATION`, `qadwaitadecorations`, `bradient`)
e se pede decoração do servidor (`xdg-decoration`, que o COSMIC atende com a arte do pack).

## A cura na origem
- Qt no Wayland: preferir a decoração do servidor (o COSMIC desenha com o tema de ícones) por variável de ambiente
  da sessão e por `flatpak override --user --env=…` só nos apps que precisam, pelo manifesto
  `toolkits-gtk-qt` (ou um manifesto novo `qt-decoracao/` se o de toolkits não couber). Conferir o efeito em foto;
  se a variável não existir no Qt 6.11, medir a alternativa e dizer qual.
- GTK que falhar na foto: achar a causa (tema não visto, CSS do pack que esconde o ícone) e curar no manifesto do
  toolkit.
- Formato sem caminho (snap sem `snapd` aqui, AppImage) → sprint nova anotada com o porquê.

## Como se prova
- Teste com HOME temporário e `flatpak` falso: aplicar grava o override/variável; segunda passada sem escrita;
  reverter desfaz.
- Foto antes e depois do ZapZap e de um app de cada toolkit medido.
- Linha de `docs/DECISOES.md` proposta ao coordenador, não escrita.
