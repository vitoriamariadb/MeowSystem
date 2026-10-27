#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

AREAS_PENDENCIA=4

AREAS_NOMES="${AREAS_NOMES:-}"
AREAS_FOLGA="${AREAS_FOLGA:-}"
AREAS_ENCAIXE="${AREAS_ENCAIXE:-}"
JANELAS_TILING="${JANELAS_TILING:-}"

AREAS_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicComp/$(meow_cosmic_v com.system76.CosmicComp)"
AREAS_ALVO="$AREAS_BASE/pinned_workspaces"
AREAS_BINARIO="/usr/bin/cosmic-comp"

AREAS_ANTES="$MEOW_ESTADO/areas"
BACKUPS_MANTIDOS="${BACKUPS_MANTIDOS:-10}"

AREAS_FIGURA=$'\u2007'

_areas_dependencia() {
  if [ ! -x "$AREAS_BINARIO" ] && [ ! -d "$AREAS_BASE" ]; then
    meow_pula "cosmic-comp não encontrado — nada a fazer com as áreas de trabalho"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3; then
    meow_pula "sem python3 — não consigo ler o RON do pinned_workspaces"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_areas_motor() {
  python3 -I - "$@" <<'PY'
import glob
import random
import re
import sys

ABRE = {"(": ")", "[": "]"}


def mascara(texto):
    """O texto com strings, chars e comentários trocados por espaços.

    Mesmo tamanho, mesmos deslocamentos: quem procurar um parêntese nesta
    máscara encontra só os parênteses ESTRUTURAIS, e o índice serve para
    fatiar o texto original sem nenhuma conversão.
    """
    saida = []
    i, n = 0, len(texto)
    while i < n:
        c = texto[i]
        if c == '"':
            j = i + 1
            while j < n:
                if texto[j] == "\\":
                    j += 2
                    continue
                if texto[j] == '"':
                    break
                j += 1
            saida.append(" " * (min(j, n - 1) - i + 1))
            i = j + 1
        elif c == "'":
            j = i + 1
            while j < n and texto[j] != "'":
                j += 2 if texto[j] == "\\" else 1
            saida.append(" " * (min(j, n - 1) - i + 1))
            i = j + 1
        elif c == "/" and i + 1 < n and texto[i + 1] == "/":
            j = texto.find("\n", i)
            j = n if j < 0 else j
            saida.append(" " * (j - i))
            i = j
        elif c == "/" and i + 1 < n and texto[i + 1] == "*":
            j = texto.find("*/", i + 2)
            j = n if j < 0 else j + 2
            saida.append(" " * (j - i))
            i = j
        else:
            saida.append(c)
            i += 1
    return "".join(saida)


def fecha(m, inicio):
    """O índice do delimitador que fecha o que abre em `inicio`, na máscara."""
    alvo = ABRE[m[inicio]]
    profundidade = 0
    for k in range(inicio, len(m)):
        if m[k] in ABRE:
            profundidade += 1
        elif m[k] in (")", "]"):
            profundidade -= 1
            if profundidade == 0:
                return k if m[k] == alvo else -1
    return -1


def desescapa(s):
    saida, i, n = [], 0, len(s)
    while i < n:
        if s[i] == "\\" and i + 1 < n:
            p = s[i + 1]
            saida.append({"n": "\n", "t": "\t", "r": "\r"}.get(p, p))
            i += 2
        else:
            saida.append(s[i])
            i += 1
    return "".join(saida)


def escapa(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def entradas(texto):
    """[(inicio, fim, campos)] de cada registro da lista, no texto CRU."""
    m = mascara(texto)
    ini = m.find("[")
    if ini < 0:
        raise ValueError("não achei a lista: falta o colchete de abertura")
    fim = fecha(m, ini)
    if fim < 0:
        raise ValueError("a lista de áreas não fecha o colchete")

    achadas = []
    i = ini + 1
    while i < fim:
        if m[i] != "(":
            i += 1
            continue
        parada = fecha(m, i)
        if parada < 0 or parada > fim:
            raise ValueError("um registro de área não fecha o parêntese")
        achadas.append((i, parada, campos(texto, m, i, parada)))
        i = parada + 1
    return ini, fim, achadas


def campos(texto, m, ini, fim):
    """Os campos do registro, com os deslocamentos ABSOLUTOS de cada valor.

    O bloco `output:` é apagado da máscara local antes da busca porque ele
    carrega um `name:` PRÓPRIO — o do conector, "DP-1". Sem isso o nome da
    área seria lido do monitor, e uma renomeação escreveria por cima do
    conector: o registro apontaria para uma saída que não existe.
    """
    bruto = texto[ini : fim + 1]
    local = m[ini : fim + 1]
    saida = {"output": None, "output_span": None}

    mo = re.search(r"output\s*:\s*\(", local)
    if mo:
        abre = mo.end() - 1
        fecha_out = fecha(local, abre)
        if fecha_out < 0:
            raise ValueError("o bloco output não fecha o parêntese")
        saida["output"] = bruto[abre : fecha_out + 1]
        saida["output_span"] = (ini + abre, ini + fecha_out + 1)
        local = local[:abre] + " " * (fecha_out + 1 - abre) + local[fecha_out + 1 :]

    def acha(chave, campo):
        r = re.search(chave + r"\s*:\s*", local)
        if not r:
            saida[campo] = None
            saida[campo + "_span"] = None
            return
        p = r.end()
        if local.startswith("None", p):
            fim_v, valor = p + 4, None
        elif local.startswith("Some(", p):
            f = fecha(local, p + 4)
            if f < 0:
                raise ValueError("o campo %s não fecha o parêntese" % chave)
            fim_v = f + 1
            dentro = re.match(r'Some\(\s*"((?:[^"\\]|\\.)*)"\s*\)\Z', bruto[p:fim_v])
            valor = desescapa(dentro.group(1)) if dentro else None
        else:
            t = re.match(r"[A-Za-z0-9_.+-]+", local[p:])
            if not t:
                saida[campo] = None
                saida[campo + "_span"] = None
                return
            fim_v, valor = p + t.end(), bruto[p : p + t.end()]
        saida[campo] = valor
        saida[campo + "_span"] = (ini + p, ini + fim_v)

    acha("tiling_enabled", "tiling")
    acha("id", "id")
    acha("name", "nome")
    if saida["tiling"] is None:
        saida["tiling"] = "false"
    return saida


def ler(caminho):
    texto = open(caminho, encoding="utf-8").read()
    _, _, achadas = entradas(texto)
    for i, (_, _, c) in enumerate(achadas):
        nome = c["nome"] if c["nome"] is not None else ""
        if "\t" in nome or "\n" in nome:
            raise ValueError(
                "a área %d tem tabulação ou quebra de linha no nome; "
                "não mexo neste arquivo sem estragá-lo" % i
            )
        print(
            "%d\t%s\t%s\t%s"
            % (i, c["id"] or "", c["tiling"], nome)
        )


def id_novo(usados):
    """Um id como o COSMIC sorteia: 24 bits em hexadecimal."""
    for _ in range(200):
        candidato = "%06x" % random.getrandbits(24)
        if candidato not in usados:
            return candidato
    raise ValueError("não consegui sortear um id de área livre")


NOVA = (
    "(\n"
    "        output: %s,\n"
    "        tiling_enabled: %s,\n"
    "        id: Some(\"%s\"),\n"
    "        name: Some(\"%s\"),\n"
    "    )"
)


def montar(caminho, encaixes, nomes):
    """O texto NOVO do arquivo, no stdout. Nada é escrito aqui."""
    texto = open(caminho, encoding="utf-8").read()
    _, _, achadas = entradas(texto)

    if len(nomes) < len(achadas):
        raise ValueError(
            "a lista pedida tem %d área(s) e o disco tem %d: isto TIRARIA "
            "alfinete, e tirar alfinete apaga a área de trabalho. Use "
            "`areas.sh desalfinetar <nome>`." % (len(nomes), len(achadas))
        )
    if not nomes:
        raise ValueError("lista vazia: um arquivo sem alfinete nenhum destrói as áreas")

    if len(nomes) == len(achadas):
        trocas = []
        for i, (_, _, c) in enumerate(achadas):
            if nomes[i] != (c["nome"] if c["nome"] is not None else ""):
                trocas.append((c["nome_span"], 'Some("%s")' % escapa(nomes[i])))
            if encaixes[i] and encaixes[i] != c["tiling"]:
                trocas.append((c["tiling_span"], encaixes[i]))
        for (ini, fim), novo in sorted(trocas, key=lambda t: -t[0][0]):
            texto = texto[:ini] + novo + texto[fim:]
        sys.stdout.write(texto)
        return

    herdado = next((c["output"] for _, _, c in achadas if c["output"]), None)
    if herdado is None:
        raise ValueError(
            "nenhuma área existente tem bloco `output:` de onde herdar o monitor; "
            "não vou inventar um EDID"
        )

    usados = {c["id"] for _, _, c in achadas if c["id"]}
    crus = []
    for i, nome in enumerate(nomes):
        if i < len(achadas):
            ini, fim, c = achadas[i]
            bruto = texto[ini : fim + 1]
            trocas = []
            if nome != (c["nome"] if c["nome"] is not None else ""):
                trocas.append((c["nome_span"], 'Some("%s")' % escapa(nome)))
            if encaixes[i] and encaixes[i] != c["tiling"]:
                trocas.append((c["tiling_span"], encaixes[i]))
            for (a, b), novo in sorted(trocas, key=lambda t: -t[0][0]):
                bruto = bruto[: a - ini] + novo + bruto[b - ini :]
            crus.append(bruto)
        else:
            novo_id = id_novo(usados)
            usados.add(novo_id)
            crus.append(
                NOVA % (herdado, encaixes[i] or "false", novo_id, escapa(nome))
            )

    ini0, fim0, _ = achadas[0]
    cabeca = texto[:ini0]
    rabo = texto[achadas[-1][1] + 1 :]
    emenda = ",\n    "
    if len(achadas) > 1:
        emenda = texto[achadas[0][1] + 1 : achadas[1][0]]
    sys.stdout.write(cabeca + emenda.join(crus) + rabo)


def tirar(caminho, indice):
    texto = open(caminho, encoding="utf-8").read()
    _, _, achadas = entradas(texto)
    if indice < 0 or indice >= len(achadas):
        raise ValueError("não existe área na posição %d" % indice)
    if len(achadas) <= 1:
        raise ValueError(
            "esta é a última área alfinetada; sem alfinete nenhum o cosmic-comp "
            "destrói o workspace assim que ele esvazia"
        )
    crus = [texto[a : b + 1] for j, (a, b, _) in enumerate(achadas) if j != indice]
    cabeca = texto[: achadas[0][0]]
    rabo = texto[achadas[-1][1] + 1 :]
    emenda = texto[achadas[0][1] + 1 : achadas[1][0]]
    sys.stdout.write(cabeca + emenda.join(crus) + rabo)


def edid_do_conector(nome):
    """O EdidProduct do conector, em RON, ou None se não houver EDID no disco."""
    achados = glob.glob("/sys/class/drm/*-%s/edid" % nome)
    if not achados:
        return None
    try:
        with open(achados[0], "rb") as fh:
            dados = fh.read()
    except OSError:
        return None
    if len(dados) < 128 or dados[:8] != b"\x00\xff\xff\xff\xff\xff\xff\x00":
        return None

    man = (dados[0x08] << 8) | dados[0x09]
    letras = [chr(((man >> 10) & 0x1F) + 0x40),
              chr(((man >> 5) & 0x1F) + 0x40),
              chr((man & 0x1F) + 0x40)]
    produto = dados[0x0A] | (dados[0x0B] << 8)
    serie = (dados[0x0C] | (dados[0x0D] << 8)
             | (dados[0x0E] << 16) | (dados[0x0F] << 24))
    semana, ano_cru, revisao = dados[0x10], dados[0x11], dados[0x13]
    ano = ano_cru + 1990 if (ano_cru >= 0x10 or revisao < 4) else 0
    semana_fab, ano_fab, ano_modelo = 0, 0, 0
    if semana == 0xFF:
        ano_modelo = ano
    else:
        ano_fab = ano
        if 0 < semana <= 54:
            semana_fab = semana

    def opcional(v):
        return "None" if v == 0 else "Some(%d)" % v

    return (
        "Some((\n"
        "                manufacturer: ('%s', '%s', '%s'),\n"
        "                product: %d,\n"
        "                serial: %s,\n"
        "                manufacture_week: %d,\n"
        "                manufacture_year: %d,\n"
        "                model_year: %s,\n"
        "            ))" % (letras[0], letras[1], letras[2], produto,
                            opcional(serie), semana_fab, ano_fab,
                            opcional(ano_modelo))
    )


def primeira(saida, encaixe, nome):
    """O texto de um `pinned_workspaces` com UMA area, no stdout."""
    if not saida:
        raise ValueError("sem nome de conector não ha como amarrar a area a um monitor")
    edid = edid_do_conector(saida) or "None"
    return sys.stdout.write(
        "[\n"
        "    (\n"
        "        output: (\n"
        '            name: "%s",\n'
        "            edid: %s,\n"
        "        ),\n"
        "        tiling_enabled: %s,\n"
        '        id: Some("%s"),\n'
        '        name: Some("%s"),\n'
        "    ),\n"
        "]\n" % (escapa(saida), edid, encaixe or "false",
                  id_novo(set()), escapa(nome))
    )


try:
    verbo = sys.argv[1]
    if verbo == "ler":
        ler(sys.argv[2])
    elif verbo == "montar":
        encaixes_csv = sys.argv[3]
        alvos = sys.argv[4:]
        lista = encaixes_csv.split(",") if encaixes_csv else []
        lista += [""] * (len(alvos) - len(lista))
        montar(sys.argv[2], lista, alvos)
    elif verbo == "primeira":
        primeira(sys.argv[2], sys.argv[3], sys.argv[4])
    elif verbo == "tirar":
        tirar(sys.argv[2], int(sys.argv[3]))
    else:
        raise ValueError("verbo desconhecido: %s" % verbo)
except (ValueError, OSError, IndexError) as erro:
    sys.stderr.write("%s\n" % erro)
    sys.exit(2)
PY
}

_areas_nome_seguro() {
  local nome="$1"
  case "$nome" in
    *'"'*|*\\*|*'('*|*')'*|*'#'*|*$'\n'*|*$'\t'*)
      meow_erro "nome de área recusado: '$nome'"
      meow_aviso "não cabem aspas, contrabarra, parênteses, # nem quebra de linha —"
      meow_aviso "os quatro primeiros quebram o RON e o # corta a linha do meow.conf."
      return 1 ;;
  esac
  [ -n "$nome" ] || { meow_erro "nome de área vazio na lista"; return 1; }
  return 0
}

_areas_partir() {
  local texto="$1" item
  while IFS= read -r -d ',' item || [ -n "$item" ]; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] && printf '%s\n' "$item"
  done < <(printf '%s,' "$texto")
}

