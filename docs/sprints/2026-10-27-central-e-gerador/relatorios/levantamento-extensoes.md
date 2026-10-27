# Levantamento — Extensões, builds e infra local (itens 10 a 13)

Medido em 27/10/2026, na branch `dev` (`69ebd802`), nesta máquina, depois da desinstalação de
hoje. Nada foi mudado no código, nem no HOME real. Capturas headless (HOME de brinquedo, via
`tests/extensoes-pagina.py --fotos`) ficaram fora do repo, no scratchpad da sessão
(`/tmp/claude-1000/-home-vitoriamaria-Desenvolvimento-MeowSystem/a7736095-6179-4e12-b0ee-1944c28bfa25/scratchpad/capturas-extensoes/`).

Sprints que saem daqui: `P120-central-de-extensoes.md`, `P121-do-zero-e-o-compositor.md`,
`P122-forks-novos.md`, `P123-pasta-enxuta.md`.

## 0. O achado que muda a ordem: a Aurora reescreve o `/usr/bin/cosmic-comp`

- `/var/log/ritual-aurora-self-heal.log`, 27/10 10:25:38 e 10:27:01: «cosmic-comp-ws: REINSTALADO
  o build patchado (versão 0.1~1792508925~24.04~8cb1802) — vale no próximo login».
- O `apt-get install --reinstall cosmic-comp` da desinstalação rodou às 10:27:01 (`dpkg.log`). Às
  10:27:56 o md5 do `/usr/bin/cosmic-comp` batia com o pacote (`1907a3d0…`); na releitura o
  arquivo tinha 34 876 696 bytes, mtime 10:27:51 e md5 `162a8f0c…`, o do artefato
  `/var/lib/aurora/cosmic-comp-<versão>.aurora-ws`. **O reinstall de hoje foi desfeito.**
- Quem faz: `~/.config/zsh/scripts/ritual-aurora-self-heal.sh` (instalado em `/usr/local/sbin`,
  roda de hora em hora e no `DPkg::Post-Invoke` de `/etc/apt/apt.conf.d/99-ritual-aurora-self-heal`)
  chama `aurora-cosmic-comp-ws.sh --ensure` (bloco `if [ -x /usr/local/sbin/aurora-cosmic-comp-ws.sh ]; then … fi`).
  O `--ensure` reinstala o artefato e pode disparar `--build-auto` por `systemd-run`.
  `aurora-night-light.py` ainda remenda bytes do shader em `TARGET = "/usr/bin/cosmic-comp"`.
- `assets/contratos/vizinhos.tsv` (38 itens) não tem item para o compositor da Aurora.
- O log da Aurora também acusa «clipboard: applet de histórico NÃO está rodando — rode:
  aurora-clipboard doctor»: outro vizinho mexe no Clipboard Manager.

Consequência: enquanto o shim do MeowSystem estiver desligado, a sessão roda o build da Aurora
(mesmos cinco patches, marcadores `AURORA-*`), e o MeowSystem não sabe disso. É a P121.

## 1. A página Extensões contra a P114 (item 10)

Provas rodadas agora, no mesmo arnês do `tests/todos.sh` (HOME de brinquedo, `sudo`/`apt`/`pkill`
falsos): `extensoes.sh`, `extensoes-gesto.sh`, `garantir-builds.sh`, `compositor-shim.sh`,
`vizinhos.sh`, `midia.sh`, `leitura-fonte-unica.sh`, `extensoes-pagina.py` → **8 verdes, 0
pulados, 0 vermelhos**, nenhuma chamada a `sudo`.

| pedido da P114 | estado | prova |
|---|---|---|
| pino de dado por applet + etapa genérica | feito | `assets/extensoes/*.pino` (5), `scripts/extensoes_build.sh`, `tests/extensoes.sh` |
| tema do pack gerado pelo doctor | **meio** | `scripts/extensoes_tema.sh` `_tema_do` só conhece `Bandeja` e `AjustesRapidos`; `now-playing`, `leitura`, `performance` têm `TEMA=""` |
| cartão por applet com Instalar/Atualizar/Remover/Pôr no painel | feito | captura `extensoes-troca.png`, `tests/extensoes-pagina.py` (58 conferências) |
| troca pendente Trocar/Manter | **quebrada para a Dock** | ver abaixo |
| bloco Builds com estado e refazer | **meio** | compositor e menu só têm «Refazer»; sem instalar, ligar, remover; o estado mente (ver abaixo) |
| Adicionar repositório, Créditos | feito | capturas `extensoes-ficha.png`, `extensoes-creditos.png` |
| todos os applets nossos, forks `meowsystem-*` | **não** | Eyedropper, Clipboard Manager, Drives, ASCII-dot-battery não têm fork (P122) |

