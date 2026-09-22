#!/usr/bin/env bash
# pack.sh — um pack de TERCEIRO instala inteiro, ou para inteiro.
#
# POR QUE ESTE ARQUIVO NASCEU EM 21/09/2026
#   Uma varredura de acoplamento perguntou o que aconteceria com um pack que não
#   fosse nem o Catppuccin nem o Dracula. A resposta, medida por leitura, foi a
#   pior possível:
#
#     1. `gerar_temas.py` falha duro:            flavor 'nord' desconhecido
#     2. `gerar_icones_autorais.py` levanta      KeyError
#     3. o `concluir()` marca as duas em FALHOS  — E O INSTALADOR SEGUE
#     4. pastas, mimetypes, agente, papel de parede e painel saem CATPPUCCIN
#
#   O estranho termina com uma máquina metade Nord, metade Catppuccin, e um log
#   dizendo que duas etapas falharam. Nenhum teste fazia essa pergunta.
#
#   A CAUSA RAIZ era a ponte shell->Python não existir: `MEOW_PALETA` não era
#   exportada por ninguém, então TODO consumidor em Python caía no
#   `assets/paleta/catppuccin.json`, sempre, houvesse o pack que houvesse. Este
#   teste é o que impede a ponte de sumir de novo — e ela sumiria calada, que é
#   como ela nasceu ausente.
#
# O PACK `nord` É DE MENTIRA, E ISSO É O RECURSO
#   Ele é montado num diretório temporário a cada rodada, apontado por
#   `$MEOW_PACKS`, com 26 slots derivados de uma cor só. Não é um tema bonito —
#   é um pack que NÃO É NENHUM DOS DOIS que este repositório conhece, que é
#   exatamente a pergunta. Versionar um `packs/nord/` de brinquedo poria arte
#   morta no repositório e daria ao `meow pack listar` um pack que ninguém quer.
#
# O QUE ELE NÃO FAZ, E É DE PROPÓSITO
#   Não roda o `install.sh` até o fim, nem escreve uma linha fora do temporário.
#   A promessa "instala inteiro ou para inteiro" é medida onde ela de fato mora:
#   a RECUSA acontece antes da primeira escrita, e a ORDEM disso dentro do
#   `main()` é conferida no código. Um teste que instalasse de verdade para
#   provar que a recusa funciona seria um teste que escreve na máquina de quem o
#   roda para provar que nada foi escrito.
#
# O ID DO PACK VEM POR ARGUMENTO, E O PADRÃO É `nord`
#   `./tests/pack.sh nord` é a linha que a spec da P20 manda rodar, e ela tem de
#   funcionar como está escrita. O argumento não é enfeite: trocá-lo prova que
#   nada aqui — nem no código que ele mede — depende do NOME do pack. Um teste
#   que só passasse com `nord` teria o defeito que veio caçar.
#
#   0 = o pack de terceiro é honrado · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ID="${1:-nord}"
case "$ID" in
  -h|--ajuda|--help)
    printf './tests/pack.sh [id]   monta um pack de mentira com esse id (padrão: nord)\n'; exit 0 ;;
  ''|*[!a-z0-9-]*|[!a-z]*)
    printf 'uso: %s [id]   — só minúsculas, dígitos e hífen, como o formato exige\n' \
      "$(basename "$0")" >&2; exit 2 ;;
