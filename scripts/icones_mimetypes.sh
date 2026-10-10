#!/usr/bin/env bash
# icones_mimetypes.sh — o pack Catppuccin vestindo os ARQUIVOS, não os programas.
#
# POR QUE ESTE SCRIPT EXISTE, E POR QUE ELE NÃO MEXE EM ÍCONE DE APLICATIVO
#   Ela mandou usar `catppuccin/vscode-icons` em vez dos ícones autorais que o
#   projeto desenhava. O pack é ótimo e tem os quatro flavors — mas ele é de
#   LINGUAGEM E FORMATO DE ARQUIVO, não de aplicativo. Medido duas vezes, em
#   passagens separadas, com o mesmo resultado:
#
#       nomes de ícone que os .desktop desta máquina pedem ......... 50
#       cobertos pelo pack .......................................... 1  (vscode)
#
#   Trocar os ícones de programa por ele deixaria 49 dos 50 sem ícone. Então os
#   programas continuam vindo do Papirus (que os cobre bem) e o pack vai para
#   onde ele foi desenhado para brilhar: `mimetypes/`, que é o que o cosmic-files
#   desenha quando você abre uma pasta.
#
# ELE SÓ ESCALA PORQUE É VETOR DE VERDADE
#   O pack é grid de 16px e isso assusta — mas o SVG é stroke puro, sem raster
#   embutido. Renderizado a 64px lado a lado com o original de 16px, não há
#   diferença de nitidez. Por isso ele entra em `scalable/`, e não num tamanho
#   fixo: quem decide o tamanho é quem desenha.
#
# O DIRETÓRIO É NOSSO, E POR ISSO PODEMOS REMOVER ÓRFÃO
#   `scalable/mimetypes/` dentro de `MeowSystem-Icons` não existe no Papirus nem
#   em tema nenhum de terceiro: ele nasce aqui. Como o dono é único, tirar uma
#   linha do mapa pode remover o arquivo com segurança — a regra que o projeto
#   aprendeu a duras penas com o `custom_logo_path` (dois donos = laço eterno)
#   não é violada, porque aqui o dono é um só.
#
# O QUE NÃO ESTIVER NO MAPA CONTINUA VINDO DO PAPIRUS
#   `MeowSystem-Icons` herda `Papirus-Dark`. Um tipo de arquivo ausente do mapa
#   (xlsx e docx, por exemplo, que o pack não cobre) resolve no Papirus como
#   sempre resolveu. Não há buraco: há herança.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o pack
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# O flavor dos ÍCONES é independente do flavor do TEMA — ela pediu explicitamente
# "frappe ou macchiato" para os ícones, com a interface em mocha. A chave separada
# é o que torna isso possível sem partir o significado de FLAVOR no resto do repo.
#
# QUEM DECIDE O FLAVOR É O `pack.py`, E NÃO MAIS UM `:-macchiato` — 23/09/2026, P31
#   Era `FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"`. Com o conf de fábrica
#   (`ICONES_FLAVOR="$FLAVOR"`) e o Dracula no ar o valor chegava `dracula`, não
#   existe acervo de mimetype Dracula, e este script saía com "nada a vestir" —
#   enquanto o pack declara `icones.mimetypes.flavor: "macchiato"` exatamente
#   para isso, e o painel já o lia desde a P10. A regra (o conf escrito à mão
#   vence; o de fábrica que não existe cai no flavor que o pack escolheu) mora
#   no `flavor_de_icones` do pack.py, e é a MESMA que a aba Ícones pergunta.
#   Ela é perguntada logo abaixo do `_pack_ref`, porque precisa do mesmo pack
#   que o `acervo` vai subir.