Defeitos medidos:

1. **«Trocar» não acha o que está na Dock.** Reproduzido num HOME temporário com o
   `plugins_wings` real da Dock dela copiado e um status-hub falso instalado:
   `extensoes_build.sh status-hub --estado` → `troca=io.github.marcelogomes90.cosmic-ext-applet-status-hub`;
   `extensoes_gesto.sh trocar status-hub` → «o painel não cita io.github.marcelogomes90…», rc 0,
   arquivo da Dock intacto. Causa: `_arquivos_do_painel` em `scripts/extensoes_gesto.sh` lista só
   `com.system76.CosmicPanel.Panel`, enquanto `_painel_cita` em `scripts/extensoes_build.sh` olha
   Panel e Dock. Pega o status-hub e o leitura, que nela moram na Dock. O `tests/extensoes-pagina.py`
   só monta `CosmicPanel.Panel`, por isso fica verde. `cmd_por` também só escreve no Panel.
2. **O estado do compositor diz «Em dia» com o shim desligado.** `garantir_builds.sh estado`
   agora, na máquina: `compositor_estado=ok`; `~/.local/bin/cosmic-comp` não existe;
   `compositor_shim.sh` com `MEOW_SHIM_SO_DIZER=1` escolheria o build, mas ninguém o chama. Causa:
   `cmd_estado` usa só `_gb_comp_valido` (binário + `estado`), nunca `_cp_shim_ativo`.
3. **O doctor compila para nada.** Às 10:25:39 o `pos-apt` baixou o fonte e às 10:29:28 guardou o
   build em `~/.local/libexec/meow/cosmic-comp/0.1~1792508925~24.04~8cb1802/` (~3 min 50 s, vendor
   quente) e escreveu «o shim está desligado: o build fica guardado, sem efeito na sessão». A
   desinstalação de hoje apagou esse build às 10:23; ele voltou sozinho seis minutos depois.
4. **Ligar o shim só pela linha de comando.** `cmd_ativar` de `scripts/compositor_patches.sh` só é
   chamado por `bin/meow compositor ativar`; nem `install.sh`, nem o doctor, nem a página o chamam.
   `docs/MANUTENCAO.md` manda digitar `meow compositor ativar` (fere «nenhuma saída manda digitar»).
   `tests/decisoes.sh` confere o shim no HOME real e está vermelho por isso desde a QA final.
5. **Applet por nome no código.** `_quer` (`extensoes_build.sh`) só instala por padrão
   `now-playing` (`MIDIA`) e `leitura` (`LEITURA_APPLET`); os outros três dependem de uma chave
   `EXTENSOES` que o `meow.conf` dela não tem. `app/servidor.py` tem `ACAO_DA_PENDENCIA` e
   `NOME_DA_PENDENCIA` com um par por applet. `_tema_do` é um `case` por app id.

## 2. A central unificada: um método para applet e build (item 11)

Hoje há três métodos: applet = pino + `extensoes_build.sh`; compositor = `patches/series` +
`compositor_patches.sh` + `garantir_builds.sh` + shim, chaveado pela versão do dpkg; menu do
Arquivos = `files_menu.sh` com marcador no binário. A proposta (P120) é um contrato só, dado no
pino, e cada tipo é uma receita atrás dele:

```
assets/extensoes/<id>.pino
  TIPO=applet|compositor|menu       a receita que compila (applet: cargo do repo pinado;
                                    compositor/menu: fonte do apt + patches/, chave = versão do dpkg)
  PADRAO=sim|nao                    o doctor instala sozinho (com selo de rede, decisão 7) ou só por gesto
  TEMA=<app id>  TEMA_CHAVES=...    o contrato de cores do INTEGRACAO.md vira dado, sem case no código
  ATIVA=painel|shim|caminho         o que «pôr para valer» significa: entrar no painel/Dock,
                                    ligar o shim do compositor, pôr o binário à frente no PATH
```

- **Estado único**, impresso pelo mesmo `--estado` para todos: `instalada`, `em_dia`, `ativa`
  (na barra / shim ligado / binário à frente), `atualizacao`, `troca`, `falhou`, `compilando`.
  Para o compositor, `ativa=nao` com build pronto vira pílula «Pronto, desligado» e não «Em dia».
- **Cartão igual** nas duas abas, com os mesmos quatro botões: **Instalar** (compila e ativa),
  **Atualizar** (pino novo ou versão do apt nova), **Refazer** (recompila o mesmo), **Remover**
  (desativa e apaga; para o compositor, desligar o shim e manter o de fábrica). «Pôr no painel» e
  «Trocar» continuam no applet porque `ATIVA=painel`.