esac
falhas=0
ok()     { printf 'ok: %s\n' "$1"; }
falha()  { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
PACKS="$T/packs"; PACK_DIR="$PACKS/$ID"; mkdir -p "$PACK_DIR" "$T/saida"

# --- o pack de mentira -------------------------------------------------------
# Os 26 slots saem de uma rampa entre o fundo e o texto do Nord, e o contraste
# entre `text` e `base` passa folgado dos 4.5:1 que o validador cobra. O que
# importa aqui não é a arte: é o pack existir fora de `RAIZ/packs`.
python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, sys, os
dir_pack, ident = sys.argv[1], sys.argv[2]
SLOTS = ["rosewater","flamingo","pink","mauve","red","maroon","peach","yellow",
         "green","teal","sky","sapphire","blue","lavender","text","subtext1",
         "subtext0","overlay2","overlay1","overlay0","surface2","surface1",
         "surface0","base","mantle","crust"]
claros = dict.fromkeys(SLOTS, "#D8DEE9")
escuro = dict.fromkeys(SLOTS, "#88C0D0")
escuro.update({"text": "#ECEFF4", "base": "#2E3440", "mantle": "#3B4252",
               "crust": "#434C5E", "mauve": "#B48EAD"})
claros.update({"text": "#2E3440", "base": "#ECEFF4", "mantle": "#E5E9F0",
               "crust": "#D8DEE9", "mauve": "#B48EAD"})
json.dump({"_comentario": "Pack de mentira do tests/pack.sh. Nao e o Nord de verdade.",
           "fonte": "https://www.nordtheme.com",
           "ordem_canonica": SLOTS,
           "claros": [ident + "claro"],
           "nomes": {ident: ident.capitalize(), ident + "claro": ident.capitalize() + " Claro"},
           "flavors": {ident: escuro, ident + "claro": claros}},
          open(os.path.join(dir_pack, "paleta.json"), "w"), indent=2, ensure_ascii=False)
json.dump({"formato": 1, "id": ident, "nome": ident.capitalize(),
           "paleta": {"arquivo": "paleta.json", "flavor_padrao": ident},
           "cosmic": {"nome_da_paleta": ident + "-<flavor>"}},
          open(os.path.join(dir_pack, "pack.json"), "w"), indent=2, ensure_ascii=False)
PY

# O ambiente de um pack de terceiro: ele mora onde `$MEOW_PACKS` aponta, e NÃO
# em `RAIZ/packs`. É aí que a quinta cópia da lista de raízes morria.
# `ID` vai no ambiente porque os `bash -c '...'` abaixo são de aspas SIMPLES —
# o texto deles é do shell FILHO, de propósito (aspas duplas fariam o pai expandir
# `$MEOW_PALETA` antes de a ponte existir, e o teste mediria o nada).
amb() { env MEOW_PACKS="$PACKS" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" ID="$ID" "$@"; }
printf 'FLAVOR="%s"\nACCENT="mauve"\nMODO="escuro"\nLOGO="%s"\nPACK="%s"\n' \
  "$ID" "$ID" "$ID" > "$T/meow.conf"

# --- 1. o pack de terceiro é ENCONTRADO fora de RAIZ/packs -------------------
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o pack em \$MEOW_PACKS é encontrado e validado" \
  || falha "o pack em \$MEOW_PACKS não validou (rc=$rc)" "$saida"

# --- 2. a ponte shell->Python existe e aponta para o pack --------------------
# É o conserto mais barato da P20 e o que desbloqueia todos os outros: sem ele
# nenhum gerador em Python enxerga o pack, e nada do que vem abaixo é sequer
# observável.
saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  PACK="$ID" FLAVOR="$ID" meow_ponte_python >/dev/null 2>&1 || exit 9
  printf "%s\n%s\n" "$MEOW_PALETA" "$MEOW_PACK_DIR"')"; rc=$?
if [ "$rc" != "0" ]; then
  falha "meow_ponte_python falhou com um pack legítimo (rc=$rc)" "$saida"
else
  case "$saida" in
    "$PACK_DIR/paleta.json"*) ok "a ponte exporta MEOW_PALETA apontando para o pack" ;;
    *) falha "MEOW_PALETA não é a paleta do pack" "$saida" ;;
  esac
  case "$saida" in
    *"$PACK_DIR") ok "a ponte exporta MEOW_PACK_DIR apontando para o pack" ;;
    *) falha "MEOW_PACK_DIR não é o diretório do pack" "$saida" ;;
  esac
fi

