#!/usr/bin/env bash
# icones_apps_dracula.sh — instala no tema os desenhos do pack autoral Dracula.
#
# O MAPA EXISTIA E NINGUÉM O LIA — MEDIDO EM 16/09/2026
#   `assets/icones/apps-dracula.map` nasceu em 15/09 com 17 casamentos
#   app -> desenho, herdados da SPRINT 32 do `Dracula_OS-Theme`. Um `grep`
#   pelo nome do arquivo em todo o repositório devolvia UMA linha: a primeira
#   do próprio mapa. Nenhum script, nenhuma etapa, nenhum verbo.
#   O sintoma na tela: a aba «Ícones» do painel listava 44 aplicativos e seis
#   deles como "de fábrica" — entre eles o Menu Editor, o Nyx e o R, que
#   TINHAM linha no mapa. "nem aqui nossos icons aparecem" (16/09/2026).
#
# POR QUE `scalable/apps`, E POR QUE ISSO FAZ O DRACULA VENCER
#   O `48x48/apps` é `Type=Fixed` e tem dono único declarado — o
#   `icones_apps_arcticons.sh`. Escrever lá seria disputar arquivo.
#   O `scalable/apps` é `Type=Scalable` (Size=128, MinSize=8, MaxSize=512 no
#   nosso index.theme) e, pelo strace de 08/08/2026 registrado no cabeçalho do
#   `completar_icones.sh`, o resolvedor pede `scalable` no caso comum — um
#   arquivo ali VENCE o `48x48`.
#
#   E vencer é a decisão dele, de 16/09/2026, feita com os dois lados na mesa:
#   onze dos dezoito nomes já vestem Arcticons monocromático pintado pela
#   paleta, e ele escolheu "Dracula vence tudo" sabendo disso. Não é acidente
#   de precedência — é a escolha, e este parágrafo existe para que no dia em
#   que alguém estranhar a troca ela esteja escrita.
#
#   O caminho de volta é barato e não destrói nada: `ICONES_DRACULA="nao"`
#   apaga o que ESTE script pôs, por nome, lido do mesmo mapa. O Arcticons
#   continua no `48x48` o tempo todo, intacto — ele reaparece na tela sozinho.
#
# O ACERVO É LOCAL, E ISSO NÃO É DETALHE DE ARRUMAÇÃO
#   A segunda coluna do mapa apontava para dentro do `Dracula_OS-Theme`, que é
#   outro repositório e só existe na máquina dele. Um script que lesse aquilo
#   funcionaria aqui e quebraria na dela — e este projeto é puxado dos dois
#   lados. Os desenhos foram copiados para `assets/icones/dracula-apps/` e a
#   coluna passou a ser um caminho relativo a `assets/icones/`.
#
# ESTE SCRIPT NÃO PINTA NADA, E É A DIFERENÇA PARA O IRMÃO DELE
#   O `icones_apps_arcticons.sh` recolore porque o Arcticons é monocromático —
#   medido: 0 cores declaradas num `.svg` do pack. Aqui cada desenho traz de 6
#   a 10 cores próprias e já nasceu Dracula. O cabeçalho do mapa diz a frase:
#   "Recolorir pela paleta não seria aplicar o tema: seria destruir o desenho."
#   Por isso a cópia é literal — o desenho que sai do acervo é o que chega ao
#   tema, sem uma tag tocada. (Literal, e não "byte a byte": o `meow_escrever`
#   normaliza o newline final, e é por isso que o `_dracula_remover` compara do
#   mesmo jeito que escreve — ver o bloco lá embaixo.)

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# O `meow_icones_derivar` mora lá — ver o bloco "DERIVAR" daquele arquivo e o
# comentário do `_dracula_instalar` abaixo.
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ALVO="$TEMA_DIR/scalable/apps"
ICONES="$RAIZ/assets/icones"
# O acervo do Dracula virou um THEME PACK em 17/09/2026 (ver docs/PACKS.md).
# O mapa e os desenhos moveram de assets/icones/{apps-dracula.map,dracula-apps/}
# para packs/dracula/icones/{apps.map,apps/}, e os caminhos DENTRO do mapa
# passaram de `dracula-apps/x.svg` para `apps/x.svg`.
# A queda para o caminho antigo existe para quem atualizar o MeowSystem sem ter
# o pack ainda: sem ela, um `git pull` no meio da migração deixaria o dock sem
# os ícones, calado.
MAPA="$(meow_pack_arquivo icones/apps.map assets/icones/apps-dracula.map)"
# A raiz que o mapa resolve: o diretório do mapa, não uma constante. Assim o
# mesmo script serve ao pack e ao lugar antigo sem saber em qual está.
ICONES_BASE_MAPA="$(dirname "$MAPA")"

