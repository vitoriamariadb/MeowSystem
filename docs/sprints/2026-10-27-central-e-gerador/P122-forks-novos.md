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

## Execução

Os quatro repositórios foram criados como fork na conta `vitoriamariadb`, com push no `main`
(o padrão do GitHub era `master` no Clipboard; saiu). Binário `meowsystem-<nome>`, `.desktop`,
ícone e metainfo pelo app id, `tema.conf` lido ao subir e a cada abertura do popup, `INTEGRACAO.md`,
`just install-user` e `just uninstall-user`, licença e autoria do upstream intactas e os dois autores
da casa acrescentados.

| fork | app id | commit pinado | libcosmic do pino | build do painel (`430f3d48`) |
|---|---|---|---|---|
| `meowsystem-eyedropper` | `io.github.meowsystem.Eyedropper` | `b60f4781e0c4c5b3ca56f0d109f98f033a4bc6af` | `c44dbe79` | compila |
| `meowsystem-clipboard` | `io.github.meowsystem.Clipboard` | `d504976ed59f20950ade22231eb3677421828e6a` | `dc1cf9f0` | não compila (`scroller_width`), cai no pino com `--locked` |
| `meowsystem-drives` | `io.github.meowsystem.Drives` | `099d4a940608710186ebbea27f1d7f095e122a13` | `dc1cf9f0` | compila |
| `meowsystem-ascii-battery` | `io.github.meowsystem.AsciiBattery` | `59d2538500b4e4b9f4ee10ec4d557decd2dd9ad6` | `c003a58f` | compila |

Nos quatro: `cargo build --release --locked` e `cargo test` verdes (o Clipboard com os testes da poda e da
migração, os outros com os do `tema.rs`).

### Itens da cura

1. Fork, nomes e tema: feito nos quatro. O Clipboard tem ainda a poda do histórico que o
   `aurora-clipboard` faz (1000 entradas, teto de 1 GB de imagem, favoritos intocados, na abertura e
   a cada hora, sob o lock) e copia o histórico do applet antigo na primeira subida, sem pisar em
   banco que já existe.
2. Pinos, em três commits: `6924d937` os quatro pinos e os ícones de cartão, `f002b960`
   as linhas dos upstreams em `docs/CREDITOS.md`, `454b3a17` as provas. `PADRAO=sim`,
   `SUBSTITUI` com o app id de hoje, `MIGRA_ESTADO` com o id antigo nos três que têm estado em
   `~/.local/state/cosmic/` (Eyedropper, Clipboard, Drives), `TEMA_CHAVES` com as sete chaves do contrato; a
   Bateria em ASCII leva `tinta:@acento`, os outros `tinta:text`.

### Provas rodadas

- `tests/extensoes.sh`: verde, com a seção nova dos quatro forks (pino do tipo applet e ligado por
  padrão, app id, binário, `SUBSTITUI`, `TEMA`, `TEMA_CHAVES`, ícone presente, `--estado` com
  `troca=<app id de hoje>` quando a Dock de brinquedo o cita).
- `tests/extensoes-pagina.py` (headless): 77 conferências, as 16 novas são os quatro cartões, cada um
  com nome, ícone carregado pelo servidor e «Não instalada».
- `applet-pino.sh`, `extensoes-gesto.sh`, `restos-do-painel.sh`, `nada-manda-digitar.sh`: verdes.
- `tests/decisoes.sh`: as duas falhas (GPU do compositor e shim) são do estado da máquina e
  aparecem igual sem os commits deste bloco.

### O que ficou de fora, e por quê

- **O formato do pino da P120 não existe no `dev`.** Os pinos têm `TIPO`, `PADRAO`, `CHAVE_DO_CONF`,
  `ATIVA` e `TEMA_CHAVES`, que o `extensoes_build.sh` do `dev` ignora (chave desconhecida é pulada) e o da
  `bloco/central` lê. Por isso as provas aqui mostram o que o `dev` enxerga (validação, `--estado`,
  cartões). A leitura de `TEMA_CHAVES` e a lista dos nove na página sobem com o merge da P120.
- **O `extensoes_tema.sh` do `dev` só sabe montar o tema da Bandeja e dos Ajustes rápidos.** Com um dos
  quatro instalados, ele avisaria «não montei o tema» até a P120 chegar; a versão da `bloco/central` monta a partir de
  `TEMA_CHAVES`. Nenhum dos quatro está instalado na máquina.
- **O `MIGRA_ESTADO` só copia `~/.local/state/cosmic/<id>/v1`.** O histórico em sqlite do Clipboard
  não passa por ele: é o próprio applet que o copia (`src/db/migra.rs`). A configuração JSON da Bateria em ASCII
  (`~/.config/<app id>/config.json`) não migra: o padrão vale.
- **O `persist` do Clipboard** (o `wl-clip-persist` do Aurora, que mantém o conteúdo depois que o
  app de origem fecha) não foi portado. Fica para um bloco próprio.
- **O corte do `aurora-clipboard`** (tirar a poda do script quando o applet novo estiver instalado) é a
  vizinhança anotada na P125; o script do Aurora não foi tocado.
- **Os limites do Clipboard** (`maximum_entries_number` 500 e vida de 30 dias, do upstream) ficaram
  como estão; vale o mais estrito entre eles e a poda.
- **Nenhum popup foi aberto**: não se instalou applet na máquina. A prova visual é a conferência dela.

### Para ela conferir com a mão

1. Instalar um fork pela página Extensões e pôr no painel: o popup e o botão com as cores do pack.
2. Trocar o pack (ou o sabor): as cores do popup mudam na próxima abertura.
3. Na troca do applet antigo, a Dock passa de `io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager`
   (e dos outros três ids) para o novo; a ordem dos applets é dela.
4. No Clipboard: o histórico antigo aparece na primeira abertura, e o que passa de 1000 entradas some na hora seguinte.