# O ACERVO MUDOU DE CASA EM 22/09/2026 — ele é do PACK, e não do motor
#   Era `$RAIZ/assets/icones/catppuccin/$FLAVOR_ICONES`: 3.281 arquivos do
#   `catppuccin/vscode-icons` morando em `assets/`, ao lado dos acervos que são
#   de fato do motor. A P13 os desceu para `packs/catppuccin/icones/mimetypes/`.
#
#   QUEM DIZ ONDE ELES ESTÃO É O `pack.json`, E NÃO ESTE SCRIPT. O verbo `acervo`
#   lê a declaração `icones.mimetypes.desenhos` do pack ativo e sobe a cadeia de
#   herança quando ele não a declara — que é o caso do Dracula, cujo `pack.json`
#   diz `icones.mimetypes.herda: "catppuccin"` justamente porque não existe
#   acervo de mimetype Dracula. Escrever `packs/catppuccin/...` aqui seria a
#   segunda verdade sobre onde mora o acervo do pack padrão, e a P13 existe para
#   não ter nenhuma.
#
#   SEM PACK NO CONF, O ALVO É O PADRÃO — perguntado, nunca digitado.
#
#   O `|| VAZIO` NÃO É ENFEITE: ELE É O QUE DEIXA O `_pronto` FALAR — 22/09/2026
#     Este arquivo roda sob `set -euo pipefail`, e uma atribuição HERDA o status
#     do comando substituído. O `pack.py acervo` sai com 1 quando nada resolve
#     (RECUSADO), que é exatamente o caso do flavor sem acervo — `dracula`, com
#     o `ICONES_FLAVOR="$FLAVOR"` que o meow.conf.exemplo traz de fábrica. Sem a
#     queda explícita o script MORRIA nesta linha, calado: `--conferir` saía com
#     rc=1 e zero linha na tela, o doctor acusava divergência sem motivo (1 é
#     MEOW_DIVERGENTE, lib/comum.sh) e o `--consertar` morria no mesmo ponto, em
#     laço. Medido em 22/09/2026, com `bash -x` parando em `+ ORIGEM=`.
#     Vazio é RESPOSTA, e o `_pronto` logo abaixo é quem a conta em português.
#
#   E O `2>/dev/null` SAIU JUNTO: quando o `acervo` recusa por pack.json
#   quebrado ele DIZ por quê em stderr, e engolir essa linha deixaria o
#   `_pronto` culpar o flavor por um defeito que é do pack.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
FLAVOR_ICONES="$(python3 "$RAIZ/scripts/pack.py" flavor-icones "$_pack_ref")" || FLAVOR_ICONES=""
ORIGEM="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" \
            icones.mimetypes.desenhos "$FLAVOR_ICONES")" || ORIGEM=""
# SEM FLAVOR, SEM ORIGEM: `acervo ... ""` devolve a pasta-mãe do acervo (a que
# guarda um diretório por flavor), e o `_pronto` a aceitaria — o `--conferir`
# diria "0 já vestidos" com nada vestido. Vazio aqui nasce de conf sem
# `ICONES_FLAVOR` nem `FLAVOR`, ou do pack.py recusando o pack; nos dois casos o
# `_pronto` diz que não há o que vestir.
[ -n "$FLAVOR_ICONES" ] || ORIGEM=""
# DE QUEM É O ACERVO, DITO NA TELA — 09/10/2026, P74 item 7 (T1). A frase dizia
#   «vestidos de Catppuccin <flavor>» com qualquer pack: o doctor desta máquina,
#   com o Dracula no ar, dizia «123 tipos de arquivo já vestidos de Catppuccin
#   macchiato». Desde a P74 o Dracula traz os dele, e a frase diz o NOME do
#   pack dono do diretório que veste (o `_pack_de` do pack.py, o mesmo que a
#   aba Ícones usa). Com o Catppuccin no ar, a frase é a de antes.
DONO_ACERVO="$( [ -n "$ORIGEM" ] && python3 -I - "$RAIZ/scripts" "$ORIGEM" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import pack
dono = pack._pack_de(sys.argv[2])
print(pack.campo(dono, "nome", dono) or "")
PY
)"
[ -n "$DONO_ACERVO" ] || DONO_ACERVO="Catppuccin"
# O MAPA SEGUIU O ACERVO PARA DENTRO DO PACK — 22/09/2026
#   A P13 desceu os 3.280 glifos para `packs/catppuccin/icones/mimetypes/` e
#   deixou o mapa em `assets/icones/mimetypes.map`. Meio caminho: O MAPA É A
#   DECISÃO. Ele diz QUAL glifo veste cada tipo de arquivo, e isso é escolha de
#   tema, não fato desta máquina — um pack que traga outro acervo traz outro
#   pareamento junto. Acervo num endereço e decisão noutro é o defeito que esta
#   família de sprints existe para acabar: quem troca de pack levava os desenhos
#   e não levava a escolha.
#
#   Mesma porta do `ORIGEM` logo acima, e o mesmo `|| MAPA=""` pelo mesmo motivo
#   que o bloco anterior explica em detalhe: `acervo` sai 1 quando nada resolve,
#   e vazio é RESPOSTA — quem a conta em português é o `_pronto`.
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" \
          icones.mimetypes.mapa)" || MAPA=""
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/mimetypes"

