#!/usr/bin/env bash
# lib/comum.sh — a base de todo módulo do MeowSystem: cores, log, códigos de
# saída e as duas travas que impedem o instalador de estragar a máquina dela.
#
# São os mesmos hex de `packs/meowsystem/paleta.json`, convertidos para o
# truecolor do terminal.
#
# 0 = certo · 1 = divergente · 2 = erro de execução · 3 = falta dependência.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Esta atribuição roda no `source`, então `MEOW_SECO=1 ./algum_script.sh` é
# SOBRESCRITO aqui e não liga seco nenhum — o script roda de verdade achando
# que está só prevendo.
MEOW_SECO="${MEOW_DRY_RUN:-0}"

MEOW_OK=0; MEOW_DIVERGENTE=1; MEOW_ERRO=2; MEOW_SEM_DEPENDENCIA=3

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_MAUVE=$'\033[38;2;203;166;247m'; C_ROSA=$'\033[38;2;245;194;231m'
  C_VERDE=$'\033[38;2;166;227;161m'; C_AMARELO=$'\033[38;2;249;226;175m'
  C_VERM=$'\033[38;2;243;139;168m';  C_AZUL=$'\033[38;2;137;180;250m'
  C_DIM=$'\033[38;2;127;132;156m';   C_FORTE=$'\033[1m'; C_ZERO=$'\033[0m'
else
  C_MAUVE=""; C_ROSA=""; C_VERDE=""; C_AMARELO=""; C_VERM=""; C_AZUL=""
  C_DIM=""; C_FORTE=""; C_ZERO=""
fi

# `silencioso` esconde o que é PROGRESSO — título, passo, info e o "já estava
# certo". Continua mostrando o que MUDOU (`~~`), o que foi pulado, aviso e erro.
MEOW_LOG_NIVEL="${LOG_NIVEL:-info}"
meow_quieto() { [ "$MEOW_LOG_NIVEL" = "silencioso" ]; }
meow_debug()  { [ "$MEOW_LOG_NIVEL" = "debug" ] && printf '  %s..%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; return 0; }

meow_titulo() { meow_quieto && return 0
                printf '\n%s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO"; }
meow_passo()  { meow_quieto && return 0
                printf '\n  %s%s%s\n  %s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO" \
                       "$C_DIM" "$(printf '%.0s─' {1..52})" "$C_ZERO"; }
meow_info()   { meow_quieto && return 0
                printf '  %s>>%s %s\n' "$C_AZUL" "$C_ZERO" "$*"; }
meow_ok()     { meow_quieto && return 0
                printf '  %sok%s   %s\n' "$C_VERDE" "$C_ZERO" "$*"; }
meow_muda()   { printf '  %s~~%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*"; }
meow_pula()   { printf '  %s--%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; }
meow_aviso()  { printf '  %s!!%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*" >&2; }
meow_erro()   { printf '  %serro%s %s\n' "$C_VERM" "$C_ZERO" "$*" >&2; }
meow_seco()   { [ "$MEOW_SECO" = "1" ]; }

# --- O MOTIVO DA PENDÊNCIA: quem mede é o `detectar`, quem fala é o `aplicar` -
#
#   `meow_app_sem "<motivo>"`      guarda a causa e devolve 3. É a ÚNICA porta
#                                  por onde um `detectar` sai pendente.
#   `meow_app_pendente <módulo>`   diz a causa guardada e devolve 3. É a ÚNICA
#                                  forma de `aplicar`/`conferir`/`reverter`
#                                  anunciarem a pendência.
#
#   O IDIOMA É `... || { meow_app_sem "..."; return; }`, E O `return` NU É DE
#   PROPÓSITO: sem argumento ele devolve o status do último comando, que é o 3
#   da própria `meow_app_sem`. Motivo e código saem do mesmo lugar, então não há
#   como um ficar para trás quando o outro mudar.
MEOW_APP_MOTIVO=""

meow_app_sem() { MEOW_APP_MOTIVO="$*"; return "$MEOW_SEM_DEPENDENCIA"; }

meow_app_pendente() {
  local modulo="${1:-sem nome}"
  if [ -n "$MEOW_APP_MOTIVO" ]; then
    meow_pula "$MEOW_APP_MOTIVO"
  else
    meow_erro "sem motivo declarado — defeito no módulo $modulo"
  fi
  return "$MEOW_SEM_DEPENDENCIA"
}

# --- O TEMA DE APLICATIVO VEM DO PACK ---------------------------------------
#
#   `meow_app_tema_do_pack <app>.<chave>`  O QUE aplicar. O módulo pergunta em
#                                          vez de saber, e deixa de conhecer o
#                                          nome de qualquer tema. A resposta sai
#                                          em `MEOW_APP_TEMA` e em
#                                          `MEOW_APP_TEMA_PACK`, NÃO no stdout.
#   `meow_app_tema_no_ar <app> <no-ar> <do-pack> [de-quem] [pergunte]`
#                                          SE aplicar. Lê o que está no ar antes
#                                          de escrever, e tem três saídas.
MEOW_APP_TEMA=""
MEOW_APP_TEMA_PACK=""

# Devolve o que o pack ATIVO declara para aquele aplicativo, ou o que ele herda,
# em `MEOW_APP_TEMA`, e o id de QUEM respondeu em `MEOW_APP_TEMA_PACK` — que é
# como o log diz "herdado do catppuccin" em vez de fingir que o tema é do pack
# no ar.
#
#   meow_app_tema_do_pack spotify.spicetify_tema
#     MEOW_APP_TEMA=Sleek          MEOW_APP_TEMA_PACK=dracula
#   meow_app_tema_do_pack qbittorrent.arquivo
#     MEOW_APP_TEMA=/…/x.qbtheme   MEOW_APP_TEMA_PACK=catppuccin  (herdado)
#
#     _SPOT_TEMA_NOME=[catppuccin]  _SPOT_TEMA_DE=[]   <- sempre vazio
#     MEOW_QBT_ORIGEM=[/…/catppuccin-mocha.qbtheme]  MEOW_QBT_NOME_AURORA=[]
meow_app_tema_do_pack() {
  local trilha="$1" saida
  MEOW_APP_TEMA=""
  MEOW_APP_TEMA_PACK=""
  meow_tem python3 || return 1
  saida="$(FLAVOR="${FLAVOR:-}" python3 "$MEOW_RAIZ/scripts/pack.py" \
             app "$(meow_pack_dir)" "apps.$trilha" 2>/dev/null)" || return 1
  MEOW_APP_TEMA_PACK="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  MEOW_APP_TEMA="$(printf '%s\n' "$saida" | sed -n 's/^valor=//p')"
  return 0
}

# --- LER O QUE ESTÁ NO AR ANTES DE ESCREVER ---------------------------------
#
#   0  MEOW_OK              já está no tema do pack -> nada a fazer, e diz qual
#   1  MEOW_DIVERGENTE      está sem tema           -> aplica
#   3  MEOW_SEM_DEPENDENCIA está num tema que não veio daqui -> PERGUNTA
#
# O instalador roda desatendido, de hora em hora.
#
# Fora da tela o caso vira PENDÊNCIA ACIONÁVEL, o arquivo dele fica intocado, e
# a linha espera na Home.
_meow_temas_mantidos() { printf '%s/temas-mantidos.tsv' "$MEOW_ESTADO"; }

_meow_tema_mantido() {
  local arq no_ar="${2//$'\t'/ }"; arq="$(_meow_temas_mantidos)"
  no_ar="${no_ar//$'\n'/ }"
  [ -f "$arq" ] || return 1
  awk -F'\t' -v a="$1" -v t="$no_ar" '$1 == a && $2 == t { achou = 1 } END { exit !achou }' "$arq"
}

_meow_tema_esquecer() {  # <app> — tira a resposta gravada daquele app
  local arq; arq="$(_meow_temas_mantidos)"
  [ -f "$arq" ] || return 0
  awk -F'\t' -v a="$1" '$1 != a' "$arq" > "$arq.tmp" 2>/dev/null && mv -f "$arq.tmp" "$arq" 2>/dev/null
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

# O PAR SE SOMA, e não substitui o que o app já tinha: o Discord pergunta uma
# vez por PASTA de cliente (BetterDiscord, Vencord, Vesktop), cada uma com o
# arquivo dela, e um «Manter o meu» que apagasse a linha da pasta anterior
# deixaria a primeira perguntando de novo na passagem seguinte.
_meow_tema_manter() {  # <app> <no-ar>
  local app="$1" no_ar="${2//$'\t'/ }"
  no_ar="${no_ar//$'\n'/ }"
  mkdir -p "$MEOW_ESTADO" || return 1
  _meow_tema_mantido "$app" "$no_ar" && return 0
  printf '%s\t%s\n' "$app" "$no_ar" >> "$(_meow_temas_mantidos)"
}

meow_app_tema_no_ar() {
  local app="$1" no_ar="$2" do_pack="$3" de_quem="${4:-$MEOW_APP_TEMA_PACK}" resp=""
  local pode_perguntar="${5:-}"
  local id="$app-tema-de-terceiro" fonte=""
  # A ORIGEM VAI SEMPRE QUE HOUVER UMA, inclusive quando ela é o pack no ar.
  [ -n "$de_quem" ] && fonte=" (do pack $de_quem)"

  if [ -z "$no_ar" ]; then
    meow_pendencia_resolvida "$id"
    meow_info "$app: está sem tema — aplico o do pack$fonte"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$no_ar" = "$do_pack" ]; then
    meow_pendencia_resolvida "$id"
    meow_ok "$app: já está no tema do pack$fonte — $no_ar"
    return "$MEOW_OK"
  fi

  # Ver o bloco de cima. A gravada vem ANTES do aviso: um «Manter o meu»
  # respondido não pode virar um `!!` no log a cada hora.
  local do_painel=""
  [ "$pode_perguntar" = "pergunte" ] && do_painel="${MEOW_TEMA_DE_TERCEIRO:-}"
  if [ -z "$do_painel" ] && _meow_tema_mantido "$app" "$no_ar" \
     && ! { [ "$pode_perguntar" = "pergunte" ] && [ -t 0 ] && [ -t 1 ] && ! meow_seco; }; then
    meow_pendencia_resolvida "$id"
    meow_ok "$app: fica no '$no_ar', como você escolheu («Manter o meu»)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_aviso "$app: está em '$no_ar', que não veio daqui"
  meow_info  "o pack$fonte traz '$do_pack'"

  # ANTES DO SECO, de propósito: o «Ver sem mudar» do «Trocar pelo tema do
  # pack» tem de ensaiar a TROCA, e quem diz o que ela escreveria é o módulo,
  # daqui para baixo, com o seco dele.
  case "$do_painel" in
    trocar)
      if meow_seco; then
        meow_muda "$app: trocaria pelo tema do pack — é a resposta do painel"
      else
        _meow_tema_esquecer "$app"
        meow_pendencia_resolvida "$id"
        meow_muda "$app: trocando pelo tema do pack — é a resposta do painel"
      fi
      return "$MEOW_DIVERGENTE" ;;
    manter)
      if meow_seco; then
        meow_pula "$app: gravaria que o '$no_ar' fica, e não perguntaria de novo"
      else
        _meow_tema_manter "$app" "$no_ar" || return "$MEOW_ERRO"
        meow_pendencia_resolvida "$id"
        meow_ok "$app: fica no '$no_ar' — não pergunto de novo enquanto ele for o tema"
      fi
      return "$MEOW_SEM_DEPENDENCIA" ;;
  esac

  # O seco promete não tocar em arquivo nenhum, e perguntar é o começo de tocar.
  if meow_seco; then
    meow_pula "perguntaria se troco pelo tema do pack (e não trocaria sozinho)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ "$pode_perguntar" = "pergunte" ] && [ -t 0 ] && [ -t 1 ]; then
    printf '  %s??%s   trocar pelo tema do pack? [s/N] ' "$C_AMARELO" "$C_ZERO"
    IFS= read -r -t 30 resp || resp=""
    printf '\n'
    case "$resp" in
      [sS]|[sS][iI][mM])
        meow_pendencia_resolvida "$id"
        meow_muda "$app: trocando pelo tema do pack a seu pedido"
        return "$MEOW_DIVERGENTE" ;;
    esac
  fi

  # O COMANDO VAI NA LINHA. Sem ele o painel não desenha botão (a regra "o
  # botão precisa das duas pontas", no `pendencias()` do app/servidor.py), e
  # ele é também o que um terminal responde: o `aplicar` deste app pergunta.
  meow_pendencia_acionavel "$id" \
    "O $app está no tema '$no_ar', que não veio do MeowSystem — deixei como está. Trocar pelo tema do pack ou manter o seu é decisão sua" \
    "meow apps aplicar $app"
  return "$MEOW_SEM_DEPENDENCIA"
}

# --- A PORTA ÚNICA DA PALETA -------------------------------------------------
#
# A promessa era falsa em duas camadas. A chave `PALETA_ARQUIVO` não existia no
# meow.conf.exemplo, e o install.sh chamava o gerador sem exportar variável
# nenhuma.
#
# A paleta do pack padrão morava em `assets/paleta/catppuccin.json`, e o nome
# dela estava cravado aqui.
#
# Os cinco consumidores em Python.
meow_paleta() {
  if [ -n "${MEOW_PALETA:-}" ] && [ "$MEOW_PALETA" != "${MEOW_PALETA_DA_PONTE:-}" ]; then
    printf '%s' "$MEOW_PALETA"
    return 0
  fi
  local _pack_dir
  _pack_dir="$(meow_pack_dir)"
  if [ -n "$_pack_dir" ] && [ -f "$_pack_dir/paleta.json" ]; then
    printf '%s' "$_pack_dir/paleta.json"
    return 0
  fi
  if [ -n "${PALETA_ARQUIVO:-}" ]; then
    printf '%s' "$MEOW_RAIZ/assets/paleta/$PALETA_ARQUIVO"
    return 0
  fi
  printf '%s' "$(meow_pack_padrao_dir)/paleta.json"
}

# O nome do arquivo, sem o caminho — para MENSAGEM, nunca para abrir.
#
# Quem decide qual pack é o ativo: a chave PACK do meow.conf, ou o FLAVOR quando
# ela não existe (a adoção por convenção, logo abaixo).
#
# Havia uma linha `[ "$PACK" = "catppuccin" ] && return 0` logo abaixo: o pack
# padrão não tinha `pack.json`, então perguntar ao `pack.py` por ele estourava
# um FileNotFoundError, e o desvio existia para não perguntar.

# A mesma lista de três diretórios — `$MEOW_PACKS`, o XDG e `$MEOW_RAIZ/packs` —
# estava escrita à mão em `scripts/pack.py:raizes()`, DUAS vezes aqui dentro do
# `meow_pack_dir` e em `app/servidor.py:_packs_no_disco`.
#
# Quem manda é o `scripts/pack.py:raizes()`, porque é ele quem abre o
# `pack.json`.
meow_pack_raizes() {
  if [ -z "${MEOW_PACK_RAIZES:-}" ]; then
    MEOW_PACK_RAIZES="$(python3 "$MEOW_RAIZ/scripts/pack.py" raizes 2>/dev/null)"
    export MEOW_PACK_RAIZES
  fi
  if [ -z "$MEOW_PACK_RAIZES" ]; then
    # SEM RESPOSTA É AVISO, NUNCA SILÊNCIO. Devolver vazio calado faria todo
    # pack desaparecer da máquina com cara de "não há pack instalado" — e o
    # `meow_pack_dir` cairia no embutido sem dizer por quê.
    [ "${MEOW_PACK_RAIZES_AVISADO:-0}" = "1" ] || {
      MEOW_PACK_RAIZES_AVISADO=1
      meow_aviso "scripts/pack.py não respondeu as raízes — nenhum pack será enxergado"
    }
    return 1
  fi
  printf '%s\n' "$MEOW_PACK_RAIZES"
}

# O diretório do pack PADRÃO — o que acompanha o projeto e de quem todo mundo
# herda o que não declarou.
#
# Agora ele mora em UM: `scripts/pack.py`, constante `PACK_PADRAO`.
#
# O CACHE É O MESMO DO `meow_pack_raizes`, E PELO MESMO MOTIVO: sem ele seria um
# fork de python por chamada, e o `meow_paleta` chama a cada consulta, num
# instalador de dezenas de etapas.
meow_pack_padrao_dir() {
  if [ -z "${MEOW_PACK_PADRAO_DIR:-}" ]; then
    MEOW_PACK_PADRAO_DIR="$(python3 "$MEOW_RAIZ/scripts/pack.py" padrao 2>/dev/null)"
    export MEOW_PACK_PADRAO_DIR
  fi
  # SEM RESPOSTA É AVISO, NUNCA SILÊNCIO — a mesma regra do `meow_pack_raizes`.
  if [ -z "$MEOW_PACK_PADRAO_DIR" ]; then
    [ "${MEOW_PACK_PADRAO_AVISADO:-0}" = "1" ] || {
      MEOW_PACK_PADRAO_AVISADO=1
      meow_aviso "scripts/pack.py não disse qual é o pack padrão — a paleta não resolve"
    }
    return 1
  fi
  printf '%s' "$MEOW_PACK_PADRAO_DIR"
}

meow_pack_dir() {
  local PACK="${PACK:-}" FLAVOR="${FLAVOR:-}" saida recusado
  # Sem a chave PACK, um FLAVOR que nomeie um pack existente adota esse pack.
  #
  # A conta acima estava escrita AQUI, em shell, e o painel tinha a dele em
  # Python (`_pack_adotado`, app/servidor.py), que também adotava pelo SABOR que
  # a paleta declara.
  [ -n "$PACK$FLAVOR" ] || return 0
  saida="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao "$PACK" "$FLAVOR" 2>/dev/null)" || {
    meow_aviso "scripts/pack.py não disse qual pack adotar (PACK='$PACK', FLAVOR='$FLAVOR') — usando o padrão"
    return 0
  }
  recusado="$(printf '%s\n' "$saida" | sed -n 's/^recusado=//p')"
  [ -n "$recusado" ] && meow_aviso "pack '$recusado' não resolve — usando o padrão"
  printf '%s' "$(printf '%s\n' "$saida" | sed -n 's/^dir=//p')"
  return 0
}

# O FLAVOR QUE VALE: o do meow.conf, e, vazio, o padrão do pack no ar.
#
# Oito scripts tinham o seu `${FLAVOR:-mocha}` (`fzf`, `completar_icones`,
# `greeter`, `midia`, `construir_icones`, `logo`, `icones_apps_arcticons` e
# `terminal`), e o `mocha` é o padrão de UM pack.
#
# A REGRA É A DO docs/PACKS.md ("Quem vence"): o FLAVOR do conf vence; vazio,
# entra o `paleta.flavor_padrao` do pack no ar.
meow_flavor() {
  local padrao
  if [ -n "${FLAVOR:-}" ]; then
    printf '%s' "$FLAVOR"
    return 0
  fi
  padrao="$(python3 -I - "$MEOW_RAIZ/scripts" "${PACK:-}" <<'PYFIM' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import pack
print(pack.vocabulario(pack.adocao(sys.argv[2], "")[0])["flavor_padrao"])
PYFIM
)"
  if [ -z "$padrao" ]; then
    meow_aviso "scripts/pack.py não respondeu qual é o flavor padrão do pack no ar (PACK='${PACK:-}') — o FLAVOR fica vazio"
    return 1
  fi
  printf '%s' "$padrao"
}

# O `meow_flavor` diz QUAL escuro (ou claro) a pessoa escolheu; o MODO diz
# qual LADO a tela veste.
meow_flavor_vestido() {
  local fl
  fl="$(meow_flavor)" || return 1
  # Sem MODO no ambiente (um script chamado à mão, sem o meow.conf), não há
  # lado a escolher: vale o FLAVOR, como antes desta função.
  case "${MODO:-}" in
    claro|escuro) ;;
    *) printf '%s' "$fl"; return 0 ;;
  esac
  python3 -I - "$MEOW_RAIZ/scripts" "$fl" "$MODO" "$(meow_paleta)" <<'PYFIM' 2>/dev/null || printf '%s' "$fl"
import json, sys
sys.path.insert(0, sys.argv[1])
import derivar_flavor
fl, modo = sys.argv[2], sys.argv[3]
with open(sys.argv[4], encoding="utf-8") as fh:
    paleta = json.load(fh)
claros = [c for c in (paleta.get("claros") or []) if c in (paleta.get("flavors") or {})]
par = derivar_flavor.par_do_outro_lado(fl, paleta) if (modo == "claro") != (fl in claros) else fl
# O par é uma chave da paleta do pack, e um pack importado é dado não
# confiável: o nome vira caminho (as pastas, o traço), então só da forma que o
# conf aceita (conferência da P74, alerta de segurança de 09/10/2026).
import re
print(par if isinstance(par, str) and re.fullmatch(r"[a-z0-9_]+", par) else fl)
PYFIM
}

# O `ICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"` de fábrica se expande quando o
# meow.conf é lido, antes de o FLAVOR vazio virar o padrão do pack, e chega
# como `cat--<acento>`.
meow_pastas_do_molde() {
  case "${ICONES_PASTAS:-}" in cat--?*) ICONES_PASTAS="cat-${FLAVOR:-}-${ICONES_PASTAS#cat--}" ;; esac
}

