#!/usr/bin/env bash
# icones_pastas.sh — o pack Catppuccin vestindo as PASTAS ESPECIAIS do cosmic-files.
#
# POR QUE ESTE SCRIPT EXISTE, E POR QUE ELE NÃO É A SPRINT C QUE ESTAVA ESCRITA
#   A tela que ela mandou dizendo "esses são os ícones que eu quero" era a página
#   do `catppuccin/vscode-icons` mostrando `folder-images`, `folder-docker`,
#   `folder-github`. A Sprint C nasceu para instalar aqueles 14 nomes.
#
#   Medido em 08/08/2026, e a premissa caiu: das 14, o `cosmic-files` pede DUAS.
#   `folder-github` e companhia são apelidos que o Papirus mantém para o
#   Dolphin/KDE, que lê um `.directory` dentro da pasta — lógica que o
#   `cosmic-files` não tem (`.directory` aparece zero vezes no binário dele).
#   Instalar aqueles 12 seria instalar ícone que ela nunca veria.
#
#   O que ele pede de verdade são os nomes XDG, e disso o pack cobre 7 — com
#   OUTRO NOME. A tradução mora em `assets/icones/pastas.map`, com a medição completa.
#
# ONDE ISTO ENTRA, E POR QUE NÃO NOS `<tam>/places`
#   Em `scalable/places`, um diretório que nasce aqui: nenhum outro script do
#   projeto escreve nele. Dono único é o que autoriza remover órfão sem repetir o
#   defeito do `custom_logo_path` (dois donos = laço eterno).
#
#   O `SPRINTS.md` dizia que isto NÃO funcionaria, porque "quem escolhe o
#   diretório é o TAMANHO, não a ordem de `Directories=`". Medido com strace num
#   Xvfb :99 (nunca na tela dela), plantando `folder-pictures` nos DOIS lugares —
#   mauve em `32x32/places` e pastel em `scalable/places`:
#
#       openat(".../MeowSystem-Icons/scalable/places/folder-pictures.svg") = 99
#
#   O `cosmic-files` abriu o `scalable`, mesmo com o `32x32` sendo o tamanho
#   EXATO que ele pediu e mesmo estando declarado antes na lista. Ou seja: para a
#   crate do COSMIC, o caminho (a) funciona.
#
#   MAS O GTK DISCORDA, E É POR ISSO QUE A CESSÃO CONTINUA OBRIGATÓRIA. Com o
#   mesmo disco, `Gtk.IconTheme.lookup_icon` devolveu:
#       16px scalable · 24px scalable · 32px 32x32 · 48px 48x48 · 64px 64x64 · 128px scalable
#   Isto é: num aplicativo GTK a mesma pasta apareceria PASTEL a 16px e MAUVE a
#   48px, conforme o tamanho do widget. Dois arquivos para o mesmo nome é o
#   defeito dos dois donos vestido de outra roupa. Quem resolve é o
#   `construir_pastas.sh`, que lê o `pastas.map` e para de criar estes apelidos.
#
# QUEM DECLARA O DIRETÓRIO NÃO É ESTE SCRIPT
#   É o `construir_icones.sh`, que monta o `index.theme` a partir do que EXISTE
#   no disco. Ter dois donos daquela linha já custou a este projeto um laço
#   eterno de seis rodadas. Aqui só se põe arquivo.
#
# O QUE NÃO ESTIVER NO MAPA CONTINUA MAUVE
#   `folder` (a pasta comum), `user-desktop` e o lixo não estão no mapa — de
#   propósito, e o porquê de cada um está em `assets/icones/pastas.map`.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o pack
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# O flavor dos ÍCONES é independente do flavor do TEMA — mesma chave que as
# etapas irmãs usam, para que os tipos de arquivo e as pastas nunca discordem.
FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"

ORIGEM="$RAIZ/assets/icones/catppuccin/$FLAVOR_ICONES"
MAPA="$RAIZ/assets/icones/pastas.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/places"

# --- o mapa, lido uma vez -----------------------------------------------------
# Formato "nome:glifo", com # de comentário. Nenhum nome de ícone tem ':'.
declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome glifo
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; glifo="${linha#*:}"
    [ -n "$nome" ] && [ -n "$glifo" ] && MAPA_LIDO["$nome"]="$glifo"
  done < "$MAPA"
  # `return 0` não é decoração: o `while` devolve o status do último teste, e com
  # `set -e` uma última linha que não case mataria o script calado. Já aconteceu
  # no `icones_sistema.sh`, na primeira execução dele.
  return 0
}

