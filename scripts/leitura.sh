#!/usr/bin/env bash
# leitura.sh — o horário liga o modo de leitura sozinho, e o desliga sozinho.
#
# O QUE ELE FAZ, EM UMA FRASE
#   A cada tique ele pergunta "que horas são?" e "que degrau o relógio pede?", e
#   põe DOIS números no disco:
#       ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_temperatura   (Kelvin)
#       ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_textura       (0.0..1.0)
#   Quem PINTA é o `cosmic-comp` recompilado (etapa 1 do plano de 29/08). Este
#   arquivo não pinta um pixel, não fala Wayland, não reinicia nada e não toca em
#   binário nenhum.
#
# ============================================================================
# O QUE ESTAVA MEDIDO NESTA MÁQUINA EM 30/08/2026, ANTES DE ESCREVER UMA LINHA
# ============================================================================
#
# 1. AS DUAS CHAVES AINDA NÃO EXISTEM, E ISSO É DE PROPÓSITO
#      ls ~/.config/cosmic/com.system76.CosmicComp/v1/
#        accessibility_zoom  activation_policy  active_hint  appearance_settings
#        autotile  autotile_behavior  edge_snap_threshold  input_default
#        keyboard_config  pinned_workspaces  xkb_config  xwayland_eavesdropping
#    Nenhuma `leitura_*`. O `cosmic-comp` do disco também não as conhece: ele é
#    o binário rebuildado às 01:46 de hoje, que traz só o patch de workspace.
#
#    ESCREVER NELAS HOJE É INOFENSIVO. O `cosmic-comp` ignora chave que não está
#    no struct dele (serde com `#[serde(default)]` por campo — chave a mais em
#    diretório de cosmic-config não é erro de parse, é arquivo que ninguém abre).
#    O valor passa a valer no login DEPOIS do build da etapa 1. Ou seja: este
#    script funciona hoje, e o efeito na tela chega quando o compositor souber
#    ler — sem que ninguém precise voltar aqui.
#
# 2. O `mv` DO `meow_escrever` **ACORDA** O WATCHER. O PLANO DE 29/08 ERRA AQUI.
#    O plano manda "escrever a chave com redirecionamento `>`, NUNCA com `mv` —
#    o watcher do cosmic-config descarta o evento de rename". Está errado, e é
#    grave o bastante para o desenho: seguir esse passo obrigaria este arquivo a
#    escrever por fora do `meow_escrever`, ou seja, por fora da TRAVA 1, da TRAVA
#    2, do manifesto e do `MEOW_DRY_RUN`.
#
#    O que o watcher descarta, LIDO NA FONTE desta máquina
#    (`~/.cargo/git/checkouts/libcosmic-*/cosmic-config/src/lib.rs:393-395`):
#        EventKind::Access(_)
#        | EventKind::Modify(ModifyKind::Metadata(_))
#        | EventKind::Modify(ModifyKind::Name(RenameMode::Both)) => return;
#    Só o `Both`. E o backend inotify do `notify` 8.2.0 (`src/inotify.rs:244-266`)
#    emite TRÊS eventos num rename: `Name(To)` com o caminho de DESTINO, depois
#    `Name(Both)` com os dois caminhos — e o `Name(From)` do temporário veio
#    antes. Ou seja, o `Name(To)` passa pelo filtro, carrega o nome da chave
#    (`leitura_temperatura`), e a callback é chamada.
#
#    Isto não é dedução nova: é EXATAMENTE o que o `lib/comum.sh:160-179` já
#    tinha medido do outro lado do problema — "o painel recebia QUATRO eventos
#    por chave gravada — o Create do temporário, o Modify(Data), o Name(From) e
#    só então o Name(To) legítimo". Aquele comentário existe porque o rename
#    acorda demais, não de menos. O `.atomicwrite` no nome do temporário é o que
#    cala os outros três (`lib.rs:407-408`), e é do próprio `meow_escrever`.
#
#    Então aqui se escreve pelo `meow_escrever`, como todo o resto do projeto.
#
# 3. A LUZ QUENTE ERA DA AURORA — E DEIXOU DE SER. ATUALIZADO EM 31/08/2026
#    O QUE ESTAVA MEDIDO EM 30/08: `/var/lib/aurora/night-light-temp` = 3500, e
#    quem esquentava a tela dela era um patch BINÁRIO da Aurora dentro do shader
#    do `cosmic-comp`. Aposentá-lo era a etapa 4 do plano, de outro dono.
#
#    A ETAPA 4 FOI FEITA, e esta linha ficou prometendo trabalho já pronto até
#    31/08/2026 — no cabeçalho e no `estado`. MEDIDO hoje:
#      - `grep -ac 'NIGHT LIGHT (Aurora)'` devolve 0 tanto no `/usr/bin/cosmic-comp`
#        (o do build de 30/08 04:59) quanto no `/proc/<pid do cosmic-comp>/exe`;
#      - `aurora-night-light.py --status` responde "estado: original (greyscale de
#        fábrica)" e "este patcher está APOSENTADO";
#      - o `night-light-temp` é de 14/07/2026 e não pinta pixel nenhum: o próprio
#        `--status` já o chama de "preferência salva".
#    Quem esquenta a tela dela hoje é o `leitura_temperatura` — este arquivo.
#
#    POR QUE O `estado` AINDA CITA O NIGHT LIGHT, EM VEZ DE CALAR. Porque a
#    aposentadoria é CONDICIONAL e a condição pode cair sem ninguém pedir. O
#    `reaplicar_night_light` do `aurora-cosmic-comp-ws.sh` continua chamando o
#    patcher a cada self-heal; quem o cala é a trava do `main()` DELE, que só
#    pergunta se `AURORA-READING-MODE` está no binário. Um `apt upgrade` de
#    `cosmic-*` troca o binário, o marcador some, a trava abre e o shader quente
#    volta — e aí os dois caminhos SE SOMAM, porque o bloco dele mora dentro do
#    `color_mode == 1.0` e o nosso vem depois da cadeia inteira: a temperatura é
#    multiplicada duas vezes (medição no cabeçalho do patch do modo de leitura).
#
#    Então a linha do `estado` trocou de pergunta: não é mais "o arquivo existe?",
#    é "o shader quente está no binário?". Sem o shader ela só informa que aquilo
#    é um resto de julho; COM o shader ela vira aviso — e é só nesse dia que
#    "a tela está quente" volta a não ser prova de que este script funcionou.
#
# 4. RON ACEITA `0` ONDE ESPERA f32 — conferido em `ron-0.11.0/src/parse.rs:852`
#    (`T::parse(&f)` = `f32::from_str`), que é a versão que o `Cargo.lock` do
#    `cosmic-comp` pina. Mesmo assim este script escreve SEMPRE com casa decimal
#    (`0.00`, `0.35`): custa nada e tira uma ambiguidade do caminho.
#
# ============================================================================
# O CONTRATO DAS CHAVES: DOIS NÍVEIS, E ELES NÃO SIGNIFICAM A MESMA COISA
# ============================================================================
#
#   LEITURA_AGENDA (meow.conf)          responde "o MeowSystem PODE agendar?"
#     vazio  o modo de leitura é dela e mais ninguém. Nada é lido, nada é
#            escrito, o `conferir` devolve 0 sem olhar. É o mesmo contrato do
#            RELOGIO_SEGUNDOS e do JANELAS_TILING.
#     nao    DESLIGAR TEM DE DESLIGAR: os dois números voltam a 0 e o
#            `install.sh` desarma o timer. Não é "deixar de escrever" — é apagar
#            o efeito, do jeito que o `WALLPAPER_NOITE="nao"` apaga as pastas
#            derivadas em vez de deixá-las paradas parecendo ligadas.
#     sim    o agendamento vale. O HORÁRIO, daqui para baixo, é do applet.
#
#   leitura_agenda (cosmic-config, o applet do painel)   "agende AGORA?"
#     false  ela desligou o "Agendar" pela interface: os sliders mandam, e este
#            script não escreve NADA — nem 0. Devolve 4, que o doctor pinta como
#            `--` ("escolha dela"). Zerar aqui seria desfazer, às 07:00, a
#            temperatura que ela acabou de arrastar às 06:58.
#     true   (ou ausente) o relógio manda.
#
# O HORÁRIO MORA NO APPLET — DECISÃO DELA, 29/08/2026
#   Ela pediu para escolher a faixa pela interface. Então a fonte da verdade é
#   `leitura_hora_inicio` / `leitura_hora_fim` em `com.system76.CosmicComp/v1`,
#   as MESMAS chaves que o applet grava. Uma fonte só, em vez de duas que podem
#   divergir em silêncio.
#
#   O APPLET EXISTE DESDE 30/08/2026 (src/applets/leitura), MAS AS CHAVES SÓ
#   NASCEM QUANDO ELA MEXE NO HORÁRIO. O applet lê o disco no arranque e só
#   ESCREVE o que ela muda — instalá-lo não cria `leitura_hora_inicio` nem
#   `leitura_hora_fim`. Então "sem applet" e "applet instalado e nunca tocado"
#   são o MESMO estado para este arquivo, e nos dois ele cai no padrão declarado
#   no `meow.conf.exemplo` (LEITURA_HORARIO_INICIO/FIM) — e DIZ que está caindo
#   nele, em vez de fingir que leu. A frase aparece no `conferir` e no `estado`;
#   no `aplicar` ela é `meow_info`, que o `LOG_NIVEL=silencioso` da unidade
#   systemd cala, senão seriam 1440 linhas por dia dizendo a mesma coisa.
#
#   E EXISTE UM TERCEIRO ESTADO, QUE ESTE ARQUIVO LIA ERRADO ATÉ 31/08/2026:
#   UMA PONTA SÓ. `Message::HoraInicio` e `Message::HoraFim` são dois braços
#   separados do `update()` do applet (`src/applets/leitura/src/main.rs`), cada um
#   chamando o seu `set_`. Arrastar só o slider de início grava
#   `leitura_hora_inicio` e mais nada — e o applet continua MOSTRANDO 07:00 no
#   fim, porque esse é o Default dele, o mesmo número do meow.conf.
#
#   (O main.rs e o install.sh são citados NESTE ARQUIVO INTEIRO por NOME DE
#   SÍMBOLO, nunca por número de linha. As três citações que ele tinha — `main.rs:393`,
#   `:403` e `:122-123` — já apontavam para o lugar errado em 31/08/2026: foram
#   medidas antes de o applet crescer, e ninguém volta a um comentário para
#   recontar as linhas do vizinho. Número de linha podre manda procurar no lugar
#   errado, que é pior do que não citar; nome de símbolo sobrevive à edição.)
#
#   O `if a=… && b=…` que estava aqui exigia AS DUAS chaves e, faltando uma,
#   jogava fora a outra. MEDIDO em 31/08/2026, com `leitura_hora_inicio="20:00"`
#   no disco e `leitura_hora_fim` ausente: às 19:00 o applet dizia "das 20:00 às
#   07:00" (tela normal) e este script escrevia 3500K/0.35 — a tela ficava âmbar
#   uma hora antes do que a interface prometia, calada. O `estado` até imprimia
#   `leitura_hora_inicio = 20:00` duas linhas abaixo de "usando o PADRÃO", sem
#   ligar uma coisa à outra.
#
#   Agora cada ponta é resolvida SOZINHA: chave do applet quando ela existe e é
#   legível, padrão do meow.conf quando não. Como os padrões dos dois lados são
#   os mesmos números (as constantes `PADRAO_INICIO`/`PADRAO_FIM` do main.rs
#   contra o LEITURA_HORARIO_INICIO/FIM do meow.conf.exemplo), a janela resolvida
#   passa a ser exatamente a que o applet desenha na tela dela. A fonte vira
#   `misto` e o `estado` diz qual ponta veio de onde.
#
#   Formato aceito nas duas chaves do applet: `"18:00"` (string RON, com ou sem
#   aspas) e o inteiro de minutos desde a meia-noite (`1080`). MEDIDO em
#   30/08/2026: o applet grava a PRIMEIRA forma — o campo é `String` e o
#   `cosmic_config` serializa com aspas, que o `_leitura_cru` apara. Os dois
#   formatos continuam aceitos de propósito: é ela quem pode abrir o arquivo e
#   escrever `1080` à mão, e recusar isso seria recusar por nada.
#
# A JANELA DA NOITE É A MESMA DO CARROSSEL, PALAVRA POR PALAVRA
#   Copiada do `e_noite()` do `wallpaper.sh:637`: com `início > fim` a noite é
#   "depois do início OU antes do fim" (é o caso normal, 18:00–07:00, que
#   atravessa a meia-noite); com `início == fim` é noite o dia inteiro. A máquina
#   não pode ter duas definições de noite — se um dia esta regra mudar lá, tem de
#   mudar aqui junto, e é por isso que a frase está repetida em vez de resumida.
#
# SECA OU RAMPA: A DECISÃO É DELA, E AS DUAS ESTÃO AQUI (LEITURA_RAMPA_MIN)
#   0 (padrão)  virada SECA: às 18:00 o degrau salta de uma vez.
#   N > 0       rampa de N minutos, um passo por minuto, DEPOIS da hora — às
#               18:00 começa a esquentar e chega ao valor cheio às 18:00+N.
#
#   A rampa vai DEPOIS da hora, nunca antes, e isso é decisão de desenho: "ligar
#   às 18:00" não pode significar "às 17:30 a tela já mexeu". Quem pede um
#   horário está pedindo que nada aconteça antes dele.
#
#   E A RAMPA PODE SER MAIOR QUE A JANELA — O SLIDER DO APPLET ANDA DE 15 EM 15
#   A conta original supunha que a subida sempre chegava ao topo antes de a
#   janela acabar. MEDIDO em 31/08/2026 com janela 18:00–18:30 e
#   LEITURA_RAMPA_MIN=60: às 18:29 a fração era 0,48 (5050K) e às 18:30 — o
#   minuto em que a janela FECHA — ela SALTAVA para 1,00 (3500K), porque o ramo
#   da descida partia de 1 sem perguntar até onde a subida tinha ido. A tela
#   pulava para o âmbar cheio na hora de desligar, e só esfriava às 19:30. Com
#   `LEITURA_RAMPA_MIN=600` o salto medido foi de 0,952 EM UM MINUTO — a rampa
#   entregando exatamente a virada seca que ela existe para evitar.
#
#   O conserto é o estado estacionário do vaivém: com a noite durando `dur_noite`
#   e o dia `dur_dia`, o mais alto que a subida alcança é `pico` e o mais baixo
#   que a descida alcança é `vale`, e os dois se resolvem sem laço (ver o awk).
#   Quando a rampa cabe nos dois lados — que é todo caso normal — dá `pico=1` e
#   `vale=0`, e a conta é IDÊNTICA à de antes. Provado duas vezes: varrendo os
#   1440 minutos das duas fórmulas em seis janelas (18:00–07:00 com n=30/60/120,
#   08:00–17:00 com n=60, 00:00–12:00 com n=60 e a janela de 1 minuto com n=1) e
#   depois rodando o SCRIPT INTEIRO, minuto a minuto, contra a versão anterior —
#   zero diferenças nos dois. Nos casos patológicos o maior salto por minuto caiu
#   de 0,517 para 0,017 e de 0,952 para 0,002.
#
#   O QUE ELE **NÃO** CONSERTA, E É DE PROPÓSITO: com a rampa maior que a janela
#   o degrau simplesmente não chega ao valor cheio — o `pico` fica onde deu. Não
#   há conserto sem guardar estado entre tiques, e este arquivo é sem estado de
#   propósito (o tique perdido, o boot no meio da noite e o `Persistent=false` do
#   timer dependem disso). Quem avisa é o `conferir`, uma vez por dia.
#
#   Na rampa a temperatura interpola a partir de 6500K — o neutro, que é o topo
#   da faixa que ela escolheu em 29/08 — até o alvo. E quando a fração chega a
#   zero escreve-se `0`, NÃO `6500`: com 6500 o passe do shader continuaria
#   ligado fazendo uma multiplicação neutra por quadro, porque o `is_noop()` da
#   etapa 1 exige `== 0` para pular o passe.
#
# POR QUE O TIMER BATE DE MINUTO EM MINUTO, E NÃO UM `OnCalendar` POR HORÁRIO
#   Porque o horário mudou de dono. Um `OnCalendar=18:00` cravado na unidade era
#   a resposta certa enquanto o horário morava no `meow.conf` — mas ele mora no
#   applet desde 29/08, e ela pode arrastá-lo a qualquer segundo. Uma unidade com
#   a hora antiga não dá erro: ela liga a tela na hora errada, calada, que é o
#   modo de falha que este projeto mais documenta ter cometido.
#
#   O preço foi medido, e é pequeno: um tique lê CINCO arquivos de poucos bytes e
#   quase sempre não escreve nada. Ver o `AccuracySec` da unidade — o systemd
#   ainda funde esses despertares com os dos outros timers.
#
#   E é este desenho que faz a promessa do plano ser verdade: trocar entre seca e
#   rampa é UMA palavra no `meow.conf`, sem `daemon-reload`, sem rearmar unidade,
#   sem tocar em arquivo de systemd. Com dois timers seria uma palavra e um
#   `./install.sh`.
#
# USO
#   leitura.sh aplicar    põe o degrau que o relógio pede (idempotente)
#   leitura.sh conferir   0 conforme · 1 divergente · 2 erro
#                         · 4 escolha dela (o applet desligou o "Agendar")
#                         O `3` estava listado aqui e NUNCA foi devolvido: em
#                         31/08/2026 `MEOW_SEM_DEPENDENCIA` não aparecia uma vez
#                         no arquivo. Com LEITURA_AGENDA vazio a saída é 0, que é
#                         a convenção dos irmãos (relogio.sh:165,
#                         autostart.sh:245) e o que o `concluir` do install.sh
#                         conta como "confere" em vez de "pulado". Um código
#                         documentado que o código nunca produz é a mesma chave
#                         inerte que este projeto passa o dia varrendo.
#   leitura.sh estado     diagnóstico: que degrau o relógio pede AGORA, o que
#                         está no disco, quem manda no horário, e se o
#                         compositor já sabe ler os dois números. É o padrão do
#                         `meow leitura` sem verbo, e por isso é aqui — e não só
#                         no `conferir` do doctor — que os avisos das chaves do
#                         meow.conf têm de sair (ver `_leitura_avisar_chaves`).
#   leitura.sh remover    zera os dois números e desarma o timer
#   leitura.sh tique      sinônimo de `aplicar`, o nome que o plano usou
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# VAZIO = NÃO TOCA. É o contrato inteiro deste arquivo; ver o cabeçalho.
LEITURA_AGENDA="${LEITURA_AGENDA:-}"
# Os padrões abaixo só valem quando a chave do applet não existe. Estão aqui E no
# meow.conf.exemplo, com o mesmo valor, de propósito: o exemplo é o que ela lê, e
# este é o que vale numa máquina cujo conf ainda não tem a linha.
LEITURA_HORARIO_INICIO="${LEITURA_HORARIO_INICIO:-18:00}"
LEITURA_HORARIO_FIM="${LEITURA_HORARIO_FIM:-07:00}"
LEITURA_TEMPERATURA="${LEITURA_TEMPERATURA:-3500}"
LEITURA_TEXTURA="${LEITURA_TEXTURA:-0.35}"
LEITURA_RAMPA_MIN="${LEITURA_RAMPA_MIN:-0}"

