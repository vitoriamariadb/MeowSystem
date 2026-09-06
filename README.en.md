<div align="center">

# MeowSystem

**Catppuccin for COSMIC, built for one machine — and documented well enough to become yours.**

Theme, icons, panel, dock, terminal and wallpaper for Pop!_OS with COSMIC in a single installer,
plus a local panel that changes all of it without opening a text file.

<img src="docs/capturas/painel.png" width="920" alt="The MeowSystem configuration panel, home screen">

[Português](README.md) · [Full manual](docs/) · GPL-3.0

</div>

---

## Install

```bash
git clone https://github.com/[REDACTED]/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # first run: asks four questions, then installs
meow ativar               # every other run
```

52 steps. Running it again on a machine that is already set up **writes nothing** — and says so,
instead of listing the steps as if it had redone them. To see what would happen before letting it
happen: `MEOW_DRY_RUN=1 ./install.sh`.

## The panel

```bash
meow abrir                # or the MeowSystem icon in the launcher
```

103 settings and 37 actions across twelve pages — one per subject, each holding everything there
is about it:

- **Papel de parede** (wallpaper) — the 46-image collection, the nine settings and the seven
  actions, on one screen. Dropping a file here says right away whether it landed in the day or
  the night group, and why.
- **Ícones** (icons) — one icon per installed program, swappable one by one, plus the theme the
  project builds.
- **O gato** (the cat) — the dock one and the terminal one, and who picks: you, the clock, or the
  shuffle.
- Plus **Barra e dock**, **Terminal**, **Dia e noite**, **Programas e jogos**, **Manutenção**.
- **Atualizar o sistema** (upgrade) — `apt`, `flatpak` and `cargo` on one screen, and right after
  it the `doctor` telling you what the upgrade undid. That second half is what a `full-upgrade`
  by hand doesn't have.

Every variable the installer reads has a control here — and a test enforces it, so a new key
can't be born invisible.

Clicking never changes the machine: choices pile up and a single button writes and applies them.
The **Ensaiar sem gravar** switch (dry run) shows what would happen, writing nothing.

<img src="docs/capturas/painel-forma.png" width="920" alt="The panel-and-dock tab, with a live drawing above the controls">

## What it dresses

| | |
|---|---|
| **The COSMIC theme** | All four trees, applied by file copy. Light and dark are the same theme with a switch, so switching doesn't flash the interface. |
| **The login screen** | `cosmic-greeter` keeps its own config and shipped empty: the last surface still stock. |
| **Panel and dock** | Shape, radius, margin, spacing and padding per segment; the blur that survives a maximized window; seconds on the clock; and the playing track beside it, with cover art and controls. |
| **The icons** | Papirus as the base, folders tinted by the accent colour, and Arcticons glyphs per program — swappable one by one, from the panel. |
| **The terminal** | All sixteen colours, the cursor, the `starship` prompt, and the cat replacing the `fastfetch` logo, redrawn in characters on every build. |
| **The wallpaper** | A carousel of 46 curated images, day and night folders split by luminance, next/previous on right-click, and favourites. |
| **Day and night** | One schedule rules everything that asks "is it night?": the dock cat, the terminal cat, the background, and reading mode — which warms the screen and gives it paper texture, on a ramp. |
| **Programs** | Spotify, VS Code and friends themed from the inside; Steam games with one launcher entry each, removed when the game is. |

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

## Check and undo

```bash
meow doctor                            # 46 checks. Writes nothing.
meow doctor --consertar                # applies only what is out of place
./scripts/aplicar_tema.sh original     # restores the previous theme
meow desinstalar                       # removes theme, icons and timers
```

Every write to a system file leaves a copy behind first, and the installer **refuses by path** —
not by good intentions — to write anywhere it doesn't know.

## What to expect

This repository was born for one machine: **Pop!_OS 24.04 LTS with COSMIC**, `apt`, an RTX 4060
and her Steam `.desktop` files. That coupling is allowed and written down — absolute paths, the
`cosmic-greeter` uid, the list of programs the launcher hides. What you get in return is the
opposite of the usual: `--wizard` asks only the four essential keys, `doctor` tells you what is
out of place before the screen does, and nothing is applied without a copy of what was there
before. If your machine looks like this one, install it. If it doesn't, read `doctor` — it talks.

## Requirements

Pop!_OS 24.04 LTS · COSMIC 1.0 · `bash`, `python3` and `apt`. The panel opens in whichever browser
is already installed, and only listens on `127.0.0.1`.

## Credits

- [Catppuccin](https://github.com/catppuccin/catppuccin) — the palette (MIT)
- [Arcticons](https://github.com/Donnnno/Arcticons) — the program and panel glyphs (CC BY-SA 4.0)
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) — the icon base (GPL-3.0)
- [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) — the coloured folders, pinned at `f83671d1`

Licence: GPL-3.0.