# OS PACKS DO DISCO QUE PASSAM NO `validar`, um id por linha, em ordem.
#
# O Obsidian e o VS Code perguntam a mesma coisa sobre o que está no aplicativo
# — o snippet ligado, o tema de ícones — e contavam os packs cada um à sua
# maneira.
#
# Sem resposta do pack.py, a lista sai vazia — e vazia quer dizer "pack nenhum",
# que não desmarca nem troca nada em aplicativo nenhum.
meow_packs_validos() {
  python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack

vistos, validos = set(), set()
for base in pack.raizes():
    try:
        nomes_da_raiz = os.listdir(base)
    except OSError:
        continue
    for n in nomes_da_raiz:
        if n in vistos or not pack.RE_ID.fullmatch(n) \
           or not os.path.isfile(os.path.join(base, n, "pack.json")):
            continue
        vistos.add(n)
        try:
            pack.validar(n, silencioso=True)
        except Exception:
            continue
        validos.add(n)
# O nome de antes de um pack (o `catppuccin`, que entrou no `meowsystem` na P96) ainda nomeia
# o que é dele: um snippet, um tema, um vestígio.
for antes, hoje in getattr(pack, "APELIDOS", {}).items():
    if hoje in validos:
        validos.add(antes)
for n in sorted(validos):
    print(n)
PYFIM
}

# Um caminho de dentro do pack ativo, com queda para o do núcleo.
# meow_pack_arquivo icones/apps.map  assets/icones/apps-dracula.map devolve o
# primeiro que existir, nessa ordem.
# O caminho passa pelo `meow_dentro`: uma pasta do pack que seja link para fora
# não vira acervo.
# O motivo de um `cargo build` que falhou, lido do registro dele: a falta de
# compilador ou de biblioteca do sistema vem antes de qualquer suspeita do código.
meow_motivo_do_cargo() {
  local log="$1" lib
  if grep -q 'linker `cc` not found' "$log" 2>/dev/null; then
    printf 'falta o compilador C (pacote build-essential)'
  elif lib="$(grep -o 'The system library `[^`]*`' "$log" 2>/dev/null | head -n1)" && [ -n "$lib" ]; then
    lib="${lib#*\`}"
    printf 'falta a biblioteca %s do sistema (o pacote -dev dela)' "${lib%\`}"
  elif grep -q 'Could not run `"pkg-config"\|pkg-config: not found\|failed to run.*pkg-config' "$log" 2>/dev/null; then
    printf 'falta o pkg-config'
  else
    printf 'o cargo não compilou'
  fi
}

# Os pacotes de que a compilação dos applets precisa, um por linha:
# `<arquivo que prova a presença>|<pacote>`.
MEOW_DEPS_DOS_APPLETS="/usr/bin/cc|build-essential
/usr/bin/pkg-config|pkg-config
/usr/include/xkbcommon/xkbcommon.h|libxkbcommon-dev
/usr/include/wayland-client.h|libwayland-dev
/usr/include/dbus-1.0/dbus/dbus.h|libdbus-1-dev"

