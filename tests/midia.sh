#!/usr/bin/env bash
# O applet de mídia: as seis afirmações do módulo, num HOME de brinquedo.
#
# POR QUE ESTE TESTE PRECISA EXISTIR — E POR QUE OS QUE JÁ HAVIA NÃO SERVEM
#   `tests/seco.sh:16` e `tests/convergencia.sh:24` rodam o instalador debaixo de
#   `env -i HOME=<falso>`. Nesse ambiente o shim do rustup FALHA — a mensagem é
#   `rustup could not choose a version of cargo to run` — e a etapa do applet cai
#   em FALHOS/PULADOS sem executar uma linha do caminho de verdade. Pior no
#   `convergencia.sh`, que só faz `grep` de `mexeu:`: uma etapa que nunca escreve
#   porque nunca chega a rodar aparece como etapa CONVERGIDA. O teste ficaria
#   VERDE sem exercitar o carimbo, a sombra ou o fail-safe.
#
#   Fingir cobertura é pior que não ter teste: o verde some da lista de dúvidas.
#   Por isso este arquivo não instala nada de verdade — ele arma o estado no
#   disco com um binário FALSO e mede o que os dois scripts fazem com ele.
#
# ELE NUNCA COMPILA, E ISSO É REGRA E NÃO ECONOMIA
#   `MIDIA_COMPILAR=1` aparece aqui uma vez só, e sempre acompanhado de
#   `MEOW_DRY_RUN=1` — no seco o `midia_build.sh` força `--conferir` (a trava da
#   linha 77 dele), então o caminho do `cargo` é inalcançável. Uma compilação de
#   verdade custa ~91s e ~1,5 GB de download; um teste que faz isso é um teste
#   que ninguém roda.
#
# AS SEIS AFIRMAÇÕES
#   1. o seco não escreve um byte — nem o `.rustup/settings.toml`;
#   2. a segunda aplicação devolve 0: a comparação é por CONTEÚDO;
#   3. sombra órfã é removida, porque sombra sem binário = dock SEM applet;
#   4. `MIDIA="nao"` DESLIGA (não é só "deixar de instalar");
#   5. valor inválido é recusado com aviso, e não gravado;
#   6. o `--reverter` tira a sombra ANTES do binário, e as chaves dela ficam.
#
# UM HOME DE BRINQUEDO, SEMPRE
#   O território real é a dock dela. Os dois scripts respeitam `HOME`,
#   `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` e `MEOW_ESTADO`; todos
#   os cinco são apontados para dentro do `mktemp -d` e o `env -i` corta o resto,
#   para que um `XDG_DATA_HOME` de fora não leve uma escrita para a casa dela.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

APP_ID="com.github.DiegoMMR.CosmicExtAppletNowPlaying"
RECEITA="$RAIZ/src/applets/now-playing"
PATCH="$RECEITA/0001-meow-capa-cor-controles.patch"

BIN="$H/.local/bin/meow-applet-now-playing"
SOMBRA="$H/.local/share/applications/$APP_ID.desktop"
CONFIG="$H/.config/cosmic-ext-applet-now-playing"
ESTADO="$H/.local/state/meowsystem"
CARIMBO="$ESTADO/midia/carimbo"
MANIFESTO="$ESTADO/manifesto.tsv"
RUSTUP="$H/.rustup/settings.toml"

falhas=0; MARCA=0; CASO=""
caso()  { CASO="$1"; MARCA="$falhas"; }
fecha() { if [ "$falhas" = "$MARCA" ]; then printf 'ok:   %s\n' "$CASO"
          else printf 'ruim: %s\n' "$CASO" >&2; fi; }