LEITURA_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicComp/v1"
LEITURA_K_TEMP="$LEITURA_BASE/leitura_temperatura"
LEITURA_K_TEXT="$LEITURA_BASE/leitura_textura"
LEITURA_K_AGENDA="$LEITURA_BASE/leitura_agenda"
LEITURA_K_INI="$LEITURA_BASE/leitura_hora_inicio"
LEITURA_K_FIM="$LEITURA_BASE/leitura_hora_fim"

# As três peças do applet (etapa 3, 30/08/2026). Só LIDAS aqui: quem as instala
# e confere é o `scripts/leitura_build.sh`, e o `plugins_wings` não é escrito por
# script nenhum deste projeto (docs/FRONTEIRA.md).
LEITURA_APPLET_ID="com.meowsystem.AppletLeitura"
LEITURA_APPLET_BIN="$HOME/.local/bin/meow-applet-leitura"
LEITURA_APPLET_SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$LEITURA_APPLET_ID.desktop"
LEITURA_APPLET_ASA="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"

# ONDE O APPLET GUARDA O PONTO QUE ELA ARRASTOU — 31/08/2026
#   `Config::new_state(NS_ESTADO, 1)` do libcosmic escreve em
#   ~/.local/state/cosmic/<id>/v1/. O applet grava ali, no `lembra_ponto()`, o
#   ÚLTIMO par não-nulo dos dois sliders — é a memória de que o interruptor
#   precisa para religar no ponto certo. Este script passou a ler as mesmas duas
#   chaves; ver o cabeçalho do `_leitura_resolver_alvo`.
LEITURA_ESTADO_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/cosmic/$LEITURA_APPLET_ID/v1"
LEITURA_K_ULT_T="$LEITURA_ESTADO_BASE/ultima_temperatura"
LEITURA_K_ULT_X="$LEITURA_ESTADO_BASE/ultima_textura"

