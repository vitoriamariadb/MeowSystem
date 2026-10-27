# P121 — do zero sem digitar: o install liga o compositor, e a Aurora sai dele

Item 13 do pedido. Depende da P120 (verbo `instalar compositor`). Leia
`relatorios/levantamento-extensoes.md`, seções 0 e 3.

## O que se mediu
- `/var/log/ritual-aurora-self-heal.log`, 27/10 10:25:38 e 10:27:01: «cosmic-comp-ws: REINSTALADO
  o build patchado». O `apt-get install --reinstall cosmic-comp` das 10:27:01 foi desfeito às
  10:27:51: `/usr/bin/cosmic-comp` com md5 `162a8f0c…`, o do `/var/lib/aurora/*.aurora-ws`.
- `assets/contratos/vizinhos.tsv`: 38 itens, nenhum para o compositor.
- `install.sh`: nenhuma etapa de compositor nem de shim. `cmd_ativar` de
  `scripts/compositor_patches.sh` só é chamado por `bin/meow compositor ativar`.
- `pos-apt.log` de hoje: o compositor foi compilado às 10:25:39–10:29:28 (~3 min 50 s, vendor
  quente) com «o shim está desligado: o build fica guardado, sem efeito na sessão».
- `docs/MANUTENCAO.md` manda digitar `meow compositor ativar`; `tests/decisoes.sh` confere o shim
  no HOME real (vermelho aceito na QA final).
- O PATH da `cosmic-session` já põe `~/.local/bin` antes de `/usr/bin`: o shim funcionaria.

## Causa
- A Aurora é dona do compositor no `ritual-aurora-self-heal.sh`, bloco
  `if [ -x /usr/local/sbin/aurora-cosmic-comp-ws.sh ]; then … fi` (`--ensure`), e o
  `vizinhos.tsv` não a tira dele.
- Ligar o shim foi deixado como gesto de linha de comando: falta etapa no `install.sh` e caminho
  no doctor.

## Cura na origem
1. `assets/contratos/vizinhos.tsv`: item `aurora-compositor`, tipo `bloco`, arquivo
   `$ZD/scripts/ritual-aurora-self-heal.sh`, início
   `if [ -x /usr/local/sbin/aurora-cosmic-comp-ws.sh ]; then`, fim `^fi$`, `requer` o shim da
   receita do compositor (P120), motivo «o compositor é do MeowSystem (shim em ~/.local/bin)».
   O self-heal se reinstala de `$SRC` (`install_if_diff … ritual-aurora-self-heal.sh`), então o
   bloco chega ao `/usr/local/sbin` na passada seguinte: provar.
2. `install.sh`: `etapa_compositor` depois de `etapa_extensoes`, que chama
   `extensoes_gesto.sh instalar compositor` em fundo (`garantir_builds.sh --fundo`) e liga o shim
   quando o build é válido. Chave `COMPOSITOR=sim|nao` no `meow.conf.exemplo`.
3. O doctor: `chk_patches` diverge quando há build válido e shim desligado com `COMPOSITOR=sim`;
   `fix_patches` liga o shim; sem build, compila em fundo como hoje.
4. O `/usr/bin/cosmic-comp` remendado pela Aurora volta ao de fábrica pela ponte de root
   (decisão 11), uma vez, depois que o item do vizinho saiu; o shim cai nele quando o build falha.
   `aurora-night-light.py` remenda o mesmo `/usr/bin`: medir se o modo de leitura da casa cobre e,
   se sim, segundo item do vizinho.
5. `docs/MANUTENCAO.md` sem comando para digitar; `tests/decisoes.sh` prova o shim no HOME de
   brinquedo, não no real.

## Prova
- `tests/vizinhos.sh`: o item novo corta só o bloco do `--ensure` numa cópia do self-heal; com o
  shim ausente, o `requer` impede o corte; `--restaurar` devolve.
- `tests/garantir-builds.sh`: `COMPOSITOR=sim`, build válido, shim ausente → doctor diverge e o
  conserto cria `~/.local/bin/cosmic-comp` com `MEOW-COSMIC-COMP-SHIM-1`; segunda passada não
  escreve.
- `tests/miudos-do-install.sh` (ou teste novo `tests/etapa-compositor.sh`): `etapa_compositor` presente e em fundo, sem `sudo`.
- `tests/decisoes.sh` verde sem tocar no HOME real.
- Manual, com ela: depois do login, `readlink /proc/$(pgrep -x cosmic-comp)/exe` aponta para
  `~/.local/libexec/meow/cosmic-comp/<versão>/cosmic-comp`.