# --- o mapa -------------------------------------------------------------------
# Uma linha por ícone: `nome : caminho-relativo-a-assets/icones/`. O comentário
# depois do `#` é a procedência e não entra em nada.
#
# O `awk` corta o comentário ANTES de contar os campos: sem isso, uma linha com
# `#` no meio viraria três campos e o caminho sairia truncado no `#`.
#
# O ALVO PASSA PELO `pack.py alvo`, E É O QUE FAZ O PREFIXO `motor:` EXISTIR
#   [22/09/2026] Um mapa de pack diz *"o Telegram veste o desenho X"* — decisão
#   de TEMA, e por isso a linha mora no pack. Mas o desenho X pode vir do acervo
#   Arcticons: 113 SVG de terceiro, base de conversão, ferramenta compartilhada
#   que não muda quando se troca de pack. Sem prefixo só havia duas saídas, e as
#   duas eram ruins: ou a decisão fica em `assets/` (e trocar de pack não troca
#   a escolha), ou cada pack carrega uma CÓPIA dos 113 — e a segunda cópia
#   defasa da primeira calado.
#
#     org.telegram.desktop          : motor:arcticons/telegram.svg
#     io.github.flattool.Warehouse  : apps/Warehouse.svg
#
#   O `packs/dracula/icones/apps.map` de hoje NÃO usa o prefixo: os dezoito
#   apontam para `apps/`, dentro do pack. Ele entra aqui porque é o resolvedor
#   que a P27 pede, e porque um mapa que o use precisa achar quem o entenda no
#   dia em que for escrito — não depois.
#
# EM LOTE, E O MOTIVO FOI MEDIDO
#   Uma chamada de `python3` por linha custou 1,1 s para as dezoito deste mapa,
#   e este laço roda dentro do `meow doctor` — o comando das 5h. Um mapa de cem
#   aplicativos custaria seis segundos, e a regressão apareceria como "o doctor
#   ficou lento", longe da causa. O `alvo` lê o STDIN inteiro e devolve UMA
#   linha por linha de entrada, então o mapa custa uma partida só.
#
#   O `paste` depende desse alinhamento: uma linha a mais ou a menos vestiria
#   cada aplicativo com o ícone do vizinho, sem erro nenhum na tela. Por isso a
#   linha recusada volta VAZIA em vez de voltar fora — e vazia não casa com
#   arquivo nenhum, caindo no aviso "no mapa mas sem desenho no disco" que o
#   `_dracula_instalar` já tem.
_dracula_pares() {
  [ -f "$MAPA" ] || return 1
  local cru
  # O CAMINHO É TUDO DEPOIS DO PRIMEIRO `:`, E NÃO O CAMPO 2 — 22/09/2026
  #   Era `caminho=$2`, e com `-F:` isso significa "até o PRÓXIMO dois-pontos".
  #   A linha que esta sprint dá como exemplo tem dois:
  #
  #       org.telegram.desktop : motor:arcticons/telegram.svg
  #
  #   São três campos para o `awk`, e `$2` valia ` motor` — o alvo resolvido
  #   virava `<pack>/icones/motor`, um diretório. Medido antes do conserto: a
  #   saída era `org.telegram.desktop<TAB>motor`, e o recurso inteiro que a P27
  #   veio entregar ficava inerte no único ponto de integração que existe. Pior:
  #   o `pack.py alvo` nunca via o prefixo, então a guarda de caminho dele não
  #   recusava `motor:../../../etc/passwd` — ela recusa `motor:`, e o que
  #   chegava lá era `motor`.
  #
  #   É o MESMO defeito que o parágrafo acima já contava ter previsto para o
  #   `#`: "uma linha com `#` no meio viraria três campos e o caminho sairia
  #   truncado no `#`". A previsão estava certa e o remédio só cobriu metade dos
  #   casos — o `sed` corta o comentário, mas o prefixo do próprio formato de
  #   mapa continuava partindo a linha. `substr` a partir do primeiro `:` não
  #   conta campos: ele diz "nome é o que vem antes, caminho é o resto", que é o
  #   formato escrito em docs/PACKS.md.
  cru="$(sed -e 's/#.*//' "$MAPA" | awk -F: '
    NF>=2 {
      nome=$1; caminho=substr($0, index($0, ":") + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", nome)
      gsub(/^[ \t]+|[ \t]+$/, "", caminho)
      if (nome != "" && caminho != "") print nome "\t" caminho
    }')"
  [ -n "$cru" ] || return 0
  paste <(printf '%s\n' "$cru" | cut -f1) \
        <(printf '%s\n' "$cru" | cut -f2 \
            | python3 "$RAIZ/scripts/pack.py" alvo "$ICONES_BASE_MAPA")
}

# --- instalar -----------------------------------------------------------------
_dracula_instalar() {
  local rc=0 nome caminho origem
  local postos=0 faltando=()

  while IFS=$'\t' read -r nome caminho; do
    [ -n "$nome" ] || continue
    # JÁ VEM RESOLVIDO do `_dracula_pares`, desde 22/09/2026. Era
    # `"$ICONES_BASE_MAPA/$caminho"` aqui e de novo no `_dracula_remover` — duas
    # junções da mesma coisa, e o prefixo `motor:` teria de ser entendido nas
    # duas. Uma delas esqueceria, e o ramo que apaga passaria a não reconhecer
    # como "nosso" o arquivo que o ramo que instala pôs lá: o desligar deixaria
    # ícone para trás, calado. Quem junta agora é o `pack.py alvo`, uma vez só.
    origem="$caminho"
    if [ ! -f "$origem" ]; then
      # Nome no mapa sem desenho no disco: é falha de quem editou o mapa, e
      # dizer QUAL é vale mais que um total. Não aborta — os outros dezessete
      # não têm culpa de um caminho digitado errado.
      faltando+=("$nome -> $caminho"); continue
    fi
    # O QUE VAI PARA O TEMA É O QUE O `derivar` DIZ — 23/09/2026, P28
    #   Era `meow_escrever "$ALVO/$nome.svg" "$(cat "$origem")"` aqui, e o
    #   `meow icones fonte` precisaria repetir a mesma conta para dizer o que
    #   deriva de cada desenho. Duas contas da mesma coisa divergem na primeira
    #   vez que uma mudar. Agora as duas perguntam ao `lib/icones.sh`. O byte
    #   que chega ao tema é o mesmo de antes: o vetor, como está, em
    #   `scalable/apps/<nome>.svg` — e é esse o endereço que o
    #   `_dracula_remover` confere lá embaixo.
    meow_icones_derivar "$origem" "$nome" "$TEMA_DIR"
    case $? in
      0) : ;;
      1) postos=$((postos+1)) ;;
      *) rc=2 ;;
    esac
  done < <(_dracula_pares)

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_aviso "no mapa mas sem desenho no disco: ${faltando[*]}"
    [ "$rc" = "0" ] && rc=1
  fi

  local rc_c; _dracula_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1

  if [ "$postos" -gt 0 ]; then
    meow_ok "$postos desenho(s) do pack Dracula no tema"
    _dracula_avisar
    rc=1
  elif [ "$rc" = "0" ]; then
    # UMA LINHA MESMO QUANDO NADA MUDA, e o motivo é a tela do doctor: um `chk_`
    # que devolve 0 e não escreve nada vira `ok dracula` seguido de vazio, ao
    # lado de vizinhos que dizem o que conferiram ("47 aplicativo(s) já vestidos
    # em traço"). Silêncio ali não é economia — é um check que não diz o que
    # checou.
    local par; par="$(_dracula_estado)"
    meow_ok "pack Dracula: ${par% *} de ${par#* } no tema"
  fi
  return "$rc"
}