LEITURA_COMP="/usr/bin/cosmic-comp"
LEITURA_MARCADOR="AURORA-READING-MODE"
LEITURA_NIGHTLIGHT="/var/lib/aurora/night-light-temp"
LEITURA_TIMER="meow-leitura.timer"

# 6500K é o NEUTRO e o topo da faixa (decisão dela, 29/08/2026: o slider vai de
# 1000K a 6500K, e o topo é o modo desligado). 1000K é o fundo da tabela
# WHITEPOINTS do redshift que o aurora-night-light.py já carrega.
LEITURA_NEUTRO=6500
LEITURA_PISO=1000
# 4 = "divergente por escolha dela". O `rotulo_rc` do bin/meow o pinta `--`,
# igual ao 3, porque a leitura é a mesma para quem olha: não há nada que o
# auto-reparo deva fazer aqui.
LEITURA_DELA=4

# --- leitura crua de uma chave do cosmic-config -----------------------------
# Apara espaço, tira as aspas de string RON, apara de novo. Devolve 1 quando o
# arquivo não existe ou está vazio — que é o mesmo caso para quem chama: não há
# valor a considerar.
_leitura_cru() {
  local arq="$1" v
  [ -f "$arq" ] || return 1
  v="$(cat "$arq" 2>/dev/null)" || return 1
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  v="${v#\"}"; v="${v%\"}"
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
  [ -n "$v" ]
}

# "18:00" -> 1080. Também aceita o inteiro de minutos: o applet grava `"18:00"`
# (conferido em 30/08/2026), mas quem edita o arquivo à mão pode escrever 1080, e
# recusar isso seria recusar por nada. Falha (1) em qualquer outra coisa.
_leitura_minutos() {
  local v="$1" h m
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9])
      h="${v%%:*}"; m="${v##*:}"
      [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
      printf '%s' "$(( 10#$h * 60 + 10#$m ))" ;;
    ""|*[!0-9]*) return 1 ;;
    *)
      [ "$((10#$v))" -le 1439 ] || return 1
      printf '%s' "$((10#$v))" ;;
  esac
}

_leitura_hhmm() { printf '%02d:%02d' "$(( $1 / 60 ))" "$(( $1 % 60 ))"; }

# --- quem manda no horário --------------------------------------------------
LEITURA_FONTE=""        # applet | padrao | misto
LEITURA_FONTE_INI=""    # applet | meow.conf
LEITURA_FONTE_FIM=""
LEITURA_INI=0
LEITURA_FIM=0
LEITURA_APPLET_DIZ=""   # "" (ausente) | sim | nao

# UMA ponta do horário: a chave do applet quando ela existe e é legível, o padrão
# do meow.conf quando não. As duas pontas são independentes — ver o cabeçalho, e
# o defeito de 31/08/2026 que essa independência conserta.
#
# ASSINA EM GLOBAIS EM VEZ DE ECOAR, e isso não é gosto: `X="$(_ponta …)"` roda a
# função num SUBSHELL, e a origem ("veio do applet ou do conf?") morreria junto
# com ele — que é metade do que esta função tem para dizer.
LEITURA_PONTA=0
LEITURA_PONTA_FONTE=""
_leitura_uma_ponta() {
  local chave="$1" padrao="$2" nome="$3" v m
  if v="$(_leitura_cru "$chave")" && m="$(_leitura_minutos "$v")"; then
    LEITURA_PONTA="$m"; LEITURA_PONTA_FONTE="applet"; return "$MEOW_OK"
  fi
  m="$(_leitura_minutos "$padrao")" || {
    meow_erro "$nome='$padrao' não é HH:MM"; return "$MEOW_ERRO"; }
  LEITURA_PONTA="$m"; LEITURA_PONTA_FONTE="meow.conf"; return "$MEOW_OK"
}