reclamar() {                      # reclamar <frase> [saída do script]
  printf 'FALHOU: %s\n' "$1" >&2
  if [ "$#" -gt 1 ] && [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/        | /' >&2; fi
  falhas=$((falhas + 1))
}

# correr [VAR=valor ...] <script.sh> [argumentos...]
# O `env -i` é o mesmo do `tests/seco.sh`; a diferença é que as cinco variáveis
# de território vão explícitas, em vez de dependerem do fallback para `$HOME`.
correr() {
  local -a chaves=()
  while [ "$#" -gt 0 ] && [ "${1#*=}" != "$1" ]; do chaves+=("$1"); shift; done
  local script="$1"; shift
  env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 \
      XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" \
      XDG_CACHE_HOME="$H/.cache" MEOW_ESTADO="$ESTADO" \
      ${chaves[@]+"${chaves[@]}"} \
      bash "$RAIZ/scripts/$script" "$@" 2>&1
}

zerar() { [ -n "$H" ] && rm -rf "$H"; mkdir -p "$H"; }
arquivos() { (cd "$H" && find . -mindepth 1 ! -type d | sort); }

# O binário FALSO: o que os dois scripts querem saber dele é só `-x`, e o
# carimbo o mede por sha256. Um `#!/bin/sh` de nove bytes serve para as duas
# perguntas e não roda nada.
binario_falso() {
  mkdir -p "$(dirname "$BIN")"
  printf '#!/bin/sh\n' > "$BIN"
  chmod +x "$BIN"
}

chave_vale() {                    # chave_vale <nome> <valor esperado>
  local tem
  tem="$(cat "$CONFIG/$1" 2>/dev/null)"
  [ "$tem" = "$2" ] || reclamar "a chave $1 diz '$tem' e devia dizer '$2'"
}

# =============================================================================
caso "1. o seco não escreve um byte, nem o .rustup/settings.toml"
# =============================================================================
# A guarda que está sendo medida é o `_rustc_versao` do `midia_build.sh`: ele
# devolve VAZIO no seco justamente porque `rustc` aqui é um shim do rustup que,
# sob `env -i`, falha E AINDA ASSIM escreve `~/.rustup/settings.toml`. Um
# `rustc -V` inocente no caminho do `--conferir` faria um script que promete não
# escrever nada nascer um arquivo no HOME.
zerar
antes="$(arquivos)"

saida="$(correr MEOW_DRY_RUN=1 MIDIA_COMPILAR=1 midia_build.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia_build.sh no seco, sem binário, devolveu rc=$rc (esperado 1)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "midia.sh no seco, sem binário, devolveu rc=$rc (esperado 3)" "$saida"

# Agora COM binário e COM carimbo, que é a única forma de o `_carimbo_bate`
# chegar a chamar o `_rustc_versao`. O carimbo bate em patch/commit/binário e
# mente no rustc de propósito: se a guarda do seco sumisse, o campo vivo entraria
# na comparação e o rc viraria 1. Devolver 0 é a prova de que a linha rodou e o
# campo foi pulado.
binario_falso
comm_pino="$( set +u; . "$RECEITA/PINO" >/dev/null 2>&1; printf '%s' "${COMMIT:-}" )"
[ -n "$comm_pino" ] || reclamar "não consegui ler COMMIT de $RECEITA/PINO"
mkdir -p "$(dirname "$CARIMBO")"
{ printf 'patch %s\n'   "$(sha256sum -- "$PATCH" | cut -d' ' -f1)"
  printf 'commit %s\n'  "$comm_pino"
  printf 'binario %s\n' "$(sha256sum -- "$BIN" | cut -d' ' -f1)"
  printf 'rustc rustc 9.9.9 (carimbo de brinquedo)\n'
} > "$CARIMBO"
antes="$(arquivos)"

saida="$(correr MEOW_DRY_RUN=1 MIDIA_COMPILAR=1 midia_build.sh)"; rc=$?
[ "$rc" = "0" ] || reclamar "com o carimbo batendo, o seco devolveu rc=$rc (esperado 0: o campo rustc é pulado no seco)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia.sh no seco, com binário e sem sombra, devolveu rc=$rc (esperado 1)" "$saida"

# O `--reverter` é o ÚNICO caminho em que o seco chega a uma função que apaga
# (linha 77 do midia.sh: o `CONFERIR=1` do seco não vale para ele).
saida="$(correr MEOW_DRY_RUN=1 midia.sh --reverter)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia.sh --reverter no seco devolveu rc=$rc (esperado 1)" "$saida"

[ -f "$RUSTUP" ] && reclamar "o seco escreveu $RUSTUP — a guarda do _rustc_versao caiu"
depois="$(arquivos)"
sobra="$(comm -13 <(printf '%s\n' "$antes") <(printf '%s\n' "$depois"))"
[ -n "$sobra" ] && reclamar "o seco escreveu no HOME de teste:"$'\n'"$sobra"
sumiu="$(comm -23 <(printf '%s\n' "$antes") <(printf '%s\n' "$depois"))"
[ -n "$sumiu" ] && reclamar "o seco APAGOU do HOME de teste:"$'\n'"$sumiu"
fecha

# =============================================================================
caso "2. a segunda aplicação devolve 0 (comparação por conteúdo)"
# =============================================================================
# Com `MIDIA_COMPILAR` desligado e um binário falso no lugar, o `midia.sh` roda
# inteiro: escreve as três chaves e a sombra pela `meow_escrever`, e na segunda
# passagem tem de reconhecer o próprio trabalho. É aqui que mora o erro que já
# custou a este projeto um `--conferir` gritando 123 divergências num tema
# correto: a `meow_escrever` grava com `printf '%s'` e come o `\n` final, então
# quem comparar com `cmp` acusa divergência para sempre.
zerar; binario_falso

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "1ª aplicação devolveu rc=$rc (esperado 1: instalou)" "$saida"
[ -f "$SOMBRA" ] || reclamar "a sombra não foi escrita em $SOMBRA" "$saida"
grep -qx "Exec=$BIN" "$SOMBRA" 2>/dev/null \
  || reclamar "o Exec= da sombra não aponta o nosso binário em caminho absoluto"
grep -qx "Icon=$APP_ID" "$SOMBRA" 2>/dev/null \
  || reclamar "a sombra perdeu o Icon= do flatpak — o ícone deixaria de resolver"
chave_vale panel-text-width  440
chave_vale panel-color-style traco
chave_vale album-art-remote  true
# Quem registrou a sombra no manifesto foi a `meow_escrever`; sem esta linha, o
# `--uninstall` deixaria a sombra na máquina.
grep -qF "$SOMBRA" "$MANIFESTO" 2>/dev/null \
  || reclamar "a sombra não entrou no manifesto — o --uninstall a deixaria para trás"

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª aplicação devolveu rc=$rc (esperado 0: já estava no lugar)" "$saida"

saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "0" ] || reclamar "o --conferir depois de convergir devolveu rc=$rc (esperado 0)" "$saida"
fecha