AREAS_TEXTO=""

_areas_ler_arquivo() {
  local saida; saida="$(cat "$1" 2>/dev/null; printf x)"
  AREAS_TEXTO="${saida%x}"
}

_areas_montar_texto() {
  local saida rc
  saida="$(_areas_motor "$@" 2>/dev/null; printf x)"; rc=$?
  AREAS_TEXTO="${saida%x}"
  return "$rc"
}

_areas_juntar() {
  local sep="" x
  for x in "$@"; do printf '%s%s' "$sep" "$(_areas_sem_folga "$x")"; sep=", "; done
}

_areas_bool() {
  case "$1" in
    sim|true|1)      printf 'true' ;;
    nao|não|false|0) printf 'false' ;;
    *) return 1 ;;
  esac
}

AREAS_ID=(); AREAS_TILING=(); AREAS_NOME=()

_areas_ler() {
  AREAS_ID=(); AREAS_TILING=(); AREAS_NOME=()
  [ -f "$AREAS_ALVO" ] || return "$MEOW_OK"
  local erro
  erro="$(_areas_motor ler "$AREAS_ALVO" 2>&1 >/dev/null)"
  if [ -n "$erro" ]; then
    meow_erro "não consegui ler $AREAS_ALVO: $erro"
    return "$MEOW_ERRO"
  fi
  while IFS=$'\t' read -r _i id tiling nome; do
    AREAS_ID+=("$id"); AREAS_TILING+=("$tiling"); AREAS_NOME+=("$nome")
  done < <(_areas_motor ler "$AREAS_ALVO" 2>/dev/null)
  return "$MEOW_OK"
}