_leitura_resolver_agenda() {
  local a
  _leitura_uma_ponta "$LEITURA_K_INI" "$LEITURA_HORARIO_INICIO" LEITURA_HORARIO_INICIO \
    || return "$MEOW_ERRO"
  LEITURA_INI="$LEITURA_PONTA"; LEITURA_FONTE_INI="$LEITURA_PONTA_FONTE"
  _leitura_uma_ponta "$LEITURA_K_FIM" "$LEITURA_HORARIO_FIM" LEITURA_HORARIO_FIM \
    || return "$MEOW_ERRO"
  LEITURA_FIM="$LEITURA_PONTA"; LEITURA_FONTE_FIM="$LEITURA_PONTA_FONTE"

  if [ "$LEITURA_FONTE_INI" != "$LEITURA_FONTE_FIM" ]; then
    LEITURA_FONTE="misto"
  elif [ "$LEITURA_FONTE_INI" = "applet" ]; then
    LEITURA_FONTE="applet"
  else
    LEITURA_FONTE="padrao"
  fi

  LEITURA_APPLET_DIZ=""
  if a="$(_leitura_cru "$LEITURA_K_AGENDA")"; then
    case "$a" in
      # O applet declara o campo como `bool` e grava `true`/`false` pelados —
      # conferido em 30/08/2026, em src/applets/leitura/src/main.rs. As formas
      # `Some(...)` ficam porque custam duas linhas e cobrem o dia em que o
      # campo virar `Option<bool>` (aí o RON no disco vem embrulhado). Os
      # parênteses são ESCAPADOS: sem aspas, o bash lê `(` como início de
      # subshell dentro do `case` e o arquivo nem parseia.
      true|"Some(true)")   LEITURA_APPLET_DIZ="sim" ;;
      false|"Some(false)") LEITURA_APPLET_DIZ="nao" ;;
    esac
  fi
  return "$MEOW_OK"
}

# --- de onde vem o ALVO dos dois números ------------------------------------
#
# O BUG QUE ESTA FUNÇÃO EXISTE PARA MATAR — RELATADO POR ELA EM 31/08/2026
#   "o negócio fica mudando de temperatura sozinho sem respeitar a temperatura
#   que eu defini."
#
#   Estava certíssima, e a conta é de um minuto: o `meow-leitura.timer` bate
#   `*-*-* *:*:00`, e cada tique gravava `LEITURA_TEMPERATURA` do meow.conf. Ela
#   arrastava o slider para 6400 K, o applet gravava 6400 na chave do
#   compositor, e menos de 60 segundos depois este script escrevia 3500 por
#   cima. Medido no disco no dia: o estado do applet dizia 6400 / 1.0 e o
#   meow.conf dizia 3500 / 0.35.
#
# O QUE ELA PEDIU, NA FRASE DELA
#   "com agendamento ligado ele sempre vai reproduzir essa funcionalidade tal
#   horário apenas. Mas respeitando os sliders."
#
#   Ou seja: o relógio decide QUANDO, e só isso. QUANTO é dos sliders.
#
# POR QUE O `ultima_*` DO ESTADO, E NÃO A CHAVE DO COMPOSITOR
#   A chave `leitura_temperatura` é o que está NA TELA agora, e de dia ela vale
#   0 — ler dali daria "o alvo da noite é zero", e a noite nunca mais acenderia.
#   O `ultima_temperatura` do estado é outra coisa: é o último ponto ÚTIL que ela
#   arrastou, gravado pelo `lembra_ponto()` do applet quando ela SOLTA o slider,
#   e ele sobrevive ao dia inteiro em que a tela está apagada. É exatamente a
#   memória que o interruptor do popup usa para religar no ponto certo — este
#   script passa a religar no mesmo ponto, que é o que faz o applet e o relógio
#   contarem a mesma história.
#
# O meow.conf CONTINUA VALENDO, E É O QUE SEGURA A MÁQUINA NOVA
#   Sem applet instalado, sem sessão em que ela tenha tocado num slider, ou com
#   lixo no estado, o alvo é o do conf — os mesmos 3500 K / 0.35 de sempre. O
#   `estado` mostra qual das duas fontes venceu, campo a campo.
LEITURA_FONTE_ALVO_T=""   # applet | meow.conf
LEITURA_FONTE_ALVO_X=""   # applet | meow.conf

_leitura_resolver_alvo() {
  local v
  LEITURA_FONTE_ALVO_T="meow.conf"
  LEITURA_FONTE_ALVO_X="meow.conf"

  # O portão é o mesmo do `_leitura_alvo_agora`: inteiro que não é inteiro, ou
  # fora de 1000..6500, não vira alvo — cai no conf em silêncio, e quem AVISA é
  # o `conferir`. Um `ultima_temperatura` corrompido não pode ser mais forte que
  # o conf; ele só pode ser IGNORADO.
  if v="$(_leitura_cru "$LEITURA_K_ULT_T")"; then
    case "$v" in
      ""|*[!0-9]*) ;;
      *) if [ "$v" -ge "$LEITURA_PISO" ] && [ "$v" -le "$LEITURA_NEUTRO" ]; then
           LEITURA_TEMPERATURA="$v"; LEITURA_FONTE_ALVO_T="applet"
         fi ;;
    esac
  fi

  # `LC_ALL=C` pelo mesmo motivo dos outros dois awk deste arquivo: em pt_BR a
  # conversão de string para número segue a locale, e um `0.35` viraria 0.
  if v="$(_leitura_cru "$LEITURA_K_ULT_X")"; then
    case "$v" in
      ""|*[!0-9.]*) ;;
      *) if LC_ALL=C awk -v x="$v" 'BEGIN{ exit !(x >= 0 && x <= 1) }'; then
           LEITURA_TEXTURA="$v"; LEITURA_FONTE_ALVO_X="applet"
         fi ;;
    esac
  fi
  return "$MEOW_OK"
}

# --- os alvos, e a conta da rampa -------------------------------------------
# Ecoa "<temperatura> <textura> <fração> <fase>". A conta inteira mora num único
# `awk` porque bash não faz ponto flutuante, e porque partir a interpolação em
# dois lugares é como se ganha duas contas que discordam.
LEITURA_ALVO_T=0
LEITURA_ALVO_X="0.00"
LEITURA_ALVO_F="0.00"
LEITURA_FASE=""
LEITURA_AGORA=0