# =============================================================================
caso "3. sombra órfã é removida (o pior modo de falha da família)"
# =============================================================================
# Sombra presente + binário ausente = NENHUM applet na dock. O cosmic-panel casa
# pelo BASENAME do `.desktop` e CONSOME o slot no primeiro acerto: ele nunca
# chega a tentar o export do flatpak, e ela fica com um BURACO — não com o
# applet de fábrica. Acontece de graça (um `rm`, um BleachBit, um disco cheio no
# meio de um build), e é por isso que o `--aplicar` APAGA neste caso.
zerar; binario_falso
correr midia.sh >/dev/null
rm -f "$BIN"

saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "1" ] || reclamar "com a sombra órfã, o --conferir devolveu rc=$rc (esperado 1)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "com a sombra órfã, o seco devolveu rc=$rc (esperado 1)" "$saida"
[ -f "$SOMBRA" ] || reclamar "o SECO removeu a sombra órfã — ele só podia dizer que removeria"

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "ao remover a sombra órfã, devolveu rc=$rc (esperado 1)" "$saida"
[ -e "$SOMBRA" ] && reclamar "a sombra órfã continua em $SOMBRA — a dock ficaria sem applet nenhum" "$saida"

saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "3" ] || reclamar "depois do fail-safe, o --conferir devolveu rc=$rc (esperado 3: nada a instalar)" "$saida"
fecha