# --- 3. a paleta que não existe PARA, e a mensagem nomeia o arquivo ----------
# É a diferença entre "para inteiro" e "metade Nord, metade Catppuccin": exportar
# um caminho que não existe faria cada consumidor em Python falhar à sua maneira,
# no meio da fila de etapas.
saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  MEOW_PALETA=/tmp/nao-existe-mesmo.json meow_ponte_python' 2>&1)"; rc=$?
[ "$rc" = "2" ] \
  && ok "a ponte recusa a paleta inexistente (rc=2)" \
  || falha "a ponte aceitou uma paleta que não existe (rc=$rc)" "$saida"
case "$saida" in
  *nao-existe-mesmo.json*) ok "a recusa NOMEIA o arquivo que não existe" ;;
  *) falha "a recusa não disse qual arquivo faltava" "$saida" ;;
esac

# --- 4. a recusa vem ANTES da primeira escrita -------------------------------
# A ordem dentro do `main()` é o que torna "para inteiro" verdade: depois do
# `etapa_conf_ler` (a ponte precisa de PACK/FLAVOR), depois do desinstalar (quem
# vai embora não deve nada à paleta) e ANTES do pré-voo e do `meow_travar` — que
# é quando a senha é pedida e o lock é tomado.
#
# Conferido por NÚMERO DE LINHA no fonte, e não rodando o instalador: um teste
# que instalasse para provar que nada foi instalado é o próprio defeito.
l_ponte="$(grep -n '^  meow_ponte_python' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
l_pre="$(grep -n '^  meow_preflight' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
l_trava="$(grep -n '^  meow_travar' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
if [ -z "$l_ponte" ] || [ -z "$l_pre" ] || [ -z "$l_trava" ]; then
  falha "não achei a ponte, o pré-voo ou a trava no main() do install.sh" \
        "ponte=$l_ponte pre-voo=$l_pre trava=$l_trava"
elif [ "$l_ponte" -lt "$l_pre" ] && [ "$l_ponte" -lt "$l_trava" ]; then
  ok "a ponte roda antes do pré-voo e da trava (linhas $l_ponte < $l_pre, $l_trava)"
else
  falha "a ponte deixou de vir antes do pré-voo/trava" \
        "ponte=$l_ponte pre-voo=$l_pre trava=$l_trava"
fi

# --- 5. o gerador de temas honra o pack, inteiro ------------------------------
# As DUAS metades de uma vez: as cores vêm da paleta do pack (sem a ponte isto
# morre com "flavor 'nord' desconhecido") e o NOME vem do `cosmic.nome_da_paleta`
# do pack (sem o leitor, o tema sairia chamado `catppuccin-nord` na GUI do
# COSMIC — que é como o Dracula desta casa estava gravado no disco).
saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  PACK="$ID" FLAVOR="$ID" meow_ponte_python >/dev/null 2>&1 || exit 9
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" "$ID-mauve" --saida "'"$T"'/saida"' 2>&1)"; rc=$?
if [ "$rc" != "0" ]; then
  falha "gerar_temas.py não gerou o tema do pack de terceiro (rc=$rc)" "$saida"
else
  nome="$(grep -m1 'name:' "$T/saida/meowsystem-$ID-mauve.ron" 2>/dev/null)"
  case "$nome" in
    *"\"$ID-$ID\""*) ok "o tema do pack se chama pelo pack, e não pelo Catppuccin" ;;
    *) falha "o palette.name não veio de cosmic.nome_da_paleta" "$nome" ;;
  esac
  # A cor tem de ser a do pack. Se ela viesse do embutido, o arquivo teria o base
  # do Catppuccin e ninguém perceberia — é a divergência silenciosa de sempre.
  grep -q '2E3440' "$T/saida/meowsystem-$ID-mauve.ron" \
    && ok "as cores do tema saíram da paleta do pack" \
    || falha "o tema não tem a cor de fundo do pack — a paleta veio de outro lugar"
fi

