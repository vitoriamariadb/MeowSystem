# O prompt

O prompt do terminal é o `starship`, na paleta do pack no ar.

| peça | onde | quem escreve |
|---|---|---|
| o preset | `~/.config/starship.toml`, de `assets/prompt/starship.toml` com as cores do pack e do flavor | `scripts/prompt.sh aplicar` |
| o `starship init` | `~/.config/meowsystem/terminal.sh`, carregado pelo bloco marcado do `.bashrc`/`.zshrc` | `scripts/terminal_bloco.sh` (decisão 20) |
| o binário | `~/.local/bin/starship`, pelo instalador oficial | `scripts/prompt.sh instalar-starship`, no install (decisão 26) |

## O preset

É o `catppuccin-powerline` oficial (<https://starship.rs/presets/toml/catppuccin-powerline.toml>),
com quatro mudanças:

1. as cores saem da paleta do pack, pelo papel, e o nome da paleta é `<pack>_<flavor>`;
2. o segmento de cabeça usa o acento `mauve`, e vermelho no prompt significa só erro;
3. `Pop = "…"` em `[os.symbols]`: sem a linha, o starship desenha um emoji que a Nerd Font não
   tem;
4. `show_notifications = false`: o preset penduraria uma notificação a cada comando demorado.

A fonte é a `JetBrainsMono Nerd Font Mono` do `scripts/instalar_fontes.sh`, a mesma do
`cosmic-term`; todos os glifos não-ASCII do preset existem nela.

## Verbos

| verbo | o que faz |
|---|---|
| `aplicar` | escreve o `starship.toml`; idempotente |
| `conferir` | `0` no lugar, `1` o arquivo divergiu (o doctor conserta), `3` falta o starship ou `PROMPT_STARSHIP="nao"` |
| `instalar-starship` | baixa o instalador oficial para `~/.local/bin`, sem `sudo` |
| `nao-quero-starship` | grava a recusa; o install deixa de baixar |
| `remover` | tira o `starship.toml` |

O doctor não baixa o starship: ausente é pulado de rotina. Para desligar tudo,
`PROMPT_STARSHIP="nao"` no `meow.conf`.
