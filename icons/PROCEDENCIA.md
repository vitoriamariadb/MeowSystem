# De onde vem cada ícone deste repositório

Uso **local**, numa máquina só. O repositório não é publicado (decidido em
05/08/2026). Mesmo assim a procedência fica registrada: é o que permite saber, no
dia em que alguma coisa mudar, o que pode ser modificado e o que não pode.

| acervo | onde | licença | pode modificar? | pode redistribuir? |
|---|---|---|---|---|
| `catppuccin/vscode-icons` | `icons/catppuccin/<flavor>/` | MIT | sim | sim, com o aviso de copyright |
| `Daveedmee/catppuccin-icons` | `icons/catppuccin-apps/<flavor>/` | **não declarada** | indefinido | **não** — uso local apenas |
| Arcticons | baixado sob demanda pela API do Iconify | **CC BY-SA 4.0** | **sim** | sim, **com atribuição e sob a mesma licença** |
| Papirus / Papirus-Dark | pacote `papirus-icon-theme` do sistema | GPL-3.0 | sim | sim, sob GPL |
| papirus-folders | `scripts/construir_pastas.sh` | GPL-3.0 | sim | sim, sob GPL |
| desenho autoral | `src/icons/autorais/` | deste projeto | — | — |

## Arcticons — o que a licença obriga

**CC BY-SA 4.0** é *share-alike com atribuição*. Uso privado numa máquina só não
dispara obrigação nenhuma. O que dispara é **distribuir**: aí é preciso creditar
o Arcticons e liberar o derivado sob a mesma licença. Como este repositório não
é publicado, o ponto é teórico — mas se um dia for, o share-alike passa a ter
consequência sobre os ícones derivados dele, e só sobre eles.

- Fonte: <https://github.com/Arcticons-Team/Arcticons>
- Medido em 05/08/2026 pela API do Iconify: **14.996 ícones**.
- Baixado **um a um**, nunca o repositório inteiro:
  `https://api.iconify.design/arcticons/<nome>.svg`
- Formato: traço monocromático, `viewBox="0 0 48 48"`, `stroke="currentColor"`,
  **sem `stroke-width` declarado** (o padrão SVG é 1 — ver
  `docs/COSMIC-THEMING.md` §4g, porque isso some a 22 px).

## O que o Arcticons cobre, e o que ele não cobre

É um catálogo de **logos de aplicativo Android**, não de conceitos de sistema.
Uma busca por `vpn` devolve NordVPN e ProtonVPN; por `dock`, TrustDock. Ainda
assim, os nomes genéricos existem e são exatamente os que faltavam aqui:
`wifi` `bluetooth` `volume` `battery` `keyboard` `mouse` `apps` `clock`
`palette` `power` `settings` `access` `contacts` `tile` `earth` `speaker`.

Ausentes como conceito genérico, medido contra o índice completo de nomes:
`ethernet` `router` `modem` `cable` `display` `monitor` `screen` `window`
`workspace` `user` `globe` `language`.

**Não force casamento.** O `arcticons:network` é um **telefone de mesa** — usá-lo
para "Rede com fio" mente sobre o que a coisa é, e isso é pior que deixar no
Papirus. A regra do projeto vale aqui igual: um ícone errado é pior que um
genérico.

## O que não se toca, por pedido expresso dela

Os jogos da Steam (`steam_icon_*`), o **Hefesto** (a logo é dela) e o
**FogStripper**. `scripts/icones_apps.sh` recusa esses nomes mesmo que entrem no
mapa — a lista está em `INTOCAVEIS` e `INTOCAVEIS_PREFIXO`.