# --- remover ------------------------------------------------------------------
# Por NOME, lido do MESMO mapa que a instalação lê. Uma varredura de órfãos em
# `scalable/apps` apagaria arquivo dos outros três donos do diretório (o
# `completar_icones.sh`, o `icones_resgatados.sh` e o `logo.sh`).
#
# E SÓ APAGA O QUE É NOSSO, CONFERINDO O CONTEÚDO: se o arquivo que está lá não
# for o desenho do acervo, ele é de outro dono (ou foi editado à mão) e fica.
# Apagar por nome sem olhar o conteúdo é como se perde o trabalho de outra
# pessoa sem nada na tela dizendo que se perdeu.
#
# A COMPARAÇÃO É `$(cat)` DOS DOIS LADOS, E NÃO `cmp` — 16/09/2026
#   Com `cmp` este ramo errava 7 dos 18: o `meow_escrever` recebe o conteúdo por
#   `$(cat "$origem")`, e o `$(...)` do shell come o `\n` final. O arquivo
#   instalado sai um byte mais curto que a origem SEMPRE que a origem termina em
#   newline — sete dos dezoito, incluindo steam, telegram e a câmera. O `cmp`
#   dizia "difere", o desligar os preservava, e `ICONES_DRACULA="nao"` deixava
#   sete ícones na tela sem nada avisando.
#   Comparar do mesmo jeito que se escreve é a única forma de as duas metades
#   deste script concordarem sobre o que é "o nosso arquivo".
_dracula_remover() {
  local rc=0 tirados=0 nome caminho origem
  while IFS=$'\t' read -r nome caminho; do
    [ -n "$nome" ] || continue
    [ -f "$ALVO/$nome.svg" ] || continue
    # JÁ VEM RESOLVIDO do `_dracula_pares` — ver o comentário gêmeo no
    # `_dracula_instalar`. As duas metades deste script PRECISAM resolver o alvo
    # do mesmo jeito: é comparando o conteúdo da origem com o que está no tema
    # que o `_dracula_remover` decide se o arquivo é nosso.
    origem="$caminho"
    # SEM ORIGEM NÃO SE PROVA POSSE, E SEM PROVA NÃO SE APAGA — 22/09/2026
    #   Era `[ -f "$origem" ] && [ conteúdo difere ]` numa condição só: com a
    #   origem ausente o `&&` curto-circuitava, o `continue` não acontecia, e o
    #   fluxo caía direto no `rm -f` lá embaixo. A guarda que o cabeçalho deste
    #   bloco descreve — "só apaga o que é nosso, conferindo o conteúdo" — ficava
    #   DESLIGADA exatamente quando não dá para conferir.
    #
    #   E o `pack.py alvo` criou um segundo jeito de cair aqui: a linha recusada
    #   sai VAZIA, de propósito, para não quebrar o alinhamento do `paste`. Vazio
    #   não casa com arquivo nenhum na instalação (vira o aviso "no mapa mas sem
    #   desenho no disco"), mas aqui virava `origem=""`, `[ -f "" ]` falso, e o
    #   `rm -f` sem conferência nenhuma. Um mapa de pack de terceiro com
    #   `motor:../../../etc/passwd` era recusado pela guarda do resolvedor e a
    #   recusa APAGAVA o `$ALVO/$nome.svg` de quem quer que fosse o dono.
    #
    #   Não conferir é motivo para deixar quieto, nunca para apagar: a linha na
    #   tela diz qual arquivo ficou e por quê, que é o contrário de "se perde o
    #   trabalho de outra pessoa sem nada na tela dizendo que se perdeu".
    if [ ! -f "$origem" ]; then
      meow_info "  $nome.svg: sem a origem não dá para conferir se é nosso — fica como está"
      continue
    fi
    if [ "$(cat "$origem")" != "$(cat "$ALVO/$nome.svg")" ]; then
      meow_info "  $nome.svg não é o desenho do acervo — fica como está"
      continue
    fi
    if meow_seco; then
      meow_muda "apagaria $ALVO/$nome.svg"
      tirados=$((tirados+1)); continue
    fi
    rm -f "$ALVO/$nome.svg" && tirados=$((tirados+1)) || rc=2
  done < <(_dracula_pares)

  if [ "$tirados" -gt 0 ]; then
    meow_ok "$tirados desenho(s) do pack Dracula retirado(s) — o Arcticons do 48x48 volta a valer"
    _dracula_avisar
    [ "$rc" = "0" ] && rc=1
  fi
  local rc_c; _dracula_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1
  [ "$tirados" = "0" ] && [ "$rc" = "0" ] && \
    meow_ok "pack Dracula desligado (ICONES_DRACULA=\"nao\") — nada dele no tema"
  return "$rc"
}