# A pasta do mascote do pack no ar (pela herança); sem nenhuma, a do pack-base.
meow_mascote_dir() {
  python3 "$MEOW_RAIZ/scripts/pack.py" mascote "$(meow_pack_dir)" 2>/dev/null \
    || printf '%s' "$MEOW_RAIZ/packs/meowsystem/mascote"
}

meow_pack_arquivo() {
  local no_pack="$1" no_nucleo="${2:-}" dir real
  dir="$(meow_pack_dir)"
  if [ -n "$dir" ] && [ -e "$dir/$no_pack" ] && real="$(meow_dentro "$dir" "$no_pack")"; then
    printf '%s' "$real"
    return 0
  fi
  [ -n "$no_nucleo" ] && [ -e "$MEOW_RAIZ/$no_nucleo" ] && printf '%s' "$MEOW_RAIZ/$no_nucleo"
  return 0
}

# --- A REGRA ÚNICA DO DADO DE PACK, EM SHELL ---------------
#
# Um pack pode vir de terceiros (`meow pack importar`, ou um `git clone` na raiz
# da pessoa, que traz symlink), e o que vem dele é dado não confiável: campo do
# pack.json, linha de mapa, arquivo de pasta de desenho.
#
# `meow_dentro <raiz> <caminho>` Imprime o `realpath` do caminho (relativo à
# raiz, ou absoluto) e sai 0 só se ele EXISTIR e cair dentro do `realpath` da
# raiz.
# O `realpath` segue todo symlink, do meio e do fim; quem chama usa o que ele
# IMPRIME, nunca o caminho que entrou.
#
# `meow_nome_seguro <nome>`: 0 quando o nome serve de arquivo do lado de cá, só
# `[A-Za-z0-9._+-]` e sem `..`. A linha que falha é pulada e contada por quem chama.
meow_dentro() {
  local raiz cheio real
  raiz="$(realpath -e -- "$1" 2>/dev/null)" || return 1
  case "$2" in /*) cheio="$2" ;; *) cheio="$1/$2" ;; esac
  real="$(realpath -e -- "$cheio" 2>/dev/null)" || return 1
  case "$real" in "$raiz"/*) printf '%s' "$real"; return 0 ;; esac
  return 1
}

meow_nome_seguro() {
  case "$1" in ''|.|*..*|*[!A-Za-z0-9._+-]*) return 1 ;; esac
  return 0
}

# É a porta de saída de texto que veio de pack, mapa, `.meowpack` ou nome de
# arquivo e vai para um aviso — nome de pack, linha pulada, pasta da raiz.
meow_texto_seguro() {
  python3 -I -c 'import re, sys
t = sys.argv[1].encode("utf-8", "surrogateescape").decode("utf-8", "replace")
sys.stdout.write(re.sub("[\x00-\x1f\x7f-\x9f\ufffd]", "?", t))' "$*"
}

# --- A CAPTURA DE TEMA: UMA PERGUNTA, UM LUGAR QUE RESPONDE -----------------
#
# As capturas desceram para dentro do pack dono
# (`packs/<id>/temas/capturados/`), e a `original` ficou no motor porque não é
# tema de pack nenhum — é o molde do esquema v1 e o reset de fábrica desta
# máquina.
#
# Quem responde é o `scripts/pack.py`, e só ele: é lá que a subida pack ->
# herança -> motor já mora, para os acervos de ícone.
meow_captura() {
  MEOW_PACK_DIR="${MEOW_PACK_DIR:-$(meow_pack_dir)}" \
    python3 "$MEOW_RAIZ/scripts/pack.py" captura "$1" 2>/dev/null
}

# Os nomes das capturas ALCANÇÁVEIS daqui — o pack ativo, os que ele herda e o
# motor. Uma por linha. Não é "tudo o que existe no disco": uma captura de um
# pack que este desktop não usa não é uma captura que ele possa aplicar.
meow_capturas() {
  MEOW_PACK_DIR="${MEOW_PACK_DIR:-$(meow_pack_dir)}" \
    python3 "$MEOW_RAIZ/scripts/pack.py" capturas 2>/dev/null
}

meow_paleta_nome() {
  local p; p="$(meow_paleta)"
  printf '%s' "${p#"$MEOW_RAIZ"/}"
}

# --- A PONTE SHELL -> PYTHON ------------------------------------------------
#
# O cabeçalho do `meow_paleta`, logo acima, diz "POR QUE UMA FUNÇÃO, E NÃO UMA
# VARIÁVEL EXPORTADA" — e o argumento continua certo PARA O SHELL. Ele só não
# cobre metade dos consumidores.
#
# Nenhum deles pode chamar uma função de shell.
#
# Vazio quer dizer "o pack é o embutido" — o mesmo sinal que o `meow_pack_dir`
# já dá ao shell.
meow_ponte_python() {
  local paleta pack_dir da_pessoa=0
  local PACK="${PACK:-$(meow_conf_valor PACK || true)}"
  local FLAVOR="${FLAVOR:-$(meow_conf_valor FLAVOR || true)}"
  # A pergunta é feita ANTES de qualquer coisa porque o `meow_paleta` logo
  # abaixo já responde por ela; o que se guarda aqui é só o que o FILHO precisa
  # saber para repetir a conta.
  [ -n "${MEOW_PALETA:-}" ] && [ "$MEOW_PALETA" != "${MEOW_PALETA_DA_PONTE:-}" ] && da_pessoa=1
  # AQUECE O CACHE DAS RAÍZES NESTE SHELL, E NÃO DENTRO DE UM `$( )` O
  # `meow_paleta` logo abaixo é chamado por substituição de comando, que roda
  # num SUBSHELL: o `export MEOW_PACK_RAIZES` feito lá dentro morre com ele, e a
  # lista seria refeita a cada consulta.
  meow_pack_raizes >/dev/null || true
  paleta="$(meow_paleta)"
  if [ ! -f "$paleta" ]; then
    meow_erro "a paleta apontada não existe: $paleta"
    if [ "$da_pessoa" = "1" ]; then
      meow_info "  ela veio de MEOW_PALETA — aponte para um arquivo que exista, ou tire a variável."
    else
      meow_info "  ela veio do pack ativo (PACK/FLAVOR do meow.conf) ou do pack padrão."
    fi
    meow_info "  sem ela nenhum gerador em Python tem cor para trabalhar, e parar aqui é"
    meow_info "  mais barato do que descobrir isso etapa por etapa."
    return "$MEOW_ERRO"
  fi
  pack_dir="$(meow_pack_dir)"
  MEOW_PALETA="$paleta"
  MEOW_PACK_DIR="$pack_dir"
  # Cheio, e igual ao `MEOW_PALETA`, quer dizer "este valor é meu": o filho pode
  # jogá-lo fora e reresolver do pack.
  if [ "$da_pessoa" = "1" ]; then MEOW_PALETA_DA_PONTE=""; else MEOW_PALETA_DA_PONTE="$paleta"; fi
  export MEOW_PALETA MEOW_PACK_DIR MEOW_PALETA_DA_PONTE
  return 0
}

# --- A RAIZ DO COSMIC: UM LUGAR SÓ PARA DIZER ONDE ELA É --------------------
# Onde mora a configuração do COSMIC desta pessoa.
#
# Uma costura meio construída é pior que nenhuma: quem lê o código vê a variável
# e supõe que ela vale, quando ela valia em pouco mais de um terço dos lugares.
#
# A divergência ainda não mordeu ninguém, e o motivo é um acaso: NADA neste
# repositório atribui `MEOW_COSMIC_DIR` — conferido, zero atribuições.
#
# Quem esquecer de chamá-lo aparece no grep do `tests/estilo.sh`.
meow_cosmic_dir() {
  printf '%s' "${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
}

# O `v1` estava escrito à mão em cada escritor. O COSMIC migra esquema, e um
# escritor cravado em `v1` continua gravando, verde no doctor, numa pasta que
# ninguém lê mais.
meow_cosmic_v() {
  local n
  n="$(ls -1 "${MEOW_COSMIC_SISTEMA:-/usr/share/cosmic}/$1" 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)"
  printf 'v%s' "${n:-1}"
}

# É por ela que o pré-voo, o oráculo do tema e os applets acompanham o COSMIC
# instalado (ou o candidato). Devolve o SHA completo; sem rede, ou sem
# `Cargo.lock`, sai 1 e não inventa.
meow_libcosmic_de() { # $1 repositório (cosmic-settings, cosmic-panel) $2 versão do pacote
  local sha="${2##*~}" rev
  [ "${MEOW_SEM_REDE:-0}" = "1" ] && return 1
  rev="$(curl -sfL --max-time 20 "https://raw.githubusercontent.com/pop-os/$1/$sha/Cargo.lock" 2>/dev/null |
    awk '/^name = "libcosmic"$/{f=1} f && /^source = /{sub(/.*#/,""); sub(/"$/,""); print; exit}')"
  [ -n "$rev" ] || return 1
  printf '%s' "$rev"
}

# Com o shim do compositor ligado (`meow compositor ativar`), o binário
# patchado mora em `~/.local/libexec/meow/cosmic-comp/<versão>/`, e quem
# decide entre ele e o de fábrica é o próprio shim.
meow_cosmic_comp_disco() {
  local shim="$HOME/.local/bin/cosmic-comp"
  if grep -qs -- MEOW-COSMIC-COMP-SHIM "$shim"; then
    MEOW_SHIM_SO_DIZER=1 bash "$shim" 2>/dev/null && return 0
  fi
  printf '%s\n' /usr/bin/cosmic-comp
}

# --- TRAVA 1: territórios proibidos ----------------------------------------
# Uma escrita fora de lugar aqui não dá erro: dá um sintoma bizarro dias depois.
#
# A primeira vale em qualquer lugar do mundo: /usr é território do gerenciador
# de pacotes, e um `apt upgrade` sobrescreve.
#
# O Aurora disputa `/usr/share` em pontos nomeados (o ícone do App Library,
# self-heal:793 — e lá ele só DESFAZ o que a v3.45 dele plantou), não o
# diretório inteiro.
MEOW_PROIBIDOS_SISTEMA=(/usr/share /usr/local/share /usr/bin /usr/lib)
MEOW_PROIBIDOS_LOCAIS=()
# `!caminho` no vizinhos.conf é a exceção por arquivo: aquele arquivo exato, dentro
# de uma pasta de outro projeto, o MeowSystem escreve (o bloco do terminal no .zshrc).
MEOW_EXCECOES_LOCAIS=()
MEOW_VIZINHOS="${MEOW_VIZINHOS:-$HOME/.config/meow/vizinhos.conf}"
if [ -f "$MEOW_VIZINHOS" ]; then
  while IFS= read -r _l || [ -n "$_l" ]; do
    _l="${_l%%#*}"                      # comentário no fim da linha
    _l="${_l%"${_l##*[![:space:]]}"}"   # apara espaço à direita
    [ -z "$_l" ] && continue
    # SEM `eval`: a única expansão que este arquivo precisa é $HOME, e passar as
    # linhas por eval transformaria um arquivo de configuração em execução de
    # código — `$(rm -rf ~)` numa linha bastaria.
    case "$_l" in
      '!'*) _l="${_l#!}"; _l="${_l//\$HOME/$HOME}"
            case "$_l" in /*) MEOW_EXCECOES_LOCAIS+=("$(readlink -m -- "$_l")") ;; esac ;;
      *)    MEOW_PROIBIDOS_LOCAIS+=("${_l//\$HOME/$HOME}") ;;
    esac
  done < "$MEOW_VIZINHOS"
  unset _l
fi

meow_destino_permitido() {
  local alvo="$1" real p
  real="$(readlink -m -- "$alvo")"
  for p in "${MEOW_PROIBIDOS_SISTEMA[@]}"; do
    case "$real" in "$p"/*)
      meow_erro "recusado: '$alvo' é território do sistema e do gerenciador de pacotes"
      return 1 ;;
    esac
  done
  for p in ${MEOW_EXCECOES_LOCAIS[@]+"${MEOW_EXCECOES_LOCAIS[@]}"}; do
    [ "$real" = "$p" ] && return 0
  done
  # Casa o caminho exato e tudo abaixo dele. Escreva CAMINHO ABSOLUTO no
  # vizinhos.conf: um nome solto de componente não é casado no meio do caminho,
  # ao contrário do que a regra antiga dos atalhos fazia.
  for p in ${MEOW_PROIBIDOS_LOCAIS[@]+"${MEOW_PROIBIDOS_LOCAIS[@]}"}; do
    case "$real" in "$p"|"$p"/*)
      meow_erro "recusado: '$alvo' pertence a outro projeto nesta máquina ($p)"
      return 1 ;;
    esac
  done
  return 0
}

# --- TRAVA 2: escrita atômica no MESMO sistema de arquivos ------------------
# O repo mora em /mnt/Apate e os destinos em /home: `mv` entre eles NÃO é
# atômico, e um corte no meio deixaria arquivo de config pela metade. O
# temporário nasce sempre dentro do diretório de DESTINO.
#
# `meow_mesmo_conteudo <a> <b>` é a MESMA régua que o `meow_escrever` usa para
# decidir "já está certo": o conteúdo, com a newline final normalizada — o
# `$(cat)` a come dos dois lados.
meow_mesmo_conteudo() {
  [ -f "$1" ] && [ -f "$2" ] && [ "$(cat "$1" 2>/dev/null)" = "$(cat "$2" 2>/dev/null)" ]
}

# O estado de antes de cada escrita, para o Restaurar do painel.
# shellcheck source=restauro.sh
. "$(dirname "${BASH_SOURCE[0]}")/restauro.sh"

meow_escrever() {
  local destino="$1" conteudo="$2" modo="${3:-644}" tmp dir
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"

  if [ -f "$destino" ] && [ "$conteudo" = "$(cat "$destino" 2>/dev/null)" ]; then
    return "$MEOW_OK"   # regra 5: comparar por conteúdo, não escrever à toa
  fi
  if meow_seco; then
    meow_muda "mudaria $destino"
    return "$MEOW_DIVERGENTE"
  fi
  meow_guardar_antes "$destino"
  mkdir -p "$dir" || return "$MEOW_ERRO"
  #   O `cosmic-config` do libcosmic IGNORA de propósito os temporários cujo nome
  #   começa com `.atomicwrite`, ao traduzir eventos de inotify em mudanças de
  #   chave (`libcosmic/cosmic-config/src/lib.rs:407-408`:
  #       // Skip any .atomicwrite temporary files
  #       if key.starts_with(".atomicwrite") { continue }
  #   ), porque é assim que ele mesmo escreve.
  # Com outro nome o painel recebia quatro eventos por chave e relia a entrada inteira
  # a cada um, alimentando a corrida do raio que apaga topbar e dock.
  tmp="$(mktemp -p "$dir" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s' "$conteudo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$destino"
  return "$MEOW_DIVERGENTE"   # 1 = "estava divergente e eu consertei"
}

# --- O MEOW.CONF: UM CAMINHO SÓ, E UMA FORMA SÓ DE ESCREVER NELE ------------
# Os dois caminhos e as duas funções abaixo VIERAM do `bin/meow`, e a mudança é
# de endereço, não de comportamento: o texto delas é o mesmo.
#
# O `wallpaper.sh permitir` precisa gravar uma chave no meow.conf, e ele NÃO é
# a CLI — é um script de `scripts/`, que roda como processo filho.
#
# `MEOW_CONF` continua sendo o override de sempre, e agora ele vale para todo
# módulo que sourceia este arquivo, não só para a CLI.
MEOW_CONF_ARQUIVO="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"
MEOW_CONF_PADRAO="${MEOW_CONF_PADRAO:-$MEOW_RAIZ/meow.conf.exemplo}"

# Troca (ou acrescenta) uma chave do meow.conf preservando o comentário da
# linha.
#
#   O meow.conf é comentado linha a linha, e o comentário é metade do valor dele
#   como documentação. Um `sed -E 's|^(MODO=)[^#]*(#.*)?$|...|'` parece resolver
#   e não resolve: o `[^#]*` é guloso, engole os espaços que separam o valor do
#   comentário e devolve `MODO="claro"# escuro | claro | auto`, colado. ERE não
#   tem quantificador preguiçoso para consertar isso. Aqui a linha é partida no
#   primeiro `#` e os espaços de antes dele são preservados como estavam.
# Troca TODAS as ocorrências: o shell obedece à última atribuição, e trocar só a
# primeira gravaria um valor e deixaria outro valendo, calado.
meow_conf_texto_definir() {
  local texto="$1" chave="$2" valor="$3" novo="" linha resto antes espacos comentario achou=0
  while IFS= read -r linha; do
    if [ "${linha#"$chave"=}" != "$linha" ]; then
      achou=1
      resto="${linha#"$chave"=}"
      if [ "${resto#*#}" != "$resto" ]; then
        antes="${resto%%#*}"
        comentario="#${resto#*#}"
        # O sufixo que sobra depois do último caractere não-branco: exatamente
        # os espaços que alinhavam o comentário.
        espacos="${antes##*[![:space:]]}"
        linha="$chave=\"$valor\"$espacos$comentario"
      else
        linha="$chave=\"$valor\""
      fi
    fi
    novo="$novo$linha"$'\n'
  done <<< "$texto"
  novo="${novo%$'\n'}"
  [ "$achou" = "1" ] || novo="$novo"$'\n'"$chave=\"$valor\""
  printf '%s' "$novo"
}

# Grava a chave no meow.conf dela. Quando o arquivo ainda não existe, a base é o
# `meow.conf.exemplo` — o mesmo caminho que o `install.sh` toma no seco, e o que
# impede a primeira gravação de nascer um arquivo de uma linha só, sem nenhum
# dos comentários que são a documentação deste projeto.
#
# Devolve o que a `meow_escrever` devolve: 0 já estava assim · 1 escreveu (ou
# escreveria, no seco) · 2 falhou.
# "A CHAVE DIZ 'nao', OU ELA SIMPLESMENTE NÃO EXISTE?" — 08/09/2026
#
# São perguntas diferentes, e confundi-las apagou um arquivo de `/etc`. O
# `${LANCADOR_SISTEMA:-nao}` que a etapa do hook de apt usava responde às duas
# com a mesma palavra: chave ausente e chave escrita "nao" viram o mesmo valor.
# Para LER a preferência isso é certo — o padrão é não mexer em `/usr/share`.
# Para DESTRUIR, não: remover um arquivo de `/etc` porque uma chave está
# faltando é agir por omissão, e omissão não é decisão.
#
# Enquanto o `sudo` falhava calado num ambiente sem terminal, o defeito era
# invisível. Com a ponte root, o mesmo caminho passou a funcionar — e o
# `tests/convergencia.sh`, que roda o instalador num HOME de brinquedo onde
# nenhuma chave existe, apagou o `99-meow-lancador` da máquina de verdade.
#
# Esta função lê o ARQUIVO, não a variável: devolve 0 só quando a chave está lá,
# escrita, com o valor pedido. Sem arquivo, ou sem a chave, devolve 1.
# O VALOR de uma chave do meow.conf, ou saída 1 quando ela não está escrita lá.
#
# POR QUE ELE NASCEU EM 21/09/2026
#   A leitura estava inteira dentro do `meow_conf_diz`, que responde SIM/NÃO. A
#   ponte shell->Python do `app/run.sh` precisa do VALOR de PACK e de FLAVOR, e
#   não de uma comparação — e escrever o mesmo `sed`/`tr` lá seria a segunda
#   cópia da regra de como este arquivo é escrito (aspas, comentário de fim de
#   linha). O `meow_conf_diz` passa a chamar este; o comportamento dele não
#   mudou em nada.
#
#   ESTA FUNÇÃO NÃO É A LEITURA CANÔNICA DO CONF, e não pretende ser: quem
#   precisa de TODAS as chaves com os defaults aplicados usa o `set -a; . conf`
#   do `etapa_conf_ler`/`carregar_conf`. Esta aqui serve a quem quer UMA chave
#   sem subir o arquivo inteiro para dentro do próprio shell.
meow_conf_valor() {
  local chave="$1" linha
  [ -f "$MEOW_CONF_ARQUIVO" ] || return 1
  linha="$(sed -n "s/^[[:space:]]*$chave=//p" "$MEOW_CONF_ARQUIVO" | tail -1)"
  [ -n "$linha" ] || return 1
  # Tira as aspas e o comentário de fim de linha, que é como o arquivo é escrito.
  linha="${linha%%#*}"
  linha="$(printf '%s' "$linha" | tr -d '"'"'"' \t\r')"
  printf '%s' "$linha"
}

meow_conf_diz() {
  local chave="$1" quer="$2" linha
  linha="$(meow_conf_valor "$chave")" || return 1
  [ "$linha" = "$quer" ]
}

# A QUEBRA DE LINHA DO FIM SOBREVIVE — 13/09/2026
#   O `$(cat)` come as quebras do fim e o `meow_escrever` grava com `printf '%s'`:
#   TODA gravação tirava o último `\n` do arquivo dela. Medido pelo painel: um
#   Salvar ligou os segundos do relógio, o seguinte desligou, e o md5 não voltou
#   — a única diferença era esse byte. Agora o arquivo é lido inteiro (o `x` do
#   fim segura as quebras dentro do `$(...)`), as quebras são separadas do texto
#   e voltam iguais na gravação.
#
#   A comparação "já estava assim" fica AQUI, e não no `meow_escrever`: lá ela é
#   feita contra outro `$(cat)`, que também come a quebra, e o texto com o `\n`
#   devolvido nunca bateria — cada Salvar regravaria o arquivo e contaria como
#   mudança uma chave que ficou igual.
meow_conf_definir() {
  local chave="$1" valor="$2" texto novo fim="" nl=$'\n'
  if [ -f "$MEOW_CONF_ARQUIVO" ]; then
    texto="$(cat "$MEOW_CONF_ARQUIVO"; printf x)"
    texto="${texto%x}"
    fim="${texto##*[!$nl]}"
    texto="${texto%"$fim"}"
  else
    texto="$(cat "$MEOW_CONF_PADRAO" 2>/dev/null)" || return "$MEOW_ERRO"
    fim="$nl"
  fi
  novo="$(meow_conf_texto_definir "$texto" "$chave" "$valor")"
  if [ -f "$MEOW_CONF_ARQUIVO" ] && [ "$novo" = "$texto" ]; then
    return "$MEOW_OK"
  fi
  meow_escrever "$MEOW_CONF_ARQUIVO" "$novo$fim" 644
}

# --- lock: o timer pode disparar enquanto ela roda na mão (regra 10) --------
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
# O que se baixa (papirus-folders, o tarball da Nerd Font) mora fora do repositório.
MEOW_CACHE="${MEOW_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem}"

# --- O ESTADO DO USUÁRIO SAI DO REPOSITÓRIO, E O `.padrao` FICA — 21/09/2026 -
#
# Até hoje a CURADORIA dela era gravada DENTRO do clone: `BANIDOS.txt` e
# `lado.tsv` moravam em `packs/meowsystem/wallpapers/` e eram versionados. Usar o
# painel virava commit pendente. Está medido no `git status` daquele dia: `+47`
# linhas em `BANIDOS.txt` e `-3` em `lado.tsv`, gravadas às 17h09 por ela clicar
# em "Tirar" e em "Dia"/"Noite". Ninguém programou nada.
#
# E SÃO DOIS USUÁRIOS REAIS, com três remotos entre si — `origin`, `fork` e um
# caminho local para a máquina dela. Cada `git pull` entre os dois era conflito
# de merge num arquivo que nenhum dos dois editou de propósito. O `merge=ours`
# do `.gitattributes` prometia resolver isso e não resolvia: o driver só existia
# no `.git/config` DELE, e nada no repositório o registrava — quem clonasse
# recebia a declaração sem o mecanismo, que é a pior das combinações porque
# parece protegido. Quem registra agora é a `etapa_cli` do `install.sh`, e ela é
# cinto de segurança, não a defesa principal: a defesa é este arquivo sair.
#
# O DESENHO É SEMENTE, E NÃO SOBREPOSIÇÃO
#   O `.padrao` versionado é o conteúdo de FÁBRICA, e ele é copiado para
#   `$MEOW_ESTADO` UMA vez. Não é uma camada lida por baixo do estado, e a
#   diferença está no `gravar_lado`: ele reescreve o `lado.tsv` INTEIRO a cada
#   escolha, então com sobreposição o lado que ela acabou de desfazer voltaria
#   na leitura seguinte, vindo da camada de baixo. Um desfazer que não desfaz é
#   pior que não ter o botão.
#
#   O `cmd_desbanir` NÃO SERVE DE EXEMPLO AQUI, e a versão anterior deste
#   comentário o usava como se servisse. Ele de fato reescreve o `BANIDOS.txt`
#   sem o nome (`grep -vxF`, `wallpaper.sh`), mas o desfazer não chega a
#   acontecer nem hoje, sem sobreposição nenhuma: ele copia com `cp` em vez de
#   `mv`, a imagem FICA em `banidos/`, e o `cmd_aplicar` que ele chama no fim
#   roda a `reconciliar_banidos_pasta` — que reescreve no `BANIDOS.txt` todo
#   nome presente em `banidos/` e ausente da lista. MEDIDO em 22/09/2026, em
#   acervo de brinquedo: `banir a.jpg` deixa uma ocorrência, `desbanir a.jpg`
#   imprime "devolvida" e deixa a MESMA uma ocorrência. Conferido idêntico no
#   commit anterior a esta sprint, com o `BANIDOS.txt` apontado para uma cópia:
#   a causa é ANTERIOR e não nasceu aqui.
#
#   Fica NOMEADO e não consertado, que é a regra da casa: mexer no `cmd_desbanir`
#   é escolher entre `mv` e uma exceção na reconciliação, e as duas decidem o
#   que `banidos/` significa — assunto de outra sprint, fora da tabela desta.
#
# O MARCADOR É O DIRETÓRIO, E NÃO O ARQUIVO
#   O `gravar_lado` APAGA o `lado.tsv` quando ela desfaz a última escolha —
#   "sem escolha" e "sem arquivo" são o mesmo estado, de propósito, para o
#   registro não virar uma segunda verdade que ninguém sabe apagar. Semear pela
#   ausência do ARQUIVO faria as escolhas de fábrica ressuscitarem nesse exato
#   instante, calado. Por isso quem responde "já semeei" é o DIRETÓRIO: ele
#   nasce na semeadura e não some mais.
#
# E POR ISSO A SEMEADURA É DO DIRETÓRIO INTEIRO, E NÃO DE UM ARQUIVO
#   Custou uma passagem do `tests/git-limpo.sh` para aparecer: com o diretório
#   servindo de marca, semear UM arquivo por chamada faz o segundo chamador
#   achar a pasta já de pé e não semear nada. No `wallpaper.sh` isso é literal —
#   o `LADO_TSV` resolve na linha 776 e o `BANIDOS_TXT` na 2331, e o primeiro
#   criava a pasta para o segundo. O `BANIDOS.txt` nascia SÓ com o nome que ela
#   acabara de banir, e as 231 imagens da curadoria de 24/08/2026 voltariam no
#   `semear` seguinte.
#
#   Então quem semeia varre TODO `*.padrao` da pasta de origem. Isso também
#   desarma a armadilha nº 3 do projeto (toda lista fixa é uma lista que alguém
#   vai esquecer): um `.padrao` novo passa a ser semeado sem ninguém precisar
#   lembrar de acrescentá-lo a uma lista aqui.
#
# O SECO NÃO SEMEIA, E A PROMESSA É MAIS FORTE QUE A CONVENIÊNCIA
#   A primeira versão disto semeava mesmo sob `--seco`, com o argumento de que
#   `$MEOW_ESTADO` é a nossa casa e não a máquina dela. O `tests/seco.sh`
#   reprovou na hora, e está certo: o contrato dele é "o seco não escreve NADA
#   fora do próprio lock", e é a única promessa que o README faz sobre
#   auditoria. Promessa com exceção não é promessa — a exceção é o que a próxima
#   pessoa copia.
#
#   O QUE SE PERDE, DITO EM VOZ ALTA: numa máquina onde o instalador nunca
#   rodou de verdade, um `--conferir` lê um estado que ainda não existe e
#   enxerga a lista de banidos vazia. É o único caso, ele some na primeira
#   passagem não-seca, e o `esta_banida` tem a pasta `banidos/` como primeira
#   defesa de qualquer jeito. O caminho devolvido continua sendo o do ESTADO,
#   e não o da semente, porque é ele que as mensagens de prévia nomeiam: um
#   `meow_muda` dizendo "entraria em BANIDOS.txt.padrao" apontaria para um
#   arquivo em que nada nunca vai ser escrito.
#
# O ARQUIVO ANTIGO, DE DENTRO DO CLONE, VENCE O `.padrao` NA SEMEADURA
#   Quem já usava o projeto tem, no clone, um `BANIDOS.txt` mais rico que o de
#   fábrica — no dele eram 47 linhas a mais que o commit, gravadas pelo painel e
#   nunca commitadas. Semear do `.padrao` ignorando esse arquivo apagaria a
#   curadoria dele no dia da migração, e apagaria calado, que é o jeito de
#   apagar do qual não se volta. Enquanto o arquivo velho estiver lá, é ELE a
#   semente; o `.padrao` atende quem clona hoje. A conta se fecha sozinha: o
#   `.gitignore` barra o arquivo velho, ele nunca mais é recriado, e quem apagar
#   o dele à mão passa a cair no `.padrao` como qualquer clone novo.
#
#   O "ENQUANTO ESTIVER LÁ" TEM PRAZO, E O PRAZO É O `git pull` DA MIGRAÇÃO.
#   Medido em 22/09/2026: com a curadoria não commitada o merge RECUSA e o pull
#   não completa; com ela commitada ou descartada, o git APAGA o arquivo antigo
#   do disco. Ou seja, esta função só alcança o arquivo velho se rodar ANTES do
#   pull — e é por isso que a `etapa_cli` a chama em toda passagem, em vez de
#   deixar para a primeira escrita do painel. Os três caminhos estão medidos um
#   a um no bloco da curadoria em `.gitignore`.
#
# A ORIGEM É SEMPRE `assets/<pasta>` e o destino `$MEOW_ESTADO/<pasta>`: um
# acervo do repositório tem um espelho de estado com o mesmo nome, e não há
# terceiro caminho a inventar. Dois argumentos em vez de quatro, e nenhuma
# chamada que possa cruzar as pastas por engano.
#
# O VERBO QUE SÓ LÊ NÃO SEMEIA — 15/10/2026, P82 (item 34). A semeadura
#   acontecia na primeira LEITURA, e o `meow wallpaper` sem argumento (o
#   «O carrossel agora» do painel, que só mostra) criava a pasta de estado de
#   quem nunca escreveu nada. Com `MEOW_ESTADO_SO_LE=1` (o script põe no verbo
#   que só lê) nada é criado, e sem o arquivo de estado o caminho devolvido é o
#   da SEMENTE — o arquivo velho do clone ou o `.padrao`, na mesma ordem da
#   semeadura —, que é o que o estado teria. Quem lê lê o mesmo que leria
#   depois de semear; quem escreve semeia antes, como sempre.
#
# Uso:  caminho="$(meow_estado_com_padrao papeis-de-parede BANIDOS.txt)"
meow_estado_com_padrao() {
  local pasta="$1" arquivo="$2" origem="$MEOW_RAIZ/assets/$1" dir="$MEOW_ESTADO/$1"
  # A semente dos papéis de parede é a curadoria do pack-base.
  [ "$pasta" = "papeis-de-parede" ] && origem="$MEOW_RAIZ/packs/meowsystem/wallpapers"
  local padrao semente
  if [ "${MEOW_ESTADO_SO_LE:-0}" = "1" ] && [ ! -f "$dir/$arquivo" ]; then
    if [ -f "$origem/$arquivo" ]; then printf '%s' "$origem/$arquivo"
    elif [ -f "$origem/$arquivo.padrao" ]; then printf '%s' "$origem/$arquivo.padrao"
    else printf '%s' "$dir/$arquivo"; fi
    return 0
  fi
  if [ ! -d "$dir" ] && ! meow_seco; then
    # Se o `mkdir` falhar, ecoamos o caminho do estado do mesmo jeito: quem
    # chamou trata "não consegui escrever" como sempre tratou, e devolver vazio
    # aqui faria o chamador operar sobre o caminho "" sem entender por quê.
    if mkdir -p "$dir" 2>/dev/null; then
      for padrao in "$origem"/*.padrao; do
        [ -f "$padrao" ] || continue          # a pasta sem nenhum `.padrao`
        semente="${padrao%.padrao}"           # o arquivo velho, de dentro do clone
        [ -f "$semente" ] || semente="$padrao"
        cp -p -- "$semente" "$dir/$(basename "${padrao%.padrao}")" 2>/dev/null
      done
    fi
  fi
  printf '%s' "$dir/$arquivo"
}

# --- UMA PASSAGEM, UMA PASTA DE BACKUP --------------------------------------
# Quatro arquivos LIAM `MEOW_CARIMBO` (`hicolor.sh` e os módulos do VS Code, do
# btop/bat e dos toolkits), todos com o mesmo `${MEOW_CARIMBO:-$(date ...)}` —
# e NINGUÉM o definia. Cada um calculava o próprio `date`, então uma passagem do
# `install.sh` que cruzasse a virada do segundo rachava os backups em duas
# pastas. Está no disco: `backups/2026-08-04T20-14-44` (Qt) e
# `backups/2026-08-04T20-17-02` (obsidian), mesma execução.
#
# `export` é o ponto: os scripts de `scripts/` e os módulos rodam como PROCESSOS
# FILHOS e sourceiam este arquivo de novo. Sem exportar, cada um recomeçaria a
# contagem e o defeito continuaria de pé. Quem já tiver a variável (o pai)
# vence — é o `:-` fazendo o trabalho.
#
# O `aplicar_tema.sh` fica de fora de propósito: ele nem sourceia este arquivo,
# usa o prefixo `<ISO>-tema-<nome>` e poda só o que casa com esse prefixo.
export MEOW_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
# --- a trava, e o vazamento de descritor que ela sofre ----------------------
# `exec {MEOW_FD}>arquivo` NÃO marca o descritor como close-on-exec — medido no
# bash 5.2.21 desta máquina em 10/08/2026: um filho lançado enquanto a trava
# está de pé aparece com o mesmo `lock` em `/proc/<pid>/fd`. Enquanto esse filho
# viver, o `flock` continua tomado, mesmo com o `meow` que o criou já morto há
# muito tempo.
#
# NÃO É TEÓRICO: naquele dia o `meow apps aplicar spotify` deixou o descritor
# vazar para o próprio Spotify. O app ficou aberto, e a partir daí TODO comando
# do projeto — inclusive o `install.sh` — recusava rodar dizendo "outro meow
# está rodando". A mensagem era falsa e, pior, não dava o que fazer: não havia
# outro meow, havia um tocador de música segurando um cadeado.
#
# Bash puro não tem como marcar FD_CLOEXEC, então a trava não some — o que dá
# para fazer, e é o que se faz aqui, é PARAR DE MENTIR sobre ela. Quando o lock
# está tomado, olha-se quem o segura de verdade e diz-se o nome do processo. Se
# não for um processo do projeto, é descritor vazado: o texto passa a explicar
# isso e a oferecer a saída (fechar aquele app, ou soltar o cadeado à força).
#
# Quem lança app de vida longa a partir de um módulo deve fechar o descritor no
# filho — a forma é acrescentar `{MEOW_FD}>&-` ao comando (conferido: com isso o
# filho não herda).
meow_travar() {
  mkdir -p "$MEOW_ESTADO"
  local lock="$MEOW_ESTADO/lock"
  exec {MEOW_FD}>"$lock" || return "$MEOW_ERRO"
  flock -n "$MEOW_FD" && return 0

  # Quem está de fato com o arquivo aberto. O `fuser` é o único que enxerga
  # descritor herdado; um arquivo de PID não veria nada, porque o dono original
  # já morreu.
  # O `$$` sai da lista: nós mesmos acabamos de abrir o arquivo duas linhas
  # acima, e sem esta exclusão o próprio script apareceria como "bash(...)" —
  # casaria com o caso legítimo logo abaixo e esconderia o verdadeiro culpado.
  local donos="" nomes=""
  if meow_tem fuser; then
    donos="$(fuser "$lock" 2>/dev/null | tr -s ' ')"
    for p in $donos; do
      [ "$p" = "$$" ] && continue
      [ -r "/proc/$p/comm" ] && nomes="$nomes $(cat "/proc/$p/comm" 2>/dev/null)($p)"
    done
  fi

  if [ -z "$nomes" ]; then
    meow_aviso "outro meow está rodando (lock em $lock) — saindo"
    return "$MEOW_ERRO"
  fi

  # Um processo do próprio projeto segurando o lock é o caso legítimo.
  case "$nomes" in
    *meow*|*install.sh*|*bash*|*aplicar_*|*construir_*|*icones_*)
      meow_aviso "outro meow está rodando ($nomes) — saindo"
      return "$MEOW_ERRO" ;;
  esac

  meow_erro "o cadeado está preso em:$nomes"
  meow_aviso "isso não é outro meow — é descritor vazado. Um módulo lançou esse"
  meow_aviso "app enquanto a trava estava de pé, e ele levou o cadeado junto."
  meow_aviso "saídas: feche o app acima, ou solte à força com"
  meow_aviso "  flock -u \"$lock\" true  &&  rm -f \"$lock\""
  return "$MEOW_ERRO"
}

# --- backup do que é do SISTEMA ---------------------------------------------
# A TRAVA 1 recusa /usr/share e está certa. Mas três scripts PRECISAM escrever
# lá: o cosmic-app-library não honra override em ~/.local/share/applications
# (bug upstream pop-os/cosmic-applets#667, medido aqui em 04/08/2026 com
# NoDisplay=true E Hidden=true e o Vim continuando no lançador), então marcar o
# arquivo que veio do apt é hoje a única coisa que esconde um app. Elas passam
# por fora de `meow_escrever` de propósito, e por isso a cópia de segurança tem
# de ser explícita: `dpkg -V nvidia-settings` já acusa `??5??????` nesta máquina,
# e não havia backup nenhum para devolver.
#
# O destino ESPELHA o caminho absoluto — sem isso, `meow desfazer --lancador`
# teria de adivinhar de onde cada arquivo veio.
meow_backup_sistema() {
  local arq="$1"
  local dir="$MEOW_ESTADO/backups/$MEOW_CARIMBO-sistema"
  local dest="$dir${arq}"
  [ -f "$arq" ] || return 0
  [ -f "$dest" ] && return 0          # já guardado nesta rodada
  mkdir -p "$(dirname "$dest")" 2>/dev/null || return "$MEOW_ERRO"
  # tolerar falha em vez de derrubar a etapa: ela é opcional, o backup não pode
  # ser o motivo de o lançador não ser vestido — mas sem ele não escrevemos.
  cp -a "$arq" "$dest" 2>/dev/null || return "$MEOW_ERRO"
  return 0
}

# --- MANIFESTO: o que este projeto pôs no disco -----------------------------
# Sem ele, desinstalar seria uma SEGUNDA lista, escrita à mão, que envelheceria
# em silêncio a cada etapa nova. Quem preenche é a própria `meow_escrever`, no
# único ponto por onde toda escrita de configuração passa.
#
# O sha256 é o que permite ao `--uninstall` PULAR um arquivo que a pessoa passou
# a manter à mão depois — remover o que ela editou seria apagar trabalho dela.
MEOW_MANIFESTO="$MEOW_ESTADO/manifesto.tsv"
meow_manifesto_registrar() {
  local alvo="$1" sha
  meow_seco && return 0
  [ -f "$alvo" ] || return 0
  sha="$(sha256sum -- "$alvo" 2>/dev/null | cut -d' ' -f1)"
  mkdir -p "$MEOW_ESTADO" || return 0
  # Uma linha por caminho: a antiga sai antes de a nova entrar. O filtro é `awk`
  # comparando o CAMPO inteiro, e não `grep "^$alvo"`, porque caminho é texto
  # cheio de `.`, `+` e `[` — num grep isso é expressão regular, e
  # `~/.config/a.conf` casaria com `~/aXconf`.
  if [ -f "$MEOW_MANIFESTO" ]; then
    awk -F'\t' -v a="$alvo" '$1 != a' "$MEOW_MANIFESTO" > "$MEOW_MANIFESTO.tmp" 2>/dev/null \
      && mv -f "$MEOW_MANIFESTO.tmp" "$MEOW_MANIFESTO" 2>/dev/null
    rm -f "$MEOW_MANIFESTO.tmp" 2>/dev/null
  fi
  printf '%s\t%s\t%s\n' "$alvo" "$(date -Iseconds)" "${sha:--}" >> "$MEOW_MANIFESTO"
  return 0
}

# --- log e notificação: as duas OUTRAS escritas, e o seco vale para elas -----
# `MEOW_DRY_RUN=1` promete não escrever nada. A promessa costuma ser lida como
# "não escreve CONFIGURAÇÃO", e é aí que ela vaza — o log é um arquivo, e a
# notificação é uma frase na tela dela.
#
# MEDIDO em 2026-08-04, com md5 antes e depois: `MEOW_DRY_RUN=1 ./install.sh`
# acrescentava `install.sh feitos=12 pulados=0 falhos=0` ao `meow.log`. E o
# `etapa_icones`/`etapa_wallpaper` do install.sh disparam `meow_notificar`
# quando o script chamado devolve 1 — que é EXATAMENTE o que ele devolve no
# seco, sem ter escrito nada. Ou seja: numa máquina com o tema divergente, uma
# auditoria em seco pendurava na TV dela um "Ícones e logo atualizados" falso.
#
# A guarda mora aqui, e não em cada chamador, porque o chamador que esquecer é
# justamente o que ninguém vai reler. Quem quiser registrar apesar do seco
# escreve no arquivo por conta própria — e aí a decisão está à vista.
meow_registrar() {
  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO"
  printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$MEOW_ESTADO/meow.log"
}

# --- A PENDÊNCIA ACIONÁVEL: a etapa que sabe o conserto não manda consertar ---
#
# POR QUE ISTO EXISTE [2026-09-22]
#   Ele mediu a mesma falha seis vezes, em seis arquivos diferentes: o programa
#   descobre o problema, SABE o conserto, e imprime a receita de terminal para
#   a pessoa rodar. "Um engenheiro lê isso como cortesia; um designer leigo lê
#   como «o programa desistiu»." As seis estão listadas na sprint P2 de
#   21/09/2026 (docs/sprints/2026-09-21-de-tema-a-produto.md).
#
#   A regra que entra com esta função, e que vale para toda etapa futura:
#
#     Uma etapa que sabe o conserto ou FAZ, ou oferece UM BOTÃO que faz.
#     Quando nem o botão é possível — porque o que falta é decisão humana
#     genuína —, a mensagem diz A DECISÃO, não a receita.
#
# AS DUAS SAÍDAS DESTA FUNÇÃO, E ELAS SÃO DE PROPÓSITO
#   `<comando>` CHEIO  a pendência tem conserto conhecido. O log diz a frase e
#                      o comando; o painel desenha um botão "Resolver".
#   `<comando>` VAZIO  a pendência tem origem conhecida e NENHUM conserto que
#                      este projeto alcance (o script que resolveria mora em
#                      outra máquina, ou o que falta é uma escolha dela). O log
#                      diz a decisão; o painel desenha a linha SEM botão.
#                      Inventar um botão que não resolve é pior que não ter
#                      botão: ele promete e some.
#
# O TSV É ESTADO, E ESTADO SE APAGA QUANDO DEIXA DE SER VERDADE
#   Por isso a função tem uma irmã, `meow_pendencia_resolvida`, e quem registra
#   é obrigado a chamá-la no caminho feliz. Uma lista de pendências que só
#   cresce vira a caixa de entrada que ninguém lê — o mesmo defeito do doctor
#   que nunca fica verde, e que a P22 acabou de consertar do outro lado.
#
# UMA LINHA POR ID: a nova substitui a velha, pelo mesmo `awk -F'\t'` de campo
# inteiro que o `meow_manifesto_registrar` usa logo acima. `grep "^$id"` seria
# expressão regular sobre um identificador, e um `.` no id casaria o vizinho.
#
# O CAMINHO SE RESOLVE NA HORA DA CHAMADA, E ISSO É O CONSERTO DE 22/09/2026
#   Até esta revisão o arquivo era fixado aqui, no `source`. Quem quisesse rodar
#   uma DETECÇÃO sem sujar o estado da máquina — um teste, ou a tabela do
#   `meow apps`, que se anuncia como leitura — não tinha como: mover
#   `MEOW_ESTADO` não movia isto, porque isto já tinha sido calculado.
#
#   Medido nesta máquina: `./tests/reversao.sh` roda o `meow_app_detectar` de
#   todo módulo de verdade, e desde que o `detectar` do Spotify registra
#   pendência (a própria P2), a suíte passou a escrever
#   `~/.local/state/meowsystem/pendencias.tsv` no HOME real de quem roda o
#   teste. É a mesma classe de defeito que o `flatpak info` e o `gsettings get`
#   já custaram a este projeto: DETECÇÃO COM EFEITO COLATERAL.
#
#   Agora quem só olha aponta `MEOW_ESTADO` para um diretório descartável e
#   pronto — sem variável nova, sem modo novo, e sem que o `detectar` precise
#   saber quem o chamou. `MEOW_PENDENCIAS` fica como o nome público do arquivo
#   (é ele que o `app/servidor.py` lê do outro lado).
MEOW_PENDENCIAS="$MEOW_ESTADO/pendencias.tsv"

_meow_pendencias_arquivo() { printf '%s/pendencias.tsv' "$MEOW_ESTADO"; }

_meow_pendencia_tirar() {
  local id="$1" arq
  arq="$(_meow_pendencias_arquivo)"
  [ -f "$arq" ] || return 0
  awk -F'\t' -v a="$id" '$1 != a' "$arq" > "$arq.tmp" 2>/dev/null \
    && mv -f "$arq.tmp" "$arq" 2>/dev/null
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

# ONDE, NO PAINEL, MORA O BOTÃO QUE FAZ ISTO — 24/09/2026, sprint P50
#   Imprime «rótulo», na aba Grupo — de uma ação do painel, ou da ação de uma
#   pendência —, e sai 1 (sem imprimir nada) quando não há botão com cartão.
#   Quem sabe o nome do botão e a aba dele é a tabela `ACOES` do
#   `app/servidor.py`, e é a ela que se pergunta: nome de tela escrito à mão
#   num script é o que deixou a conferência mandando a uma aba «Instalar e
#   conferir» dezoito dias depois de ela virar «Instalação» (achado 47). Sem
#   python3 ou sem o painel no clone, a resposta é vazia, e a frase que a usaria
#   simplesmente não cita tela nenhuma — melhor que citar a errada.
#   DESDE A P57 (24/09/2026) ELA RESPONDE TAMBÉM CARTÃO E ABA: uma chave do
#   meow.conf dá «título do cartão», na aba Seção, e `inicio` dá a aba que abre
#   o painel — as duas frases que o `install.sh` ainda escrevia à mão.
meow_onde_no_painel() {
  local servidor="$MEOW_RAIZ/app/servidor.py"
  [ -f "$servidor" ] && command -v python3 >/dev/null 2>&1 || return 1
  MEOW_RAIZ="$MEOW_RAIZ" python3 "$servidor" --onde "$1" 2>/dev/null
}

# A ETAPA SAI DO ARQUIVO QUE CHAMOU, e não de um argumento a mais: um argumento
# é uma string que alguém digita errado uma vez e ninguém confere depois. O
# `BASH_SOURCE[1]` é o estado real de quem chamou — a mesma disciplina que o
# resto do projeto aplica a monitor, biblioteca de jogos e vizinho.
meow_pendencia_acionavel() {
  local id="$1" frase="$2" comando="${3:-}"
  local etapa; etapa="$(basename "${BASH_SOURCE[1]:-desconhecida}")"

  # A PENDÊNCIA DE UM OPCIONAL NÃO AVISA — 15/10/2026, P82 (item 2). O `!!`
  #   pesa no veredito do doctor (`pulado_com_aviso`). Quem oferece um botão
  #   para o que é opcional (o starship) chama com `MEOW_PENDENCIA_ROTINA=1`,
  #   e a linha sai como o pulado de rotina; o botão continua na Início.
  if [ "${MEOW_PENDENCIA_ROTINA:-}" = "1" ]; then meow_pula "$frase"; else meow_aviso "$frase"; fi
  # O BOTÃO CITADO É O QUE EXISTE, NA ABA EM QUE ELE ESTÁ — P50 (achado 32).
  #   Dizia "(ou o botão «Resolver» no painel)": na gaveta de «Gravar as
  #   áreas» não há «Resolver» nenhum, e a pendência sem ação na tabela
  #   `ACAO_DA_PENDENCIA` do servidor não ganha «Resolver» em lugar nenhum.
  #   Agora quem nomeia é o `meow_onde_no_painel`, e sem botão a frase não
  #   promete botão.
  # [O COMANDO SAI QUANDO HÁ BOTÃO — 10/10/2026, P80 (item 8). A linha era
  #   «resolve: <comando>  (ou, no painel, «X»)»: dentro da gaveta do painel,
  #   a tela mandando digitar o que um botão faz. Com botão, a linha diz só o
  #   botão; o comando fica no TSV, que é de onde o botão sabe o que rodar, e
  #   na linha só quando não há botão nenhum (um terminal sem o painel).]
  if [ -n "$comando" ]; then
    local onde; onde="$(meow_onde_no_painel "$id")"
    if [ -n "$onde" ]; then
      meow_info "resolve: no painel, $onde"
    else
      meow_info "resolve: $comando"
    fi
  fi

  # O seco não escreve o TSV pelo mesmo motivo que não escreve o meow.log: ele
  # promete não tocar em arquivo nenhum, e uma pendência gravada por uma
  # auditoria em seco apareceria na Home dela sem que nada tivesse rodado.
  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO" || return 0
  _meow_pendencia_tirar "$id"
  # Tabulação e quebra de linha são os dois bytes que quebrariam o TSV, e a
  # frase vem de código nosso — então a defesa é barata e fica aqui, no único
  # ponto por onde toda pendência passa.
  frase="${frase//$'\t'/ }"; frase="${frase//$'\n'/ }"
  comando="${comando//$'\t'/ }"; comando="${comando//$'\n'/ }"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$etapa" "$frase" "$comando" "$(date -Iseconds)" >> "$(_meow_pendencias_arquivo)"
  return 0
}

# A irmã. Chamada no caminho feliz de quem registrou — sem ela a linha fica na
# Home depois de o problema ter sumido, que é a mentira que a P3 desta mesma
# leva persegue.
meow_pendencia_resolvida() {
  meow_seco && return 0
  _meow_pendencia_tirar "$1"
}

# --- PRECISA DE GENTE: o que a máquina não conserta sozinha, num lugar só (P86) ---
#   `precisa-de-gente.tsv`, uma linha por id: id, nome curto, desde quando, porquê.
#   A Início desenha UM cartão com essas linhas; o porquê vai para a dica.
#   O `desde` é do PRIMEIRO registro do id e sobrevive a medidas novas do mesmo
#   problema. Repetir o registro idêntico não escreve nada. O dono do problema
#   chama a irmã `_resolvida` quando ele some, e a linha sai.
_meow_gente_arquivo() { printf '%s/precisa-de-gente.tsv' "$MEOW_ESTADO"; }

meow_precisa_de_gente() { # $1 id · $2 nome curto · $3 porquê
  local id="$1" nome="$2" porque="$3" arq desde igual
  meow_seco && return 0
  nome="${nome//$'\t'/ }"; nome="${nome//$'\n'/ }"
  porque="${porque//$'\t'/ }"; porque="${porque//$'\n'/ }"
  arq="$(_meow_gente_arquivo)"
  mkdir -p "$MEOW_ESTADO" || return 0
  desde="$(awk -F'\t' -v a="$id" '$1 == a {print $3; exit}' "$arq" 2>/dev/null)"
  igual="$(awk -F'\t' -v a="$id" -v n="$nome" -v p="$porque" '$1 == a && $2 == n && $4 == p {print "s"; exit}' "$arq" 2>/dev/null)"
  [ "$igual" = "s" ] && return 0
  [ -n "$desde" ] || desde="$(date -Iseconds)"
  { awk -F'\t' -v a="$id" '$1 != a' "$arq" 2>/dev/null
    printf '%s\t%s\t%s\t%s\n' "$id" "$nome" "$desde" "$porque"; } > "$arq.tmp" \
    && mv -f "$arq.tmp" "$arq"
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

meow_precisa_de_gente_resolvida() { # $1 id
  local arq; arq="$(_meow_gente_arquivo)"
  meow_seco && return 0
  [ -f "$arq" ] || return 0
  awk -F'\t' -v a="$1" '$1 == a {achou = 1} END {exit !achou}' "$arq" || return 0
  awk -F'\t' -v a="$1" '$1 != a' "$arq" > "$arq.tmp" && mv -f "$arq.tmp" "$arq"
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

meow_tem() { command -v "$1" >/dev/null 2>&1; }

# O RUST, QUANDO FALTA — a regra do applet de leitura (P80), que o de mídia
# passou a usar também (P82, 15/10/2026). Devolve 0 com o `cargo` no PATH.
# O rustup na casa de quem usa (`~/.cargo`), sem sudo e sem mexer no PATH do
# shell dela: é o caminho que o próprio projeto do rust recomenda, e o cargo
# do apt costuma ser velho demais para o libcosmic. Baixa da internet — por
# isso só no conserto e no instalador, que já declaram rede (decisão 7).
meow_garantir_cargo() {
  meow_tem cargo && return 0
  if [ -x "$HOME/.cargo/bin/cargo" ]; then PATH="$HOME/.cargo/bin:$PATH"; return 0; fi
  meow_seco && { meow_muda "instalaria o rust pelo rustup, em ~/.cargo (baixa da internet)"; return 1; }
  meow_tem curl || return 1
  local instalador
  instalador="$(mktemp)" || return 1
  meow_info "instalando o rust pelo rustup, em ~/.cargo (baixa da internet)"
  if curl --proto '=https' --tlsv1.2 -sSf --max-time 120 https://sh.rustup.rs -o "$instalador" \
     && sh "$instalador" -y --profile minimal --no-modify-path >/dev/null 2>&1; then
    rm -f "$instalador"
    PATH="$HOME/.cargo/bin:$PATH"
    meow_tem cargo
    return $?
  fi
  rm -f "$instalador"
  return 1
}

# Um flatpak instalado deixa DIRETÓRIO no disco; `flatpak info` deixa um repo
# ostree INTEIRO em ~/.local/share/flatpak/repo só por ter sido perguntado
# (medido em HOME virgem, 10/08/2026). Detecção com efeito colateral é o mesmo
# vazamento que o `meow_registrar` acima já teve de tapar: `MEOW_DRY_RUN=1`
# promete não escrever nada, e perguntar não pode ser escrever.
#
# INSTALADO É A IMPLANTAÇÃO, E NÃO A PASTA DE DADOS — 24/09/2026, sprint P57
#   Esta função cobria também "o dado por app em ~/.var/app", e era o defeito:
#   `~/.var/app/<id>` é onde o app guarda os DADOS dele, e o `flatpak
#   uninstall` a deixa para trás (só o `--delete-data` a leva). Medido nesta
#   máquina: o `org.mozilla.thunderbird_esr` tem pasta ali, não está no
#   `flatpak list`, e esta função dizia 0. Desde a P49 ela é a regra ÚNICA de
#   "instalado" — a tabela do `meow apps` e os módulos perguntam aqui —, então o
#   falso positivo saía nos dois lugares.
#
#   Instalado é o que o próprio flatpak chama de implantado: `app/<id>/<arq>/
#   <ramo>/active` apontando para a pasta do commit. Só a pasta `app/<id>` não
#   basta — é a sobra de uma implantação desfeita pela metade. E as instalações
#   são as que o flatpak consulta, pelas variáveis dele (`man flatpak`,
#   ENVIRONMENT; `man flatpak-installation`): a do usuário (`FLATPAK_USER_DIR`,
#   ou `$XDG_DATA_HOME/flatpak`), a do sistema (`FLATPAK_SYSTEM_DIR`, ou
#   /var/lib/flatpak) e as que cada `.conf` de `installations.d` declara no
#   `Path=` — lidas do disco, e não escritas aqui. As variáveis são também o que
#   deixa um teste perguntar numa instalação de brinquedo.
meow_flatpak_tem() {   # 0 = instalado, 1 = não
  local id="$1" base ativo conf
  local -a bases=("${FLATPAK_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak}"
                  "${FLATPAK_SYSTEM_DIR:-/var/lib/flatpak}")
  for conf in "${FLATPAK_CONFIG_DIR:-/etc/flatpak}"/installations.d/*.conf; do
    [ -f "$conf" ] || continue
    while IFS= read -r base; do
      [ -n "$base" ] && bases+=("$base")
    done < <(sed -n 's/^[[:space:]]*Path[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$conf" 2>/dev/null)
  done
  for base in "${bases[@]}"; do
    for ativo in "$base/app/$id"/*/*/active; do
      [ -d "$ativo" ] && return 0
    done
  done
  meow_debug "flatpak '$id' sem implantação em nenhuma instalação (${bases[*]})"
  return 1
}