_leitura_alvo_agora() {
  local t="$LEITURA_TEMPERATURA" x="$LEITURA_TEXTURA" n="$LEITURA_RAMPA_MIN" saida
  LEITURA_AGORA="$(_leitura_minutos "$(date +%H:%M)")" || return "$MEOW_ERRO"

  # OS TRÊS `case` ABAIXO SÃO O PORTÃO, E O DO MEIO EVITOU UM `inf` NO DISCO
  #   O awk não recusa lixo, ele o CONVERTE — e o que ele converte depende de o
  #   texto "parecer número", o que muda a conta inteira sem dar erro.
  #
  #   MEDIDO em 31/08/2026, com `LEITURA_RAMPA_MIN="abc"`: o mawk compara string
  #   com número por STRING, então `n <= 0` deu falso ("a" > "0") e o ramo da
  #   rampa rodou com n valendo 0. `f = dini / 0` = inf, e o script GRAVOU
  #   `-9223372036854775807` em `leitura_temperatura` e `inf` em
  #   `leitura_textura`. O `f32::from_str` do Rust aceita `inf` — ou seja, uma
  #   palavra errada no meow.conf mandava infinito para dentro do shader.
  #
  #   MEDIDO no mesmo dia, com `LEITURA_TEMPERATURA="-500"`: "-500" PARECE
  #   número, virou -500, e o `alvo_t < piso` o aparou em 1000K — o âmbar mais
  #   fundo da tabela. E o `conferir` prometia, na mesma máquina, "tratada como
  #   6500K (desligado)". A promessa era o comportamento certo; quem estava
  #   errado era o caminho. Agora inteiro que não é inteiro cai no NEUTRO, que é
  #   o desligado, e a frase do `conferir` passa a ser verdade.
  #
  #   E `LEITURA_TEXTURA="0,35"` — a vírgula do pt_BR dela, o erro de digitação
  #   mais provável deste arquivo inteiro — não é strnum para o awk sob `LC_ALL=C`
  #   e virava 0 em silêncio: textura desligada para sempre, sem uma linha em
  #   lugar nenhum. Continua virando 0, mas agora é o `conferir` que diz por quê.
  case "$t" in ""|*[!0-9]*)  t="$LEITURA_NEUTRO" ;; esac
  case "$x" in ""|*[!0-9.]*) x=0 ;; esac
  case "$n" in ""|*[!0-9]*)  n=0 ;; esac

  # `LC_ALL=C` NÃO É ZELO, É O PRIMEIRO DEFEITO QUE ESTE ARQUIVO TEVE (30/08/2026)
  #   A locale desta máquina é pt_BR, e o `printf "%.2f"` do awk obedece ao
  #   LC_NUMERIC: a primeira execução gravou `0,35` em `leitura_textura`. Um f32
  #   de RON com vírgula não é "quase certo" — é erro de parse, e o cosmic-config
  #   devolve o Default (0.0) sem uma linha de aviso em lugar nenhum. Ou seja: a
  #   textura ficaria eternamente desligada, e a tela não teria como acusar.
  #   O `C` vale também para a LEITURA dos números: o awk converte string em
  #   número pela mesma locale, então um `0,35` vindo do disco viraria 0.
  saida="$(LC_ALL=C awk -v ini="$LEITURA_INI" -v fim="$LEITURA_FIM" -v n="$n" \
               -v agora="$LEITURA_AGORA" -v alvo_t="$t" -v alvo_x="$x" \
               -v neutro="$LEITURA_NEUTRO" -v piso="$LEITURA_PISO" 'BEGIN{
    # As três linhas abaixo são o e_noite() do wallpaper.sh:637, e a igualdade
    # entre os dois arquivos é o que impede a máquina de ter duas noites.
    if      (ini == fim) noite = 1;
    else if (ini >  fim) noite = (agora >= ini || agora <  fim);
    else                 noite = (agora >= ini && agora <  fim);

    # Com ini == fim é noite o dia inteiro: não existe borda de onde a rampa
    # partisse, e inventar uma faria a tela saltar para o neutro uma vez por dia.
    if (n <= 0 || ini == fim) {
      f = noite ? 1 : 0;
      fase = noite ? "noite" : "dia";
    } else {
      dini = (agora - ini + 1440) % 1440;
      dfim = (agora - fim + 1440) % 1440;

      # O TETO E O PISO QUE A JANELA PERMITE — ver o cabeçalho (31/08/2026).
      # A subida sobe 1/n por minuto e tem `dur_noite` minutos; a descida desce
      # 1/n por minuto e tem `dur_dia`. Quando uma das duas não tem tempo de
      # chegar ao fim, o vaivém se acomoda entre `vale` e `pico` — e é ISSO que
      # a descida tem de tomar como ponto de partida, senão ela começa em 1 e a
      # tela salta para o âmbar cheio no minuto em que a janela fecha.
      #
      # O estado estacionário fecha sem laço: o lado mais LONGO é o que chega ao
      # seu extremo, e o mais curto herda o que sobrou do outro.
      dur_noite = (fim - ini + 1440) % 1440;
      dur_dia   = 1440 - dur_noite;
      if (dur_noite >= dur_dia) { pico = 1; vale = 1 - dur_dia/n;   if (vale < 0) vale = 0 }
      else                      { vale = 0; pico = dur_noite/n;     if (pico > 1) pico = 1 }

      if (noite) {
        f = vale + dini / n; if (f > 1) f = 1;
        fase = (f >= pico) ? "noite" : "esquentando";
      } else {
        f = pico - dfim / n; if (f < 0) f = 0;
        fase = (f <= vale) ? "dia" : "esfriando";
      }
    }

    # A temperatura sai do neutro e caminha para o alvo. Fora da faixa útil o
    # valor é aparado em silêncio aqui; quem AVISA é o `conferir`, uma vez por
    # dia, e não o timer, 1440 vezes.
    if (alvo_t < piso)   alvo_t = piso;
    if (alvo_t > neutro) alvo_t = neutro;
    if (alvo_x < 0)      alvo_x = 0;
    if (alvo_x > 1)      alvo_x = 1;

    temp = int(neutro - f * (neutro - alvo_t) + 0.5);
    # `0`, e nunca `6500`: o is_noop() da etapa 1 exige == 0 para PULAR o passe
    # do shader. Escrever o neutro deixaria a multiplicação neutra rodando por
    # quadro, para sempre, sem nada na tela para acusar.
    if (f <= 0 || temp >= neutro) temp = 0;

    tex = f * alvo_x;
    if (tex < 0.005) tex = 0;

    printf "%d %.2f %.2f %s\n", temp, tex, f, fase;
  }' 2>/dev/null)" || return "$MEOW_ERRO"

  [ -n "$saida" ] || return "$MEOW_ERRO"
  read -r LEITURA_ALVO_T LEITURA_ALVO_X LEITURA_ALVO_F LEITURA_FASE <<< "$saida"
  return "$MEOW_OK"
}

# 0 = os dois são o mesmo número até a segunda casa. Existe por causa de um caso
# concreto: o applet grava `0.4` e este script grava `0.40`. Um `[ "$a" = "$b" ]`
# — e o próprio `meow_escrever`, que compara por conteúdo — chamaria isso de
# divergência e reescreveria a chave, acordando o compositor de graça.
#
# A FRASE ANTERIOR DIZIA "divergência ETERNA, a cada minuto", E ISSO ERA DEMAIS
#   MEDIDO em 31/08/2026, chamando o `meow_escrever` três vezes com `0.40` sobre
#   um disco que tinha `0.4`: ele escreveu UMA vez e as outras duas devolveram 0
#   com o mesmo inode. Depois da primeira o disco já diz `0.40` e ele se cala. O
#   que esta função evita, então, não é um laço — é a normalização silenciosa do
#   número que ELA arrastou: sem ela, o `0.4` do applet vira `0.40` do script na
#   primeira virada, e o valor no disco deixa de ser o que ela pôs lá. Verificado
#   nos dois sentidos no mesmo dia: com a função, três tiques seguidos deixam o
#   `0.4` intacto.
_leitura_mesmo_numero() {
  local a="${1:-}" b="${2:-}"
  # OS DOIS PORTÕES VÊM PRIMEIRO, E A ORDEM É O CONTRATO
  #   O que NÃO é número não é "o mesmo número", ainda que os bytes batam. Em
  #   31/08/2026 o atalho de baixo estava ACIMA destes dois `case` e alargava o
  #   contrato sem querer: `abc` contra `abc` passou a responder "mesmo número",
  #   quando antes respondia "diferentes". Inalcançável hoje (o segundo argumento
  #   é sempre saída do awk ou um literal deste arquivo), mas apertar custou
  #   trocar duas linhas de lugar: `case` é builtin, não nasce processo nenhum, e
  #   o atalho continua valendo para todo número.
  case "$a" in ""|*[!0-9.+-]*) return 1 ;; esac
  case "$b" in ""|*[!0-9.+-]*) return 1 ;; esac
  # ATALHO PARA O CASO QUE ACONTECE 1438 VEZES POR DIA: byte a byte igual é o
  # mesmo número, e nenhum awk precisa nascer para descobrir isso. O tique em
  # repouso chamava esta função duas vezes e pagava dois `fork`+`exec` de mawk
  # para comparar "3500" com "3500" e "0.35" com "0.35" — ~2880 processos por
  # dia numa unidade que o `meow-leitura.timer` já mede em 26ms. O awk continua
  # aí embaixo, e é ele quem faz o trabalho de verdade: `0.4` (do applet) contra
  # `0.40` (daqui) são strings diferentes e o mesmo número.
  [ "$a" = "$b" ] && return 0
  # `LC_ALL=C` pelo mesmo motivo do `_leitura_alvo_agora`: em pt_BR o awk lê
  # `0.35` como 0 e `0,35` como 0,35 — e a comparação diria "diferente" para
  # sempre, reescrevendo a chave a cada minuto.
  LC_ALL=C awk -v a="$a" -v b="$b" 'BEGIN{ exit ((a-b) < 0.005 && (b-a) < 0.005) ? 0 : 1 }'
}

_leitura_no_disco() {
  LEITURA_DISCO_T="$(_leitura_cru "$LEITURA_K_TEMP")" || LEITURA_DISCO_T=""
  LEITURA_DISCO_X="$(_leitura_cru "$LEITURA_K_TEXT")" || LEITURA_DISCO_X=""
}
LEITURA_DISCO_T=""
LEITURA_DISCO_X=""

# Grava os dois números, e só o que MUDOU. Devolve 0 (já estava assim), 1
# (escreveu, ou escreveria no seco) ou 2.
_leitura_gravar() {
  local temp="$1" text="$2" motivo="$3" mudou=0 r
  _leitura_no_disco

  if ! _leitura_mesmo_numero "$LEITURA_DISCO_T" "$temp"; then
    meow_escrever "$LEITURA_K_TEMP" "$temp" 644; r=$?
    case "$r" in
      2) meow_erro "não consegui gravar $LEITURA_K_TEMP"; return "$MEOW_ERRO" ;;
      1) mudou=1 ;;
    esac
  fi
  if ! _leitura_mesmo_numero "$LEITURA_DISCO_X" "$text"; then
    meow_escrever "$LEITURA_K_TEXT" "$text" 644; r=$?
    case "$r" in
      2) meow_erro "não consegui gravar $LEITURA_K_TEXT"; return "$MEOW_ERRO" ;;
      1) mudou=1 ;;
    esac
  fi

  if [ "$mudou" = "1" ]; then
    if meow_seco; then
      meow_muda "gravaria temperatura=$temp textura=$text ($motivo)"
    else
      meow_muda "$motivo: temperatura=${temp}K textura=$text"
      # O registro no meow.log é condicionado ao que MUDOU, e não ao tique. Um
      # `meow_registrar` incondicional aqui daria 1440 linhas por dia num arquivo
      # que o `meow log` mostra — o log viraria só isto.
      meow_registrar "leitura.sh temp=$temp textura=$text fase=${LEITURA_FASE:-$motivo}"
    fi
    return "$MEOW_DIVERGENTE"
  fi
  return "$MEOW_OK"
}

