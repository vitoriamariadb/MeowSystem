# P128 — App Flatpak em runtime GNOME antigo abre no COSMIC

**Aberta em 27/10.** O contorno roda só no Nitro (`relatorios/contorno-local.md`, o `Clapper.sh` e a parte de runtime do script global).
Na máquina dela nenhum app está em runtime GNOME ≤ 47 hoje: a prova é a casa de brinquedo.

**Pedido de quem usa (27/10):** «pode ver pq o clapper não abre no meu pc?»

## O que se mediu (no Nitro)
- Clapper 0.10.0 (Flathub) usa o runtime `org.gnome.Platform//47` (GTK 4.16). No Wayland do COSMIC ele
  morre antes de abrir janela: SIGSEGV em `linux_dmabuf_tranche_done`, chamado de `_gdk_wayland_display_open`
  dentro de `gtk_init` (pilha tirada com gdb no `org.gnome.Sdk//47`). Eram 21 coredumps em 30 dias.
- Tema, renderizador (`GSK_RENDERER`), `GDK_DISABLE=dmabuf` e `GDK_DEBUG=no-dmabuf` não mudam nada.
- Com `--runtime=org.gnome.Platform//49` ou `//50` ele abre. Com `//51` não abre: `undefined symbol:
  gst_play_config_set_loop`, porque o GTK do 51 liga no GStreamer do runtime e o Clapper traz o próprio.
  Então «o runtime mais novo» é uma regra errada; vale a lista dos validados.
- Pelo X11 (`--socket=x11 --env=GDK_BACKEND=x11`) o runtime 47 abre, mas sem Wayland nativo.
- O `.desktop` do Clapper tem `DBusActivatable=true`: o lançador do COSMIC abre o app pelo serviço D-Bus e
  ignora o `Exec`. O contorno precisa estar nos dois: `~/.local/share/applications/<id>.desktop` e
  `~/.local/share/dbus-1/services/<id>.service` (o barramento procura ali antes dos exports do Flatpak).
- Hoje só o Clapper está num runtime GNOME ≤ 47 no Nitro.

## A causa
Bug do GTK 4.16 com o feedback de dmabuf do cosmic-comp, corrigido nas versões seguintes. O app só sai dele
quando o mantenedor subir o runtime no Flathub.

## A cura
- Módulo de modificação «runtime»: para app com runtime GNOME < 48, grava o `.desktop` e o serviço D-Bus
  locais com `--runtime=org.gnome.Platform//<v>`, onde `<v>` é o primeiro instalado da lista validada
  (`49 50`, com o motivo de cada exclusão escrito ao lado).
- Mantém uma cópia local de `.desktop` que já exista (pode ter tradução própria); o serviço leva uma marca
  `# corrigir-flatpaks-libadwaita` para o módulo saber o que é dele.
- Quando o app passar para runtime ≥ 48, o módulo tira o contorno sozinho (já implementado no contorno, `relatorios/contorno-local.md`).
- Falta de runtime validado instalado: o doctor mostra e o `--consertar` instala `org.gnome.Platform//49
  --user`, sem senha.
- Fora desta sprint: a issue no Clapper pedindo o runtime novo fica para ela decidir (anotada no `ANDAMENTO.md`).

## Como se prova
- Teste com `flatpak` falso: app em runtime 47 recebe o contorno, a segunda passada não escreve, app que sobe
  para o 49 perde o contorno, o serviço D-Bus sem a marca não é tocado.
- No Nitro, quando ela levar o produto para lá: clicar no Clapper pelo lançador abre a janela (`gdbus ... org.freedesktop.Application.Activate`
  e print).

## Execução

Feito em 27/10 junto com a P127 (mesmo script, alvo `runtime`).

- Lista validada em dado, não em código: `assets/flatpak/runtimes-gnome.tsv` (`versao estado motivo`): 47 quebra, 48 livre, 49 e 50 válidos, 51 excluído, cada um com o motivo.
- Para app libadwaita em `org.gnome.Platform` < 48, o módulo grava `~/.local/share/applications/<id>.desktop` (parte do `.desktop` exportado, trocando `flatpak run ` por `flatpak run --runtime=org.gnome.Platform//<v> `, o que já existia como cópia local mantém a tradução dela) e `~/.local/share/dbus-1/services/<id>.service` com a marca `# corrigir-flatpaks-libadwaita`. `<v>` é o primeiro instalado da lista (49, depois 50).
- Serviço D-Bus sem a marca não é tocado. App que sobe para ≥ 48, ou que deixa de ser libadwaita, perde o contorno sozinho. App sem libadwaita (Qt, Electron) fica como está.
- Sem runtime validado instalado: o doctor mostra, o `--consertar` instala `org.gnome.Platform//49 --user`, sem senha; se o Flathub recusar sai 3 e não escreve contorno.

Provas (`tests/flatpak-tema.sh`, seção 9): Clapper em 47 recebe o contorno nos dois arquivos; a segunda passada não escreve; app que sobe para o 49 perde o contorno; serviço sem marca intocado; sem o 49 e com o 50 instalado, o 50 serve; instalação recusada devolve 3.

Fica para a mão dela, no Nitro: clicar no Clapper pelo lançador abre a janela. Na máquina dela nenhum app está em GNOME ≤ 47 (a lista dela hoje é 50 e 51).