# --- a cache do tema ----------------------------------------------------------
# Com um `icon-theme.cache` dentro do diretório do tema, o GTK lê a CACHE e
# ignora o disco — um SVG copiado depois dela não existe para o resolvedor. É a
# mesma guarda do `completar_icones.sh` e do `icones_resgatados.sh`.
#
# A LINHA DO `find` É A REGRA DE OURO, E ELA FALTAVA — 16/09/2026
#   A primeira versão desta função reindexava SEMPRE que houvesse cache no
#   disco, e devolvia 1 sempre. O efeito imediato: `meow doctor` acusava
#   `~~ dracula reindexaria a cache de MeowSystem-Icons` a cada passagem, para
#   sempre, numa máquina onde os 18 ícones já estavam no lugar — divergência
#   eterna, e o auto-reparo das 5h "consertando" todo dia o que já estava certo.
#   O irmão `icones_resgatados.sh` já tinha o teste certo: só há o que reindexar
#   se ALGUM `.svg` do diretório for mais novo que a cache.
_dracula_cache() {
  local cache="$TEMA_DIR/icon-theme.cache"
  [ -f "$cache" ] || return 0
  [ -n "$(find "$ALVO" -name '*.svg' -newer "$cache" -print -quit 2>/dev/null)" ] || return 0

  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($cache está velha e esconde o pack)"
    return 1
  fi
  if ! meow_tem gtk-update-icon-cache; then
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info  "  apague o arquivo: rm '$cache'"
    return 1
  fi
  if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
    meow_ok "cache do tema reindexada (ela escondia o pack Dracula)"
    return 1
  fi
  meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
  return 1
}