# --- 6. o arquivo declarado e ausente é ERRO ---------------------------------
# O `packs/dracula/pack.json` declarava `creditos: CREDITOS.md` sem o arquivo
# existir, e `meow pack validar dracula` saía 0. Um validador que carimba o que
# não conferiu ensina a declaração vazia.
python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo)); p["creditos"] = "CREDITOS.md"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  falha "o pack promete CREDITOS.md, não entrega, e mesmo assim validou" "$saida"
else
  ok "o arquivo declarado e ausente recusa o pack (rc=$rc)"
  case "$saida" in
    *CREDITOS.md*) ok "a recusa NOMEIA o arquivo prometido" ;;
    *) falha "a recusa não disse qual arquivo faltava" "$saida" ;;
  esac
fi
printf 'creditos do pack de mentira\n' > "$PACK_DIR/CREDITOS.md"

# --- 7. o campo sem leitor é AVISO NOMEADO, nunca silêncio -------------------
# Metade do que o `packs/dracula/pack.json` declara não tinha um único leitor em
# código. Um formato que aceita declaração morta ensina a escrever declaração
# morta: quem copia um pack.json repete os campos mortos achando que eles fazem
# alguma coisa.
python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo)); p["campo_que_ninguem_le"] = "x"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
case "$saida" in
  *campo_que_ninguem_le*) ok "o campo sem leitor aparece nomeado no aviso" ;;
  *) falha "o campo sem leitor passou em silêncio" "$saida" ;;
esac
[ "$rc" = "0" ] \
  && ok "o campo sem leitor é aviso, e não recusa" \
  || falha "o aviso de campo sem leitor recusou o pack (rc=$rc)" "$saida"

# --- 8. `caminho` continua sendo a sonda de existência -----------------------
# A ARMADILHA MEDIDA DA P20, e ela mata em silêncio: `lib/comum.sh` chama
# `pack.py caminho "$PACK" id`, joga a saída fora e só olha o código de retorno.
# Quem reaproveitar o nome `caminho` para outra semântica faz TODO script de
# shell deixar de enxergar o pack, sem erro nenhum na tela. Por isso o verbo do
# resolvedor de acervo chama-se `acervo`.
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && ok "o verbo 'caminho' ainda responde como sonda de existência" \
  || falha "o verbo 'caminho' parou de servir de sonda — o lib/comum.sh deixa de ver o pack, calado"

# --- 9. o resolvedor de acervo sobe pack -> herança -> motor -----------------
mkdir -p "$PACK_DIR/icones"
printf 'firefox : apps/firefox.svg\n' > "$PACK_DIR/icones/apps.map"
python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"] = {"apps": {"mapa": "icones/apps.map"}}
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" acervo "$ID" icones.apps.mapa 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$saida" = "$PACK_DIR/icones/apps.map" ] \
  && ok "o acervo do pack de terceiro resolve fora de RAIZ/packs" \
  || falha "o acervo não resolveu o mapa do pack (rc=$rc)" "$saida"
amb python3 "$RAIZ/scripts/pack.py" acervo "$ID" icones.pastas.desenhos >/dev/null 2>&1 \
  && falha "o acervo inventou um caminho para uma categoria que o pack não declara" \
  || ok "categoria não declarada devolve ausência, e não um caminho torto"

# --- 10. a lista de raízes é UMA, e todo mundo pergunta a ela ----------------
# Eram quatro cópias digitadas (pack.py, duas no comum.sh, servidor.py) e uma
# quinta que só conhecia `RAIZ/packs`. Nenhuma divergência entre elas dá erro:
# some um pack da tela, calado.
raizes="$(amb python3 "$RAIZ/scripts/pack.py" raizes)"
case "$raizes" in
  "$PACKS"*) ok "as raízes honram \$MEOW_PACKS, e ele vem primeiro" ;;
  *) falha "\$MEOW_PACKS não é a primeira raiz" "$raizes" ;;
esac
dir_shell="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; PACK="$ID" meow_pack_dir')"
[ "$dir_shell" = "$PACK_DIR" ] \
  && ok "o shell acha o pack pela mesma lista de raízes" \
  || falha "meow_pack_dir não achou o pack em \$MEOW_PACKS" "$dir_shell"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack de terceiro é honrado de ponta a ponta"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1