# =============================================================================
caso "4. MIDIA=\"nao\" desliga de verdade"
# =============================================================================
# Deixar de instalar não é desligar: a sombra que a execução de ontem escreveu
# continuaria de pé, e o sintoma seria "desliguei e continua" — o pior de todos,
# porque não há onde olhar.
zerar; binario_falso
correr midia.sh >/dev/null

saida="$(correr MIDIA=nao midia.sh --conferir)"; rc=$?
[ "$rc" = "1" ] || reclamar "com MIDIA=nao e tudo instalado, o --conferir devolveu rc=$rc (esperado 1)" "$saida"
[ -f "$SOMBRA" ] || reclamar "o --conferir REMOVEU a sombra — conferir é leitura pura"
[ -x "$BIN" ]    || reclamar "o --conferir REMOVEU o binário — conferir é leitura pura"

saida="$(correr MIDIA=nao midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "com MIDIA=nao, o --aplicar devolveu rc=$rc (esperado 1)" "$saida"
[ -e "$SOMBRA" ] && reclamar "com MIDIA=nao, a sombra sobreviveu ao --aplicar" "$saida"
[ -e "$BIN" ]    && reclamar "com MIDIA=nao, o binário sobreviveu ao --aplicar" "$saida"

saida="$(correr MIDIA=nao midia.sh --conferir)"; rc=$?
[ "$rc" = "3" ] || reclamar "com MIDIA=nao e nada instalado, o --conferir devolveu rc=$rc (esperado 3)" "$saida"

# O par: o midia_build.sh não remove nada, de propósito — dois donos para a
# mesma remoção é como se cria a sombra sem binário do caso 3.
saida="$(correr MIDIA=nao MEOW_DRY_RUN=1 midia_build.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "com MIDIA=nao, o midia_build.sh devolveu rc=$rc (esperado 3: não é ele quem desliga)" "$saida"
fecha

# =============================================================================
caso "5. valor inválido é recusado com aviso, e não gravado"
# =============================================================================
# Uma largura de 5000 sairia do clamp do próprio applet e voltaria ao padrão sem
# nada avisar — e a conferência gritaria divergência para sempre, contra um
# arquivo que o applet nunca vai obedecer.
zerar; binario_falso

saida="$(correr MIDIA_LARGURA=5000 midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_LARGURA=5000 devolveu rc=$rc (esperado 3)" "$saida"
printf '%s' "$saida" | grep -q 'MIDIA_LARGURA' \
  || reclamar "MIDIA_LARGURA=5000 foi recusada em silêncio — o aviso tem de dizer a chave" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_LARGURA=5000 gravou em $CONFIG"
[ -e "$SOMBRA" ] && reclamar "MIDIA_LARGURA=5000 escreveu a sombra"

saida="$(correr MIDIA_COR_ALBUM=roxo midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_COR_ALBUM=roxo devolveu rc=$rc (esperado 3)" "$saida"
printf '%s' "$saida" | grep -q 'MIDIA_COR_ALBUM' \
  || reclamar "MIDIA_COR_ALBUM=roxo foi recusada em silêncio" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_COR_ALBUM=roxo gravou em $CONFIG"
[ -e "$SOMBRA" ] && reclamar "MIDIA_COR_ALBUM=roxo escreveu a sombra"

# A terceira da família, e a mais silenciosa das três: sem porta, um valor
# estranho cai no `else` do `_capa_valor` e DESLIGA a capa — a queixa dela
# voltaria por um erro de digitação, sem nada na tela dizendo por quê.
saida="$(correr MIDIA_CAPA=xis midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_CAPA=xis devolveu rc=$rc (esperado 3)" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_CAPA=xis gravou em $CONFIG — a capa teria sido desligada em silêncio"

# E o válido no limite continua passando: uma recusa grande demais seria pior
# que a ausência de recusa.
saida="$(correr MIDIA_LARGURA=900 MIDIA_COR_ALBUM=chapado MIDIA_CAPA=nao midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "os valores válidos no limite devolveram rc=$rc (esperado 1)" "$saida"
chave_vale panel-text-width  900
chave_vale panel-color-style chapado
chave_vale album-art-remote  false
fecha