# --- O MENU DE LANÇAMENTO RELÊ OS ÍCONES ------------------------------------
# TRÊS CONSUMIDORES, TRÊS CACHES DIFERENTES, E É ISSO QUE FAZ "instalei e não
# apareceu" parecer defeito de instalação quando não é:
#
#   o dock / painel .... `cosmic-panel`, resolve no arranque -> `painel.sh reciclar`
#   o terminal ......... `fastfetch`, relê o arquivo a cada execução -> nada a fazer
#   o menu de lançamento `cosmic-app-library` + `cosmic-launcher`, resolvem no
#                        arranque e guardam -> é o que esta função destrava
#
# Medido em 11/08/2026: o Flatseal aparecia chapado no lançador (processo das
# 09:34) e em traço na dock (processo das 13:08) — mesmo arquivo no disco, mesmo
# tema ativo, idades de processo diferentes. Conferir por arquivo responde "está
# instalado?"; só reiniciar o consumidor responde "está na tela dela?".
#
# `pkill -x cosmic-app-library` NÃO FUNCIONA, e a razão é boba: o `comm` do
# kernel trunca em 15 caracteres, o nome tem 18, e o `-x` exige casamento
# exato. Vai de `-f`, sobre a linha de comando inteira.
#
# MATAR AQUI É SEGURO, e é a diferença para o applet do painel (que deixa buraco
# no dock quando morre sozinho): estes dois são filhos do `cosmic-session`, que
# os repõe em segundos e resolve o binário pelo PATH. A grade fecha se estiver
# aberta — por isso NUNCA chamar isto sem que algo tenha de fato mudado.
meow_lancador_reler() {
  meow_seco && return 0
  local matou=0
  # `cosmic-launcher` primeiro: é o mais barato de repor e o que ela usa por
  # atalho de teclado, então a janela de indisponibilidade fica no menor.
  # SÓ OS DESTA CASA — 24/09/2026, achado da P46. Era `pkill -f`, pelo nome, na
  #   máquina inteira: um `meow` rodado com outro HOME (a casa de brinquedo dos
  #   testes) fechava a grade da sessão de verdade. A regra é a da P44 para o
  #   painel (`meow_painel_desta_casa`, lib/painel.sh): deste usuário e deste
  #   HOME. Na sessão dela nada muda — o lançador tem o HOME dela.
  local p casa eu="${HOME%/}"
  for alvo in cosmic-launcher cosmic-app-library; do
    for p in $(pgrep -u "$(id -u)" -f "$alvo" 2>/dev/null); do
      casa="$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^HOME=//p' | head -n1)"
      [ -n "$casa" ] && [ "${casa%/}" = "$eu" ] || continue
      kill "$p" 2>/dev/null && matou=1
    done
  done
  [ "$matou" = "1" ] && meow_debug "lançador chacoalhado — o cosmic-session repõe em segundos"
  return 0
}