- **Um gesto, um caminho**: `extensoes_gesto.sh <verbo> <id>` passa a servir os três tipos; o
  servidor deixa de ter `build_compositor` e `files_menu_build` como ações à parte.
- O `garantir_builds.sh` fica como o gatilho por versão do dpkg (login, pós-apt), chamando a
  receita do tipo; deixa de decidir estado.

## 3. Instalar do zero pelo MeowSystem (item 13)

O caminho de hoje, medido no código, sem rodar o install:

| passo | quem | senha | tempo |
|---|---|---|---|
| 1. `install.sh` (ela já fez uma vez; refazer é idempotente) | ela, no terminal | **sim, uma vez** (`apt` dos pacotes, `MEOW_DEPS_DOS_APPLETS`) | minutos |
| 2. rust pelo rustup em `~/.cargo` (`meow_garantir_cargo`) | install/doctor | não | 1 a 2 min (já existe: cargo 1.99.1) |
| 3. `etapa_extensoes`: compila os applets com `EXTENSOES_COMPILAR=1` | install | não | status-hub ~4 min (INTEGRACAO.md); os outros **não medidos**, estimo 3 a 6 min cada com o registro do cargo quente (460 MB em `~/.cargo/registry`) |
| 4. `etapa_files_menu`: menu do Arquivos | install / login | não | «minutos», ~161 MB de fonte; não medido |
| 5. compositor | **ninguém no install**; só o doctor/pós-apt, em fundo | não | 3 min 50 s medido hoje com vendor quente; ~30 min do zero (texto do script) |
| 6. ligar o shim | **só digitando** `meow compositor ativar` | não | instantâneo, vale no próximo login |
| 7. trocar as entradas velhas do painel | página, «Trocar» | não | **falha para a Dock** (status-hub, leitura) |
| 8. o painel reler | **ninguém** | não | o `cosmic-panel` só relê ao subir; hoje ela precisaria sair da sessão |

Na página, depois do install: Extensões → Applets → «Instalar» em cada cartão que não for padrão
(performance, quick-settings, status-hub, hoje fora do `_quer`) → «Trocar» na faixa de troca →
sair e entrar na sessão. Nenhum desses pede senha (decisão 11). O compositor não tem cartão que
instale.

O que falta para ela não digitar nada (P121, depois da P120):

1. Etapa `etapa_compositor` no `install.sh` que compila em fundo e liga o shim pela receita do
   tipo `compositor` (sem `meow compositor ativar` à mão), com a guarda de quedas que o
   `compositor_shim.sh` já tem.
2. O item do vizinho: Aurora sai do compositor quando o shim do MeowSystem estiver ligado (bloco
   do `--ensure` no self-heal, com `requer` apontando a receita do shim), e o `/usr/bin` volta ao
   de fábrica pela ponte de root (o shim cai nele quando o build falha).
3. «Trocar» e «Pôr no painel» que conheçam a Dock.
4. Reiniciar o painel por gesto depois da troca (botão no aviso «vale quando o painel reiniciar»),
   nunca sozinho.
5. `docs/MANUTENCAO.md` sem comando para digitar; `tests/decisoes.sh` com a prova do shim no HOME
   de brinquedo.

Ordem final sem digitar: install (uma senha) → doctor em fundo compila applets padrão, menu e
compositor e liga o shim (estimado: ~30 min com cargo quente, ~1 h do zero; só o compositor foi medido) → página: «Trocar», «Reiniciar o
painel» → próximo login: compositor da casa.

## 4. Os forks novos (item 10, P122)

Dados lidos dos manifestos de `pop-os/cosmic-flatpak` (`app/<id>/<id>.json`) e da API do GitHub.