# --- dependências -------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o pack Catppuccin não está em assets/icones/catppuccin/$FLAVOR_ICONES — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem assets/icones/pastas.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o que deveria estar no disco ---------------------------------------------
# "nome<TAB>caminho-de-origem", só dos glifos que existem de fato. Um glifo
# faltando é aviso, não erro: aquele nome continua vindo do `construir_pastas.sh`
# em mauve, que é exatamente o que ele era antes desta sprint.
_desejado() {
  local nome glifo
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$glifo.svg" ] && printf '%s\t%s\n' "$nome" "$ORIGEM/$glifo.svg"
  done
}

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Um `cmp` byte
#   a byte acusaria divergência eterna num arquivo perfeito — já custou um
#   `--conferir` gritando 123 divergências num tema correto, e num projeto cujo
#   auto-reparo roda por timer isso é uma notificação mentirosa por dia.
_conferir() {
  local nome origem divergentes=0 ausentes=0 orfaos=0 total=0 arq
  while IFS=$'\t' read -r nome origem; do
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.svg" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(cat "$origem")" != "$(cat "$DESTINO/$nome.svg")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  fi

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total pasta(s) especiais já vestidas de Catppuccin $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_muda "pastas especiais: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local nome origem arq mudou=0 postos=0 removidos=0 rc

  while IFS=$'\t' read -r nome origem; do
    set +e
    meow_escrever "$DESTINO/$nome.svg" "$(cat "$origem")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $DESTINO/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  # Órfão: estava no mapa ontem, não está hoje. Podemos remover porque este
  # diretório tem um dono só (ver o cabeçalho). E remover aqui é o que devolve o
  # nome ao `construir_pastas.sh`: sem o pastel no disco ele para de ceder e a
  # pasta volta a ser mauve na mesma rodada, em vez de ficar azul.
  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then
          meow_muda "removeria $arq (saiu do mapa)"
        else
          meow_destino_permitido "$arq" || return "$MEOW_ERRO"
          rm -f "$arq"
        fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "pastas especiais já vestidas de Catppuccin $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_info "pastas especiais: $postos posto(s), $removidos removido(s) — flavor $FLAVOR_ICONES"
  meow_info "o cosmic-files relê o tema ao abrir uma janela nova"
  return "$MEOW_DIVERGENTE"
}

# DESLIGAR TEM DE DESLIGAR — e ela desligou isto no dia em que viu na tela
#   Em 08/08/2026, olhando o Gestor de Arquivos depois da primeira aplicação, ela
#   disse: *"as pastas do temas dos icons do vscode catpuccin, tipo as folders,
#   essas nao tão legais tambem"*. O risco estava previsto no desenho da Sprint C
#   — "pode ficar ótimo (destaque para pastas especiais) ou pode ficar
#   inconsistente" — e a medição que decide é a dela olhando a tela: as 7 do pack
#   são pasta VAZADA de traço claro, ao lado das mauve CHEIAS do papirus-folders.
#   Nenhuma delas usa `mauve`, que é o accent dela; o conjunto não fechou.
#
#   Por isso o padrão passou a ser `PASTAS_XDG="nao"`, e o recurso fica de pé
#   atrás de uma chave em vez de ser apagado: o trabalho está medido e pronto
#   para o dia em que ela quiser experimentar de novo (ou em `ICONES_FLAVOR=latte`,
#   que a folha mostra com contraste melhor).
#
# E EM 10/08/2026 ELA FECHOU A QUESTÃO PELO OUTRO LADO
#   *"Cada pasta ganha o símbolo interno do que ela guarda, tudo recolorido no
#   mauve dela. Mesma silhueta, mesmo mauve, símbolo por tipo."* Conferido no
#   resolvedor real no mesmo dia, é exatamente o que os SETE nomes deste mapa já
#   entregam vindos do `construir_pastas.sh`: `folder-documents` resolve para
#   `folder-cat-mocha-mauve-documents.svg`, que é pasta mauve `#CBA6F7` com a
#   folha em `#313244` dentro — e assim os sete.
#
#   Ou seja: ligar `PASTAS_XDG="sim"` hoje não ACRESCENTA símbolo, SUBSTITUI o
#   que já tem por traço vazado sem mauve. As duas decisões dela apontam para o
#   mesmo lado. Quem for reabrir isto, releia `assets/icones/pastas.map` inteiro antes —
#   a medição está lá, com a tabela nome -> arquivo final.
#
# COMO O DESLIGAMENTO FUNCIONA, E POR QUE NÃO TEM CÓDIGO NOVO
#   Esvaziar o mapa faz todo arquivo que está em `scalable/places` virar ÓRFÃO, e
#   a remoção de órfão já existe logo acima — é o mesmo caminho que roda quando
#   ela tira uma linha do `pastas.map`. Um segundo caminho de remoção seria uma
#   segunda regra para o mesmo ato, e a que ninguém relê é sempre a que quebra.
#
#   O `construir_pastas.sh` faz o resto sozinho: ele só cede o nome cujo pastel
#   ESTÁ no disco, então com o diretório limpo os 7 voltam a mauve na mesma
#   passagem do instalador. Nenhuma pasta fica sem ícone no meio do caminho.
_desligado() { [ "${PASTAS_XDG:-nao}" != "sim" ]; }

main() {
  _pronto || return $?
  _ler_mapa
  if _desligado; then
    # Sem nada no disco não há o que desfazer: dizer "removi" aqui seria a mesma
    # mentira de tempo verbal que o projeto já corrigiu no modo seco.
    if [ -d "$DESTINO" ] && [ -n "$(find "$DESTINO" -maxdepth 1 -name '*.svg' -print -quit 2>/dev/null)" ]; then
      meow_info "PASTAS_XDG=\"${PASTAS_XDG:-nao}\" — devolvendo as pastas especiais ao mauve"
      MAPA_LIDO=()
    else
      meow_ok "pastas especiais desligadas (PASTAS_XDG=\"${PASTAS_XDG:-nao}\") — as pastas seguem mauve"
      return "$MEOW_OK"
    fi
  fi
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"