# --- A TELA INTEIRA RELÊ O QUE MUDOU ------------------------------------------
# 13/09/2026. Queixa dela: "as alterações que faço pela interface seja icones,
# configs e afins nada tá aplicando de verdade". Nos ícones a medição deu razão
# a ela: o `icones_apps_arcticons.sh` punha o desenho no tema e terminava com
# "os ícones novos aparecem no próximo login" — o arquivo certo no disco, e a
# dock e o menu mostrando o de antes até ela sair da sessão.
#
# Os dois consumidores que resolvem no arranque, cada um pela porta dele:
#   o dock e o painel -> `scripts/painel.sh reciclar`, a porta única, que recusa
#                        quando ninguém repõe a barra;
#   o menu            -> `meow_lancador_reler`, logo acima.
#
# SÓ DEPOIS DE ALGO TER MUDADO, pela mesma razão da função de cima: o painel
# pisca uns 2 s e a grade de aplicativos fecha se estiver aberta.
#
# E SÓ NA CASA DE VERDADE. Os testes rodam o instalador num HOME de brinquedo,
# e um reciclo dali derrubaria a barra DELA no meio de uma suíte — é a lição da
# ponte root: dar poder a um automatismo acorda os caminhos que só não faziam
# estrago por falharem. O HOME tem de ser o da conta, lido do passwd.
#
# O CÓDIGO DIZ O QUE ACONTECEU, para quem chama poder dizer a verdade na tela:
#   0  releu (ou é ensaio da CLI, que não relê nada de propósito)
#   1  o painel recusou reciclar — o menu releu, a dock fica para o login
#   3  este HOME não é o da sessão: nada foi tocado
#   4  dentro de uma passada do instalador: fica para o fim dela (abaixo)
#
# UM RELER POR PASSADA — 10/10/2026, P80 (item 7). O `icones_apps_arcticons.sh`,
#   o `icones_apps_dracula.sh` e o `icones_resgatados.sh` chamam esta função no
#   fim do passo deles, e uma instalação que mudava os três reciclava o
#   `cosmic-panel` três vezes seguidas — um reciclo do painel foi o gatilho da
#   faixa verde de 09/10 (Migração-OS/levas/leva-08-gpu-regressao.md). Agora o
#   `install.sh` arma `MEOW_RELER_NO_FIM` (um arquivo) antes do laço das
#   passagens: com ele no ambiente, o pedido só anota quem pediu e sai 4, e o
#   `meow_tela_reler_no_fim`, depois do laço, relê UMA vez. Fora do instalador
#   (o «Usar este ícone» do painel roda o passo sozinho) nada muda: relê na
#   hora. E quem pediu vai junto (`MEOW_QUEM_RECICLA`), para o `painel.sh
#   reciclar` registrar no meow.log.
meow_tela_reler() {
  meow_seco && return 0
  local lar rc=0 quem="${MEOW_QUEM_RECICLA:-$(basename "$0")}"
  if [ -n "${MEOW_RELER_NO_FIM:-}" ] && printf '%s\n' "$quem" >> "$MEOW_RELER_NO_FIM" 2>/dev/null; then
    meow_debug "a tela relê uma vez, no fim da passada (pedido de $quem)"
    return 4
  fi
  lar="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  if [ -z "$lar" ] || ! [ "$HOME" -ef "$lar" ]; then
    meow_debug "HOME ($HOME) não é o da conta — a tela não é desta sessão, nada a reler"
    return 3
  fi
  if [ -x "$MEOW_RAIZ/scripts/painel.sh" ] && pgrep -x cosmic-panel >/dev/null 2>&1; then
    if ! MEOW_QUEM_RECICLA="$quem" "$MEOW_RAIZ/scripts/painel.sh" reciclar; then
      meow_aviso "o painel recusou reciclar agora — na dock, o desenho novo aparece no próximo login"
      rc=1
    fi
  fi
  meow_lancador_reler
  return "$rc"
}

