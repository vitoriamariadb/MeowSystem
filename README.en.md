<div align="center">

<img src="docs/logo.svg" width="128" alt="The MeowSystem logo: a lilac line-art cat inside a circle">

# MeowSystem

**COSMIC dressed from head to toe by a theme pack, and a doctor that fixes things on its own.**

*Everything it writes, it knows how to undo — and running it again on a ready machine writes nothing.*

[![licence](https://img.shields.io/badge/licence-GPL--3.0-CBA6F7?style=for-the-badge&labelColor=1E1E2E)](LICENSE)
[![platform](https://img.shields.io/badge/Pop!__OS%2024.04-COSMIC-89B4FA?style=for-the-badge&labelColor=1E1E2E)](https://github.com/pop-os/cosmic-epoch)
[![languages](https://img.shields.io/badge/bash%204.3+-python%203%20stdlib%20only-A6E3A1?style=for-the-badge&labelColor=1E1E2E)](install.sh)
![version](https://img.shields.io/badge/version-v1.2.4-FAB387?style=for-the-badge&labelColor=1E1E2E)

[![installer](https://img.shields.io/badge/installer-68%20steps-89DCEB?style=for-the-badge&labelColor=1E1E2E)](install.sh)
[![doctor](https://img.shields.io/badge/doctor-73%20checks-94E2D5?style=for-the-badge&labelColor=1E1E2E)](bin/meow)
[![browser suite](https://img.shields.io/badge/browser-123%2F123-F5C2E7?style=for-the-badge&labelColor=1E1E2E)](tests/app-navegador.py)

Theme, icons, panel, dock, terminal, login screen, wallpaper and the themes inside your programs,
for Pop!_OS with COSMIC, in a single installer — plus a local panel that changes all of it
without opening a text file.

The colours come from a **theme pack**: a directory of data, without a single line of code.
Catppuccin is the default pack; Dracula ships complete, light side (Alucard) included. Whatever a
pack doesn't declare it inherits, and `meow pack info` says, category by category, where each
thing came from. The format is in **[docs/PACKS.md](docs/PACKS.md)** (in Portuguese).

<img src="docs/capturas/painel.png" width="920" alt="The MeowSystem configuration panel, home screen">

[Português](README.md) · [Full manual](docs/) · [Final state](docs/ESTADO-FINAL.md) · [Credits](docs/CREDITOS.md) · GPL-3.0

</div>

---

## Install

```bash
git clone https://github.com/AndreBFarias/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # first run: asks five questions, then installs
meow ativar               # every other run
```

On a blank PC, with the choices kept in a profile (`perfis/<name>/`: the `meow.conf` and the
chosen-icons map), the clone and `./install.sh --perfil <name>` are enough: the profile goes to
`~/.config/meow/`, what was there is kept beside it, and the rest comes from the repository.

68 steps. On a machine already set up, running it again **writes nothing** and says so. To
rehearse first: `MEOW_DRY_RUN=1 ./install.sh`, or **Ver sem mudar** (see what it would do) in
the panel.

The sudo password is asked **once**, to register the root bridge: a closed set of verbs (system
`.desktop` files, login screen, apt hook, dependencies) that then runs with no password.
`PONTE_ROOT="nao"` in `meow.conf` removes the bridge on the next pass.

## Packs

```bash
meow pack listar                      # installed packs, and whether each one validates
meow pack usar dracula                # switch the machine's pack and apply it
meow pack usar catppuccin latte       # with the chosen flavour
meow pack exportar dracula            # a .meowpack to take to another machine
meow pack importar my-theme.meowpack  # checks everything before touching the disk
meow pack remover my-theme            # removes an imported pack
meow pack exportar-tema dracula       # the assembled icon theme, usable without MeowSystem
```

In the panel, **Início** (home) shows one card per pack: logo, palette, what it brings and what
it inherits. **Usar este** (use this one) switches packs. The switch carries what belongs to the
pack (icon base, pointer, sound, what it hides from the launcher) and gives back what the previous
one hid.

**A pack is data, never code.** Nothing in it is executed: paths must land inside the pack, links
pointing outside and scripts are refused, and a third-party pack's drawings are served in a
sandbox. A VS Code extension asked for by an imported pack only installs on a gesture on it.

## The panel

```bash
meow abrir                # or the MeowSystem icon in the launcher
```

122 settings and 67 actions across fourteen pages: Início and thirteen subject pages. The menu
has two blocks: **Tópicos** (your screen) and **Sistema** (what the machine does on its own).

### The interface shows instead of explaining

<img src="docs/capturas/painel-leitura.png" width="920" alt="The reading-mode tab: the drawing shows the same page cold on the left and warm on the right">

Only title, label and value stay on screen. The why lives behind the **?**. Each block opens with
a preview drawn from your real values (wallpaper, cat, installed icon) that **repaints while you
drag the slider**.

With a pending choice, the preview becomes two: **Como está** (as it is) and **Como fica** (as it
will be). "Como está" undoes only that block.

### What you can do here

<img src="docs/capturas/painel-areas.png" width="920" alt="The workspaces tab, with a drawing of the bar and the two screens above its settings">

- **Ícones** (icons): one per program, swappable one by one. The picker shows the whole
  collection in folders (each pack, the one in use first; library; hand-made; Arcticons; rescued;
  uploaded). The drawing in use is marked.
- **Papel de parede** (wallpaper): the collection and its actions. A dropped file lands in the
  day or the night group, and **Dia** and **Noite** move it.
- **Áreas de trabalho** (workspaces): name, **order** and window tiling of each one.
- **Modo de leitura** (reading mode): temperature, texture, schedule and ramp of the warm night
  screen.
- **Install from the panel**: pointer theme (`.zip`), font, icon theme, cat, wallpaper, icon.
  Uploads live in `~/.local/share/meowsystem/`, never in the repository.
- Plus **Cor e tela**, **Logo do sistema**, **Painel e dock**, **Dia e noite**, **Terminal**,
  **Lançadores e jogos**, **Manutenção**, **Instalação** and **Atualização** (`apt`, `flatpak`
  and `cargo`, followed by `doctor`).

Every variable the installer reads has a control here, and a test enforces it.

Clicking never changes the machine: choices pile up and **Salvar e aplicar** (save and apply)
writes them and runs the installer. **Ver sem mudar** rehearses without writing. **Restaurar ao
padrão** (restore default) goes back to the factory value. Actions that download wear a network
badge.

<img src="docs/capturas/painel-forma.png" width="920" alt="The panel-and-dock tab, with a live drawing above the controls">

## What it dresses

| | |
|---|---|
| **The colours** | From a theme pack: `pack.json` and `paleta.json` with 26 named slots. Catppuccin (latte, frappé, macchiato, mocha) and Dracula (dracula and the light alucard) ship with the project; yours lives in `~/.local/share/meowsystem/packs`. |
| **The COSMIC theme** | All four trees, applied by file copy. Light and dark are the same theme with a switch, and with `MODO=claro` the pack's light side also dresses the dock line art and the folders. |
| **The login screen** | `cosmic-greeter` keeps its own config, and the bridge dresses it. |
| **Panel and dock** | Shape, radius, margin, spacing and padding per segment; the blur that follows the installed COSMIC, **on the bar and on windows**; seconds on the clock; and the playing track beside it, with cover art and controls. And a watcher that brings the bar back when it dies **or when it stays alive without drawing**. |
| **The workspaces** | Name, order and tiling for each one. The order of the list is the order of the bar. |
| **The icons** | The base comes from the pack (Papirus for Catppuccin; `dracula-icons` for Dracula, the `circle` branch over `main`), folders and file types in the pack's palette, and one drawing per program — swappable one by one, from the panel. |
| **The terminal** | All sixteen colours, the `starship` prompt, the `fzf` colours, and the cat replacing the `fastfetch` logo, redrawn in characters on every build. |
| **The wallpaper** | A carousel with day and night folders split by luminance, next/previous on right-click, and favourites. A pack can bring its own. |
| **Day and night** | At night the dock cat and the terminal cat change faces, the background switches to the dark images, and reading mode warms the screen and gives it paper texture, on a ramp — each on its own schedule, all 18:00 to 07:00 by default. |
| **Programs** | Spotify, VS Code, Obsidian, qBittorrent, Heroic, Telegram, Discord (Vesktop and Vencord), OnlyOffice, kitty, GNOME Terminal, ZapZap, btop and bat in the pack in use; Steam and Heroic games with one launcher entry each, cover art included, removed when the game is. |

## The machine

<table>
<tr>
<td width="50%"><img src="docs/capturas/desktop.jpg" alt="The desktop with panel and dock"></td>
<td width="50%"><img src="docs/capturas/desktop-claro.png" alt="The same desktop in the light theme"></td>
</tr>
<tr>
<td><img src="docs/capturas/fastfetch.png" alt="fastfetch with the cat drawn in characters"></td>
<td><img src="docs/capturas/lancador.jpg" alt="The launcher with Arcticons glyphs"></td>
</tr>
</table>

## The doctor fixes

```bash
meow doctor                            # 73 checks. Writes nothing.
meow doctor --consertar                # fixes whatever is out of place
meow desfazer                          # restores this machine's previous theme
./install.sh --uninstall               # removes theme, icons and timers
```

`doctor` never asks you to type: whatever it knows how to fix, `--consertar` fixes. It runs by
itself at 05:00, and the panel's **Consertar** (fix) is the same gesture.

Every write to a system file keeps a copy first, and the installer **refuses by path** to write
anywhere it doesn't know.

## COSMIC can update

Two builds are its own: the compositor (`cosmic-comp` with the `patches/` series) and the
wallpaper menu of `cosmic-files`. When apt brings a new COSMIC, the build redoes itself with no
sudo: after apt, at the next login and in the 05:00 doctor. The new binary takes effect at the
next login. A patch that doesn't apply changes nothing: the session comes up with the stock
compositor.

Run `apt full-upgrade` freely. The upgrade chain and how to go back:
**[docs/MANUTENCAO.md](docs/MANUTENCAO.md)** (in Portuguese).

## What to expect

Made for **Pop!_OS 24.04 LTS with COSMIC**. The coupling that remains is written down, and
`doctor` warns before the screen does.

- **the colours** come from a theme pack, not from the source;
- **what isn't here is skipped, not an error**: no Steam, no Heroic, no theme on disk, each step
  says what it skipped and moves on;
- **the installed COSMIC decides the path**: native key when there is one, patch only where not;
- **nothing is applied without a copy of what was there**, and `--wizard` asks only five keys:
  `FLAVOR`, `ACCENT`, `MODO`, `LANCADOR_SISTEMA` and `PONTE_ROOT` (`LOGO` comes from
  `meow.conf.exemplo`).

If your machine runs COSMIC, install it.

## Requirements

Pop!_OS 24.04 LTS · COSMIC (measured from 1.0 to 1.10) · `bash`, `python3` and `apt`. The builds
of its own need `cargo`, which whoever compiles installs through rustup when it's missing. The
panel opens in whichever browser is already installed, and only listens on `127.0.0.1`.

## Credits

Almost everything on screen was drawn by other people, under licences that allow this. The
largest:

- [Catppuccin](https://github.com/catppuccin/catppuccin) — the default pack's palette (MIT)
- [Dracula](https://draculatheme.com) — the Dracula pack's palette, and [`dracula-icons`](https://github.com/m4thewz/dracula-icons) as its icon base (GPL-3.0)
- [Arcticons](https://github.com/Donnnno/Arcticons) — the program and panel glyphs (CC BY-SA 4.0)
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) — Catppuccin's icon base (GPL-3.0)
- [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) — the coloured folders, pinned at `f83671d1`

**The full list is in [`docs/CREDITOS.md`](docs/CREDITOS.md)** and in each pack's `CREDITOS.md`:
cursors, fonts, wallpapers, in-app themes, what was turned down and what to do when redistributing
(in Portuguese).

Licence: GPL-3.0.