# =============================================================================
caso "6. o --reverter tira a sombra ANTES do binário"
# =============================================================================
# A ordem é metade do valor da reversão: a sombra sai primeiro para que o
# flatpak reassuma o slot; só depois o binário. O contrário abriria — mesmo que
# por milissegundos — exatamente o buraco que o fail-safe do caso 3 existe para
# tapar.
zerar; binario_falso
correr midia.sh >/dev/null
[ -f "$SOMBRA" ] && [ -x "$BIN" ] || reclamar "não consegui armar o estado do caso 6"

saida="$(correr midia.sh --reverter)"; rc=$?
[ "$rc" = "1" ] || reclamar "o --reverter devolveu rc=$rc (esperado 1: mexeu)" "$saida"
[ -e "$SOMBRA" ] && reclamar "o --reverter deixou a sombra em $SOMBRA" "$saida"
[ -e "$BIN" ]    && reclamar "o --reverter deixou o binário em $BIN" "$saida"
# As chaves FICAM: são preferência dela, e o applet do flatpak não as lê.
# Apagá-las faria uma reinstalação perder a largura e a cor que ela escolheu.
chave_vale panel-text-width 440

saida="$(correr midia.sh --reverter)"; rc=$?
[ "$rc" = "0" ] || reclamar "o --reverter sem nada para remover devolveu rc=$rc (esperado 0)" "$saida"

# A ORDEM, E POR QUE ELA É MEDIDA NO CÓDIGO E NÃO NO DISCO
#   As duas remoções não têm saída antecipada entre elas: com a sombra primeiro
#   ou com o binário primeiro, o estado FINAL é o mesmo, e o estado
#   INTERMEDIÁRIO dura microssegundos. Todo jeito de flagrá-lo de fora (deixar um
#   diretório sem permissão de escrita para uma das duas falhar, espiar com
#   inotify, correr um `while` de fora) mede o relógio, não o programa — e um
#   teste que às vezes acusa é um teste que vira `|| true` na primeira
#   madrugada. Então o que se afirma aqui é o que é verificável: o estado final
#   acima, e a ORDEM DAS DUAS LINHAS na fonte. Se alguém trocá-las, esta
#   asserção cai com o motivo escrito.
fonte="$RAIZ/scripts/midia.sh"
l_sombra="$(grep -nF 'rm -f "$SOMBRA"; mexeu=1' "$fonte" | cut -d: -f1)"
l_binario="$(grep -nF 'rm -f "$BINARIO"; mexeu=1' "$fonte" | cut -d: -f1)"
if [ "$(printf '%s\n' "$l_sombra" | grep -c .)" != "1" ] \
|| [ "$(printf '%s\n' "$l_binario" | grep -c .)" != "1" ]; then
  reclamar "não achei exatamente uma remoção de cada em _reverter — o teste da ordem precisa ser reescrito"
elif [ "$l_sombra" -ge "$l_binario" ]; then
  reclamar "o --reverter remove o binário (linha $l_binario) ANTES da sombra (linha $l_sombra) — isso abre a janela em que a dock fica sem applet nenhum"
fi
fecha

# --- nota: a armadilha do rustup é real nesta máquina, e é medida aqui --------
# Não é asserção — numa máquina sem rustup não há o que medir. É a prova de que
# a guarda do caso 1 tem função: o mesmo `env -i` que os testes usam faz o shim
# criar `settings.toml` num HOME onde ele não deveria tocar.
if command -v rustc >/dev/null 2>&1; then
  N="$H/nota-rustup"; mkdir -p "$N"
  env -i PATH="$PATH" HOME="$N" rustc -V >/dev/null 2>&1
  if [ -f "$N/.rustup/settings.toml" ]; then
    printf 'nota: sob env -i, o shim do rustup escreveu .rustup/settings.toml num HOME limpo\n'
    printf '      (é essa escrita que o _rustc_versao do midia_build.sh evita no seco)\n'
  fi
fi

[ "$falhas" = "0" ] || { printf '\n%s caso(s) reprovado(s)\n' "$falhas" >&2; exit 1; }
printf '\nok: os seis casos do applet de mídia passaram, sem compilar nada\n'
