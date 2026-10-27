# P120 — a central de extensões: um método para applet, compositor e menu do Arquivos

Itens 10 e 11 do pedido. Leia `relatorios/levantamento-extensoes.md`, seções 1 e 2.

## O que se mediu
- Três métodos para a mesma coisa: applet = `assets/extensoes/*.pino` + `scripts/extensoes_build.sh`;
  compositor = `patches/series` + `scripts/compositor_patches.sh` + `scripts/garantir_builds.sh` +
  shim; menu = `scripts/files_menu.sh`. A aba Builds só tem «Refazer» no compositor e no menu
  (captura `extensoes-builds-1500x900.png`).
- `garantir_builds.sh estado` na máquina: `compositor_estado=ok` com `~/.local/bin/cosmic-comp`
  ausente (shim desligado). A página diria «Em dia».
- «Trocar» falha para a Dock: num HOME temporário com o `plugins_wings` real da Dock,
  `extensoes_build.sh status-hub --estado` dá `troca=io.github.marcelogomes90.cosmic-ext-applet-status-hub`
  e `extensoes_gesto.sh trocar status-hub` responde «o painel não cita…», rc 0, sem mudar nada.
- Applet por nome no código: `_quer` (só now-playing e leitura por padrão), `_tema_do` (`case`
  com Bandeja e AjustesRapidos), `ACAO_DA_PENDENCIA`/`NOME_DA_PENDENCIA` em `app/servidor.py`.
  `now-playing`, `leitura` e `performance` têm `TEMA=""`.

## Causa
- `scripts/extensoes_gesto.sh` `_arquivos_do_painel` lista só `com.system76.CosmicPanel.Panel`;
  `_painel_cita` (`extensoes_build.sh`) olha Panel e Dock. `cmd_por` só escreve no Panel.
- `scripts/garantir_builds.sh` `cmd_estado` decide `ok` por `_gb_comp_valido`, sem `_cp_shim_ativo`.
- O pino não tem tipo, padrão nem contrato de tema; cada exceção virou `case` no código.

## Cura na origem
1. O pino ganha `TIPO=applet|compositor|menu`, `PADRAO=sim|nao`, `TEMA_CHAVES` (as chaves do
   contrato de `tema.conf` do INTEGRACAO.md) e `ATIVA=painel|shim|caminho`. Dois pinos novos:
   `assets/extensoes/compositor.pino` e `assets/extensoes/menu-arquivos.pino`.
2. `extensoes_build.sh` despacha pela receita do tipo; para `compositor` e `menu` chama o que
   `compositor_patches.sh` e `files_menu.sh` já fazem (chave = versão do dpkg). `--estado` sai igual
   para os três, com `ativa=` (na barra / shim ligado / binário à frente no PATH). `_quer` lê
   `PADRAO` do pino; as chaves `MIDIA` e `LEITURA_APPLET` seguem valendo como «não» explícito.
3. `garantir_builds.sh estado` lê o `--estado` do pino do compositor; com build pronto e shim
   desligado, `compositor_estado=desligado`.
4. `extensoes_gesto.sh`: um verbo serve os três tipos (`instalar` liga o shim no compositor;
   `remover` o desliga e mantém o de fábrica); `_arquivos_do_painel` inclui a Dock; `por` escreve
   no painel onde o applet trocado morava, ou no Panel se não houver troca; verbo novo
   `reiniciar-painel`, só por gesto.
5. `extensoes_tema.sh` lê `TEMA` e `TEMA_CHAVES` do pino; sai o `case`.
6. `app/servidor.py`: ações `extensao_*` servem os três tipos; saem `build_compositor`,
   `files_menu_build` e os pares por applet de `ACAO_DA_PENDENCIA`/`NOME_DA_PENDENCIA` (a pendência
   vem do id do pino).
7. `app/pagina/extensoes.js`: a aba Builds usa o mesmo cartão (Instalar/Atualizar/Refazer/Remover),
   pílula «Pronto, desligado» quando `ativa=nao`; o aviso do «Trocar» ganha «Reiniciar o painel».

## Prova
- `tests/extensoes-gesto.sh`: `trocar` com o applet velho só na Dock troca na Dock; `por` sem troca
  vai ao Panel; segunda passada não escreve.
- `tests/garantir-builds.sh`: build pronto + shim desligado → `compositor_estado=desligado`;
  `instalar compositor` cria o shim no HOME de brinquedo; `remover` o tira.
- `tests/extensoes.sh`: pino com `PADRAO=sim` entra no `--todas` sem chave `EXTENSOES`; pino com
  `TEMA_CHAVES` gera o `tema.conf` sem `case`.
- `tests/extensoes-pagina.py`: a casa de brinquedo monta Panel **e** Dock; cartão do compositor com
  os quatro botões; «Pronto, desligado»; Trocar na Dock.
- `./tests/todos.sh` sem vermelho novo.

## Arquivos
`assets/extensoes/*.pino` (os cinco de hoje e os dois novos), `scripts/extensoes_build.sh`,
`scripts/extensoes_gesto.sh`, `scripts/extensoes_tema.sh`, `scripts/garantir_builds.sh`,
`app/servidor.py` (só o bloco `EXT_*`, `_ext_*`, as ações `extensao_*`/`build_*`/`files_menu_build`
e as duas tabelas de pendência), `app/pagina/extensoes.js`, `app/pagina/extensoes.css`,
`tests/extensoes.sh`, `tests/extensoes-gesto.sh`, `tests/garantir-builds.sh`,
`tests/extensoes-pagina.py`.

## Fora desta sprint
O install e o vizinho da Aurora (P121), os forks (P122), a limpeza da pasta (P123), o gerador de
ícone. `compositor_patches.sh` e `files_menu.sh` só são chamados, não reescritos.