# A frase de "de onde veio o horário". `meow_info` de propósito: o
# `LOG_NIVEL=silencioso` da unidade systemd a cala, e ela reaparece inteira
# quando alguém roda o comando na mão, no `conferir` e no `estado`.
_leitura_dizer_fonte() {
  local diz="${1:-info}"
  local janela; janela="das $(_leitura_hhmm "$LEITURA_INI") às $(_leitura_hhmm "$LEITURA_FIM")"
  case "$LEITURA_FONTE" in
    applet)
      "meow_$diz" "horário do applet (leitura_hora_inicio/fim): $janela" ;;
    misto)
      # O estado de "ela arrastou UM slider só". Dizer de qual ponta veio cada
      # número é o que impede a pergunta "por que a janela não é a que eu
      # marquei?" — as duas metades estão certas, e vêm de lugares diferentes.
      #
      # A FRASE ANTIGA ERA `início: applet, fim: meow.conf`, E ISSO PEDIA UMA
      # TRADUÇÃO QUE NÃO É DELA (31/08/2026)
      #   Duas palavras de ARQUITETURA — onde o valor MORA — para descrever uma
      #   coisa que ela fez com o dedo. A irmã de baixo já falava certo ("o
      #   applet ainda não gravou horário"), e esta destoava: agora as duas dizem
      #   o que ACONTECEU. Qual ponta veio do applet é decidido no `if`, e não
      #   escrito à mão, porque `misto` só existe quando exatamente uma veio.
      local ponta="o início"
      [ "$LEITURA_FONTE_INI" = "applet" ] || ponta="o fim"
      "meow_$diz" "o applet gravou só $ponta — a outra ponta vem do PADRÃO do meow.conf ($janela)" ;;
    *)
      # "não gravou", e não "não existe": desde 30/08/2026 o applet existe, e o
      # que falta é ela ter mexido no horário — ele só escreve o que ela muda.
      # Dizer "não existe" mandaria procurar um binário que está instalado.
      "meow_$diz" "o applet ainda não gravou horário — usando o PADRÃO do meow.conf: $janela" ;;
  esac
}

# --- os avisos das chaves do meow.conf --------------------------------------
# O awk APARA em silêncio o que não entende (ver o portão do `_leitura_alvo_agora`);
# esta função é a única coisa na máquina que DIZ que aparou. Ela não mora no
# `aplicar` porque o `aplicar` roda 1440 vezes por dia pelo timer, e um aviso que
# aparece 1440 vezes por dia é um aviso que se aprende a ignorar.
#
# ELA PRECISA ESTAR NOS DOIS COMANDOS, E ESTAVA SÓ NO QUE ELA NÃO RODA (31/08/2026)
#   `meow leitura` SEM VERBO cai no `estado` (o `cmd_leitura` do `bin/meow` usa
#   `${1:-estado}`); o `conferir` é o que o doctor das 05:00 despeja para dentro
#   de um log. Ou seja, os três avisos escritos ontem nasceram no comando que ela
#   não digita. MEDIDO no mesmo dia, com `LEITURA_TEXTURA="0,35"` no meow.conf —
#   a vírgula do teclado pt_BR dela, o erro de digitação mais provável deste
#   arquivo inteiro: o `estado` imprimia `alvo do conf  3500K / 0,35` e, três
#   linhas abaixo, `o relógio pede  temperatura=3500  textura=0.00`, sem uma
#   palavra ligando as duas. A frase existia e estava no outro comando.
#
# NÃO ESCREVE NADA — quatro `case`, um `awk` de comparação e `meow_aviso`. É essa
# ausência que permite chamá-la do `estado`, que é leitura pura por contrato.
#
# PRECONDIÇÃO DO ÚLTIMO AVISO: `LEITURA_INI`/`LEITURA_FIM` já resolvidos, isto é,
# chamada DEPOIS do `_leitura_resolver_agenda` — que é o que os dois chamadores
# fazem. Chamada antes, as duas pontas valem 0, a janela mede zero e o aviso da
# rampa se cala sozinho: exatamente a falha silenciosa que este arquivo caça.
_leitura_avisar_chaves() {
  case "$LEITURA_TEMPERATURA" in
    ""|*[!0-9]*) meow_aviso "LEITURA_TEMPERATURA='$LEITURA_TEMPERATURA' não é um inteiro — tratada como ${LEITURA_NEUTRO}K (desligado)" ;;
    *) if [ "$LEITURA_TEMPERATURA" -lt "$LEITURA_PISO" ] || [ "$LEITURA_TEMPERATURA" -gt "$LEITURA_NEUTRO" ]; then
         meow_aviso "LEITURA_TEMPERATURA=$LEITURA_TEMPERATURA está fora de ${LEITURA_PISO}–${LEITURA_NEUTRO}K — aparada"
       fi ;;
  esac
  # A VÍRGULA É A PIOR DAS TRÊS: `LEITURA_TEXTURA="0,35"` vira 0 lá dentro (o awk
  # sob `LC_ALL=C` não lê vírgula) e o papel fica desligado PARA SEMPRE, sem nada
  # na tela para acusar — nem erro, nem valor estranho, só um recurso que não
  # aparece. As outras duas ao menos mudam um número visível.
  case "$LEITURA_TEXTURA" in
    ""|*[!0-9.]*) meow_aviso "LEITURA_TEXTURA='$LEITURA_TEXTURA' não é um decimal com PONTO — tratada como 0 (sem papel)" ;;
    *) if ! LC_ALL=C awk -v v="$LEITURA_TEXTURA" 'BEGIN{ exit (v <= 1) ? 0 : 1 }'; then
         meow_aviso "LEITURA_TEXTURA=$LEITURA_TEXTURA está fora de 0.0–1.0 — aparada"
       fi ;;
  esac
  case "$LEITURA_RAMPA_MIN" in
    ""|*[!0-9]*) meow_aviso "LEITURA_RAMPA_MIN='$LEITURA_RAMPA_MIN' não é um inteiro de minutos — tratada como 0 (virada seca)" ;;
  esac
  # A rampa que não cabe na janela não é erro, é uma escolha que entrega menos do
  # que promete: o degrau nunca chega ao valor cheio, e o `estado` mostra a fração
  # parando no meio. Dizê-lo é mais barato que ela descobrir olhando a tela e não
  # sabendo o que perguntar.
  if [ "$LEITURA_RAMPA_MIN" -gt 0 ] 2>/dev/null && [ "$LEITURA_INI" != "$LEITURA_FIM" ]; then
    local dur_noite=$(( (LEITURA_FIM - LEITURA_INI + 1440) % 1440 ))
    if [ "$LEITURA_RAMPA_MIN" -gt "$dur_noite" ] || [ "$LEITURA_RAMPA_MIN" -gt $(( 1440 - dur_noite )) ]; then
      meow_aviso "LEITURA_RAMPA_MIN=$LEITURA_RAMPA_MIN é maior que a janela (${dur_noite}min ligada / $(( 1440 - dur_noite ))min desligada) — a rampa não chega ao fim"
    fi
  fi
  return "$MEOW_OK"
}

# --- aplicar ----------------------------------------------------------------
cmd_aplicar() {
  if [ -z "$LEITURA_AGENDA" ]; then
    meow_info "LEITURA_AGENDA vazio — o modo de leitura é seu; não escrevo nada"
    return "$MEOW_OK"
  fi
  case "$LEITURA_AGENDA" in
    sim|nao|não) ;;
    *) meow_erro "LEITURA_AGENDA='$LEITURA_AGENDA' — esperado sim, nao ou vazio"
       return "$MEOW_ERRO" ;;
  esac

  # DESLIGAR TEM DE DESLIGAR: os números voltam a 0. Quem desarma o timer é o
  # `install.sh` (etapa_leitura) e o `remover` daqui — não este caminho, porque
  # um `aplicar` disparado PELO timer que desarma o próprio timer é a receita de
  # unidade que morre no meio de si mesma.
  if [ "$LEITURA_AGENDA" != "sim" ]; then
    LEITURA_FASE="desligado"
    _leitura_gravar 0 "0.00" "LEITURA_AGENDA=\"$LEITURA_AGENDA\" — modo de leitura desligado"
    local rc=$?
    [ "$rc" = "$MEOW_OK" ] && meow_ok "modo de leitura já estava desligado (0 / 0.00)"
    return "$rc"
  fi

  _leitura_resolver_agenda || return $?

  if [ "$LEITURA_APPLET_DIZ" = "nao" ]; then
    meow_info "o applet diz 'Agendar: desligado' — os sliders mandam, não escrevo nada"
    return "$LEITURA_DELA"
  fi

  _leitura_resolver_alvo
  _leitura_alvo_agora || { meow_erro "não consegui calcular o degrau da hora"; return "$MEOW_ERRO"; }
  _leitura_dizer_fonte info

  _leitura_gravar "$LEITURA_ALVO_T" "$LEITURA_ALVO_X" "$LEITURA_FASE"
  local rc=$?
  if [ "$rc" = "$MEOW_OK" ]; then
    meow_ok "modo de leitura já no degrau da hora ($LEITURA_FASE: ${LEITURA_ALVO_T}K / $LEITURA_ALVO_X)"
  fi
  return "$rc"
}