# --- o aviso que evita a pergunta "por que não mudou?" ------------------------
# O `cosmic-app-library` e o `cosmic-panel` não ligam em GTK: varrem o tema AO
# NASCER e guardam em memória. Um SVG que chega depois não existe para eles até
# o processo reiniciar. Reiniciar o painel derruba a topbar e a dock por alguns
# segundos, e o `meow-painel.service` existe porque o supervisor do COSMIC tem
# um backoff SEM TETO que já deixou esta máquina 16h sem barra — caro demais
# para ser efeito colateral de "instalei um ícone". Quem decide é ele.
_dracula_avisar() {
  meow_info "  o painel e o lançador leem o tema ao nascer e guardam em memória —"
  meow_info "  para ver agora, sem esperar o próximo login:"
  meow_info "      pkill -x cosmic-panel && pkill -f cosmic-app-library"
}

# --- estado -------------------------------------------------------------------
_dracula_estado() {
  local total=0 postos=0 nome caminho
  while IFS=$'\t' read -r nome caminho; do
    [ -n "$nome" ] || continue
    total=$((total+1))
    [ -f "$ALVO/$nome.svg" ] && postos=$((postos+1))
  done < <(_dracula_pares)
  printf '%s %s' "$postos" "$total"
}

# --- ponto de entrada ---------------------------------------------------------
# O PADRÃO É `nao`, E O PADRÃO É A CURADORIA
#   Onze dos dezoito nomes já vestem arte aprovada no artifact de 12-15/09.
#   Ligar isto de fábrica trocaria aquele trabalho pela arte do pack na primeira
#   rodada do instalador em QUALQUER máquina — inclusive na dela, que não
#   participou da decisão. Quem liga é o meow.conf, e a chave está no painel.
_dracula_aplicar() {
  if [ "${ICONES_DRACULA:-nao}" = "sim" ]; then _dracula_instalar
  else _dracula_remover; fi
}

case "${1:-aplicar}" in
  aplicar|--aplicar) _dracula_aplicar ;;
  # `--conferir` é o `aplicar` de olhos abertos e mãos no bolso: o `meow_seco`
  # faz o `meow_escrever` relatar em vez de gravar, e o código de saída 1 é o
  # que o `meow doctor` lê como "divergente".
  --conferir) MEOW_SECO=1 _dracula_aplicar ;;
  instalar) _dracula_instalar ;;
  remover)  _dracula_remover ;;
  estado)   _dracula_estado ;;
  *) printf 'uso: icones_apps_dracula.sh [aplicar|--conferir|instalar|remover|estado]\n' >&2; exit 2 ;;
esac