| applet | app id de hoje | upstream | licença | HEAD (data) | libcosmic do flatpak | arquivos de dado |
|---|---|---|---|---|---|---|
| Eyedropper | `io.github.nalladev.CosmicExtAppletEyedropper` | nalladev/cosmic-ext-applet-eyedropper (flatpak v0.6.1, Cargo 0.6.2) | MPL-2.0 | `29becada` (13/09) | `c44dbe79` | `resources/app.desktop`, `app.metainfo.xml`, `icon.svg`, justfile |
| Clipboard Manager | `io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager` | cosmic-utils/clipboard-manager (flatpak `7d2c3789`) | GPL-3.0 | `27a246fa` (25/10) | `dc1cf9f0` | `res/desktop_entry.desktop`, `res/app_icon.svg`, `res/icons/*`, `migrations/` (sqlite), `build.rs` |
| Drives | `dev.cappsy.CosmicExtAppletDrives` | cosmic-utils/cosmic-ext-applet-drives (flatpak v0.1.2) | GPL-3.0 | `4a410b3c` (19/09) | `dc1cf9f0` | `resources/app.desktop`, `resources/icons/hicolor/scalable/apps/icon.svg` |
| ASCII-dot-battery | `com.github.pewmoe.cosmic-ext-ASCII-dot-battery` | pewmoe/Cosmic-Desktop-ASCII-Battery-Applet (flatpak `6f9989e4`, 1.3.0) | MPL-2.0 | `195f2ca7` (23/09) | `c003a58f` | `resources/app.desktop`, `icon.svg`, `build.rs` |

O painel instalado é `cosmic-panel 1.11.0~1792526322`; o `_aplicar` já reaponta a libcosmic para a
do painel e cai no pino com `--locked`.

O que cada fork precisa para o contrato da casa (o molde é o `INTEGRACAO.md` do
`meowsystem-status-hub`): repo `vitoriamariadb/meowsystem-<nome>`; app id
`io.github.meowsystem.<Nome>`; binário `meowsystem-<nome>`; `.desktop`, ícone e metainfo
renomeados para o app id (hoje são `app.desktop`/`icon.svg` genéricos, e o `ICONES` do pino copia o
nome do arquivo: o ícone ficaria com nome errado); leitura de
`~/.config/meowsystem/extensoes/<app id>/tema.conf` ao abrir o popup; `INTEGRACAO.md`; licença e
autoria do upstream mantidas; pino com `SUBSTITUI=<app id de hoje>` para o «Trocar». O Eyedropper,
o Clipboard Manager e o status-hub dela estão na Dock: a P122 depende do «Trocar» da Dock (P120).
O Clipboard Manager guarda histórico em sqlite: o pino precisa de `MIGRA_ESTADO` do flatpak (dados
mantidos na desinstalação de hoje).

## 5. Pasta local x infra enxuta (item 12, P123)

`git status --porcelain --ignored`: 139 linhas. Nada foi apagado. Destinos propostos:

| caminho | tamanho | origem | destino |
|---|---|---|---|
| `src/applets/` | 1,5 GB | só `leitura/target`: sobra do cargo da era em que o applet morava no repo | apagar |
| `assets/papeis-de-parede/` | 321 MB, 348 arquivos | acervo antigo, anterior ao pack | **mover** para `~/.local/share/backgrounds/meowsystem` (o padrão do `wallpaper.sh`) e o doctor troca o `WALLPAPER_BASE`; ver pergunta 3 |
| `assets/icones/upstream/` | 95 MB, 21 882 arquivos | download antigo; hoje o `baixar_upstream.sh` baixa em `$MEOW_CACHE/upstream` | apagar (cache refaz) |
| `assets/icones/catppuccin-apps/` (ignorado), `catppuccin/` | 205 MB + 13 MB | geração de setembro | apagar (cache) |
| `.playwright-mcp/` | 92 MB | capturas de UX das levas P73–P90 | apagar |
| `MeowSystem-master.zip` | 12 MB, 3 187 arquivos | instantâneo de 25/10 | apagar (o git tem) |
| `.trabalho-icones/` (ignorado) | 24 MB | trabalho do gerador | apagar ou cache |
| `assets/fontes/upstream/` | 6,1 MB | download de fonte | cache |
| `docs/folhas/`, `docs/pesquisas/` | 6,3 MB + 7,9 MB | pesquisa antiga | branch `arquivo` (decisão 24) |
| `assets/icones/*.map`, `autorais/`, `arcticons*`, `convertidos-apps/`, `tray-terceiros/`, `previa-arcticons/`, `PROCEDENCIA.md` | — | sobras de setembro; os mapas vivos são `packs/meowsystem/icones/*.map` | conferir diferença com o pack; o que não estiver lá, branch `arquivo` |
| `assets/temas/capturados/{latte-mauve,mocha-mauve,mocha-pink}` | — | capturas fora do git (123 capturadas estão no git) | pack, se forem do pack; senão apagar |
| `assets/gatos/`, `assets/cursores/`, `assets/temas-de-apps/` (3,2 MB), `assets/sons/CREDITOS.md`, `assets/paleta/catppuccin.json`, `assets/prompt/aurora.patch` | — | anteriores à pasta `packs/` | o que for arte, ao pack; o resto, branch `arquivo` |
| `app/pagina/previas-sistema.js`, `previas-tela.js` | — | saíram do git (último commit `20b285d8`); nada os carrega | apagar |
| `scripts/icones_apps.sh`, `vizinhos.conf.exemplo`, `docs/capturas/spotify.jpg`, `aba7.png`, `Imagem colada.png` | — | sobras | apagar |
| `assets/apps/jogos-fora.map` (modificado) | — | mudança local não commitada | ela decide: commit ou descartar |
| `__pycache__/`, `assets/temas/*.ron`, `packs/dracula/temas/capturados/{alucard-mauve,dracula-pink}` | — | gerados | ficam (ignorados) |
| `docs/sprints/2026-10-26-qa-final/{capturas,fotos}` | 39 MB, ignorados | leva fechada | branch `arquivo` ou apagar |