# O fim da passada: relê uma vez, se algum passo pediu, e desarma a marca —
# depois do laço, um pedido volta a reler na hora. Diz o que aconteceu, uma
# linha, no lugar das três que os passos diziam.
meow_tela_reler_no_fim() {
  local marca="${MEOW_RELER_NO_FIM:-}" quem rc=0
  [ -n "$marca" ] || return 0
  unset MEOW_RELER_NO_FIM
  if [ -s "$marca" ]; then
    quem="$(sort -u "$marca" | paste -sd, -)"
    MEOW_QUEM_RECICLA="fim da passada ($quem)" meow_tela_reler; rc=$?
    case "$rc" in
      0) meow_ok "a dock e o menu releram o que mudou ($quem)" ;;
      3) meow_info "fora da sessão gráfica: o que mudou aparece na dock e no menu no próximo login" ;;
    esac
  fi
  rm -f "$marca"
  return "$rc"
}

# Notificação: ela precisa saber quando algo mudou sozinho.
meow_notificar() {
  meow_seco && return 0
  meow_tem notify-send || return 0
  notify-send -a MeowSystem -i preferences-desktop-theme "$1" "${2:-}" 2>/dev/null || true
}

# ============================================================================
# A PONTE ROOT — 08/09/2026
# ============================================================================
# Pedido dela: *"não conseguimos de alguma forma usar sudo só na instalar e criar
# um perfil naquele conf.d ... aquele que só preciso uma vez e fica lá registrado
# pra sempre?"*
#
# `/usr/local/lib/meowsystem/ponte_root.sh` é o braço root do projeto, e
# `/etc/sudoers.d/49-meowsystem-ponte` libera os verbos DELE sem senha. Quem
# instala os dois é o `install.sh`, e é ali — uma vez — que a senha é pedida.
# O porquê do desenho está no cabeçalho da própria ponte.
#
# ESTAS DUAS FUNÇÕES SÃO A ÚNICA PORTA. Nenhum script chama a ponte pelo caminho
# cru: assim "a ponte existe?", "ela está liberada?" e "o que fazer quando não
# está" ficam escritos uma vez só, e um script novo não pode esquecer metade.
MEOW_PONTE="${MEOW_PONTE:-/usr/local/lib/meowsystem/ponte_root.sh}"