## Arquivos
`assets/contratos/vizinhos.tsv`, `install.sh` (só a etapa nova e a lista de etapas), `bin/meow`
(`chk_patches`, `fix_patches`), `meow.conf.exemplo`, `docs/MANUTENCAO.md`, `tests/vizinhos.sh`,
`tests/garantir-builds.sh` (bloco novo, no fim), `tests/decisoes.sh` (a prova do shim),
`tests/miudos-do-install.sh` ou `tests/etapa-compositor.sh`.

## Fora desta sprint
O cartão e o método (P120), os forks (P122), apagar `~/Desenvolvimento/cosmic-comp-patch` (P123),
mexer no `aurora-cosmic-comp-ws.sh` em si.

## Execução
Feita em 27/10/2026, na `bloco/central`.

- `vizinhos.tsv`: dois itens. `aurora-compositor` (o bloco do `--ensure`, quatro linhas) e
  `aurora-night-light` (o bloco do `aurora-night-light.py`, até o `fi` da coluna 0). Medido: o modo
  de leitura da casa cobre o night-light (`req cosmic-comp-modo-leitura.patch AURORA-READING-MODE` na
  série, `scripts/leitura.sh` escreve `leitura_temperatura`/`leitura_textura`), então ele sai junto.
  Os dois `requer` o shim: `$HOME/.local/bin/cosmic-comp:MEOW-COSMIC-COMP-SHIM-1`; o
  `vizinhos.sh` passou a ler um `requer` com `$HOME/` na casa (`_requer_ok`).
- Ensaio numa cópia do self-heal real (no scratchpad, nunca no `$ZD`): 19 linhas comentadas (4 + 15),
  `bash -n` limpo, nada mais muda.
- `install.sh`: `etapa_compositor` depois de `etapa_extensoes`; com `COMPOSITOR="nao"` tira o shim.
  Chave `COMPOSITOR="sim"` no `meow.conf.exemplo` e no `chave-etapa.tsv`.
- `extensoes_build.sh`: em fundo, o build que já corre não é pedido de novo nem conta como mudança
  (sem isso o install fazia cinco passagens enquanto o build rodava).
- `bin/meow`: `chk_patches` diverge com build pronto, shim fora e `COMPOSITOR=sim`; `fix_patches`
  segue disparando o `garantir_builds.sh --fundo` e depois liga o shim.
- `docs/MANUTENCAO.md`: o caminho de volta é o cartão do Compositor na aba Builds, sem comando.
- `tests/decisoes.sh`: o shim é provado no HOME de brinquedo; a GPU (D6) segue vermelha, é da máquina.

Provas, verdes: `tests/vizinhos.sh` (seção 8: sem shim o `requer` segura; com shim só os dois blocos
saem; segunda passada não escreve; `--restaurar` devolve byte a byte; o `install_if_diff` do
self-heal está na cópia), `tests/garantir-builds.sh` (seção 4: diverge, o conserto cria o shim com
`MEOW-COSMIC-COMP-SHIM-1`, sem compilar; segunda passada 0 e sem escrita), `tests/etapa-compositor.sh`
(novo, no `PORTATIL`: etapa na lista, em fundo, um build só, shim criado, segunda vez numa passagem
sem escrita, `COMPOSITOR=nao` tira, sem sudo além da sondagem `sudo -n true` do próprio install),
`tests/chave-etapa.sh`, `tests/miudos-do-install.sh`, `tests/instalacao.sh`, `tests/seco.sh`,
`tests/convergencia.sh`.

Não fechou:
- Cura 4, a volta do `/usr/bin/cosmic-comp` de fábrica pela ponte de root: a ponte
  (`scripts/ponte_root.sh`) tem verbos fixos e nenhum reinstala o pacote; um verbo novo pede a regra
  do sudoers reinstalada pelo `install.sh`, com a senha. O shim já não depende do `/usr/bin`
  remendado (roda o build da casa e só cai no `/usr/bin` se o build falha), então fica para um
  bloco com ela presente.
- O corte de verdade no `$ZD` dela (`vizinhos.sh --desativar aurora-compositor aurora-night-light`)
  não roda daqui: muda o HOME real. Vale depois do login com o shim ligado.