Fora do repo, ligados a ele:

- **`assets/papeis-de-parede/ativos-dia` é o fundo vivo dela**: `~/.config/cosmic/com.system76.CosmicBackground/v1/all`
  e as duas saídas apontam `source: Path("/mnt/Apate/Desenvolvimento/MeowSystem/assets/papeis-de-parede/ativos-dia")`
  (`/mnt/Apate/Desenvolvimento` é a mesma pasta, mesmo inode), e o `meow.conf` tem
  `WALLPAPER_BASE` no repo. Das 340 imagens, 339 não têm cópia fora do repo; só 75 das 344 estão no
  `packs/meowsystem/wallpapers/FONTES.tsv` (ativos 32/43, dia 15/20, noite 17/23, banidos 11/258).
  Apagar a pasta tira o fundo dela e perde as imagens.
- `~/.local/state/meowsystem/midia` 1,6 GB e `leitura` 1,5 GB: árvores de build da era antiga dos
  applets (hoje é `extensoes/<id>`): apagar.
- `~/.cache/meowsystem/cosmic-comp` 3,3 GB: fonte e alvo do build de hoje: cache, fica.
- `~/.local/state/meowsystem/backups` 401 MB (inclui a desinstalação de hoje): fica.

Pastas irmãs em `~/Desenvolvimento`: nenhuma árvore `MeowSystem-*` sobrou. `meowsystem-{leitura,
now-playing,performance,quick-settings,status-hub}` são os repos dos applets (ficam).
`cosmic-comp-patch/` 3,3 GB é o build da Aurora (sem git; o `.tar.xz` de 94 MB é o mesmo fonte que
o MeowSystem guarda em `~/.local/share/meowsystem/fontes`): sai junto com o item do vizinho (P121).
`Meow-Portatil` é link para `~/.config/zsh`; `Spellbook-OS` é link para `~/Remotos/Spellbook-OS`;
`extra-cosmic-xkill-applet` (368 KB, repo dela de 16/01) e `vitoriamariadb` (perfil) ficam.

## Anotado para depois

- Gerador de ícone: a moldura de quatro cantos soltos que não fecha o retângulo (foto 5, a fala
  dela). É do item 8, não desta área.
- `patches/series` diz no cabeçalho «a lista que o aurora-cosmic-comp-ws.sh aplica»: texto velho.
- `patches/versao` só lista `0.1~1791491785`; a versão instalada passa pela matriz.
- `aurora-clipboard doctor` e o Clipboard Manager da casa: precisará de item de vizinho quando o
  fork existir.
- A página não mostra tempo estimado de compilação; o build do compositor do zero leva ~30 min.

## Perguntas que só ela decide

1. **Quais applets o doctor instala sozinho?** Recomendo `PADRAO=sim` nos cinco da casa e nos
   quatro forks (todos estavam na barra dela), com o selo «baixa da internet» da decisão 50.
2. **O compositor passa a ser só do MeowSystem?** Recomendo sim: shim ligado pelo install, a
   Aurora sai pelo vizinho e o `/usr/bin` volta ao de fábrica pela ponte de root. Hoje o
   `/usr/bin/cosmic-comp` já é o da Aurora de novo (10:27:51).
3. **O acervo antigo de papéis de parede.** Recomendo mover a pasta inteira para
   `~/.local/share/backgrounds/meowsystem` e o doctor apontar o fundo para lá, sem apagar imagem.
4. **Reiniciar o painel depois do «Trocar»?** Recomendo um botão «Reiniciar o painel» no aviso, nunca
   automático.
5. **Nomes dos forks.** Recomendo `meowsystem-eyedropper`, `meowsystem-clipboard`,
   `meowsystem-drives` e `meowsystem-ascii-battery`, no padrão dos que já existem (`now-playing`,
   `status-hub`, `quick-settings`: o nome do upstream sem o `cosmic-ext-applet-`).