# --- conferir (leitura pura; é o que o doctor chama) ------------------------
cmd_conferir() {
  # ESTRUTURAL, E NÃO POR INSPEÇÃO: o `bin/meow:35` promete que "nenhum caminho
  # de `doctor` sem `--consertar` escreve", e hoje esse caminho passa por aqui.
  # Nenhuma linha desta função chama um escritor — mas a próxima que alguém
  # acrescentar não sabe disso, e com o seco ligado ela cai no `meow_escrever`
  # que devolve 1 sem tocar no disco. É o mesmo `MEOW_SECO=1` do
  # `terminal.sh:285` e do `wallpaper.sh:1567`, pelo mesmo motivo.
  # shellcheck disable=SC2034  # quem lê MEOW_SECO é o meow_seco() do comum.sh
  MEOW_SECO=1
  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — nada a conferir (o modo de leitura é seu)"
    return "$MEOW_OK"
  fi
  case "$LEITURA_AGENDA" in
    sim|nao|não) ;;
    *) meow_erro "LEITURA_AGENDA='$LEITURA_AGENDA' — esperado sim, nao ou vazio"
       return "$MEOW_ERRO" ;;
  esac

  local alvo_t alvo_x
  if [ "$LEITURA_AGENDA" != "sim" ]; then
    alvo_t=0; alvo_x="0.00"; LEITURA_FASE="desligado"
  else
    _leitura_resolver_agenda || return $?
    if [ "$LEITURA_APPLET_DIZ" = "nao" ]; then
      meow_pula "o applet desligou o 'Agendar' — o degrau é o que você arrastou"
      return "$LEITURA_DELA"
    fi
    _leitura_resolver_alvo
    _leitura_alvo_agora || { meow_erro "não consegui calcular o degrau da hora"; return "$MEOW_ERRO"; }
    alvo_t="$LEITURA_ALVO_T"; alvo_x="$LEITURA_ALVO_X"
    _leitura_avisar_chaves
    _leitura_dizer_fonte pula
  fi

  _leitura_no_disco
  local ok_t=1 ok_x=1
  _leitura_mesmo_numero "$LEITURA_DISCO_T" "$alvo_t" && ok_t=0
  _leitura_mesmo_numero "$LEITURA_DISCO_X" "$alvo_x" && ok_x=0

  if [ "$ok_t" = "0" ] && [ "$ok_x" = "0" ]; then
    meow_ok "modo de leitura conforme ($LEITURA_FASE: ${alvo_t}K / $alvo_x)"
    return "$MEOW_OK"
  fi
  meow_muda "modo de leitura divergente ($LEITURA_FASE): disco=${LEITURA_DISCO_T:-<ausente>}K/${LEITURA_DISCO_X:-<ausente>}, a hora pede ${alvo_t}K/$alvo_x"
  # "COM O RELÓGIO ARMADO" NÃO É ENFEITE — A FRASE ANTERIOR PROMETIA DEMAIS
  #   Ela dizia, seco, "senão o timer devolve o valor da hora no próximo minuto",
  #   e isso é FALSO em toda máquina onde o timer não está armado: `AUTO_REPARO`
  #   desligado, sessão sem `systemd --user`, máquina onde o `install.sh` nunca
  #   passou, e qualquer `meow leitura conferir` rodado na mão nessas condições —
  #   que é justamente quando alguém está lendo esta linha. Prometer um conserto
  #   automático que não vem é mandá-la esperar por nada, e esperar por nada é
  #   como este projeto perde uma tarde. Quem sabe se o relógio está armado é o
  #   `estado`, que responde isso na última linha (31/08/2026).
  meow_aviso "os dois sliders do applet escrevem NAS MESMAS chaves."
  meow_aviso "se foi você quem arrastou, desligue o 'Agendar' no applet — ou"
  meow_aviso "esvazie LEITURA_AGENDA no meow.conf. Com o relógio armado, ele"
  meow_aviso "devolve o valor da hora no próximo minuto."
  return "$MEOW_DIVERGENTE"
}

# --- estado (read-only, e é o comando de responder "por quê?") --------------
_leitura_col() { printf '%-22s' "$1"; }

