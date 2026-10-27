# P122 — os quatro forks: Eyedropper, Clipboard Manager, Drives e ASCII-dot-battery

Item 10 do pedido («todos os applets nossos»). Leia `relatorios/levantamento-extensoes.md`, seção 4.
O código dos forks pode andar junto com a P120; os pinos entram depois dela (campos `PADRAO`,
`TEMA_CHAVES`).

## O que se mediu
| applet | upstream | licença | commit a pinar | libcosmic | app id de hoje (na barra dela) |
|---|---|---|---|---|---|
| Eyedropper | nalladev/cosmic-ext-applet-eyedropper | MPL-2.0 | `29becadabe9c1b792db877e02cd7e8b9419be20d` | `c44dbe79` | `io.github.nalladev.CosmicExtAppletEyedropper` (Dock) |
| Clipboard Manager | cosmic-utils/clipboard-manager | GPL-3.0 | `27a246fab0c3051a89f67e137dddada1869145ca` | `dc1cf9f0` | `io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager` (Dock) |
| Drives | cosmic-utils/cosmic-ext-applet-drives | GPL-3.0 | `4a410b3cfaa5e53e89b1ea3c582b6965d22e968c` | `dc1cf9f0` | `dev.cappsy.CosmicExtAppletDrives` |
| ASCII-dot-battery | pewmoe/Cosmic-Desktop-ASCII-Battery-Applet | MPL-2.0 | `195f2ca70bb3bbd25534e75e6316471b30da9272` | `c003a58f` | `com.github.pewmoe.cosmic-ext-ASCII-dot-battery` |

Os flatpaks foram removidos hoje com os dados mantidos. Os arquivos de dado são genéricos
(`resources/app.desktop`, `icon.svg`, `res/app_icon.svg`); o `ICONES` do pino copia o nome do
arquivo, então o ícone instalado ficaria `icon.svg`.

## Causa
Os quatro vêm de terceiros pelo Flathub: sem tema do pack, sem pino, fora da página Extensões.

## Cura na origem
1. Para cada um, repo `vitoriamariadb/meowsystem-<nome>` (fork do upstream, nome pela pergunta 5 do
   relatório), com: app id `io.github.meowsystem.<Nome>`; binário `meowsystem-<nome>`; `.desktop`,
   ícone e metainfo renomeados para o app id; `Exec` absoluto pela receita; leitura de
   `~/.config/meowsystem/extensoes/<app id>/tema.conf` ao abrir o popup (contrato do
   `INTEGRACAO.md` do `meowsystem-status-hub`); `INTEGRACAO.md`; licença e autoria do upstream
   intactas, os dois autores da casa acrescentados.
2. Criar o repo no GitHub é dela (nada de push pelo agente): o agente prepara as pastas locais em
   `~/Desenvolvimento/meowsystem-<nome>` e o roteiro de publicação.
3. Um pino por fork em `assets/extensoes/`, `TIPO=applet`, `SUBSTITUI=<app id de hoje>`,
   `UPSTREAM`, `TEMA`/`TEMA_CHAVES`; o Clipboard Manager com `MIGRA_ESTADO` do histórico sqlite do
   flatpak (`~/.var/app/<id>/`).
4. Ícone de cartão em `assets/extensoes/icones/<id>.svg`; créditos dos upstreams no diálogo
   Créditos (dado já lido do pino).

## Prova
- Em cada repo: `cargo build --release --locked` verde com a libcosmic do painel instalado
  (`cosmic-panel 1.11.0~1792526322`) e com a do pino.
- `tests/extensoes.sh`: os quatro pinos válidos (`_pino_valido`), `--estado` com `troca=` apontando
  o app id de hoje quando ele está na Dock de brinquedo.
- `tests/extensoes-pagina.py`: os quatro cartões aparecem com ícone e nome.
- Manual, com ela: popup de cada um com as cores do pack; trocar o pack troca as cores.

## Arquivos
`assets/extensoes/{eyedropper,clipboard,drives,ascii-battery}.pino`,
`assets/extensoes/icones/{eyedropper,clipboard,drives,ascii-battery}.svg`, `docs/CREDITOS.md` (só as
linhas dos upstreams novos), as quatro pastas `~/Desenvolvimento/meowsystem-*` novas (fora do repo).

## Fora desta sprint
O método e a página (P120), o item de vizinho do `aurora-clipboard` (anotado), mudar o
comportamento dos applets além do tema e dos nomes.