# --- o mapa, lido uma vez -----------------------------------------------------
# Formato "nome:glifo", com # de comentário. O `cut` não serve: há nomes com '+'
# e com '.', mas nenhum com ':', então o separador é seguro.
declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome glifo pulados=()
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; glifo="${linha#*:}"
    # Os dois lados viram nome de arquivo (`<nome>.svg` no tema, `<glifo>.svg`
    # no acervo): só de um conjunto fechado, sem `/` nem `..` — um mapa de pack
    # importado é dado não confiável (conferência da P74, alerta de segurança
    # de 09/10/2026). A linha fora dele é pulada.
    # [P78: o conjunto é o `meow_nome_seguro` do lib/comum.sh, a regra única
    #   que o pack.py também segue, e a linha pulada agora é contada.]
    if ! meow_nome_seguro "$nome" || ! meow_nome_seguro "$glifo"; then
      # O nome vai para o aviso, no terminal: pela porta de saída de texto de
      # pack, e uma sequência de controle plantada no mapa não chega lá crua.
      pulados+=("$(meow_texto_seguro "$nome")"); continue
    fi
    [ -n "$nome" ] && [ -n "$glifo" ] && MAPA_LIDO["$nome"]="$glifo"
  done < "$MAPA"
  [ "${#pulados[@]}" -gt 0 ] && \
    meow_aviso "$MAPA: ${#pulados[@]} linha(s) com nome fora de [A-Za-z0-9._+-] (ou com '..') puladas: ${pulados[*]:0:3}"
  return 0
}

# --- dependências -------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "não há acervo de mimetype para o flavor '$FLAVOR_ICONES' — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "o pack não traz mapa de mimetype (icones.mimetypes.mapa) — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o que deveria estar no disco ---------------------------------------------
# Devolve, uma por linha, "nome<TAB>caminho-de-origem" — só dos glifos que existem
# de fato. Um glifo faltando é aviso, não erro: o mapa pode citar algo que o pack
# renomeou, e nesse caso o Papirus continua atendendo aquele tipo.
_desejado() {
  local nome glifo real
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    # Link não entra: o `cat` o seguiria para fora do acervo (P74, idem).
    # [P78: link para dentro do acervo entra, pela forma que o `meow_dentro`
    #   conferiu; o que sai dele continua de fora.]
    [ -f "$ORIGEM/$glifo.svg" ] && real="$(meow_dentro "$ORIGEM" "$glifo.svg")" \
      && printf '%s\t%s\n' "$nome" "$real"
  done
  return 0
}

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR — senão o doctor grita eternamente
#   Primeira versão disto usava `cmp -s`, byte a byte, e o resultado foi um script
#   que aplicava com sucesso e em seguida dizia "123 a atualizar", para sempre. O
#   motivo: `meow_escrever` grava com `printf '%s' "$conteudo"`, e `$(cat ...)`
#   come o `\n` final — o arquivo instalado tem exatamente 1 byte a menos que o
#   original, com conteúdo idêntico. `cmp` vê diferença; o escritor não vê.
#   Num projeto cujo auto-reparo roda todo dia por timer, um conferir mais severo
#   que o escritor é uma notificação mentirosa diária. Compare do mesmo jeito que
#   se escreve, sempre.
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
    meow_ok "$total tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_muda "tipos de arquivo: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
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
  # diretório tem um dono só (ver o cabeçalho).
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
    meow_ok "tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_info "tipos de arquivo: $postos posto(s), $removidos removido(s) — flavor $FLAVOR_ICONES"
  meow_info "o cosmic-files relê o tema ao abrir uma janela nova"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"