cmd_estado() {
  meow_info "$(_leitura_col "meow.conf") LEITURA_AGENDA=\"${LEITURA_AGENDA:-}\" rampa=${LEITURA_RAMPA_MIN}min"
  meow_info "$(_leitura_col "alvo do conf") ${LEITURA_TEMPERATURA}K / ${LEITURA_TEXTURA}"

  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — o MeowSystem não agenda nada; segue o diagnóstico"
  fi

  if _leitura_resolver_agenda; then
    # COLADO NO `alvo do conf`, e é aí que ele serve: é a linha de cima que
    # mostra o `0,35` e é este aviso que diz por que ele vira 0. Vem antes do
    # `dizer_fonte` justamente para não deixar as duas se separarem de novo.
    # Depois do resolver por causa da precondição da janela — ver a função.
    _leitura_avisar_chaves
    _leitura_dizer_fonte info
    case "$LEITURA_APPLET_DIZ" in
      sim) meow_info "quem manda agora: o relógio (o applet quer o agendamento)" ;;
      nao) meow_pula "quem manda agora: OS SLIDERS — o applet desligou o 'Agendar'" ;;
      *)   meow_pula "quem manda agora: o relógio (o applet ainda não gravou o 'Agendar')" ;;
    esac
    _leitura_resolver_alvo
    # A linha `alvo do conf`, acima, mostra os DOIS números antes desta função
    # rodar — ou seja, mostra o conf. Esta diz de onde cada um veio DEPOIS, que é
    # a pergunta que ela fez em 31/08 ("por que muda sozinho?").
    if [ "$LEITURA_FONTE_ALVO_T" = "applet" ] || [ "$LEITURA_FONTE_ALVO_X" = "applet" ]; then
      meow_info "$(_leitura_col "alvo que vale") ${LEITURA_TEMPERATURA}K ($LEITURA_FONTE_ALVO_T) / ${LEITURA_TEXTURA} ($LEITURA_FONTE_ALVO_X) — os sliders mandam no QUANTO"
    fi
    if _leitura_alvo_agora; then
      meow_info "$(_leitura_col "agora são")$(_leitura_hhmm "$LEITURA_AGORA") — fase: $LEITURA_FASE (fração $LEITURA_ALVO_F)"
      meow_info "$(_leitura_col "o relógio pede")temperatura=${LEITURA_ALVO_T}  textura=${LEITURA_ALVO_X}"
    fi
  fi

  _leitura_no_disco
  local k v
  for k in leitura_temperatura leitura_textura leitura_agenda leitura_hora_inicio leitura_hora_fim; do
    if v="$(_leitura_cru "$LEITURA_BASE/$k")"; then
      meow_info "$(_leitura_col "$k")= $v"
    else
      meow_pula "$(_leitura_col "$k")= <ausente>"
    fi
  done

  # O APPLET, EM TRÊS PEÇAS QUE FALHAM SEPARADO (30/08/2026)
  #   Binário, sombra `.desktop` e a linha no `plugins_wings` da topbar. Cada uma
  #   some por um motivo diferente, então mostrar as três em linhas separadas é o
  #   que troca "o applet sumiu" por "sumiu ESTA peça". A conferência de verdade
  #   é do `scripts/leitura_build.sh --conferir`; aqui é diagnóstico, e por isso
  #   nada acende divergência.
  #
  #   NENHUMA DAS TRÊS PRECISA DE LOGOUT — e isso contraria o que este projeto
  #   vinha repetindo. MEDIDO em 30/08/2026, 05:43: o `cosmic-panel` mantém um
  #   watch de inotify no diretório `CosmicPanel.Panel/v1` (visto em
  #   `/proc/<pid>/fdinfo`, inode do diretório), e `plugins_wings` está na lista
  #   `must_recreate` do `space_container.rs` do painel. Escrever a linha
  #   RECRIOU o espaço da topbar na hora: o processo do painel manteve o mesmo
  #   PID e TODOS os applets renasceram com PIDs novos, o nosso incluído.
  #   Quem ainda espera o logout é o SHADER — o `cosmic-comp` da sessão.
  if [ -x "$LEITURA_APPLET_BIN" ]; then
    meow_ok "$(_leitura_col "applet: binário")$LEITURA_APPLET_BIN"
  else
    meow_pula "$(_leitura_col "applet: binário")ausente — LEITURA_COMPILAR=1 ./scripts/leitura_build.sh"
  fi
  if [ -f "$LEITURA_APPLET_SOMBRA" ]; then
    meow_ok "$(_leitura_col "applet: .desktop")$LEITURA_APPLET_SOMBRA"
  else
    meow_pula "$(_leitura_col "applet: .desktop")ausente — o painel não tem o que abrir"
  fi
  if grep -qs "\"$LEITURA_APPLET_ID\"" "$LEITURA_APPLET_ASA"; then
    meow_ok "$(_leitura_col "applet: na topbar")citado no plugins_wings"
  else
    meow_pula "$(_leitura_col "applet: na topbar")NÃO citado no plugins_wings — acrescente \"$LEITURA_APPLET_ID\" à mão"
  fi

  # AS DUAS PERGUNTAS QUE NINGUÉM VÊ HOJE, E QUE SÃO DIFERENTES: o binário do
  # DISCO sabe ler os dois números? E o processo que está desenhando a tela dela
  # AGORA sabe? Um build feito e uma sessão que não relogou são um estado normal,
  # e é justamente esse estado que faz "escrevi a chave e nada aconteceu".
  if [ -r "$LEITURA_COMP" ]; then
    if grep -aqs "$LEITURA_MARCADOR" "$LEITURA_COMP"; then
      meow_ok "$(_leitura_col "cosmic-comp no disco")sabe ler leitura_* ($LEITURA_MARCADOR presente)"
    else
      meow_pula "$(_leitura_col "cosmic-comp no disco")NÃO sabe ler leitura_* — falta a etapa 1 (o patch do compositor)"
    fi
  fi
  # `meow_tem pgrep` porque sem ele a resposta seria "cosmic-comp não está
  # rodando" — um diagnóstico ERRADO com cara de certo, dado justamente pelo
  # comando cujo trabalho é responder "por quê?". Sem pgrep a pergunta fica sem
  # resposta, e é isso que a linha diz.
  local pid=""
  if ! meow_tem pgrep; then
    meow_pula "$(_leitura_col "a sessão viva")sem pgrep nesta máquina — não dá para dizer"
  else
    pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
    if [ -z "$pid" ]; then
      meow_aviso "cosmic-comp não está rodando — nada desenha esta tela"
    elif grep -aqs "$LEITURA_MARCADOR" "/proc/$pid/exe"; then
      meow_ok "$(_leitura_col "a sessão viva")roda um cosmic-comp que sabe ler (PID $pid)"
    else
      meow_pula "$(_leitura_col "a sessão viva")roda um cosmic-comp SEM o modo de leitura (PID $pid)"
      meow_info "  escrever a chave hoje é inofensivo e passa a valer no PRÓXIMO LOGIN."
    fi
  fi

  # O NIGHT LIGHT DA AURORA: RESTO INERTE HOJE, AVISO NO DIA EM QUE VOLTAR
  #   Esta linha dizia "patch BINÁRIO, outro dono; aposentá-lo é a etapa 4". A
  #   etapa 4 foi feita em 30/08/2026 e a frase virou promessa de trabalho pronto
  #   (medições no item 3 do cabeçalho). O que sobrou é o arquivo de julho.
  #
  #   O TESTE MUDOU DE "o arquivo existe" PARA "o shader quente está no binário",
  #   porque é essa a pergunta que a linha existe para responder — quem esquenta a
  #   tela dela AGORA. O arquivo sozinho não responde: ele é preferência salva, e
  #   sobrevive à aposentadoria. Já o marcador do shader volta sozinho no dia em
  #   que um `apt upgrade` tirar o `AURORA-READING-MODE` do binário e destravar o
  #   `aurora-night-light.py`, que o self-heal segue chamando de hora em hora.
  #
  #   OS DOIS ALVOS, `||`, DE PROPÓSITO: disco = valeria no próximo login, sessão
  #   viva = vale agora. Para um AVISO, qualquer um dos dois já basta para ela
  #   querer saber; exigir os dois calaria a metade da janela. `$pid` é o mesmo do
  #   bloco acima — sem pgrep ele é vazio e sobra o teste do disco.
  #
  #   NÃO ESCREVE NADA: dois `grep -aqs`, um `cat` e uma linha impressa.
  if [ -r "$LEITURA_NIGHTLIGHT" ]; then
    local nl_shader="NIGHT LIGHT (Aurora)" nl_temp
    nl_temp="$(cat "$LEITURA_NIGHTLIGHT" 2>/dev/null)"
    if grep -aqs "$nl_shader" "$LEITURA_COMP" ||
       { [ -n "$pid" ] && grep -aqs "$nl_shader" "/proc/$pid/exe"; }; then
      meow_aviso "o night light da Aurora VOLTOU ao shader (${nl_temp}K) — dois donos esquentando a tela, e as temperaturas se multiplicam; confira com: aurora-night-light.py --status"
    else
      meow_pula "$(_leitura_col "night light da Aurora")aposentado em 30/08 — ${nl_temp}K é só a preferência guardada; quem esquenta a tela é o leitura_temperatura"
    fi
  fi

  # O `-d /run/user/.../systemd` é o MESMO teste do `cmd_remover` logo abaixo e
  # da `etapa_leitura` do `install.sh`, e faltava só aqui: sem barramento de
  # usuário o `systemctl --user` não devolve "inactive", devolve erro engolido pelo
  # `2>/dev/null` — e o `estado` dizia "ausente" para um timer que pode estar
  # armado numa sessão que este processo não enxerga.
  if meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]; then
    local ativo; ativo="$(systemctl --user is-active "$LEITURA_TIMER" 2>/dev/null)"
    case "$ativo" in
      active) meow_ok "$(_leitura_col "$LEITURA_TIMER")armado — próximo tique em menos de 1 min" ;;
      *)      meow_pula "$(_leitura_col "$LEITURA_TIMER")${ativo:-ausente} — ninguém vai virar o degrau sozinho" ;;
    esac
  else
    meow_pula "$(_leitura_col "$LEITURA_TIMER")sem systemd --user aqui — não dá para dizer se está armado"
  fi
  return "$MEOW_OK"
}

# --- remover ----------------------------------------------------------------
# Zera os dois números E desarma o timer. As duas coisas, porque só zerar deixa o
# relógio de pé para repor o valor no minuto seguinte — o recurso pareceria
# desligado por um minuto e voltaria sozinho, que é pior que não desligar.
#
# NÃO APAGA os arquivos: `0` é conferível e é exatamente o que o Default do
# compositor vale (etapa 1, EDIÇÃO 5). É a mesma lição do `relogio.sh`, medida em
# 25/08/2026 — apagar o arquivo é um jeito de reverter que não se pode conferir.
cmd_remover() {
  LEITURA_FASE="desligado"
  _leitura_gravar 0 "0.00" "modo de leitura removido"
  local rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "os dois números já estavam em 0"

  if meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]; then
    if meow_seco; then
      meow_muda "desarmaria o $LEITURA_TIMER"
    elif [ "$(systemctl --user is-enabled "$LEITURA_TIMER" 2>/dev/null)" = "enabled" ] ||
         [ "$(systemctl --user is-active  "$LEITURA_TIMER" 2>/dev/null)" = "active" ]; then
      if systemctl --user disable --now "$LEITURA_TIMER" >/dev/null 2>&1; then
        meow_muda "$LEITURA_TIMER desarmado"
      else
        meow_aviso "não consegui desarmar o $LEITURA_TIMER"
      fi
      rc="$MEOW_DIVERGENTE"
    fi
  fi
  meow_seco || meow_registrar "leitura.sh remover rc=$rc"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar|tique) cmd_aplicar ;;
  conferir)      cmd_conferir ;;
  estado)        cmd_estado ;;
  remover)       cmd_remover ;;
  *) meow_erro "uso: leitura.sh {aplicar|conferir|estado|remover}"; exit "$MEOW_ERRO" ;;
esac