# "Dá para usar a ponte agora?" — e as DUAS metades importam. O arquivo pode
# existir sem a regra (instalação pela metade, ou `PONTE_ROOT="nao"` a caminho),
# e a regra pode existir sem o arquivo (um `rm` manual). `sudo -n` responde às
# duas de uma vez, e responde pela VERDADE do sudo, não pela nossa suposição
# sobre ele — que é a diferença entre conferir e adivinhar.
# O `$HOME` TEM DE SER O DA MÁQUINA, E ISSO CUSTOU UM ARQUIVO DE /etc
#   Em 08/09/2026, no mesmo dia em que a ponte nasceu, o `tests/convergencia.sh`
#   — que roda o instalador num HOME de brinquedo, com `env -i` — APAGOU o
#   `/etc/apt/apt.conf.d/99-meow-lancador` da máquina de verdade. O caminho é
#   este: naquele HOME não há `meow.conf`, então `LANCADOR_SISTEMA` cai no
#   padrão "nao", e a etapa do hook toma o ramo de REMOVER.
#
#   Antes da ponte isso era inofensivo: sob `env -i` o `sudo rm` falhava calado,
#   e a etapa avisava "sem sudo para remover". A ponte tornou EFETIVO um caminho
#   que só não fazia estrago porque não tinha permissão — e é esse o preço de
#   dar poder a um programa: os caminhos que falhavam por falta de permissão
#   passam a acontecer.
#
#   A cerca é comparar o `$HOME` de quem chama com o `lar` que o instalador
#   gravou como root. A ponte não consegue fazer isso sozinha: com `env_reset`,
#   o sudo troca o `HOME` pelo do usuário-alvo antes de ela nascer. Aqui, do
#   lado de cá, o `$HOME` ainda é o verdadeiro.
#
#   O `perfil` é 0644 de propósito — ele não guarda segredo nenhum, e ser
#   legível é o que permite esta conferência sem elevar nada.
#
#   O hook de apt continua funcionando: o `meow-lancador-apt.sh` roda como root
#   e a primeira coisa que ele faz é `HOME="$LAR"`, que é exatamente o `lar` do
#   perfil.
meow_ponte_viva() {
  [ -x "$MEOW_PONTE" ] || return 1
  local lar
  lar="$(sed -n 's/^lar=//p' "${MEOW_PONTE%/*}/perfil" 2>/dev/null)"
  if [ -n "$lar" ] && [ "$lar" != "${HOME:-}" ]; then
    meow_debug "ponte: \$HOME é '$HOME' e o perfil diz '$lar' — não uso a ponte daqui"
    return 1
  fi
  sudo -n "$MEOW_PONTE" estado >/dev/null 2>&1
}

# Roda um verbo pela ponte. O stdin do chamador atravessa — é por ele que o nome
# do arquivo e o conteúdo viajam, e é por isso que nenhum verbo tem argumento.
#
# Devolve 127 quando a ponte não está no ar, e esse número é escolhido: ele não
# colide com nenhum código de saída do projeto (0, 1, 2, 3), então quem chama
# consegue distinguir "a ponte recusou" de "não há ponte" e cair no caminho
# antigo — o `sudo` que pede senha — em vez de tratar as duas como erro.
meow_ponte() {
  meow_ponte_viva || return 127
  sudo -n "$MEOW_PONTE" "$1"
}

# ============================================================================
# ESCREVER `.desktop` DE SISTEMA — UM CAMINHO, QUATRO CHAMADORES
# ============================================================================
# `ocultar_apps.sh`, `nomes_apps.sh`, `icones_absolutos.sh` e o `bin/meow`
# escreviam a mesma coisa com o mesmo `sudo install`, cada um com a sua guarda.
# Desde 08/09/2026 há a ponte, e ela é a terceira forma de escrever ali — copiar
# a escolha entre as três para quatro arquivos é garantir que o quinto esqueça
# metade.
#
# A ORDEM É DELIBERADA:
#   1. o arquivo é MEU        -> escrevo direto, sem elevar nada
#   2. a ponte está no ar     -> pela ponte, sem senha (o caso normal)
#   3. o sudo está em cache   -> `sudo install`, como sempre foi
#   4. nada disso             -> 127, e quem chamou conta ao usuário
#
# O 3 continua existindo por causa da máquina que ainda não instalou a ponte —
# e do `PONTE_ROOT="nao"`, que é escolha dela. Tirar o caminho antigo faria a
# ponte deixar de ser conforto e virar requisito.

# "Dá para escrever neste `.desktop` de sistema?" — sem escrever nada.
meow_desktop_pode() {
  [ -w "$1" ] && return 0
  meow_ponte_viva && return 0
  sudo -n true 2>/dev/null
}

# meow_desktop_escrever <arquivo-alvo> <arquivo-com-o-conteudo>
meow_desktop_escrever() {
  local alvo="$1" fonte="$2" nome
  nome="${alvo##*/}"
  if [ -w "$alvo" ]; then
    install -m 644 "$fonte" "$alvo" 2>/dev/null && return 0
  fi
  # A ponte recebe o NOME e o CONTEÚDO pelo stdin, nesta ordem, porque nenhum
  # verbo dela aceita argumento — é o que deixa a regra de sudo sem curinga.
  if meow_ponte_viva; then
    { printf '%s\n' "$nome"; cat "$fonte"; } | meow_ponte desktop 2>/dev/null && return 0
  fi
  sudo install -m 644 "$fonte" "$alvo" 2>/dev/null
}

# O banco de dados do lançador, pelo caminho que estiver disponível.
meow_desktop_banco() {
  local dir="${1:-/usr/share/applications}"
  meow_tem update-desktop-database || return 0
  if [ -w "$dir" ]; then
    update-desktop-database "$dir" 2>/dev/null || true
    return 0
  fi
  if [ "$dir" = "/usr/share/applications" ] && meow_ponte_viva; then
    meow_ponte desktop-banco 2>/dev/null && return 0
  fi
  sudo -n update-desktop-database "$dir" 2>/dev/null || true
  return 0
}