_areas_sem_folga() {
  local n="$1"
  while [ "${n#"$AREAS_FIGURA"}" != "$n" ]; do n="${n#"$AREAS_FIGURA"}"; done
  while [ "${n%"$AREAS_FIGURA"}" != "$n" ]; do n="${n%"$AREAS_FIGURA"}"; done
  printf '%s' "$n"
}

_areas_guardar() {
  meow_seco && return 0
  [ -f "$AREAS_ALVO" ] || return 0

  if [ ! -f "$AREAS_ANTES/pinned_workspaces.antes" ]; then
    mkdir -p "$AREAS_ANTES" 2>/dev/null \
      || { meow_erro "não consegui criar $AREAS_ANTES"; return "$MEOW_ERRO"; }
    meow_guardar_antes "$AREAS_ANTES/pinned_workspaces.antes"
    cp -a "$AREAS_ALVO" "$AREAS_ANTES/pinned_workspaces.antes" 2>/dev/null \
      || { meow_erro "não consegui guardar o estado de antes — não vou escrever"; return "$MEOW_ERRO"; }
  fi

  local dir="$MEOW_ESTADO/backups/$MEOW_CARIMBO-areas"
  mkdir -p "$dir" 2>/dev/null \
    || { meow_erro "não consegui criar $dir"; return "$MEOW_ERRO"; }
  cp -a "$AREAS_ALVO" "$dir/pinned_workspaces" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $AREAS_ALVO — não vou escrever"; return "$MEOW_ERRO"; }
  cat > "$dir/COMO-RESTAURAR.txt" <<FIM
As áreas de trabalho alfinetadas do COSMIC, como estavam em
$(date '+%d/%m/%Y %H:%M:%S'), antes de o MeowSystem escrever.

Para voltar exatamente a este estado:

    cp -a $dir/pinned_workspaces $AREAS_ALVO

Ou, pelo projeto:  ./scripts/areas.sh reverter

Em qualquer um dos dois, o COSMIC só relê no PRÓXIMO INÍCIO DE SESSÃO.
FIM

  local -a antigas=() velho
  for velho in "$MEOW_ESTADO"/backups/*-areas; do
    [ -d "$velho" ] && antigas+=("$velho")
  done
  [ "${BACKUPS_MANTIDOS:-10}" -eq 0 ] 2>/dev/null && return 0
  if [ "${#antigas[@]}" -gt "$BACKUPS_MANTIDOS" ]; then
    printf '%s\n' "${antigas[@]}" | sort | head -n "-$BACKUPS_MANTIDOS" \
      | while read -r velho; do rm -rf "$velho"; done
  fi
  return 0
}

_areas_recusar_vazio() {
  local texto="$1"
  case "$texto" in
    *'('*) return "$MEOW_OK" ;;
  esac
  meow_erro "recusado: o texto novo não tem NENHUMA área alfinetada"
  meow_aviso "sem alfinete o cosmic-comp destrói o workspace assim que ele esvazia —"
  meow_aviso "gravar isto apagaria as suas áreas de trabalho no próximo login."
  return "$MEOW_ERRO"
}

_areas_so_no_login() {
  meow_info "vale no PRÓXIMO INÍCIO DE SESSÃO: o cosmic-comp lê este arquivo uma"
  meow_info "vez, ao iniciar. Nada muda na barra agora, e isso não é defeito."
}

_areas_col() { printf '%-14s' "$1"; }

cmd_estado() {
  _areas_dependencia || return $?
  _areas_ler || return $?

  if [ "${#AREAS_NOME[@]}" -eq 0 ]; then
    meow_aviso "nenhuma área alfinetada em $AREAS_ALVO"
    meow_aviso "sem alfinete as áreas não têm nome: o painel mostra a POSIÇÃO delas."
    return "$MEOW_OK"
  fi

  local i nu dono
  meow_info "áreas alfinetadas, na ordem em que nascem:"
  for i in "${!AREAS_NOME[@]}"; do
    nu="$(_areas_sem_folga "${AREAS_NOME[$i]}")"
    dono="nosso"
    printf '  %s%2d.%s %s  id=%-8s encaixe=%-5s (%s)%s\n' \
      "$C_MAUVE" "$((i + 1))" "$C_ZERO" "$(_areas_col "$nu")" \
      "${AREAS_ID[$i]:-<sem id>}" "${AREAS_TILING[$i]}" "$dono" \
      "$([ "$nu" != "${AREAS_NOME[$i]}" ] && printf '  [com folga invisível]')"
  done

  local nomes="" folgas="" sep=""
  for i in "${!AREAS_NOME[@]}"; do
    nu="$(_areas_sem_folga "${AREAS_NOME[$i]}")"
    nomes="$nomes$sep$nu"
    [ "$nu" != "${AREAS_NOME[$i]}" ] && folgas="$folgas$sep$nu"
    sep=", "
  done
  meow_info "para o meow.conf:  AREAS_NOMES=\"$nomes\"   AREAS_FOLGA=\"$folgas\""

  _areas_so_no_login
  local pid; pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
  [ -n "$pid" ] || meow_aviso "cosmic-comp NÃO está rodando — nada disto está valendo agora"
  return "$MEOW_OK"
}

AREAS_ALVO_NOME=(); AREAS_ALVO_ENCAIXE=()

_areas_planejar() {
  AREAS_ALVO_NOME=(); AREAS_ALVO_ENCAIXE=()
  local -a pedidos=() folgas=() encaixes=()
  local n b i

  while IFS= read -r n; do pedidos+=("$n"); done < <(_areas_partir "$AREAS_NOMES")
  while IFS= read -r n; do folgas+=("$n");  done < <(_areas_partir "$AREAS_FOLGA")
  while IFS= read -r n; do encaixes+=("$n"); done < <(_areas_partir "$AREAS_ENCAIXE")

  for n in "${pedidos[@]}"; do _areas_nome_seguro "$n" || return "$MEOW_ERRO"; done

  if [ "${#pedidos[@]}" -lt "${#AREAS_NOME[@]}" ]; then
    meow_erro "AREAS_NOMES tem ${#pedidos[@]} área(s) e o disco tem ${#AREAS_NOME[@]}"
    meow_aviso "faltar um nome aqui TIRARIA um alfinete, e tirar alfinete apaga a área."
    meow_aviso "para tirar de propósito:  MEOW_SIM=1 ./scripts/areas.sh desalfinetar <nome>"
    return "$MEOW_ERRO"
  fi

  if [ "${#encaixes[@]}" -gt 0 ] && [ "${#encaixes[@]}" -ne 1 ] \
     && [ "${#encaixes[@]}" -ne "${#pedidos[@]}" ]; then
    meow_erro "AREAS_ENCAIXE tem ${#encaixes[@]} resposta(s) para ${#pedidos[@]} área(s)"
    meow_aviso "use uma resposta (vale para todas) ou uma por área, na mesma ordem."
    return "$MEOW_ERRO"
  fi

  local pendencia="$MEOW_OK" uniforme=1 primeiro=""
  for i in "${!pedidos[@]}"; do
    n="${pedidos[$i]}"
    for b in ${folgas[@]+"${folgas[@]}"}; do
      [ "$b" = "$n" ] && { n="$AREAS_FIGURA$n$AREAS_FIGURA"; break; }
    done

    AREAS_ALVO_NOME+=("$n")

    local e=""
    if [ "${#encaixes[@]}" -eq 1 ]; then e="${encaixes[0]}"
    elif [ "${#encaixes[@]}" -gt 0 ]; then e="${encaixes[$i]}"; fi
    if [ -n "$e" ]; then
      e="$(_areas_bool "$e")" || {
        meow_erro "AREAS_ENCAIXE tem '${encaixes[$i]:-${encaixes[0]}}' — esperado sim ou nao"
        return "$MEOW_ERRO"; }
      [ -z "$primeiro" ] && primeiro="$e"
      [ "$e" = "$primeiro" ] || uniforme=0
    fi
    AREAS_ALVO_ENCAIXE+=("$e")
  done

  if [ -n "$primeiro" ] && [ -n "$JANELAS_TILING" ]; then
    local jt; jt="$(_areas_bool "$JANELAS_TILING")" || jt=""
    if [ "$uniforme" = "0" ] || { [ -n "$jt" ] && [ "$jt" != "$primeiro" ]; }; then
      meow_aviso "AREAS_ENCAIXE e JANELAS_TILING discordam sobre o mesmo campo."
      meow_aviso "o janelas.sh grava tiling_enabled em TODAS as áreas de uma vez, e o"
      meow_aviso "'meow doctor' o chama todo dia — o que eu gravar por área ele achata."
      meow_aviso "esvazie JANELAS_TILING no meow.conf para o encaixe ser por área."
      meow_aviso "não gravei o encaixe: gravar e ver voltar amanhã é pior que não gravar."
      for i in "${!AREAS_ALVO_ENCAIXE[@]}"; do AREAS_ALVO_ENCAIXE[i]=""; done
      pendencia="$AREAS_PENDENCIA"
    fi
  fi
  return "$pendencia"
}

_areas_saida_em_uso() {
  meow_tem cosmic-randr || return 1
  cosmic-randr list 2>/dev/null \
    | sed -E 's/\x1b\[[0-9;]*m//g' \
    | LC_ALL=C awk '
        /^[^ ]/ { nome = (index($0, "(enabled)") > 0) ? $1 : ""
                  if (nome != "" && primeira == "") primeira = nome
                  next }
        nome != "" && /^  Xwayland primary:/ && $3 == "true" { print nome; achou = 1; exit }
        END { if (!achou && primeira != "") print primeira }'
}

cmd_alfinetar_primeira() {
  _areas_dependencia || return $?

  _areas_ler || return $?
  if [ "${#AREAS_NOME[@]}" -gt 0 ]; then
    meow_ok "já há ${#AREAS_NOME[@]} área(s) alfinetada(s) — nada a criar"
    meow_info "para nomeá-las como o meow.conf pede:  meow areas aplicar"
    meow_pendencia_resolvida areas-sem-alfinete
    return "$MEOW_OK"
  fi

  local primeiro
  primeiro="$(_areas_partir "$AREAS_NOMES" | head -1)"
  if [ -z "$primeiro" ]; then
    meow_pula "AREAS_NOMES vazio — as áreas de trabalho são suas"
    meow_info "falta o nome da primeira área (no painel, «Nomes das áreas de trabalho»)"
    return "$MEOW_OK"
  fi
  _areas_nome_seguro "$primeiro" || return "$MEOW_ERRO"

  local saida
  saida="$(_areas_saida_em_uso)"
  if [ -z "$saida" ]; then
    meow_erro "nenhuma saída de vídeo ligada segundo o cosmic-randr"
    meow_aviso "sem conector não há a que amarrar a área — e um monitor inventado"
    meow_aviso "poria a área numa saída que não existe."
    return "$MEOW_ERRO"
  fi

  local encaixe=""
  if [ -n "$AREAS_ENCAIXE" ]; then
    encaixe="$(_areas_bool "$(_areas_partir "$AREAS_ENCAIXE" | head -1)")" || encaixe=""
  fi

  _areas_montar_texto primeira "$saida" "$encaixe" "$primeiro" || {
    meow_erro "não consegui montar o pinned_workspaces"; return "$MEOW_ERRO"; }
  _areas_recusar_vazio "$AREAS_TEXTO" || return "$MEOW_ERRO"

  if meow_seco; then
    meow_muda "criaria o primeiro alfinete «$primeiro» em $saida"
    return "$MEOW_DIVERGENTE"
  fi

  _areas_guardar || return "$MEOW_ERRO"
  mkdir -p "$AREAS_BASE" 2>/dev/null || {
    meow_erro "não consegui criar $AREAS_BASE"; return "$MEOW_ERRO"; }
  meow_escrever "$AREAS_ALVO" "$AREAS_TEXTO" 644
  case $? in
    "$MEOW_ERRO") meow_erro "não consegui escrever $AREAS_ALVO"; return "$MEOW_ERRO" ;;
  esac
  meow_muda "primeiro alfinete criado: «$primeiro» em $saida"
  meow_pendencia_resolvida areas-sem-alfinete
  _areas_so_no_login
  meow_info "depois do próximo login:  meow areas aplicar  escreve o resto da lista"
  return "$MEOW_DIVERGENTE"
}

cmd_aplicar() {
  if [ -z "$AREAS_NOMES" ] && [ -z "$AREAS_ENCAIXE" ]; then
    meow_pula "AREAS_NOMES vazio — as áreas de trabalho são suas"
    meow_info "para ver as de agora e a linha pronta:  ./scripts/areas.sh estado"
    return "$MEOW_OK"
  fi
  _areas_dependencia || return $?

  _areas_ler || return $?

  if [ ! -f "$AREAS_ALVO" ] || [ "${#AREAS_NOME[@]}" -eq 0 ]; then
    if [ -z "$(_areas_partir "$AREAS_NOMES" | head -1)" ]; then
      meow_pendencia_acionavel areas-sem-alfinete \
        "Nenhuma área de trabalho está fixada, e o nome da primeira é escolha sua: escreva-o em AREAS_NOMES (no painel ou no meow.conf) e eu crio a área" \
        ""
    else
      meow_pendencia_acionavel areas-sem-alfinete \
        "Nenhuma área de trabalho está fixada; sem isso não sei em que monitor escrever" \
        "meow areas alfinetar-primeira"
    fi
    return "$AREAS_PENDENCIA"
  fi

  meow_pendencia_resolvida areas-sem-alfinete

  local rc_plano; _areas_planejar; rc_plano=$?
  [ "$rc_plano" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"

  local encaixes_csv="" sep="" e
  for e in ${AREAS_ALVO_ENCAIXE[@]+"${AREAS_ALVO_ENCAIXE[@]}"}; do
    encaixes_csv="$encaixes_csv$sep$e"; sep=","
  done
  encaixes_csv=""; sep=""
  local i
  for i in "${!AREAS_ALVO_NOME[@]}"; do
    encaixes_csv="$encaixes_csv$sep${AREAS_ALVO_ENCAIXE[$i]}"; sep=","
  done

  local novo erro
  erro="$(_areas_motor montar "$AREAS_ALVO" "$encaixes_csv" \
            "${AREAS_ALVO_NOME[@]}" 2>&1 >/dev/null)"
  if [ -n "$erro" ]; then
    meow_erro "não consegui montar o pinned_workspaces: $erro"
    return "$MEOW_ERRO"
  fi
  _areas_montar_texto montar "$AREAS_ALVO" "$encaixes_csv" "${AREAS_ALVO_NOME[@]}"
  novo="$AREAS_TEXTO"
  _areas_recusar_vazio "$novo" || return "$MEOW_ERRO"

  _areas_ler_arquivo "$AREAS_ALVO"
  if [ "$novo" = "$AREAS_TEXTO" ]; then
    meow_ok "as áreas de trabalho já estavam assim ($(_areas_juntar "${AREAS_ALVO_NOME[@]}"))"
    meow_registrar "areas.sh aplicar rc=$rc_plano (sem mudança)"
    return "$rc_plano"
  fi

  _areas_guardar || return "$MEOW_ERRO"
  local rc; meow_escrever "$AREAS_ALVO" "$novo" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui gravar $AREAS_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      if meow_seco; then
        meow_muda "gravaria as áreas: $(_areas_juntar "${AREAS_ALVO_NOME[@]}")"
      else
        meow_muda "áreas de trabalho gravadas: $(_areas_juntar "${AREAS_ALVO_NOME[@]}")"
        _areas_so_no_login
      fi ;;
  esac
  [ "$rc_plano" = "$AREAS_PENDENCIA" ] && rc="$AREAS_PENDENCIA"
  meow_registrar "areas.sh aplicar areas=${#AREAS_ALVO_NOME[@]} rc=$rc"
  return "$rc"
}

cmd_conferir() {
  if [ -z "$AREAS_NOMES" ] && [ -z "$AREAS_ENCAIXE" ]; then
    meow_pula "AREAS_NOMES vazio — nada a conferir (as áreas são suas)"
    return "$MEOW_OK"
  fi
  _areas_dependencia || return $?
  _areas_ler || return $?
  [ "${#AREAS_NOME[@]}" -gt 0 ] || { meow_aviso "nenhuma área alfinetada"; return "$AREAS_PENDENCIA"; }

  local rc_plano; _areas_planejar; rc_plano=$?
  [ "$rc_plano" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"

  local i divergente=0
  for i in "${!AREAS_ALVO_NOME[@]}"; do
    if [ "$i" -ge "${#AREAS_NOME[@]}" ]; then
      meow_muda "área $((i + 1)) '${AREAS_ALVO_NOME[$i]}' não existe no disco"
      divergente=1; continue
    fi
    [ "${AREAS_ALVO_NOME[$i]}" = "${AREAS_NOME[$i]}" ] || {
      meow_muda "área $((i + 1)): disco='${AREAS_NOME[$i]}', conf pede '${AREAS_ALVO_NOME[$i]}'"
      divergente=1; }
    [ -z "${AREAS_ALVO_ENCAIXE[$i]}" ] || \
      [ "${AREAS_ALVO_ENCAIXE[$i]}" = "${AREAS_TILING[$i]}" ] || {
        meow_muda "área $((i + 1)) encaixe: disco='${AREAS_TILING[$i]}', conf pede '${AREAS_ALVO_ENCAIXE[$i]}'"
        divergente=1; }
  done

  if [ "$divergente" = "0" ]; then
    [ "$rc_plano" = "$MEOW_OK" ] && meow_ok "as áreas de trabalho estão conformes"
    return "$rc_plano"
  fi
  _areas_so_no_login
  [ "$rc_plano" = "$AREAS_PENDENCIA" ] && return "$AREAS_PENDENCIA"
  return "$MEOW_DIVERGENTE"
}

cmd_reverter() {
  _areas_dependencia || return $?
  local guardado="$AREAS_ANTES/pinned_workspaces.antes"
  if [ ! -f "$guardado" ]; then
    meow_pula "não há estado de antes em $guardado — este script nunca escreveu aqui"
    meow_info "as cópias por passagem, se houver, estão em $MEOW_ESTADO/backups/*-areas/"
    return "$AREAS_PENDENCIA"
  fi
  local texto; _areas_ler_arquivo "$guardado"; texto="$AREAS_TEXTO"
  _areas_recusar_vazio "$texto" || return "$MEOW_ERRO"
  _areas_ler_arquivo "$AREAS_ALVO"
  if [ "$texto" = "$AREAS_TEXTO" ]; then
    meow_ok "as áreas já estavam como antes da nossa primeira escrita"
    return "$MEOW_OK"
  fi

  local rc; meow_escrever "$AREAS_ALVO" "$texto" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui devolver $AREAS_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "devolveria as áreas de trabalho de antes" \
                || { meow_muda "áreas de trabalho devolvidas ao estado de antes"; _areas_so_no_login; } ;;
    *) meow_ok "as áreas já estavam como antes da nossa primeira escrita" ;;
  esac
  meow_registrar "areas.sh reverter rc=$rc"
  return "$rc"
}

cmd_desalfinetar() {
  local alvo="${1:-}"
  [ -n "$alvo" ] || { meow_erro "uso: areas.sh desalfinetar <nome>"; return "$MEOW_ERRO"; }
  _areas_dependencia || return $?
  _areas_ler || return $?

  local i achado=-1
  for i in "${!AREAS_NOME[@]}"; do
    [ "$(_areas_sem_folga "${AREAS_NOME[$i]}")" = "$alvo" ] && { achado="$i"; break; }
  done
  if [ "$achado" -lt 0 ]; then
    meow_erro "não há área alfinetada chamada '$alvo'"
    meow_info "as que existem:  ./scripts/areas.sh estado"
    return "$MEOW_ERRO"
  fi
  if [ "${#AREAS_NOME[@]}" -le 1 ]; then
    meow_erro "recusado: '$alvo' é a última área alfinetada"
    meow_aviso "sem nenhum alfinete o cosmic-comp destrói o workspace ao esvaziar."
    return "$MEOW_ERRO"
  fi

  meow_aviso "TIRAR O ALFINETE DE '$alvo' (id ${AREAS_ID[$achado]:-<sem id>}) CUSTA:"
  meow_aviso "  · o nome some — o painel passa a mostrar a POSIÇÃO da área;"
  meow_aviso "  · a área é DESTRUÍDA pelo cosmic-comp assim que ficar vazia;"
  meow_aviso "  · as áreas seguintes ANDAM uma posição, e o que dependia da"
  meow_aviso "    posição delas (atalhos, parking de janela) passa a mirar outra."
  if [ "${MEOW_SIM:-0}" != "1" ]; then
    meow_erro "não fiz nada. Se é isso mesmo que você quer:"
    meow_erro "  MEOW_SIM=1 ./scripts/areas.sh desalfinetar '$alvo'"
    return "$AREAS_PENDENCIA"
  fi
  local novo erro
  erro="$(_areas_motor tirar "$AREAS_ALVO" "$achado" 2>&1 >/dev/null)"
  [ -n "$erro" ] && { meow_erro "não consegui tirar a área: $erro"; return "$MEOW_ERRO"; }
  _areas_montar_texto tirar "$AREAS_ALVO" "$achado"
  novo="$AREAS_TEXTO"
  _areas_recusar_vazio "$novo" || return "$MEOW_ERRO"

  _areas_guardar || return "$MEOW_ERRO"
  local rc; meow_escrever "$AREAS_ALVO" "$novo" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui gravar $AREAS_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "tiraria o alfinete de '$alvo'" \
                || { meow_muda "alfinete de '$alvo' retirado"; _areas_so_no_login
                     meow_info "para voltar atrás:  ./scripts/areas.sh reverter" ; } ;;
  esac
  meow_registrar "areas.sh desalfinetar '$alvo' rc=$rc"
  return "$rc"
}

case "${1:-estado}" in
  estado)        cmd_estado ;;
  conferir)      cmd_conferir ;;
  aplicar)       cmd_aplicar ;;
  alfinetar-primeira) cmd_alfinetar_primeira ;;
  reverter)      cmd_reverter ;;
  desalfinetar)  shift; cmd_desalfinetar "${1:-}" ;;
  *) meow_erro "uso: areas.sh {estado|conferir|aplicar|alfinetar-primeira|reverter|desalfinetar <nome>}"
     exit "$MEOW_ERRO" ;;
esac
