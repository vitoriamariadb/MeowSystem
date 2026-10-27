# Auditoria: tema do pack ajustado para cada app (27/10)

**Pergunta de quem usa:** «lá teremos a possibilidade de criar um tema ajustado pra cada app de acordo com o
nosso themepack, vale uma auditoria», para decidir a P127 e a P130 com base em medida.

Medido no Nitro, o PC do André (Pop!_OS 24.04, COSMIC no Wayland, Flatpak 1.18.1, pack `meowsystem`, flavor `mocha`,
acento `mauve`). Os módulos existentes foram lidos, mas **não testados** nesta auditoria.

## As três medidas que decidem

1. **`GTK_THEME` não faz nada pelos apps GTK3.** Uma janela GTK3 dentro de um Flatpak dá o mesmo resultado
   com e sem a variável: tema `adw-gtk3-dark` e fundo `0.13 0.13 0.15`. O tema chega pelo portal (`gtk-theme`
   do gsettings) e pela extensão `org.gtk.Gtk3theme.adw-gtk3-dark`. O caminho que a variável aponta
   (`/usr/share/themes`) o Flatpak nem deixa montar: o aviso «O caminho "/usr" está reservado» sai em toda
   execução. Para os apps libadwaita, a variável desliga o estilo inteiro (P127).
2. **Os packs não têm tema GTK.** Nenhum `pack.json` declara um; o `flatpak_tema.sh:88` só copia o
   `gtk-theme` do sistema. Não existe `org.gtk.Gtk3theme.Dracula` no Flathub, só `Adwaita-dark`,
   `adw-gtk3` e `adw-gtk3-dark`. Então a dúvida «o pack Dracula precisa do `GTK_THEME`?» tem resposta: não.
3. **O tema por app funciona nos apps libadwaita.** Um `gtk.css` em `~/.var/app/<id>/config/gtk-4.0/`, com as
   variáveis do libadwaita 1.6+ (`--accent-bg-color`, `--window-bg-color` e afins) preenchidas pela paleta do
   pack, foi aplicado no Clapper: o botão saiu exatamente em `#CBA6F7` (o mauve do pack), medido no pixel. A
   tela inicial do Clapper fixa a própria cor de fundo (`.initialstate { background-color: @dark_4 }`), e o
   mesmo arquivo consegue sobrescrevê-la com um seletor do app. É o canal do «tema ajustado por app»: uma
   base comum, gerada da paleta, mais um ajuste fino por app quando o app fixa cor própria.

O canal que existe hoje, o `gtk.css` que o COSMIC gera (`toolkits-gtk-qt` depende dele), **não serve** para
os apps libadwaita em Flatpak: com ele, o Clapper fica com fundo branco e texto branco. O formato do COSMIC
(`@define-color`) é o antigo; o libadwaita do runtime GNOME 49 usa variáveis CSS.

## Os apps do Nitro, por canal de tema

| canal | apps instalados | módulo hoje | o que fazer |
|---|---|---|---|
| libadwaita (CSS por app em `~/.var/app/<id>/config/gtk-4.0/gtk.css`) | Clapper, Gradia, BoxBuddy, Warehouse, Upscaler | nenhum | um modelo só, gerado da paleta, mais ajuste fino por app (o Clapper precisa de um seletor). Esforço baixo e medido |
| Qt (KDE runtime, `kdeglobals` e esquema `.colors`) | qBittorrent, ZapZap, Ghostwriter, Krita, OBS | qbittorrent, zapzap | Ghostwriter e Krita aceitam esquema `.colors`; o OBS tem tema próprio (`.obt`). Medir se o `kdeglobals` exposto já chega neles |
| Electron e Chromium (CSS injetado ou tema do app) | Discord, Spotify, Obsidian, Edge, Boxy SVG | discord, spotify (spicetify), obsidian | Edge e Boxy SVG não têm canal estável; ficam de fora |
| tema próprio do app | Telegram (`.tdesktop-theme`), OnlyOffice | telegram, onlyoffice | já cobertos |
| GTK3 + `userChrome.css` | Waterfox | nenhum | o Firefox aceita `userChrome.css` por perfil; esforço médio |
| libcosmic (iced) | Câmera e os applets do COSMIC | não precisa | seguem o tema do COSMIC, que o pack já aplica |

Fora do Flatpak, os módulos kitty, gnome-terminal, btop-bat, vscode e heroic continuam como estão.

## O que isso decide

- **P127: opção b.** Tirar `GTK_THEME` e `xdg-data/icons` do que o `flatpak_tema.sh` escreve, e tirar o
  `xdg-config/gtk-4.0` herdado do NitroKit. Garantir a extensão `org.gtk.Gtk3theme.<gtk-theme>` instalada.
  Com o global limpo, os apps libadwaita não precisam mais de exceção por app para funcionar; o que fica
  por app é só o tema, que é opcional e é o que a aba Modificações liga e desliga.
- **P130: a Modificações é o lugar do tema por app**, e a tabela acima é o catálogo inicial dos cartões.
