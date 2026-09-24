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
# A VITRINE ENTROU NO PACK MÍNIMO EM 23/09/2026 (P15): o `validar` cobra a
# capa, e um pack de mentira sem ela deixaria de validar no teste 1 por um
# motivo que não é o que o teste 1 pergunta. A capa é o `logo.svg`, e quem o
# escreve é o gerador da P25, logo abaixo. Até a revisão da P15 havia aqui
# também um SVG escrito à mão, que o gerador sobrescrevia na linha seguinte.
json.dump({"formato": 1, "id": ident, "nome": ident.capitalize(),
           "paleta": {"arquivo": "paleta.json", "flavor_padrao": ident},
           "cosmic": {"nome_da_paleta": ident + "-<flavor>"},
           "vitrine": {"capa": "logo.svg"}},
          open(os.path.join(dir_pack, "pack.json"), "w"), indent=2, ensure_ascii=False)
PY
# O PACK DE MENTIRA TAMBÉM PRECISA DE CARA — 23/09/2026, sprint P25. Desde ela o
# `logo.svg` é obrigatório para PUBLICAR, e sem ele o verbo `validar` recusa o
# `nord`: medido na revisão, caem as três conferências que pedem `validar` com
# saída 0 (a 1 e as duas da 7). O motor não cobra o logo, então a sonda
# `caminho` e a ponte seguem vendo o pack. Ele sai do GERADOR, e não de um SVG
# escrito aqui: é o que um pack novo de verdade recebe, e assim o gerador roda a
# cada rodada contra uma paleta que não é nenhuma das duas do repositório.
python3 "$RAIZ/scripts/pack.py" logo-gerado "$PACK_DIR" > "$PACK_DIR/logo.svg" || exit 2

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

# --- 11. o valor da ponte NÃO gruda no filho --------------------------------
# O defeito que a revisão de 22/09 mediu: a ponte exportava `MEOW_PALETA` e o
# `meow_paleta` devolvia essa variável em curto-circuito, ANTES de olhar o pack.
# Num processo de vida longa — `meow configurar`, que reescreve o meow.conf e
# depois chama o `install.sh` como filho — o filho herdava a resolução do PAI e
# nunca reresolvia: paleta do Catppuccin com `MEOW_PACK_DIR` do pack, um par que
# não fecha, e `flavor desconhecido` no gerador.
cat > "$T/filho.sh" <<'FILHO'
#!/usr/bin/env bash
. "$MEOW_RAIZ/lib/comum.sh"
meow_ponte_python >/dev/null 2>&1 || exit 9
printf '%s\n%s\n' "$MEOW_PALETA" "$MEOW_PACK_DIR"
FILHO
chmod +x "$T/filho.sh"
saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  PACK=catppuccin FLAVOR=mocha meow_ponte_python >/dev/null 2>&1 || exit 9
  export PACK="$ID" FLAVOR="$ID"
  exec "'"$T"'/filho.sh"')"; rc=$?
if [ "$rc" != "0" ]; then
  falha "a ponte do filho falhou depois de o pai ter resolvido o embutido (rc=$rc)" "$saida"
else
  case "$saida" in
    "$PACK_DIR/paleta.json"*) ok "o filho reresolve a paleta com o conf novo, e não herda a do pai" ;;
    *) falha "o filho herdou a paleta do pai — o eco da ponte voltou a grudar" "$saida" ;;
  esac
  # O PAR TEM DE FECHAR. Era esta a assinatura do defeito: o diretório de um
  # pack ao lado da paleta de outro, e nenhuma das duas partes errada sozinha.
  case "$saida" in
    *"$PACK_DIR") ok "a paleta e o diretório do pack saem do MESMO pack" ;;
    *) falha "a ponte exportou um par incoerente (paleta de um pack, diretório de outro)" "$saida" ;;
  esac
fi

# --- 12. a variável da PESSOA continua vencendo, inclusive no filho ---------
# A outra metade do mesmo conserto, e a que a conferência nº 1 da P20 cobra: o
# marcador distingue "eu mesmo exportei isto" de "a pessoa escolheu isto". Se ele
# passasse a jogar fora os dois casos, `MEOW_PALETA=... ./install.sh` deixaria de
# valer — e esse é o jeito de testar uma paleta sem editar o meow.conf.
#
# O caminho do embutido é PERGUNTADO ao `meow_paleta`, e não digitado aqui: o
# `tests/estilo.sh` recusa shell que resolva a paleta sozinho, e ele tem razão
# até dentro de um teste — foi um caminho digitado à mão que abriu a divergência
# que a P20 inteira veio fechar.
embutida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; PACK=catppuccin meow_paleta')"
saida="$(amb bash -c 'export MEOW_PALETA="'"$embutida"'"
  . "$MEOW_RAIZ/lib/comum.sh"
  PACK="$ID" FLAVOR="$ID" meow_ponte_python >/dev/null 2>&1 || exit 9
  export PACK="$ID" FLAVOR="$ID"
  exec "'"$T"'/filho.sh"')"; rc=$?
case "$saida" in
  "$embutida"*) ok "o MEOW_PALETA da pessoa atravessa o filho sem ser reresolvido" ;;
  *) falha "a escolha da pessoa foi descartada pelo filho (rc=$rc)" "$saida" ;;
esac

# --- 13. o acervo não lê fora do pack ---------------------------------------
# O `validar` aplica o `_dentro` em `icones.*.mapa` e `desenhos`; o `acervo` só
# olhava `os.path.exists`, e ele é chamado SEM validação antes (o painel o chama
# direto). Um pack de terceiro com `"mapa": "../../algo"` era lido.
printf 'isto esta fora do pack\n' > "$T/fora-do-pack.map"
python3 - "$PACK_DIR" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"]["apps"]["mapa"] = "../../fora-do-pack.map"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" acervo "$ID" icones.apps.mapa 2>&1)"; rc=$?
case "$saida" in
  *fora-do-pack.map*"sai de dentro do pack"*) ok "o acervo recusa o caminho que sai do pack, e o NOMEIA" ;;
  *) falha "o acervo leu (ou calou) um caminho que sai de dentro do pack (rc=$rc)" "$saida" ;;
esac
python3 - "$PACK_DIR" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"]["apps"]["mapa"] = "icones/apps.map"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY

# --- 14. a paleta não tranca a porta de saída -------------------------------
# O `install.sh` põe a ponte DEPOIS do desinstalar de propósito — "quem está indo
# embora não deve nada à paleta". No `bin/meow` a ponte ficou pendurada no
# `carregar_conf`, e com isso o `desfazer`, o `status` e o `doctor` passaram a
# recusar por causa de um arquivo de cor. Conferido no FONTE, como o teste 4: os
# três não escrevem tema nenhum e pedem a ponte como opcional.
#
# O corpo vai para uma VARIÁVEL antes do grep, e não por um cano: com
# `set -o pipefail`, um `grep -q` que acha no começo fecha o cano e mata o `sed`
# com SIGPIPE — a busca teria achado e o teste falharia mesmo assim.
for verbo in cmd_status cmd_doctor cmd_desfazer; do
  corpo="$(sed -n "/^$verbo()/,/^}/p" "$RAIZ/bin/meow")"
  if printf '%s\n' "$corpo" | grep -q 'carregar_conf --ponte-opcional'; then
    ok "$verbo não é trancado pela paleta"
  else
    falha "$verbo voltou a depender da paleta para rodar"
  fi
done


# --- 15. o pack PADRÃO é um pack, e não uma exceção no código ---------------
# A P13, em 22/09/2026. Até ela, `PACK_PADRAO` chamava-se `PACK_EMBUTIDO`, não
# havia `packs/catppuccin/`, e `pack.py validar catppuccin` estourava um
# FileNotFoundError em `RAIZ/pack.json` — porque o `achar` devolvia a RAIZ para
# ele, e lá não há `pack.json`.
#
# O NOME DO PADRÃO É PERGUNTADO, NUNCA DIGITADO, pelo mesmo motivo que o `ID`
# deste teste vem por argumento: um teste que só passa com `catppuccin` teria o
# defeito que veio caçar. Quem responde é o verbo `padrao`.
padrao="$(amb python3 "$RAIZ/scripts/pack.py" padrao 2>/dev/null)"
if [ -z "$padrao" ] || [ ! -f "$padrao/pack.json" ]; then
  falha "o pack padrão não é um diretório com pack.json" "padrao=$padrao"
else
  ok "o pack padrão tem pack.json, como qualquer outro"
  saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$padrao" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "o pack padrão valida com as MESMAS regras do pack de terceiro" \
    || falha "o pack padrão não valida (rc=$rc)" "$saida"
  # Ele é o primeiro `pack.json` que alguém copia. Um campo sem leitor aqui
  # ensina a promessa vazia antes de ela ter conserto — ver o teste 7.
  case "$saida" in
    *"NENHUM código lê"*) falha "o pack padrão declara campo sem leitor" "$saida" ;;
    *) ok "o pack padrão sai limpo do aviso de campo sem leitor" ;;
  esac
fi

# --- 16. o padrão aparece na varredura, e não por linha especial ------------
# O `bin/meow:cmd_pack listar` tinha um `meow_info "catppuccin — Catppuccin
# (embutido, em assets/paleta/)"` com um comentário admitindo o defeito:
# "o embutido não tem pack.json e não aparece na varredura — mas existe, e
# esconder isso faria a lista mentir por omissão". A lista sai do DISCO; um pack
# que precisa de código para aparecer nela não é um pack.
corpo="$(sed -n '/^cmd_pack()/,/^}/p' "$RAIZ/bin/meow")"
if printf '%s\n' "$corpo" | grep -vE '^\s*#' | grep -q 'catppuccin'; then
  falha "cmd_pack voltou a cravar o nome de um pack em código" \
        "$(printf '%s\n' "$corpo" | grep -vE '^\s*#' | grep -n 'catppuccin')"
else
  ok "o cmd_pack não nomeia pack nenhum — a lista sai do disco"
fi
saida="$(env MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" MEOW_ESTADO="$T/estado" \
         "$RAIZ/bin/meow" pack listar 2>&1)"
linha_padrao="$(printf '%s\n' "$saida" | grep -F "$padrao" || true)"
[ -n "$linha_padrao" ] \
  && ok "o pack padrão aparece no 'meow pack listar' com o diretório dele" \
  || falha "o pack padrão sumiu da lista, ou entrou sem vir da varredura" "$saida"

# --- 17. nenhum código volta a cravar o caminho da paleta do padrão ---------
# A P13 tirou o literal `assets/paleta/catppuccin.json` de nove pontos de código.
# Sobrou UM, e ele está isentado abaixo com nome e motivo: são 9 -> 1, e não
# 9 -> 0. Fora dele, todo o resto pergunta: `pack.paleta_do_pack_ativo()` no
# Python, `meow_paleta`/`meow_pack_padrao_dir` no shell, e o nome do pack padrão
# mora em `scripts/pack.py:PACK_PADRAO`.
#
# COMENTÁRIO CONTINUA LIVRE, e o filtro é o MESMO do `tests/estilo.sh`: a
# citação que tem um `#` antes dela não conta. Reescrever a prosa para agradar um
# grep apagaria o porquê e não consertaria nada — e o histórico desta casa ("era
# `assets/paleta/catppuccin.json` cravado até a porta única") é exatamente o que
# explica por que a porta existe.
#
#   ELE SÓ PASSOU A SER O MESMO EM 22/09/2026. Estava escrito `[^#]*#`, sem o
#   resto: isso descarta QUALQUER linha que tenha um `#`, esteja ele onde
#   estiver. Um `PAL = "assets/paleta/catppuccin.json"  # nota` — código de
#   verdade, com prosa no fim — saía verde. O `.*` que veio depois é o que
#   exige que o `#` venha ANTES da citação, e é a forma que o
#   `tests/estilo.sh:94` já usava.
#
# `scripts/pack.py` SAI DA VARREDURA PORQUE É A PRÓPRIA PORTA — é a mesma
# isenção que o `tests/estilo.sh` dá ao `lib/comum.sh`, e pelo mesmo motivo: é
# ali que o nome do pack padrão tem o direito de morar. O preço está dito: uma
# docstring dele (prosa indentada, sem `#` na frente) escapa dos dois filtros
# acima, e por isso a isenção é por ARQUIVO e não por linha.
#
# O PADRÃO É MONTADO EM DUAS METADES, E NÃO É CAPRICHO
#   O `tests/estilo.sh` cobra qualquer `.sh` que escreva `assets/paleta` seguido
#   de uma barra e um nome — e esta linha, escrita inteira, casaria com a régua
#   dele: o teste que procura o defeito seria acusado de tê-lo. Partir a palavra
#   é o que diz "isto é um padrão de busca, não uma resolução de paleta". Quem
#   juntar as duas metades de volta pinta o CI de vermelho sem nada ter
#   acontecido.
_velho='assets/paleta'"/catppuccin\.json"

# O ENDEREÇO NOVO CONTA TANTO QUANTO O VELHO — 22/09/2026
#   A primeira versão desta conferência procurava SÓ o literal velho, e por isso
#   dava verde para um caminho cravado no endereço novo — o mesmo defeito com
#   outro CEP. Medido: `scripts/derivar_claro.py:79` atravessou a P13 trocando
#   `assets/paleta/catppuccin.json` por `packs/catppuccin/paleta.json`, e este
#   teste não viu. Um grep que só conhece o passado promete para sempre uma
#   coisa que deixou de conferir no dia em que a casa mudou.
#   Partido em duas metades por SIMETRIA com o `_velho`, e não por obrigação:
#   nenhuma régua de hoje procura `packs/<pack>/paleta.json` dentro de um teste.
#   Custa nada e tira a pergunta de quem ler os dois lado a lado.
_novo='packs/catppuccin'"/paleta\.json"

# `bin/` ENTRA PORQUE A CONFERÊNCIA DA SPRINT O INCLUI — e o `--include` precisa
# do nome inteiro: `bin/meow` não tem extensão, e `*.sh`/`*.py` o deixavam de
# fora sem uma palavra. Era um diretório inteiro fora da varredura.
#
# `scripts/derivar_claro.py` É ISENTO, E A ISENÇÃO TEM MOTIVO ESCRITO
#   Ele não resolve a paleta ATIVA: ele nomeia, lado a lado, as duas paletas de
#   que precisa — a do Dracula, que é a identidade, e a do Catppuccin, que é a
#   RÉGUA de luminância do Latte. Trocar a régua junto com o pack ativo faria a
#   saída dele deixar de ser reprodutível, e o cabeçalho da função diz isso com
#   todas as letras. É um gerador de tiro único, registrado como órfão em
#   `tests/orfaos.sh:119`, cuja saída já está colada em
#   `packs/dracula/paleta.json`. A isenção é por ARQUIVO, como a do `pack.py`, e
#   o preço é o mesmo: uma cravação NOVA dentro dele passaria verde. Está dito.
cravado="$(grep -rnE --include='*.sh' --include='*.py' --include='meow' \
             "($_velho|$_novo)" "$RAIZ/install.sh" "$RAIZ/lib" \
             "$RAIZ/scripts" "$RAIZ/app" "$RAIZ/bin" 2>/dev/null \
           | grep -v 'scripts/pack\.py:' \
           | grep -v 'scripts/derivar_claro\.py:' \
           | grep -vE ":[0-9]+:[^#]*#.*($_velho|$_novo)" \
           | grep -vE ':[0-9]+:\s*("""|#)' || true)"
if [ -n "$cravado" ]; then
  falha "código cravando o caminho da paleta do pack padrão:"
  printf '%s\n' "$cravado" | sed "s#^$RAIZ/#  #" >&2
else
  ok "nenhum código crava a paleta do pack padrão — todos passam pela porta"
fi

# --- 15. o acervo de ícone mora no pack, e nenhum desenho some no caminho ----
#
# A P27 DESCEU 55 DESENHOS DE `assets/icones/autorais/` PARA DENTRO DOS PACKS
#   Aquele diretório se chamava `autorais` e não dizia DE QUEM: guardava, lado a
#   lado, 44 do Catppuccin e 11 do Dracula. Quem trocava de pack levava os dois
#   montes. As três conferências abaixo são a trava dessa mudança.
#
# POR QUE NÃO UM NÚMERO CRAVADO
#   A spec manda "conta 3.566 SVG antes e depois". Um teste com esse número
#   dentro falharia na próxima sprint que desenhar um ícone — e o que ele
#   protege não é o total, é a IDENTIDADE: nenhum arquivo versionado pode deixar
#   de existir no disco. É isso que um `git mv` errado quebra, e é isso que se
#   mede sem número mágico.
# `-e` E NÃO `-d`: num WORKTREE o `.git` é um ARQUIVO que aponta para o
# repositório de verdade, não um diretório. Com `-d` as duas conferências abaixo
# se pulavam caladas justamente onde toda sprint deste projeto é desenvolvida —
# medido aqui em 22/09/2026, com o bloco inteiro sem imprimir uma linha. O
# `rev-parse` é o que decide de fato: ele responde pelos dois casos e também por
# quem rodar o teste de um tarball sem git nenhum.
if command -v git >/dev/null 2>&1 \
   && git -C "$RAIZ" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sumidos="$(git -C "$RAIZ" ls-files '*.svg' | while IFS= read -r f; do
               [ -e "$RAIZ/$f" ] || printf '%s\n' "$f"
             done)"
  [ -z "$sumidos" ] \
    && ok "todo SVG versionado existe no disco — nenhum sumiu numa mudança de casa" \
    || falha "SVG versionado que não está no disco:" "$sumidos"

  # A conferência 1 da spec: nenhum desenho DE TEMA sobrou em assets/icones/.
  # O `*/*.svg` é de propósito — pega um nível de subdiretório, que é onde os
  # acervos por flavor moravam. O `autorais/leitura/` sobrevive a ela porque
  # aqueles oito não têm flavor no nome: são recoloridos em tempo de build, e
  # por isso são do MOTOR e não de pack nenhum.
  restos="$(git -C "$RAIZ" ls-files 'assets/icones/*/*.svg' \
              | grep -E '(mocha|macchiato|frappe|latte|dracula|alucard)' || true)"
  [ -z "$restos" ] \
    && ok "nenhum desenho de tema ficou em assets/icones/ — todo ícone que veste alguém mora no pack" \
    || falha "desenho de flavor ainda em assets/icones/:" "$restos"
fi

# O BURACO DO ALUCARD, E ELE ERA ESTE — 22/09/2026
#   O flavor claro do Dracula nasceu em 19/09 e ficou com ZERO dos onze
#   autorais. No modo claro do Dracula esses ícones caíam no `latte`, que é o
#   claro do OUTRO pack — o mesmo defeito que o `packs/dracula/pack.json` já
#   tinha consertado para a PALETA e que continuou vivo para os ÍCONES mais três
#   dias, porque a paleta morava no pack e os desenhos não.
#
#   A TRAVA É POR FLAVOR VAZIO, E NÃO POR "TEM 11 DO ALUCARD"
#     Contar onze do alucard protegeria este caso e só ele. O defeito de verdade
#     é ESTRUTURAL: um flavor declarado na paleta que não tem desenho nenhum no
#     acervo cai, calado, no acervo de quem o pack herda — e num pack de
#     terceiro isso é a cara de outro tema. A pergunta certa é "algum flavor
#     deste pack está vazio enquanto um irmão dele não está?", e ela vale para o
#     pack que ainda nem foi escrito.
vazios="$(python3 - "$RAIZ" <<'PY'
import json, os, sys
raiz = sys.argv[1]
base = os.path.join(raiz, "packs")
for pid in sorted(os.listdir(base) if os.path.isdir(base) else []):
    dir_pack = os.path.join(base, pid)
    manifesto = os.path.join(dir_pack, "pack.json")
    if not os.path.isfile(manifesto):
        continue
    try:
        p = json.load(open(manifesto, encoding="utf-8"))
        declarado = ((p.get("icones") or {}).get("autorais") or {}).get("desenhos")
        if not declarado:
            continue
        acv = os.path.join(dir_pack, declarado)
        if not os.path.isdir(acv):
            continue
        arq = os.path.join(dir_pack, (p.get("paleta") or {}).get("arquivo", "paleta.json"))
        flavors = json.load(open(arq, encoding="utf-8")).get("flavors", {})
    except (OSError, ValueError):
        continue
    svgs = [a for a in os.listdir(acv) if a.endswith(".svg")]
    conta = {f: sum(1 for a in svgs if a.endswith("-%s.svg" % f)) for f in flavors}
    # Acervo autoral inteiro vazio é outra coisa — é um pack que não desenha,
    # e isso é legítimo. O achado é o flavor vazio ao lado de um irmão cheio.
    if any(conta.values()):
        for f, n in sorted(conta.items()):
            if n == 0:
                print("%s: o flavor %r não tem nenhum autoral, e os irmãos têm" % (pid, f))
PY
)"
[ -z "$vazios" ] \
  && ok "nenhum flavor cai no acervo autoral do vizinho — o claro de cada pack é dele" \
  || falha "flavor sem desenho autoral próprio (ele cai no acervo herdado, calado):" "$vazios"

# --- 16. o prefixo `motor:` tira a DECISÃO de assets/ sem duplicar o acervo --
#
#   Um mapa de pack diz "o Telegram veste o desenho X". A frase é decisão de
#   TEMA e mora no pack; o desenho X pode vir do acervo Arcticons, que são 113
#   SVG de terceiro e ferramenta compartilhada. Sem o prefixo só havia duas
#   saídas ruins: a decisão fica em `assets/`, ou cada pack carrega uma CÓPIA
#   dos 113 — e a segunda cópia defasa da primeira calado.
base_mapa="$PACK_DIR/icones"
saida="$(printf 'apps/x.svg\nmotor:arcticons/y.svg\n' \
           | amb python3 "$RAIZ/scripts/pack.py" alvo "$base_mapa" 2>/dev/null)"
esperado="$base_mapa/apps/x.svg
$RAIZ/assets/icones/arcticons/y.svg"
[ "$saida" = "$esperado" ] \
  && ok "'motor:' resolve em assets/icones/ e o resto cai dentro do pack" \
  || falha "o prefixo motor: não resolveu como o contrato manda" "$saida"

# UMA LINHA DE SAÍDA POR LINHA DE ENTRADA, E ISSO NÃO É DETALHE
#   Quem chama junta esta saída com os NOMES do mapa, lado a lado, com `paste`.
#   Uma linha a mais ou a menos veste cada aplicativo com o ícone do vizinho, e
#   não há erro nenhum na tela para dizer isso. Por isso a linha recusada sai
#   VAZIA em vez de sair fora.
entrada="$(printf 'apps/a.svg\n../../fora.svg\nmotor:../../../etc/passwd\napps/b.svg\n')"
n_ent=$(printf '%s\n' "$entrada" | wc -l)
n_sai=$(printf '%s\n' "$entrada" \
          | amb python3 "$RAIZ/scripts/pack.py" alvo "$base_mapa" 2>/dev/null | wc -l)
[ "$n_ent" = "$n_sai" ] \
  && ok "o resolvedor de alvo devolve uma linha por linha, mesmo recusando ($n_sai/$n_ent)" \
  || falha "o alvo perdeu o alinhamento entrada/saída — o paste vestiria o app errado" \
           "entrada=$n_ent saída=$n_sai"
fugas="$(printf '%s\n' "$entrada" \
           | amb python3 "$RAIZ/scripts/pack.py" alvo "$base_mapa" 2>/dev/null \
           | grep -v "^$base_mapa/" | grep -v "^$RAIZ/assets/icones/" | grep -v '^$' || true)"
[ -z "$fugas" ] \
  && ok "alvo que sai da raiz é recusado, e a linha volta vazia" \
  || falha "o resolvedor deixou um alvo escapar da raiz:" "$fugas"

# --- 16b. e o PARSER do mapa tem de entregar o prefixo inteiro --------------
#
#   O teste 16 acima alimenta o `pack.py alvo` pelo STDIN, e por isso ele passava
#   com o único ponto de integração que existe quebrado: o `_dracula_pares` do
#   `icones_apps_dracula.sh` cortava a linha com `awk -F:` e pegava `$2`, que
#   para `nome : motor:caminho` vale ` motor`. O alvo virava `<pack>/icones/motor`
#   e o prefixo nunca chegava ao resolvedor — nem para resolver, nem para ser
#   recusado. Um teste que pula o parser não mede o recurso; mede metade dele.
#
#   Então este mede a linha do mapa até o caminho no disco, com a função
#   VERBATIM do script — e o `sed` que a extrai é de propósito: copiar o `awk`
#   para cá criaria uma segunda cópia do parser, e seria ela que passaria no dia
#   em que a primeira quebrasse.
mapa_t="$T/apps-parser.map"
printf '%s\n' \
  'um.motor : motor:arcticons/telegram.svg' \
  'dois.pack : apps/Warehouse.svg' \
  'tres.comentario : apps/Warehouse.svg # a procedência não entra em nada' \
  > "$mapa_t"
pares="$(MAPA="$mapa_t" ICONES_BASE_MAPA="$base_mapa" RAIZ="$RAIZ" bash -c '
  set -uo pipefail
  eval "$(sed -n "/^_dracula_pares() {\$/,/^}\$/p" "$RAIZ/scripts/icones_apps_dracula.sh")"
  _dracula_pares' 2>/dev/null)"
esperado_p="um.motor	$RAIZ/assets/icones/arcticons/telegram.svg
dois.pack	$base_mapa/apps/Warehouse.svg
tres.comentario	$base_mapa/apps/Warehouse.svg"
[ "$pares" = "$esperado_p" ] \
  && ok "o parser do mapa entrega o prefixo 'motor:' inteiro ao resolvedor" \
  || falha "o parser do mapa truncou o caminho — o 'motor:' não chega ao resolvedor" "$pares"

# --- 17. a porta de quem ESCREVE responde antes de o diretório existir -------
#   O `acervo` só responde o que já está no disco, e essa é a resposta certa
#   para quem vai abrir. O gerador precisa do contrário: num pack novo o
#   `icones/autorais/` só passa a existir depois que ele escreve lá dentro. Se
#   as duas portas discordassem, o `completar_icones.sh` instalaria de um
#   diretório e o `gerar_icones_autorais.py` escreveria noutro — e o passo 2
#   procuraria a fonte que o passo 1 acabara de gravar.
onde="$(amb python3 "$RAIZ/scripts/pack.py" onde "$ID" icones.autorais.desenhos icones/autorais/ 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$onde" = "$PACK_DIR/icones/autorais/" ] && [ ! -d "$onde" ] \
  && ok "o 'onde' responde o endereço do acervo antes de ele existir" \
  || falha "o 'onde' não respondeu o acervo de um pack que ainda não o criou (rc=$rc)" "$onde"

# --- 18. a vitrine: o pack tem cara, e ela é cobrada — 23/09/2026, P15 -------
#
#   "Ninguém escolhe um tema por um `id`." O bloco `vitrine` é o que o cartão
#   de pack mostra, e a conferência da sprint é esta: com capa, `validar` sai 0;
#   sem ela, recusa nomeando o arquivo. As outras recusas são as quatro que a
#   sprint lista — capa que não é SVG, capa fora do pack, frase acima do teto,
#   URL que não é https —, mais a que a varredura genérica de URL não pega:
#   `javascript:` não tem `://`, e o `site` é o único campo que vira link.
#
#   QUAL PORTA COBRA O QUÊ, e isto também é cobrado aqui, porque o texto já
#   mentiu uma vez [23/09/2026, revisão da P15]. A vitrine é da porta de quem
#   PUBLICA: sem a capa, ou com a frase acima do teto, o `caminho` — a sonda de
#   existência do `meow_pack_dir` — continua vendo o pack, e o logo da P25 está
#   na mesma fronteira desde a a3ee4a6. A exceção é a URL fora de https, que é
#   regra do pack inteiro e roda no motor; o `pack.py` e o docs/PACKS.md diziam
#   que não. Cada afirmação do documento vira uma conferência abaixo, para a
#   próxima divergência aparecer aqui, e não numa revisão.
mkdir -p "$PACK_DIR/capturas"
printf '# %s\n\nHistória com <script>alert(1)</script> e **negrito**.\n' "$ID" > "$PACK_DIR/LEIA-ME.md"
printf '\x89PNG\r\n\x1a\n' > "$PACK_DIR/capturas/tela.png"
cp "$PACK_DIR/logo.svg" "$T/logo-guardado.svg"
# Uma capa que NÃO é o `logo.svg`, com `<script>` dentro. O logo é o arquivo
# que `vitrine.capa` nomeia (P25, a3ee4a6), então ela tem de passar pela
# conferência do logo — no `validar` e na porta do painel —, e não escapar dela
# por ter outro nome. É o achado 5.3 da revisão, medido do lado de cá.
sed 's#</svg>#<script>alert(1)</script></svg>#' "$PACK_DIR/logo.svg" > "$PACK_DIR/outra-capa.svg"
por_vitrine() {
  python3 - "$PACK_DIR" "$1" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["autor"] = "o tests/pack.sh"
if sys.argv[2] == "-":
    p.pop("vitrine", None)
else:
    p["vitrine"] = json.loads(sys.argv[2])
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
}
VIT_BOA='{"capa": "logo.svg", "descricao_curta": "Um pack de mentira, para o teste.",
          "descricao": "LEIA-ME.md", "tags": ["escuro", "teste"],
          "capturas": ["capturas/tela.png"], "site": "https://www.nordtheme.com"}'

por_vitrine "$VIT_BOA"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a vitrine completa valida (capa, frase, história, tags, captura, site)" \
  || falha "a vitrine completa foi recusada (rc=$rc)" "$saida"

# A conferência da sprint, literal: `info | head -6` traz nome, autor, frase,
# tags e o "próprio / herdado" numa linha só.
cabeca="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1 | head -6)"
case "$cabeca" in
  *"o tests/pack.sh"*"Um pack de mentira"*"escuro, teste"*"próprio: "*" · "*)
    ok "o info abre com autor, frase, tags e a linha próprio/herdado" ;;
  *) falha "as seis primeiras linhas do info não são a vitrine" "$cabeca" ;;
esac

rm -f "$PACK_DIR/logo.svg"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  falha "sem a capa, o pack validou" "$saida"
else
  case "$saida" in
    *vitrine.capa*logo.svg*) ok "sem a capa, validar recusa (rc=$rc) e nomeia o arquivo que falta" ;;
    *) falha "a recusa sem capa não nomeou o arquivo" "$saida" ;;
  esac
fi
# O docs/PACKS.md diz que a capa ausente não tira o tema do desktop. Se um dia a
# capa, ou o logo, voltar a ser cobrada na porta do motor, esta linha cai e
# manda corrigir o documento junto.
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && ok "sem a capa o motor continua vendo o pack — a vitrine não tranca o tema" \
  || falha "a capa ausente fez o pack sumir da sonda do meow_pack_dir"
cp "$T/logo-guardado.svg" "$PACK_DIR/logo.svg"

# O RESTO DA VITRINE NÃO TRANCA O MOTOR: com a frase acima do teto, `validar`
# recusa, e o `caminho` e o `info` continuam vendo o pack — o `info` dizendo o
# que falta.
por_vitrine '{"capa": "logo.svg", "descricao_curta": "12345678901234567890123456789012345678901234567890123456789012345678901234567890X"}'
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && ok "a frase acima do teto não tira o pack do motor" \
  || falha "a frase acima do teto fez o pack sumir da sonda do meow_pack_dir"
saida="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"NÃO VALIDA"*"81 caracteres"* ]] \
  && ok "o info mostra o pack de frase comprida, e diz o que falta" \
  || falha "o info escondeu o pack de frase comprida, ou não disse por quê (rc=$rc)" "$saida"

# A URL FORA DE https:// É REGRA DO PACK INTEIRO (item 11), e vale no motor
# desde antes da vitrine. Cobrado para o documento não voltar a dizer que só o
# verbo `validar` a vê.
por_vitrine '{"capa": "logo.svg", "site": "http://exemplo.org"}'
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && falha "o site em http:// não tirou o pack do motor — o docs/PACKS.md diz que tira" \
  || ok "o site em http:// tira o pack do motor, como toda URL fora de https"
por_vitrine "$VIT_BOA"

# As recusas uma a uma. Cada linha: o bloco vitrine, e o trecho que a mensagem
# precisa ter — a recusa que não diz o campo manda procurar no lugar errado.
while IFS='|' read -r bloco espera nome; do
  por_vitrine "$bloco"
  saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1 </dev/null)"; rc=$?
  if [ "$rc" != "0" ] && [[ "$saida" == *"$espera"* ]]; then
    ok "recusa $nome (rc=$rc)"
  else
    falha "não recusou $nome, ou não disse por quê (rc=$rc)" "$saida"
  fi
done <<'CASOS'
-|'vitrine'|o pack sem bloco vitrine
{"descricao_curta": "sem capa"}|vitrine.capa: é obrigatória|a vitrine sem capa declarada
{"capa": "capturas/tela.png"}|não é .svg|a capa que não é SVG
{"capa": "../fora.svg"}|sai de dentro do pack|a capa fora do pack
{"capa": "outra-capa.svg"}|outra-capa.svg: tem <script>|a capa que é outro SVG, com script: ela é o logo, e passa pela conferência dele
{"capa": "logo.svg", "descricao_curta": "12345678901234567890123456789012345678901234567890123456789012345678901234567890X"}|81 caracteres, e o teto é 80|a frase curta acima de 80
{"capa": "logo.svg", "site": "http://exemplo.org"}|só https|o site em http
{"capa": "logo.svg", "site": "javascript:alert(1)"}|vitrine.site|o site em javascript:
{"capa": "logo.svg", "descricao": "pack.json"}|vitrine.descricao|a história que não é Markdown
CASOS
por_vitrine "$VIT_BOA"

# O PAINEL: a história chega CRUA, e a arte só sai pelo que o pack declarou.
#   O `<script>` do LEIA-ME tem de chegar como texto no JSON — nem executado,
#   nem "limpo" pelo servidor: quem garante que ele não roda é o `<pre>` com
#   `textContent`, e um servidor que escapasse HTML esconderia um cliente que
#   voltou a usar `innerHTML`. A rota de arte não aceita caminho; `../` e
#   número fora da lista são "não achei".
saida="$(amb python3 - "$RAIZ" "$ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
ident = sys.argv[2]
achados = [p for p in servidor.packs_com_vitrine() if p["id"] == ident]
if not achados:
    print("o pack de mentira não veio no /api/packs"); sys.exit(1)
p = achados[0]
erros = []
if "<script>alert(1)</script>" not in p["descricao"]:
    erros.append("a história não chegou crua: %r" % p["descricao"][:80])
if not p["capa"] or p["problemas"]:
    erros.append("a capa não veio, ou veio com problema: %r %r" % (p["capa"], p["problemas"]))
if p["site"] != "https://www.nordtheme.com" or len(p["capturas"]) != 1:
    erros.append("site ou capturas errados: %r %r" % (p["site"], p["capturas"]))
if "próprio: " not in p["origem"] or len(p["amostra"]) != 26:
    erros.append("origem ou amostra errados: %r (%d cores)" % (p["origem"], len(p["amostra"])))
capa = servidor.arte_da_vitrine(ident, "capa")
if not capa or capa[1] != "image/svg+xml":
    erros.append("a capa não é servida como SVG: %r" % (capa and capa[1]))
# A capa sai do `logo()` no flavor padrão do pack (o `nord` de mentira usa o
# próprio id), e não dos bytes crus do arquivo — ver `arte_da_vitrine`.
elif capa[0].decode("utf-8") != servidor.modulo_pack().logo(ident, ident):
    erros.append("a capa servida não é o que o logo() responde no flavor padrão")
if not servidor.arte_da_vitrine(ident, "0"):
    erros.append("a captura declarada não é servida")
for arte in ("1", "../pack.json", "../../../etc/passwd", "-1", ""):
    if servidor.arte_da_vitrine(ident, arte) is not None:
        erros.append("a rota de arte serviu %r" % arte)
if servidor.arte_da_vitrine(os.path.join(sys.argv[1], "packs", "dracula"), "capa") is not None:
    erros.append("a rota de arte aceitou um CAMINHO no lugar do id")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o /api/packs leva a história crua, e a rota de arte só serve o que o pack declarou" \
  || falha "o painel não honra a vitrine" "$saida"

# A CAPA COM SCRIPT NÃO CHEGA AO PAINEL, e o cartão diz por quê. O motor não
# confere o logo desde a a3ee4a6 da P25, então quem segura aqui é o `logo()`,
# pelo qual o servidor passa a capa. O `info` também tem de dizer o motivo, em
# vez de listar a capa como boa enquanto o `validar` a recusa.
por_vitrine '{"capa": "outra-capa.svg"}'
saida="$(amb python3 - "$RAIZ" "$ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
ident = sys.argv[2]
p = [p for p in servidor.packs_com_vitrine() if p["id"] == ident][0]
erros = []
if servidor.arte_da_vitrine(ident, "capa") is not None:
    erros.append("a rota de arte serviu a capa com <script>")
if p["capa"] or not any("<script>" in x for x in p["problemas"]):
    erros.append("o cartão levou a capa, ou não disse o motivo: %r %r" % (p["capa"], p["problemas"]))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
info="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1)"
[ "$rc" = "0" ] && [[ "$info" == *"NÃO VALIDA"*"outra-capa.svg: tem <script>"* ]] \
  && ok "a capa com script não é servida, e o cartão e o info dizem por quê" \
  || falha "a capa com script chegou ao painel, ou ninguém disse por quê" "$saida
$info"
por_vitrine "$VIT_BOA"

# A REGRA DE SEGURANÇA, NO CÓDIGO DA PÁGINA. A história entra num `<pre>` por
# `texto` (textContent). Um `html:` ou um `innerHTML` dentro do cartão é o
# Markdown de terceiro virando HTML numa página com token de sessão.
corpo="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
if [ -z "$corpo" ]; then
  falha "não achei a função cartaoDePack em app/pagina/app.js"
elif printf '%s\n' "$corpo" | grep -vE '^\s*(\*|/\*|//)' | grep -qE '\bhtml:|innerHTML|insertAdjacentHTML'; then
  falha "o cartão de pack interpreta HTML — a história tem de ser texto puro" \
        "$(printf '%s\n' "$corpo" | grep -nE '\bhtml:|innerHTML|insertAdjacentHTML')"
elif printf '%s\n' "$corpo" | grep -q 'elemento("pre"' \
     && printf '%s\n' "$corpo" | grep -q 'texto: p.descricao'; then
  ok "a história do pack entra num <pre> como texto, sem interpretar nada"
else
  falha "o cartão de pack deixou de pôr a história num <pre> por texto"
fi

# --- 19. trocar de pack e voltar, conferindo o tema no disco — 23/09/2026, P10
#
#   A sprint: "`meow pack usar <id>` — escreve PACK= e FLAVOR= no meow.conf,
#   valida antes, e roda a aplicação". A aplicação é o `install.sh` inteiro, e
#   este arquivo não o roda (ver o cabeçalho). O que se confere é a CADEIA que
#   ele percorre: o verbo grava as duas chaves e mais nada; um shell novo,
#   lendo aquele conf, resolve o pack pela ponte; e o tema do COSMIC que esse
#   pack captura é o que vai para o disco — escrito aqui num COSMIC de
#   brinquedo, pelo mesmo `aplicar_tema.sh` que o instalador chama. Ida e volta,
#   porque a volta é o que prova que nada ficou grudado no primeiro.
#
#   TUDO DENTRO DO TEMPORÁRIO. `env -i` com HOME, conf e COSMIC próprios: o
#   `aplicar_tema.sh` escreve de verdade, e o endereço dele tem de ser o
#   brinquedo, nunca o `~/.config/cosmic` de quem roda o teste.
CASA="$T/casa"; mkdir -p "$CASA"
cp "$RAIZ/meow.conf.exemplo" "$T/usar.conf"
usar_amb() {
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/usar.conf" \
    MEOW_COSMIC_DIR="$CASA/cosmic" NO_COLOR=1 "$@"
}
# O tema que o conf de agora pediria: a ponte num shell NOVO, e o `aplicar_tema.sh`
# com o que ela exportou. Devolve o pack resolvido e o código do `--conferir`.
tema_do_conf() {
  usar_amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
    set -a; . "$MEOW_CONF"; set +a
    meow_ponte_python >/dev/null 2>&1 || exit 9
    par="$FLAVOR-$ACCENT"
    "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$par" >/dev/null 2>&1 || exit 8
    "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$par" --conferir >/dev/null 2>&1; rc=$?
    printf "%s %s %s\n" "$(basename "$MEOW_PACK_DIR")" "$par" "$rc"'
}
sem_as_duas() { grep -vE '^(PACK|FLAVOR)=' "$1"; }

antes="$(sem_as_duas "$T/usar.conf")"
saida="$(usar_amb "$RAIZ/bin/meow" pack usar dracula --sem-aplicar 2>&1)"; rc=$?
if [ "$rc" = "0" ] && grep -qx 'PACK="dracula"' "$T/usar.conf" \
   && grep -q '^FLAVOR="dracula"' "$T/usar.conf" \
   && [ "$(sem_as_duas "$T/usar.conf")" = "$antes" ]; then
  ok "meow pack usar grava PACK e FLAVOR, e nenhuma outra linha do conf"
else
  falha "meow pack usar dracula não gravou só as duas chaves (rc=$rc)" "$saida"
fi
ida="$(tema_do_conf)"
[ "$ida" = "dracula dracula-mauve 0" ] \
  && ok "depois da troca, o tema no disco é o do Dracula ($ida)" \
  || falha "o tema no disco não é o do pack escolhido" "esperava 'dracula dracula-mauve 0', veio '$ida'"

saida="$(usar_amb "$RAIZ/bin/meow" pack usar catppuccin --sem-aplicar 2>&1)"; rc=$?
volta="$(tema_do_conf)"
if [ "$rc" = "0" ] && grep -qx 'PACK="catppuccin"' "$T/usar.conf" \
   && [ "$volta" = "catppuccin mocha-mauve 0" ]; then
  ok "e a volta: o flavor que não é do pack cai no padrão dele, e o tema no disco acompanha ($volta)"
else
  falha "a volta ao Catppuccin não levou o tema junto (rc=$rc, veio '$volta')" "$saida"
fi
residuo="$(usar_amb "$RAIZ/scripts/aplicar_tema.sh" dracula-mauve --conferir >/dev/null 2>&1; echo $?)"
[ "$residuo" != "0" ] \
  && ok "o tema do pack de antes deixou de conferir: nada dele ficou no disco" \
  || falha "o COSMIC de brinquedo ainda confere com o Dracula depois da volta"

# A RECUSA VEM ANTES DA ESCRITA: um flavor que o pack não tem, um pack que não
# existe, e o ensaio — os três saem sem tocar um byte do conf.
copia="$(cat "$T/usar.conf")"
usar_amb "$RAIZ/bin/meow" pack usar dracula mocha --sem-aplicar >/dev/null 2>&1; r1=$?
usar_amb "$RAIZ/bin/meow" pack usar nao-existe --sem-aplicar >/dev/null 2>&1; r2=$?
usar_amb env MEOW_DRY_RUN=1 "$RAIZ/bin/meow" pack usar dracula --sem-aplicar >/dev/null 2>&1; r3=$?
if [ "$r1" != "0" ] && [ "$r2" != "0" ] && [ "$r3" = "1" ] && [ "$(cat "$T/usar.conf")" = "$copia" ]; then
  ok "flavor de outro pack, pack inexistente e ensaio saem sem escrever (rc=$r1 $r2 $r3)"
else
  falha "meow pack usar escreveu onde devia recusar (rc=$r1 $r2 $r3)" "$(diff <(printf '%s\n' "$copia") "$T/usar.conf")"
fi

# O NOME DO PACK NÃO IMPORTA: o de mentira, fora de RAIZ/packs, troca igual.
saida="$(usar_amb env MEOW_PACKS="$PACKS" "$RAIZ/bin/meow" pack usar "$ID" --sem-aplicar 2>&1)"; rc=$?
[ "$rc" = "0" ] && grep -qx "PACK=\"$ID\"" "$T/usar.conf" && grep -q "^FLAVOR=\"$ID\"" "$T/usar.conf" \
  && ok "o pack de terceiro também se usa pelo verbo, com o flavor padrão dele" \
  || falha "meow pack usar $ID não gravou o pack de terceiro (rc=$rc)" "$saida"

# O QUE FICOU DE OUTRO PACK É O QUE O PAINEL DIRIA — 23/09/2026, revisão da P10
#   A primeira versão do verbo refazia em `awk` a regra do «Vestígio do pack» e
#   perdia as duas exceções que o `_vestigio_de_pack` (app/servidor.py) já
#   tinha aprendido. Medido pela revisão, com o conf de fábrica e o Catppuccin no
#   ar: `usar dracula` acusava `CURSOR` de ser resto do Catppuccin — o valor que
#   o próprio `packs/dracula/pack.json` receita —, e prometia que o painel o
#   marcaria, enquanto o painel respondia `None`. No sentido inverso, com
#   `PACK=""` e um sabor no FLAVOR, o verbo calava o que o painel marca.
#   Os três casos abaixo são esses dois e o vestígio de verdade, e em cada um a
#   lista do terminal tem de ser a do painel lida no conf que a troca deixou.
vestigios_do_painel() {
  usar_amb env MEOW_CONF="$1" python3 - "$RAIZ" <<'PY' 2>/dev/null
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
print(" ".join(sorted(k for k in servidor.valores_brutos() if servidor._vestigio_de_pack(k))))
PY
}
vest_caso() {   # $1 rótulo · $2 pack a usar · $3 a chave que o caso exige ("" = nenhuma) · $4 sed do conf
  local conf="$T/vest.conf" saida painel k faltou=""
  sed "$4" "$RAIZ/meow.conf.exemplo" > "$conf"
  saida="$(usar_amb env MEOW_CONF="$conf" "$RAIZ/bin/meow" pack usar "$2" --sem-aplicar 2>&1)"
  painel="$(vestigios_do_painel "$conf")"
  for k in $painel; do grep -qw -- "$k" <<< "$saida" || faltou="$faltou $k"; done
  if [ -n "$3" ] && ! grep -qw -- "$3" <<< "$painel"; then
    falha "$1: o caso deixou de montar o que mede (o painel marca '$painel', esperava $3)"
  elif [ -z "$3" ] && { [ -n "$painel" ] || grep -q 'CURSOR' <<< "$saida"; }; then
    falha "$1: o terminal ou o painel acusam um vestígio que não existe (painel: '$painel')" "$saida"
  elif [ -n "$faltou" ]; then
    falha "$1: o painel marca$faltou e o terminal não disse" "$saida"
  else
    ok "$1 (painel: '${painel:-nenhum}')"
  fi
}
vest_caso "Catppuccin -> Dracula: o CURSOR que o Dracula receita não é vestígio" \
  dracula "" 's/^PACK=.*/PACK="catppuccin"/'
vest_caso "Dracula -> Catppuccin: o ICONES_BASE do Dracula é vestígio, e o terminal diz" \
  catppuccin ICONES_BASE 's/^PACK=.*/PACK="dracula"/; s/^FLAVOR=.*/FLAVOR="dracula"/; s/^ICONES_BASE=.*/ICONES_BASE="Dracula-Icones"/'
vest_caso "sabor sem PACK -> Dracula: o CURSOR do Latte é vestígio, e o terminal diz" \
  dracula CURSOR 's/^FLAVOR=.*/FLAVOR="latte"/; s/^CURSOR=.*/CURSOR="catppuccin-latte-dark"/'

# A ABA ÍCONES FALA COM AS PALAVRAS DO PACK NO AR. É a conferência da sprint no
# nível do dado que a página desenha: com o Dracula no ar, nenhuma opção
# oferecida carrega "Mocha" nem "Frappé", e o molde `${FLAVOR}` não é rótulo de
# nada — ele só existe como VALOR da primeira opção das pastas.
saida="$(env MEOW_RAIZ="$RAIZ" MEOW_PACK_DIR="$RAIZ/packs/dracula" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
esquema = servidor.ler_esquema()
vocab = servidor.modulo_pack().vocabulario("dracula")
servidor._com_o_vocabulario_do_pack(esquema, vocab, {"FLAVOR": "dracula"})
item = {i["chave"]: i for i in esquema}
erros = []
fl = item["ICONES_FLAVOR"]
if fl["opcoes"] != ["macchiato"] or fl["rotulos"].get("macchiato") != "Macchiato (herdado do Catppuccin)":
    erros.append("variante dos ícones de arquivo: %r %r" % (fl["opcoes"], fl.get("rotulos")))
if item["ICONES_DRACULA"]["titulo"] != "Ícones do pack nos aplicativos" \
        or "«Dracula»" not in item["ICONES_DRACULA"]["frase"]:
    erros.append("o ajuste dos ícones de aplicativo ainda nomeia um pack no rótulo")
molde = item["ICONES_PASTAS"]["molde_pastas"]
rotulos = [o["rotulo"] for o in molde["variantes"] + molde["cores"]]
for palavra in ("Mocha", "Frappé", "Latte", "${FLAVOR}", "${ACCENT}", "cat-"):
    if any(palavra in r for r in rotulos) or palavra in item["ICONES_PASTAS"]["frase"]:
        erros.append("as pastas ainda mostram %r" % palavra)
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "com o Dracula no ar, a aba Ícones oferece o vocabulário dele, e não o do Catppuccin" \
  || falha "a aba Ícones ainda fala Catppuccin com o Dracula no ar" "$saida"

# --- 20. o pack que viaja: novo, exportar, apagar, importar — 23/09/2026, P11 --
#
#   A conferência da sprint, em pequeno: `meow pack novo` a partir do que está
#   no ar (aqui, o pack de mentira), `exportar`, apagar, `importar` — e cada
#   arquivo que chegou com o MESMO sha256 com que saiu. Depois, as recusas que
#   são a regra dura da sprint, "um pack é dado, nunca é código", e a da
#   licença: cada uma tem de dizer QUAL arquivo, e nenhuma pode deixar nada
#   escrito para trás.
#
#   NADA SAI DO TEMPORÁRIO. O `novo` escreve em `$MEOW_PACKS`, a raiz de teste,
#   e o `importar` na raiz da pessoa — que aqui é um `XDG_DATA_HOME` de
#   brinquedo. Um teste de importação que escrevesse no ~/.local/share de quem
#   o roda instalaria um pack de mentira na máquina dela.
#
#   O `stdin` vem fechado: o `exportar` pergunta se as imagens vão junto quando
#   há terminal, e um teste não é alguém para responder.
viaja() { amb env XDG_DATA_HOME="$T/xdg" MEOW_ESTADO="$T/estado" "$@" </dev/null; }
somas() { ( cd "$1" && find . -type f -printf '%P\n' | LC_ALL=C sort | xargs -d '\n' sha256sum ); }
NOVO="$ID-viaja"
DA_PESSOA="$T/xdg/meowsystem/packs"
conf_antes="$(sha256sum < "$T/meow.conf")"

saida="$(viaja "$RAIZ/bin/meow" pack novo "$NOVO" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -f "$PACKS/$NOVO/pack.json" ]; then
  falha "meow pack novo não criou o pack (rc=$rc)" "$saida"
else
  ok "meow pack novo cria o pack a partir do que está no ar"
  cmp -s "$PACKS/$NOVO/paleta.json" "$PACK_DIR/paleta.json" \
    && ok "a paleta do pack novo é a que está no ar, byte a byte" \
    || falha "a paleta do pack novo não é a do pack no ar"
  # "Nunca referenciados por caminho absoluto": o resto vem por id, pela
  # herança, e nenhum valor do pack.json aponta para a máquina de quem criou.
  achado="$(python3 - "$PACKS/$NOVO/pack.json" "$ID" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
def andar(n, t=""):
    if isinstance(n, dict):
        for k, v in n.items():
            yield from andar(v, f"{t}.{k}")
    elif isinstance(n, list):
        for i, v in enumerate(n):
            yield from andar(v, f"{t}[{i}]")
    elif isinstance(n, str) and n.startswith(("/", "~")):
        yield f"{t} = {n}"
erros = list(andar(p))
if p.get("heranca") != sys.argv[2]:
    erros.append(f"heranca = {p.get('heranca')!r}, e o pack no ar é {sys.argv[2]!r}")
print("\n".join(erros))
PY
)"
  [ -z "$achado" ] \
    && ok "o resto vem do pack no ar pela herança, por id, sem caminho absoluto" \
    || falha "o pack.json novo aponta para a máquina, ou não herda do pack no ar:" "$achado"
fi
saida="$(viaja "$RAIZ/bin/meow" pack novo "$NOVO" 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"já existe"* ]] \
  && ok "o novo não escreve por cima de um pack que já existe (rc=$rc)" \
  || falha "o novo aceitou um id que já existe (rc=$rc)" "$saida"

somas "$PACKS/$NOVO" > "$T/saiu.sha"
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$NOVO" "$T/$NOVO.meowpack" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ -s "$T/$NOVO.meowpack" ] \
  && ok "meow pack exportar escreve o .meowpack" \
  || falha "o exportar falhou (rc=$rc)" "$saida"
rm -rf "${PACKS:?}/$NOVO"
importou="$(viaja "$RAIZ/bin/meow" pack importar "$T/$NOVO.meowpack" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -d "$DA_PESSOA/$NOVO" ]; then
  falha "o importar não instalou o pack exportado (rc=$rc)" "$importou"
else
  ok "meow pack importar instala na raiz da pessoa"
  saida="$(viaja "$RAIZ/bin/meow" pack validar "$NOVO" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "o pack importado valida (rc=0)" \
    || falha "o pack importado não valida (rc=$rc)" "$saida"
  chegou="$(somas "$DA_PESSOA/$NOVO")"
  [ "$chegou" = "$(cat "$T/saiu.sha")" ] \
    && ok "cada arquivo chegou com o sha256 com que saiu ($(wc -l < "$T/saiu.sha") arquivos)" \
    || falha "o que chegou não é o que saiu" "$(diff <(printf '%s\n' "$chegou") "$T/saiu.sha")"
fi
# IMPORTAR NÃO APLICA. O meow.conf é onde se troca de tema, e ele não pode ter
# mudado um byte; e a tela tem de dizer isso, para ninguém esperar a troca.
[ "$(sha256sum < "$T/meow.conf")" = "$conf_antes" ] && [[ "$importou" == *"nada foi aplicado"* ]] \
  && ok "importar não aplica: o meow.conf não mudou, e a saída diz isso" \
  || falha "o importar mexeu no meow.conf, ou não disse que não aplicou" "$importou"
rm -rf "${DA_PESSOA:?}/$NOVO"

# AS RECUSAS DA IMPORTAÇÃO. O `.meowpack` forjado sai do bom, com UMA coisa
# errada — e o MANIFESTO acertado quando a coisa errada é o conteúdo, para que a
# recusa seja pelo motivo que o caso pergunta, e não por um sha que não bate.
cat > "$T/forja.py" <<'PY'
import hashlib, io, subprocess, sys, tarfile
origem, saida, modo, *resto = sys.argv[1:]
bruto = subprocess.run(["zstd", "-d", "-c", "-q", origem], capture_output=True, check=True).stdout
velho = tarfile.open(fileobj=io.BytesIO(bruto))
arquivos = {m.name: velho.extractfile(m).read() for m in velho if m.isfile()}
ident = next(n.split("/")[0] for n in arquivos if "/" in n)
links = []
if modo == "extra":      # um arquivo a mais, e o MANIFESTO certinho
    rel, dado = resto[0], resto[1].encode().decode("unicode_escape").encode()
    arquivos[f"{ident}/{rel}"] = dado
    arquivos["MANIFESTO"] += f"{hashlib.sha256(dado).hexdigest()}  {rel}\n".encode()
elif modo == "troca":    # o conteúdo muda, o MANIFESTO não
    arquivos[f"{ident}/{resto[0]}"] = resto[1].encode()
elif modo == "fuga":
    arquivos["../fora.txt"] = b"fora"
elif modo == "link":
    links.append(resto[0])
buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode="w") as tar:
    for nome, dado in arquivos.items():
        info = tarfile.TarInfo(nome)
        info.size, info.mode = len(dado), 0o755   # o tar pede execução; ninguém dá
        tar.addfile(info, io.BytesIO(dado))
    for rel in links:
        info = tarfile.TarInfo(f"{ident}/{rel}")
        info.type, info.linkname = tarfile.SYMTYPE, "/etc/passwd"
        tar.addfile(info)
comprimido = subprocess.run(["zstd", "-q", "-c"], input=buf.getvalue(), capture_output=True, check=True)
open(saida, "wb").write(comprimido.stdout)
PY
printf 'isto não e zstd\n' > "$T/texto.meowpack"
while IFS='|' read -r modo rel dado espera nome; do
  if [ "$modo" = "texto" ]; then
    forjado="$T/texto.meowpack"
  else
    forjado="$T/forjado.meowpack"
    python3 "$T/forja.py" "$T/$NOVO.meowpack" "$forjado" "$modo" "$rel" "$dado" || exit 2
  fi
  saida="$(viaja "$RAIZ/bin/meow" pack importar "$forjado" 2>&1)"; rc=$?
  restos="$(ls -A "$DA_PESSOA" 2>/dev/null)"
  if [ "$rc" != "0" ] && [[ "$saida" == *"$espera"* ]] && [ -z "$restos" ]; then
    ok "recusa $nome (rc=$rc), e nada foi escrito"
  else
    falha "não recusou $nome, não disse qual arquivo, ou deixou rastro (rc=$rc)" "$saida
restos: $restos"
  fi
done <<CASOS
extra|ganchos.sh|#!/bin/sh\necho oi|$NOVO/ganchos.sh: é script de shell|o .sh dentro do tarball, dizendo qual arquivo
extra|icones/leia.txt|#!/usr/bin/env python3|$NOVO/icones/leia.txt: começa com #!|o script com outro nome, pelo #!
troca|pack.json|{}|sha256 não confere|o arquivo que mudou depois de exportado
fuga|||sai do pack|a entrada que sai do diretório do pack
link|icones/senha.svg||não é arquivo comum|o link simbólico
texto|||não é um .meowpack|o arquivo que não é zstd
CASOS
# E o que o tar pede de modo não chega ao disco: todo arquivo forjado acima vem
# 0755, e o que se instala nasce 0644.
python3 "$T/forja.py" "$T/$NOVO.meowpack" "$T/forjado.meowpack" extra nota.md "oi" || exit 2
saida="$(viaja "$RAIZ/bin/meow" pack importar "$T/forjado.meowpack" 2>&1)"; rc=$?
execs="$(find "$DA_PESSOA/$NOVO" -type f -perm /111 2>/dev/null)"
[ "$rc" = "0" ] && [ -f "$DA_PESSOA/$NOVO/nota.md" ] && [ -z "$execs" ] \
  && ok "o bit de execução do tar não chega ao disco — tudo nasce 0644" \
  || falha "o importado ganhou bit de execução, ou não foi importado (rc=$rc)" "$saida
$execs"
rm -rf "${DA_PESSOA:?}/$NOVO"

# AS RECUSAS DO EXPORTAR. A licença (P28): sem CREDITOS.md não sai, e a arte do
# PROCEDENCIA.md sem licença escrita também não. E o pack que não valida — o
# `validar` é o de sempre, e um segundo validador aqui aprovaria o que ele recusa.
LIC="$ID-licenca"
viaja "$RAIZ/bin/meow" pack novo "$LIC" >/dev/null 2>&1 || falha "o novo não criou $LIC"
exporta_recusa() {  # <o que a mensagem tem de dizer> <nome do caso>
  rm -f "$T/lic.meowpack"
  saida="$(viaja "$RAIZ/bin/meow" pack exportar "$LIC" "$T/lic.meowpack" 2>&1)"; rc=$?
  if [ "$rc" != "0" ] && [[ "$saida" == *"$1"* ]] && [ ! -e "$T/lic.meowpack" ]; then
    ok "o exportar recusa $2 (rc=$rc), e não escreve o arquivo"
  else
    falha "o exportar não recusou $2, ou não disse por quê (rc=$rc)" "$saida"
  fi
}
printf '| arquivo | lido de | licença | sha256 |\n|---|---|---|---|\n| `logo.svg` | `~/x/logo.svg` |  | `%064d` |\n' 0 \
  > "$PACKS/$LIC/PROCEDENCIA.md"
exporta_recusa "logo.svg não diz a licença" "a arte de terceiro sem licença no PROCEDENCIA.md"
rm -f "$PACKS/$LIC/PROCEDENCIA.md"
python3 - "$PACKS/$LIC/pack.json" <<'PY' || exit 2
import json, sys
p = json.load(open(sys.argv[1])); p.pop("creditos", None)
json.dump(p, open(sys.argv[1], "w"), indent=2, ensure_ascii=False)
PY
mv "$PACKS/$LIC/CREDITOS.md" "$T/creditos-guardado.md"
exporta_recusa "sem o CREDITOS.md" "o pack sem CREDITOS.md"
mv "$T/creditos-guardado.md" "$PACKS/$LIC/CREDITOS.md"
rm -f "$PACKS/$LIC/logo.svg"
exporta_recusa "vitrine.capa" "o pack que não valida"
rm -rf "${PACKS:?}/$LIC"

# O TAMANHO, E A PERGUNTA DAS IMAGENS. O pack de mentira tem uma captura em PNG
# (o teste 18 a pôs lá). Sem terminal, as imagens vão junto e a saída diz como
# deixá-las; com `--sem-imagens`, o PNG fica e a vitrine da cópia o esquece —
# senão o pack que chega declararia uma captura que não trouxe.
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$ID" "$T/com.meowpack" 2>&1)"; rc=$?
lista="$(zstd -d -c -q "$T/com.meowpack" 2>/dev/null | tar -tf - 2>/dev/null)"
[ "$rc" = "0" ] && [[ "$saida" == *"1 imagem(ns)"*"ninguém para perguntar"* ]] \
  && [[ "$lista" == *"$ID/capturas/tela.png"* ]] \
  && ok "o exportar diz quanto pesam as imagens, e sem terminal elas vão junto" \
  || falha "o exportar não disse o tamanho das imagens, ou as deixou de fora (rc=$rc)" "$saida"
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$ID" "$T/sem.meowpack" --sem-imagens 2>&1)"; rc=$?
lista="$(zstd -d -c -q "$T/sem.meowpack" 2>/dev/null | tar -tf - 2>/dev/null)"
capturas="$(zstd -d -c -q "$T/sem.meowpack" 2>/dev/null | tar -xOf - "$ID/pack.json" 2>/dev/null \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["vitrine"].get("capturas"))' 2>&1)"
[ "$rc" = "0" ] && [[ "$lista" != *"tela.png"* ]] && [ "$capturas" = "[]" ] \
  && ok "--sem-imagens deixa o PNG de fora, e a vitrine da cópia não o promete" \
  || falha "o --sem-imagens levou a imagem, ou a vitrine ficou prometendo (rc=$rc)" "$saida
capturas: $capturas"

# O DESTINO QUE NÃO EXISTE. A revisão de 23/09/2026 mediu o traceback cru do
# `open` saindo daqui. Tem de ser uma linha de erro, código 2, e nada escrito.
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$ID" "$T/nao-existe/x.meowpack" 2>&1)"; rc=$?
[ "$rc" = "2" ] && [[ "$saida" == *"esse diretório não existe"* ]] \
  && [[ "$saida" != *"Traceback"* ]] && [ ! -e "$T/nao-existe" ] \
  && ok "o exportar para um diretório que não existe diz isso numa linha (rc=$rc)" \
  || falha "o exportar para um diretório que não existe não saiu limpo (rc=$rc)" "$saida"

# --- 20b. a página e as rotas falam a MESMA língua — revisão de 23/09/2026 ---
#
#   A revisão provou pelo HTTP que as duas metades divergiam: os botões da P10
#   mandavam `confirmado` e esperavam `precisa_confirmar`, a rota lia
#   `confirmar`, e o primeiro clique terminava em "entrou" sem nada instalado.
#   Aqui as rotas são chamadas pelo método do servidor, sem subir o painel —
#   com o `_json` e o `_baixar` trocados por quem só anota —, e a página é
#   conferida pelas palavras que ela manda e lê. Um lado que mude sozinho
#   quebra este teste, e não a tela dela.
#
#   O script vai para um ARQUIVO, e não para o stdin: o `viaja` fecha o stdin
#   (`</dev/null`, pelo `exportar` que pergunta), e um `python3 -` ali leria um
#   programa vazio e sairia 0 sem conferir nada — medido, com a rota trocada
#   de volta para `confirmar`, o teste passava.
cat > "$T/contrato.py" <<'PY'
import base64, os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
arquivo, destino, dir_id = sys.argv[1:]
ident = os.path.basename(dir_id)
h = servidor.Manipulador.__new__(servidor.Manipulador)
h._json = lambda dados, status=200: (status, dados)
h._baixar = lambda corpo, nome, tipo: (200, {"arquivo": nome, "cabeca": corpo[:4]})
erros = []
pedido = {"nome": os.path.basename(arquivo),
          "conteudo": base64.b64encode(open(arquivo, "rb").read()).decode()}

st, r = h._api_pack_importar(dict(pedido))
if not (st == 200 and r.get("precisa_confirmar") is True and isinstance(r.get("resumo"), str)
        and r.get("titulo") and len(next(iter((r.get("pack") or {}).get("paleta", {}).values()), [])) == 26):
    erros.append(f"o ensaio do importar não pediu confirmação com resumo e paleta: {st} {r}")
if os.path.exists(destino):
    erros.append("o ensaio do importar escreveu o pack")
st, r = h._api_pack_importar(dict(pedido, confirmar=True))
if os.path.exists(destino) or r.get("instalado"):
    erros.append("`confirmar`, a palavra que a página não manda, instalou o pack")
st, r = h._api_pack_importar(dict(pedido, confirmado=True))
if not (st == 200 and r.get("instalado") is True and r.get("frase") and os.path.isdir(destino)):
    erros.append(f"com `confirmado: true` o importar não instalou: {st} {r}")

st, r = h._api_pack_exportar({"id": [ident], "medir": ["1"]})
if not (st == 200 and r.get("imagens") == 1 and isinstance(r.get("tamanho_sem_imagens"), str)):
    erros.append(f"o medir não disse as imagens e o tamanho: {st} {r}")
st, r = h._api_pack_exportar({"id": [ident], "imagens": ["nao"]})
if not (st == 200 and r.get("cabeca") == b"\x28\xb5\x2f\xfd"):
    erros.append(f"o exportar não devolveu o .meowpack: {st} {r}")
creditos = os.path.join(dir_id, "CREDITOS.md")
os.rename(creditos, creditos + ".fora")
try:
    for consulta in ({"id": [ident], "medir": ["1"]}, {"id": [ident]}):
        st, r = h._api_pack_exportar(consulta)
        if not (st == 400 and "CREDITOS.md" in r.get("erro", "")):
            erros.append(f"o pack que o exportar recusa não voltou como erro ({consulta}): {st} {r}")
finally:
    os.rename(creditos + ".fora", creditos)
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
saida="$(viaja python3 "$T/contrato.py" "$T/$NOVO.meowpack" "$DA_PESSOA/$NOVO" "$PACKS/$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "as rotas falam o contrato dos botões: ensaio, confirmado, medir, e a recusa como erro" \
  || falha "as rotas do .meowpack não falam o contrato da página" "$saida"
rm -rf "${DA_PESSOA:?}/$NOVO"

corpo="$(sed -n '/^async function importarPack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
exporta="$(sed -n '/^async function exportarPack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
packs="$(sed -n '/^function montarPacks(/,/^}/p' "$RAIZ/app/pagina/app.js")"
faltam=""
for palavra in "confirmado: true" "r.precisa_confirmar" "corpo: r.pack ? telaDoPack(r.pack)" "!r.instalado"; do
  [[ "$corpo" == *"$palavra"* ]] || faltam+=" importarPack:'$palavra'"
done
for palavra in '"&medir=1"' '"&imagens=nao"' "resposta.ok" "perguntar("; do
  [[ "$exporta" == *"$palavra"* ]] || faltam+=" exportarPack:'$palavra'"
done
[[ "$packs" == *"exportarPack(noAr)"* && "$packs" != *'href: `/api/pack-exportar'* ]] \
  || faltam+=" montarPacks: o exportar voltou a ser um link"
[ -z "$faltam" ] \
  && ok "a página manda confirmado, desenha o pack, só diz 'entrou' com instalado, e pergunta antes de baixar" \
  || falha "a página deixou de falar o contrato das rotas:$faltam"

# --- 21. o pack cobre o resto: ponteiro, fontes, e a tabela inteira — P12 ----
#
#   A P12 pediu "um pack de teste com as onze categorias próprias". Medido em
#   23/09/2026: são QUINZE linhas no `info`, e onze delas são declaráveis —
#   paleta, mapa do COSMIC, quatro de ícone, ponteiro, papéis de parede, temas
#   de aplicativo, som e fontes. As outras quatro (o traço do gerador, prompt,
#   fastfetch, gatos) não têm campo no formato, e o `info` tem de dizer isso
#   em vez de sumir com elas. Então: as onze declaráveis PRÓPRIAS, as quatro
#   ditas "não declarável", e nenhuma a mais nem a menos.
#
#   `wallpapers` entra com campos que ainda não têm leitor, e de propósito: a
#   tabela diz PRÓPRIO para ele e o docs/PACKS.md registra que isso é a exceção
#   a consertar. O aviso de campo morto é o que conta a verdade — e ele é
#   cobrado aqui, para a exceção não virar silêncio no dia em que alguém mexer.
#
#   O PONTEIRO É DE MENTIRA POR DENTRO, e basta: o formato confere nome, a pasta
#   `cursors/`, o ponteiro de repouso e os links, e não decodifica Xcursor. A
#   FONTE também — só os quatro bytes de assinatura que o `pack.py` olha.
mexer_pack() {  # $1 = diretório do pack, $2 = JSON a fundir (null apaga a chave)
  python3 - "$1" "$2" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
def fundir(a, b):
    for k, v in b.items():
        if v is None:
            a.pop(k, None)
        elif isinstance(v, dict) and isinstance(a.get(k), dict):
            fundir(a[k], v)
        else:
            a[k] = v
fundir(p, json.loads(sys.argv[2]))
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
}
TEMA="$PACK_DIR/cursores/$ID-roxo"
mkdir -p "$TEMA/cursors" "$PACK_DIR/fontes" "$PACK_DIR/icones/pastas" \
         "$PACK_DIR/icones/mimetypes" "$PACK_DIR/icones/autorais"
printf 'Xcur de mentira' > "$TEMA/cursors/default"
ln -sf default "$TEMA/cursors/left_ptr"
printf '[Icon Theme]\nName=%s-roxo\n' "$ID" > "$TEMA/index.theme"
printf '\x00\x01\x00\x00fonte de mentira' > "$PACK_DIR/fontes/Mentira-Regular.ttf"
# O mapa do COSMIC também é de mentira: o `validar` cobra que o arquivo
# declarado exista, e o gerador de temas já rodou no passo 5. Copiar o do motor
# poria um caminho de `assets/paleta/` num script, que o `tests/estilo.sh` recusa.
printf '{}\n' > "$PACK_DIR/cosmic-map.json"
mexer_pack "$PACK_DIR" '{
  "cosmic": {"mapa": "cosmic-map.json"},
  "icones": {"pastas": {"desenhos": "icones/pastas/"},
             "mimetypes": {"desenhos": "icones/mimetypes/"},
             "autorais": {"desenhos": "icones/autorais/"}},
  "origens": {"cursores": {"proprio": "cursores/'"$ID"'-roxo"},
              "wallpapers": {"tipo": "github-arvore", "repo_do_conf": "WALLPAPER_SEMENTE_REPO"}},
  "apps": {"spotify": {"spicetify_tema": "Mentira", "esquema": "Mentira"}},
  "som": {"fundamental": 440.0},
  "fontes": {"proprio": [{"arquivo": "fontes/Mentira-Regular.ttf"}]}}'

saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o pack com ponteiro e fontes próprios valida" \
  || falha "o pack com ponteiro e fontes próprios foi recusado (rc=$rc)" "$saida"
case "$saida" in
  *origens.wallpapers.tipo*) ok "os campos de wallpapers seguem nomeados como campo morto — a exceção da tabela está dita" ;;
  *) falha "o aviso de campo morto parou de nomear origens.wallpapers — o PRÓPRIO dele na tabela ficou sem contrapeso" "$saida" ;;
esac

info="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1)"
tabela="$(printf '%s\n' "$info" | sed -n '/^  ----/,$p' | tail -n +2)"
nao_proprias=""
for cat in paleta cosmic.mapa icones.apps icones.pastas icones.mimetypes icones.autorais \
           cursores wallpapers apps som fontes; do
  printf '%s\n' "$tabela" | grep -qE "^  $cat +PRÓPRIO" || nao_proprias="$nao_proprias $cat"
done
[ -z "$nao_proprias" ] \
  && ok "as onze categorias declaráveis saem PRÓPRIO no info" \
  || falha "categorias declaradas que o info não chama de PRÓPRIO:$nao_proprias" "$tabela"
n_fixas="$(printf '%s\n' "$tabela" | grep -cE '^  (gerador|prompt|fastfetch|gatos) +DO MOTOR — não declarável')"
n_linhas="$(printf '%s\n' "$tabela" | grep -c .)"
[ "$n_fixas" = "4" ] && [ "$n_linhas" = "15" ] \
  && ok "gerador, prompt, fastfetch e gatos aparecem como não declaráveis, e a tabela tem as 15 linhas" \
  || falha "a tabela do info não tem as 15 linhas, ou as 4 fixas no motor (linhas=$n_linhas, fixas=$n_fixas)" "$tabela"
case "$tabela" in
  *"CURSOR=\"$ID-roxo\", do pack $ID"*"1 fonte(s), do pack $ID"*)
    ok "o info diz o valor de CURSOR e quantas fontes, e de quem" ;;
  *) falha "a coluna do info não diz o ponteiro e as fontes que a cadeia acha" "$tabela" ;;
esac

# O CARTÃO DA HOME CABE NO TETO DA P7 — achado da revisão da P12, 23/09/2026.
#   O `resumo_de_origem` é a linha que o cartão de pack imprime crua (`p.origem`
#   num `<p class="home-nota">`, no app.js), e a primeira versão da P12 a fez
#   crescer de 170 para 266 caracteres no Dracula, pendurando em todo cartão as
#   quatro categorias que nenhum pack declara. O `tests/app-acessibilidade.py`
#   não pega: ele cobra os 220 nos literais de ajuda do `servidor.py`, e esta
#   frase é montada no `pack.py`. Então ela é medida aqui, na fonte, para os
#   packs do repositório e para o de mentira, que declara as onze.
#   DESDE A P34 (23/09/2026) o cartão não imprime mais o `p.origem` cru: o
#   `linhaDeOrigem` do app.js faz o MESMO agrupamento a partir das categorias,
#   com o nome do pack no lugar do id («herdado do Catppuccin»). A medida daqui
#   continua valendo para ele: as duas linhas só diferem no tamanho do nome
#   contra o do id, e nos dois packs do repositório os dois têm as mesmas letras.
saida="$(amb python3 - "$RAIZ" "$ID" <<'PY' 2>&1
import json, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "scripts"))
import pack
TETO = 220
base = os.path.join(sys.argv[1], "packs")
refs = [sys.argv[2]] + sorted(n for n in os.listdir(base)
                              if os.path.isfile(os.path.join(base, n, "pack.json")))
medidas, longos = [], []
for ref in refs:
    with open(os.path.join(pack.achar(ref), "pack.json"), encoding="utf-8") as fh:
        linha = pack.resumo_de_origem(json.load(fh))
    medidas.append("%s %d" % (ref, len(linha)))
    if len(linha) > TETO:
        longos.append("%s: %d caracteres — %s" % (ref, len(linha), linha))
print("\n".join(longos) if longos else ", ".join(medidas))
sys.exit(1 if longos else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a linha de origem do cartão cabe nos 220 da P7 ($saida)" \
  || falha "a linha de origem do cartão passou dos 220 caracteres da P7" "$saida"

saida="$(amb python3 "$RAIZ/scripts/pack.py" ponteiro "$ID" 2>&1)"
[ "$saida" = "pack=$ID
dir=$TEMA
valor=$ID-roxo" ] \
  && ok "o verbo 'ponteiro' devolve o pack, o tema e o valor da chave" \
  || falha "o verbo 'ponteiro' não respondeu o que o cursor.sh lê" "$saida"
saida="$(amb python3 "$RAIZ/scripts/pack.py" tipografia "$ID" 2>&1)"
[ "$saida" = "$(printf '%s\tMentira-Regular.ttf\t%s\t-' "$ID" "$PACK_DIR/fontes/Mentira-Regular.ttf")" ] \
  && ok "o verbo 'tipografia' devolve a fonte, de onde ela sai e de quem" \
  || falha "o verbo 'tipografia' não respondeu o que o instalar_fontes.sh lê" "$saida"

# A HERANÇA: um filho sem ponteiro, sem fontes e sem som. Os dois primeiros
# sobem até o pai e a tabela diz de quem; o som NÃO sobe — o `som.sh` lê só o
# pack ativo —, e a tabela não pode dizer "HERDADO" para ele.
FILHO="$PACKS/$ID-filho"; mkdir -p "$FILHO"
cp "$PACK_DIR/paleta.json" "$PACK_DIR/logo.svg" "$FILHO/"
printf '{"formato": 1, "id": "%s-filho", "nome": "Filho", "heranca": "%s",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "%s"}, "vitrine": {"capa": "logo.svg"}}\n' \
  "$ID" "$ID" "$ID" > "$FILHO/pack.json"
tabela="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID-filho" 2>&1 | sed -n '/^  ----/,$p')"
if printf '%s\n' "$tabela" | grep -qE "^  cursores +HERDADO de $ID +CURSOR=\"$ID-roxo\", do pack $ID" \
   && printf '%s\n' "$tabela" | grep -qE "^  fontes +HERDADO de $ID +1 fonte\(s\), do pack $ID" \
   && printf '%s\n' "$tabela" | grep -qE "^  som +DO MOTOR"; then
  ok "o filho herda ponteiro e fontes do pai, e o som dele é o do motor"
else
  falha "a herança de ponteiro, fontes ou som não saiu como o código resolve" "$tabela"
fi

# AS RECUSAS, cada uma numa cópia do pack, e cada uma dizendo o campo.
recusa() {  # $1 = o que é, $2 = trecho esperado na mensagem
  local R="$T/recusa"
  saida="$(env MEOW_PACKS="$R" MEOW_RAIZ="$RAIZ" python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
  if [ "$rc" != "0" ] && [[ "$saida" == *"$2"* ]]; then
    ok "recusa $1 (rc=$rc)"
  else
    falha "não recusou $1, ou não disse por quê (rc=$rc)" "$saida"
  fi
}
copia() { rm -rf "$T/recusa"; mkdir -p "$T/recusa"; cp -a "$PACK_DIR" "$T/recusa/$ID"; C="$T/recusa/$ID"; }
SHA_A="$(printf 'a%.0s' $(seq 64))"
copia; ln -s /etc/hostname "$C/cursores/$ID-roxo/cursors/fora"
recusa "o ponteiro com link para fora do tema" "aponta para fora do tema"
# O link que não leva a nada passava — achado da revisão da P12, 23/09/2026: um
# `cursors/hand -> hand2` sem o `hand2` validava, e o `aplicar` nunca convergia.
copia; ln -s hand2 "$C/cursores/$ID-roxo/cursors/hand"
recusa "o ponteiro com link que não leva a nada" "não leva a arquivo nenhum"
copia; rm -f "$C/cursores/$ID-roxo/cursors/default" "$C/cursores/$ID-roxo/cursors/left_ptr"
recusa "o ponteiro sem default nem left_ptr" "não tem default nem left_ptr"
copia; mv "$C/cursores/$ID-roxo" "$C/cursores/$ID roxo"; mexer_pack "$C" "{\"origens\": {\"cursores\": {\"proprio\": \"cursores/$ID roxo\"}}}"
recusa "o ponteiro com espaço no nome" "o tema chama-se"
copia; mexer_pack "$C" '{"origens": {"cursores": {"herda": "catppuccin"}}}'
recusa "proprio e herda juntos no ponteiro" "'proprio' e 'herda' ao mesmo tempo"
copia; mexer_pack "$C" '{"origens": {"cursores": {"proprio": "cursores/nao-existe"}}}'
recusa "o ponteiro declarado e ausente" "NÃO existe no pack"
copia; printf '\x89PNG\r\n' > "$C/fontes/Mentira-Regular.ttf"
recusa "a fonte que não é fonte por dentro" "não é TrueType nem OpenType"
copia; mexer_pack "$C" "{\"fontes\": {\"proprio\": [{\"nome\": \"X.ttf\", \"url\": \"http://exemplo.org/X.ttf\", \"sha256\": \"$SHA_A\"}]}}"
recusa "a fonte em http" "só https"
copia; mexer_pack "$C" '{"fontes": {"proprio": [{"nome": "X.ttf", "url": "https://exemplo.org/X.ttf"}]}}'
recusa "a fonte de fora sem sha256" "declara as três"
copia; mexer_pack "$C" '{"fontes": {"proprio": [{"arquivo": "fontes/Mentira-Regular.ttf"}, {"arquivo": "fontes/Mentira-Regular.ttf"}]}}'
recusa "duas fontes com o mesmo nome" "um nome, um arquivo no disco"
copia; mexer_pack "$C" '{"fontes": {"proprio": [{"arquivo": "../fora.ttf"}]}}'
recusa "a fonte fora do pack" "sai de dentro do pack"
copia; mexer_pack "$C" '{"fontes": {"proprio": null, "herda": "pack-que-nao-existe"}}'
recusa "as fontes herdadas de um pack que não existe" "pack-que-nao-existe"
rm -rf "$T/recusa"

# O SCRIPT E O PAINEL RESOLVEM A MESMA REGRA — a lição da P17, cobrada aqui.
#   Num HOME de brinquedo, com o filho no ar: o ponteiro do pai entra na lista
#   dos dois lados ANTES de estar instalado, com uma prévia por opção; com um
#   diretório de nome exato sequestrando o valor, ele sai dos dois lados. E o
#   `aplicar` em seco diz que instalaria do pack, sem baixar e sem escrever.
# Casa PRÓPRIA: a seção 19 (P10) já monta a dela em "$T/casa", e este bloco
# cobra que o aplicar em seco não escreva nada no HOME — a sobra da outra
# seção seria lida como escrita desta.
H="$T/casa-p12"; mkdir -p "$H"
printf 'PACK="%s-filho"\nCURSOR="%s-roxo"\n' "$ID" "$ID" > "$T/meow-p12.conf"
painel_cursor() {
  env -i PATH="$PATH" HOME="$H" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    MEOW_CONF="$T/meow-p12.conf" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
t, p = servidor._temas_de_cursor(), servidor._prev_cursores()
print(len(t), len(p), " ".join(t))
PY
}
script_cursor() {
  env -i PATH="$PATH" HOME="$H" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" NO_COLOR=1 \
    PACK="$ID-filho" CURSOR="$ID-roxo" "$@" bash "$RAIZ/scripts/cursor.sh" "${ACAO:-listar}" 2>&1
}
read -r n_t n_p nomes <<< "$(painel_cursor)"
if [ "$n_t" = "$n_p" ] && [[ " $nomes " == *" $ID-roxo "* ]] && [[ "$(script_cursor)" == *"$ID-roxo"* ]]; then
  ok "o ponteiro do pack está nas duas listas antes de instalar, com uma prévia por opção ($n_p de $n_t)"
else
  falha "o painel e o script não oferecem o ponteiro do pack juntos" "painel: $n_t $n_p $nomes
script: $(script_cursor)"
fi
saida="$(ACAO=aplicar script_cursor MEOW_DRY_RUN=1)"
if [[ "$saida" == *"vem do pack $ID"*"instalaria o ponteiro"* ]] && [[ "$saida" != *baixaria* ]] \
   && [ -z "$(find "$H" -mindepth 1 2>/dev/null)" ]; then
  ok "o aplicar em seco instala do pack, sem rede, e não escreve nada"
else
  falha "o aplicar em seco não veio do pack, baixaria da rede, ou escreveu" "$saida
$(find "$H" -mindepth 1 2>/dev/null | head -5)"
fi
mkdir -p "$H/.local/share/icons/$ID-roxo"
read -r n_t n_p nomes <<< "$(painel_cursor)"
if [ "$n_t" = "$n_p" ] && [[ " $nomes " != *" $ID-roxo "* ]] && [[ "$(script_cursor)" != *"$ID-roxo"* ]]; then
  ok "com o nome sequestrado por um diretório exato, o ponteiro do pack sai das duas listas"
else
  falha "o nome sequestrado deixou o ponteiro do pack numa das listas" "painel: $n_t $n_p $nomes
script: $(script_cursor)"
fi
rm -rf "$H/.local"

# E O `aplicar` DE VERDADE CONVERGE — achado da revisão da P12, 23/09/2026.
#   Medido pela revisão num HOME de brinquedo: com `cursors/hand -> hand2` e sem
#   o `hand2`, as passagens 2, 3 e 4 saíam 1 dizendo "difere do pacote —
#   substituindo", e o `conferir` também. O `diff -rq` seguia o link dos dois
#   lados, não achava o alvo e saía 2, lido como "difere". O `validar` agora
#   recusa esse link (a recusa está acima), e a comparação olha o link COMO
#   link (`--no-dereference`), que é o que o `cp -a` copia.
#   O link daqui é o que o formato ACEITA e faz o mesmo estrago: `aqui -> .`
#   cai dentro do tema e existe, e o `diff` que segue link sai 2 com "loop de
#   diretório recursivo". Sem o `--no-dereference`, este teste cai.
#   O `gsettings` é de mentira e guarda no HOME de brinquedo: o teste não
#   encosta no dconf de quem o roda.
mkdir -p "$T/bin"
cat > "$T/bin/gsettings" <<'G'
#!/bin/sh
f="$HOME/.gsettings-de-mentira-$3"   # uma por chave: a do tamanho não é a do tema
case "$1" in
  get) if [ -f "$f" ]; then printf "'%s'\n" "$(cat "$f")"; else printf "'Adwaita'\n"; fi ;;
  set) printf '%s' "$4" > "$f" ;;
esac
G
chmod +x "$T/bin/gsettings"
ln -s . "$TEMA/cursors/aqui"
ACAO=aplicar PATH="$T/bin:$PATH" script_cursor >/dev/null
saida="$(ACAO=aplicar PATH="$T/bin:$PATH" script_cursor)"; rc_a=$?
saida_c="$(ACAO=conferir PATH="$T/bin:$PATH" script_cursor)"; rc_c=$?
if [ "$rc_a" = "0" ] && [[ "$saida" == *"já está instalado e idêntico"* ]] && [ "$rc_c" = "0" ]; then
  ok "o ponteiro do pack instalado converge: a segunda passagem diz idêntico, e o conferir concorda"
else
  falha "o ponteiro do pack não convergiu (aplicar rc=$rc_a, conferir rc=$rc_c)" "$saida
$saida_c"
fi
rm -f "$TEMA/cursors/aqui"; rm -rf "$H"; mkdir -p "$H"

# O TEMA RECUSADO É IGNORADO EM VOZ ALTA. Com o link que não leva a nada o
# `pack.py ponteiro` ignora o tema e diz por quê no stderr; o `cursor.sh` o
# calava, e o que sobrava na tela era "não deu para baixar (sem rede, ou release
# mudou)" — o motivo errado para um pack quebrado.
ln -s hand2 "$TEMA/cursors/hand"
saida="$(ACAO=aplicar script_cursor MEOW_DRY_RUN=1)"
if [[ "$saida" == *"não leva a arquivo nenhum"*"o ponteiro do pack foi ignorado"* ]] \
   && [[ "$saida" != *"vem do pack"* ]]; then
  ok "o ponteiro do pack com link que não leva a nada é ignorado, e o cursor.sh diz por quê"
else
  falha "o cursor.sh usou o ponteiro recusado, ou calou o motivo" "$saida"
fi
rm -f "$TEMA/cursors/hand"

# E AS FONTES CHEGAM AO INSTALADOR, em seco: sem as ferramentas dele (saída 3)
# a conferência é pulada, e dito — o formato já foi cobrado acima.
saida="$(env -i PATH="$PATH" HOME="$H" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" NO_COLOR=1 \
  PACK="$ID-filho" MEOW_DRY_RUN=1 bash "$RAIZ/scripts/instalar_fontes.sh" 2>&1)"; rc=$?
if [ "$rc" = "3" ]; then
  printf 'pulado: o instalar_fontes.sh não tem as ferramentas dele nesta máquina\n'
elif [[ "$saida" == *"instalaria a fonte Mentira-Regular.ttf do pack $ID"* ]]; then
  ok "o instalar_fontes.sh lê as fontes que o pack herda, e diz de quem"
else
  falha "o instalar_fontes.sh não leu as fontes do pack (rc=$rc)" "$saida"
fi

# --- 22. a paleta entra por CSV — 23/09/2026, P16 ----------------------------
#
#   "a ideia é darmos via json ou csv um theme completo." Um CSV de 26 linhas,
#   um flavor escuro e nada mais, vira um pack que VALIDA — e o claro que ele
#   não trouxe nasce derivado e diz que é derivado.
#
#   AS CORES SÃO AS DO `dracula` ESCURO, E ISSO É A PROVA DO MÉTODO. O claro
#   derivado tem de sair igual ao `alucard` versionado, 26 de 26: a sprint
#   manda usar o método que gerou o alucard, e não inventar outro. Se alguém
#   "melhorar" a derivação, este teste diz que ela deixou de ser a do projeto.
#
#   O PACK SAI DO `meow pack novo --de-csv` [segunda metade da P16, 23/09/2026].
#   Até a P11 entrar ele era montado à mão aqui, e o bloco dizia que passaria a
#   chamar o `--de-csv` quando ele fosse ligado. Foi: a TRADUÇÃO continua
#   conferida pelo verbo `de-csv`, e o pack pelo `novo`, que tem de escrever o
#   MESMO `paleta.json` que o `de-csv` imprime — uma regra só.
CSV_ID="$ID-csv"; CSV_DIR="$PACKS/$CSV_ID"
python3 - "$RAIZ" "$T/cores.csv" "$T/duas.csv" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[1] + "/packs/dracula/paleta.json", encoding="utf-8"))
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n")
    for s in d["ordem_canonica"]:
        fh.write(f"{s},tinta,{d['flavors']['dracula'][s]}\n")
# O mesmo, com o claro trazido pela pessoa: aí nada se deriva.
with open(sys.argv[3], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n")
    for f, nome in (("dracula", "tinta"), ("alucard", "papel")):
        for s in d["ordem_canonica"]:
            fh.write(f"{s},{nome},{d['flavors'][f][s]}\n")
PY
[ "$(wc -l < "$T/cores.csv")" = "27" ] || falha "o CSV de teste não tem cabeçalho + 26 linhas"

amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/cores.csv" > "$T/csv-paleta.json" 2> "$T/csv.err"; rc=$?
aviso_csv="$(cat "$T/csv.err")"
[ "$rc" = "0" ] \
  && ok "o CSV de 26 linhas vira paleta.json (rc=0)" \
  || falha "o de-csv recusou um CSV certo (rc=$rc)" "$aviso_csv"
# A RÉGUA AVISA E NÃO BLOQUEIA. As cores oficiais do Dracula reprovam em
# `blue` contra o Latte — então o aviso TEM de aparecer, com o slot, e o rc
# acima TEM de ser 0. As duas coisas juntas são a regra da sprint.
[[ "$aviso_csv" == *"aviso"*"régua de contraste"*"tinta: blue/base"* ]] \
  && ok "a régua de contraste avisa com a lista do que reprovou, sem bloquear" \
  || falha "a régua de contraste não disse o que reprovou" "$aviso_csv"

saida="$(amb python3 - "$RAIZ" "$T/csv-paleta.json" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1] + "/packs/dracula/paleta.json", encoding="utf-8"))
o = json.load(open(sys.argv[2], encoding="utf-8"))
erros = []
if o.get("claros") != ["tintaclaro"] or o.get("derivados") != {"tintaclaro": "tinta"}:
    erros.append("claros/derivados: %r %r" % (o.get("claros"), o.get("derivados")))
else:
    dif = [s for s in d["ordem_canonica"]
           if o["flavors"]["tintaclaro"][s].upper() != d["flavors"]["alucard"][s].upper()]
    if dif:
        erros.append("o claro derivado difere do alucard em %d slot(s): %s" % (len(dif), ", ".join(dif)))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o claro derivado é o alucard, 26 de 26 — o método é o do projeto, não um segundo" \
  || falha "a derivação do claro deixou de ser a que gerou o alucard" "$saida"

# AS DUAS PORTAS DÃO O MESMO CLARO — 23/09/2026, P34. O `scripts/derivar_claro.py`
# que gerou o `alucard` tinha uma cópia própria do método, e a conferência de
# cima cobrava só a do `pack.py`. Desde a P34 o script chama a mesma função e
# imprime o claro no STDOUT; aqui as duas portas são comparadas slot a slot, e
# um script que volte a derivar por conta própria — ou a imprimir outra coisa —
# cai aqui. O relatório dele vai para o STDERR, e por isso fica de fora.
saida="$(amb python3 "$RAIZ/scripts/derivar_claro.py" 2>/dev/null \
         | python3 -c 'import json, sys
porta = json.load(sys.stdin)
csv = json.load(open(sys.argv[1], encoding="utf-8"))["flavors"]["tintaclaro"]
dif = [s for s in csv if porta.get(s) != csv[s]] + sorted(set(porta) - set(csv))
print(", ".join(dif))
sys.exit(1 if dif else 0)' "$T/csv-paleta.json" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o derivar_claro.py e o de-csv dão o mesmo claro, 26 de 26 — uma régua, duas portas" \
  || falha "o derivar_claro.py e o de-csv divergem no claro (rc=$rc)" "$saida"

# A CONFERÊNCIA DA SPRINT, AO PÉ DA LETRA, pelo `bin/meow`: `novo --de-csv`,
# `validar` saindo 0, e o `info` com a linha do claro. O meow.conf de teste
# está no pack de mentira — o pack no ar —, e o pack de CSV tem de herdar do
# PADRÃO assim mesmo: o mesmo CSV dá o mesmo pack em qualquer máquina.
novo_csv="$(amb env MEOW_ESTADO="$T/estado" "$RAIZ/bin/meow" pack novo "$CSV_ID" --de-csv "$T/cores.csv" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -f "$CSV_DIR/pack.json" ]; then
  falha "meow pack novo --de-csv não criou o pack (rc=$rc)" "$novo_csv"
else
  ok "meow pack novo --de-csv cria o pack a partir do CSV"
  cmp -s "$T/csv-paleta.json" "$CSV_DIR/paleta.json" \
    && ok "o paleta.json do novo é o que o de-csv imprime, byte a byte — uma tradução só" \
    || falha "o novo --de-csv escreveu uma paleta diferente da do de-csv" \
             "$(diff "$T/csv-paleta.json" "$CSV_DIR/paleta.json" | head -8)"
  [[ "$novo_csv" == *"aviso"*"régua de contraste"*"tinta: blue/base"* ]] \
    && ok "o novo --de-csv roda a régua de contraste e avisa, sem bloquear" \
    || falha "o novo --de-csv não disse o que reprovou na régua" "$novo_csv"
fi
achado="$(python3 - "$CSV_DIR/pack.json" "$(basename "$padrao")" "$ID" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
padrao, no_ar = sys.argv[2], sys.argv[3]
erros = []
if p.get("heranca") != padrao:
    erros.append(f"heranca = {p.get('heranca')!r}: é o pack padrão ({padrao!r}), e não o no ar ({no_ar!r})")
if (p.get("paleta") or {}).get("flavor_padrao") != "tinta":
    erros.append(f"flavor_padrao = {(p.get('paleta') or {}).get('flavor_padrao')!r}; o primeiro do CSV é 'tinta'")
if "som" in p:
    erros.append("o timbre do ar entrou num pack de CSV")
if ((p.get("icones") or {}).get("autorais") or {}).get("gerar") is not True:
    erros.append("sem icones.autorais.gerar, os autorais ficam nos flavors do pai")
print("\n".join(erros))
PY
)"
[ -z "$achado" ] \
  && ok "o pack de CSV herda do padrão, e o flavor_padrao é o primeiro do CSV" \
  || falha "o pack.json do novo --de-csv não é o que a sprint pede" "$achado"
saida="$(amb "$RAIZ/bin/meow" pack validar "$CSV_ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" != *"NENHUM código lê"* ]] \
  && ok "o pack feito de CSV valida (rc=0), sem campo que ninguém lê" \
  || falha "o pack feito de CSV não valida, ou declara campo morto (rc=$rc)" "$saida"
saida="$(amb "$RAIZ/bin/meow" pack info "$CSV_ID" 2>&1)"
[[ "$(grep claro <<< "$saida")" == *"claro: derivado do escuro pelo método do Latte (não é próprio)"* ]] \
  && ok "o info diz que o claro é derivado, e não próprio" \
  || falha "o info não diz que o claro foi derivado" "$saida"
# OS AUTORAIS NAS CORES DO CSV, E NÃO NOS FLAVORS DO PAI. Herdados, eles eram
# os 44 do Catppuccin — mocha, macchiato, frappe, latte —, e nenhum vestia o
# `tinta`. O `novo` os entrega construídos: 11 desenhos x 2 flavors, próprios.
linha_autorais="$(grep '^  icones.autorais ' <<< "$saida")"
[[ "$linha_autorais" == *"PRÓPRIO"*"22 desenho(s), 2 flavor(s)"* ]] \
  && ok "os ícones autorais nascem próprios, nas cores do CSV: 22 desenhos, 2 flavors" \
  || falha "os ícones autorais do pack de CSV não são dele" "$linha_autorais"
# O id tem hífen e o flavor não pode ter: um CSV com o flavor escrito como o id
# é recusado com a linha, e nada é escrito.
sed 's/,tinta,/,meu-tema,/' "$T/cores.csv" > "$T/hifen.csv"
saida="$(amb "$RAIZ/bin/meow" pack novo "$CSV_ID-hifen" --de-csv "$T/hifen.csv" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"o CSV não virou paleta"*"flavor 'meu-tema' — uma palavra só"* ]] \
  && [ ! -e "$PACKS/$CSV_ID-hifen" ] \
  && ok "o flavor com hífen no CSV é recusado pelo novo, com a linha, e nada é escrito" \
  || falha "o novo --de-csv aceitou o flavor com hífen, ou deixou rastro (rc=$rc)" "$saida"
saida="$(amb "$RAIZ/bin/meow" pack novo "$CSV_ID-sem" --de-csv 2>&1)"; rc=$?
[ "$rc" = "2" ] && [[ "$saida" == *"pede o arquivo"* ]] \
  && ok "o --de-csv sem arquivo é erro de uso (rc=2)" \
  || falha "o --de-csv sem arquivo não foi erro de uso (rc=$rc)" "$saida"

# A TELA MOSTRA O QUE VEIO POR HERANÇA E O QUE VEIO POR DERIVAÇÃO. É o risco
# que a sprint declara: um pack de CSV tem paleta e nada mais, e sem isto a
# pessoa acha que ganhou menos do que ganhou.
saida="$(amb python3 - "$RAIZ" "$CSV_ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
p = [p for p in servidor.packs_com_vitrine() if p["id"] == sys.argv[2]][0]
erros = []
if "herdado de" not in p.get("origem", ""):
    erros.append("o cartão não diz o que veio por herança: %r" % p.get("origem"))
if p.get("claros_derivados") != [{"flavor": "tintaclaro", "de": "tinta"}]:
    erros.append("o cartão não diz que o claro é derivado: %r" % p.get("claros_derivados"))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o /api/packs leva a herança e o claro derivado para o cartão" \
  || falha "o cartão do pack de CSV esconde de onde vieram as coisas" "$saida"
# A ETIQUETA TORTA É COBRADA DE QUEM PUBLICA, E NÃO TIRA O TEMA DO DESKTOP. Um
# `derivados` apontando para um flavor que não existe: o `validar` recusa, a
# sonda `caminho` do motor continua vendo o pack, e o `info` não inventa a
# frase de derivado a partir de uma etiqueta que não confere.
cp "$CSV_DIR/paleta.json" "$T/paleta-boa.json"
python3 - "$CSV_DIR/paleta.json" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["derivados"] = {"tintaclaro": "nenhum"}
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$CSV_ID" 2>&1)"; rc=$?
amb python3 "$RAIZ/scripts/pack.py" caminho "$CSV_ID" id >/dev/null 2>&1; rc_motor=$?
info="$(amb python3 "$RAIZ/scripts/pack.py" info "$CSV_ID" 2>&1)"
[ "$rc" = "1" ] && [[ "$saida" == *"'derivados'"*"tintaclaro"* ]] && [ "$rc_motor" = "0" ] \
  && [[ "$info" != *"derivado do escuro"* ]] \
  && ok "o derivados torto é recusado no validar, sem tirar o pack do motor" \
  || falha "o derivados torto passou, ou tirou o pack do motor (validar=$rc caminho=$rc_motor)" "$saida
$info"
# `claros: null` passa no `validar` (ele cobra a chave, não o tipo) e chega ao
# cartão. Com um `derivados` que pareceria bom, o `claros_derivados` levantava
# TypeError fora do try do `packs_com_vitrine`, e o /api/packs INTEIRO caía —
# medido na revisão da P16, 23/09/2026. Quem só mostra não derruba a lista.
python3 - "$CSV_DIR/paleta.json" "$T/paleta-boa.json" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[2], encoding="utf-8"))
d["claros"] = None
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 - "$RAIZ" "$CSV_ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
p = [p for p in servidor.packs_com_vitrine() if p["id"] == sys.argv[2]][0]
print(p.get("claros_derivados"))
sys.exit(0 if p.get("claros_derivados") == [] else 1)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "claros: null não derruba o /api/packs, e o cartão não inventa derivado" \
  || falha "claros: null derrubou o /api/packs (rc=$rc)" "$saida"
cp "$T/paleta-boa.json" "$CSV_DIR/paleta.json"

corpo="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
printf '%s\n' "$corpo" | grep -q 'p.claros_derivados' \
  && ok "o cartão de pack desenha a linha do claro derivado" \
  || falha "o cartão de pack não lê claros_derivados"
# "Traga as 26 linhas no CSV" não dizia para onde. Até a segunda metade da
# P16 a tela não tinha onde, e o cartão mandava ao terminal (`meow pack
# de-csv`); agora o «Importar um pack» aceita o .csv, e a frase aponta para ele.
printf '%s\n' "$corpo" | grep -q '«Importar um pack», com outro nome de arquivo' \
  && ok "o cartão diz onde trocar o claro derivado: o «Importar um pack» da tela" \
  || falha "o cartão manda trocar o claro sem apontar o importar da tela"

# O `.csv` PELA PORTA DO IMPORTAR — P16, item 5. No terminal primeiro: o id
# sai do nome do arquivo, o pack vai para a raiz da pessoa, o meow.conf não
# muda, e o mesmo nome de novo é recusado dizendo por quê.
cp "$T/cores.csv" "$T/Minha Tinta.csv"
conf_antes="$(sha256sum < "$T/meow.conf")"
importou="$(viaja "$RAIZ/bin/meow" pack importar "$T/Minha Tinta.csv" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -d "$DA_PESSOA/minha-tinta" ]; then
  falha "o importar não instalou o .csv (rc=$rc)" "$importou"
else
  ok "meow pack importar aceita um .csv solto, e o id sai do nome do arquivo"
  saida="$(viaja "$RAIZ/bin/meow" pack validar minha-tinta 2>&1)"; rc=$?
  n_autorais="$(find "$DA_PESSOA/minha-tinta/icones/autorais" -name '*.svg' | wc -l)"
  # Igual MENOS o `_comentario`, que diz o nome do CSV de onde a paleta saiu —
  # e aqui o CSV se chama outra coisa, de propósito, porque é ele que faz o id.
  mesma="$(python3 -c 'import json, sys
a, b = (json.load(open(x, encoding="utf-8")) for x in sys.argv[1:])
for d in (a, b): d.pop("_comentario", None)
print("sim" if a == b else "nao")' "$T/csv-paleta.json" "$DA_PESSOA/minha-tinta/paleta.json")"
  [ "$rc" = "0" ] && [ "$mesma" = "sim" ] && [ "$n_autorais" = "22" ] \
    && ok "o pack importado do .csv valida, com a paleta e os autorais do novo --de-csv" \
    || falha "o .csv importado não é o pack que o novo --de-csv monta (rc=$rc, $n_autorais autorais)" "$saida"
fi
[ "$(sha256sum < "$T/meow.conf")" = "$conf_antes" ] && [[ "$importou" == *"nada foi aplicado"* ]] \
  && [[ "$importou" == *"claro derivado    : tintaclaro"* ]] \
  && ok "importar o .csv não aplica, e a saída diz o claro derivado" \
  || falha "o importar do .csv mexeu no meow.conf, ou calou o claro derivado" "$importou"
saida="$(viaja "$RAIZ/bin/meow" pack importar "$T/Minha Tinta.csv" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"já existe"*"com outro nome, ele vira outro pack"* ]] \
  && ok "o mesmo .csv de novo é recusado, dizendo que o nome do arquivo faz o id" \
  || falha "o .csv importado duas vezes não foi recusado como devia (rc=$rc)" "$saida"
rm -rf "${DA_PESSOA:?}/minha-tinta"

# E PELA ROTA, com o contrato da 20b: o ensaio pede confirmação e desenha o
# pack sem escrever, o `confirmado` instala, e o `pack` traz a régua e o claro
# derivado para a caixa de confirmar. O script vai para um arquivo pelo motivo
# da 20b: o `viaja` fecha o stdin.
cat > "$T/contrato-csv.py" <<'PY'
import base64, os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
arquivo, destino = sys.argv[1:]
h = servidor.Manipulador.__new__(servidor.Manipulador)
h._json = lambda dados, status=200: (status, dados)
erros = []
pedido = {"nome": "Minha Tinta.csv",
          "conteudo": base64.b64encode(open(arquivo, "rb").read()).decode()}
st, r = h._api_pack_importar(dict(pedido))
pack = r.get("pack") or {}
if not (st == 200 and r.get("precisa_confirmar") is True and "minha-tinta" in r.get("resumo", "")
        and len(pack.get("paleta", {}).get("tinta", [])) == 26):
    erros.append(f"o ensaio do .csv não pediu confirmação com o pack desenhado: {st} {r}")
if pack.get("derivados") != {"tintaclaro": "tinta"} or not any("blue/base" in l for l in pack.get("regua", [])):
    erros.append(f"o pack do ensaio não traz o claro derivado e a régua: {pack.get('derivados')} {pack.get('regua')}")
if pack.get("icones") != 22 or "herdado de" not in pack.get("ponteiro", ""):
    erros.append(f"o pack do ensaio não diz os autorais próprios e o que é herdado: {pack}")
if os.path.exists(destino):
    erros.append("o ensaio do .csv escreveu o pack")
st, r = h._api_pack_importar(dict(pedido, confirmado=True))
if not (st == 200 and r.get("instalado") is True and os.path.isdir(destino)):
    erros.append(f"com `confirmado: true` o .csv não foi instalado: {st} {r}")
st, r = h._api_pack_importar(dict(pedido, nome="???.csv"))
if not (st == 400 and "nome do arquivo" in r.get("erro", "")):
    erros.append(f"o .csv sem nome que vire id não voltou como erro: {st} {r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
saida="$(viaja python3 "$T/contrato-csv.py" "$T/cores.csv" "$DA_PESSOA/minha-tinta" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$(sha256sum < "$T/meow.conf")" = "$conf_antes" ] \
  && ok "a rota do importar aceita o .csv com o contrato da tela, e não aplica" \
  || falha "a rota do importar não fala o contrato para o .csv, ou mexeu no meow.conf" "$saida"
rm -rf "${DA_PESSOA:?}/minha-tinta"
packs_js="$(sed -n '/^function montarPacks(/,/^}/p' "$RAIZ/app/pagina/app.js")"
tela_js="$(sed -n '/^function telaDoPack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
faltam=""
[[ "$packs_js" == *'accept: ".meowpack,.csv"'* ]] || faltam+=" montarPacks:'accept .csv'"
for palavra in "pack.derivados" "pack.regua"; do
  [[ "$tela_js" == *"$palavra"* ]] || faltam+=" telaDoPack:'$palavra'"
done
[ -z "$faltam" ] \
  && ok "a página aceita o .csv no seletor, e a caixa de confirmar lê o derivado e a régua" \
  || falha "a página não fala o .csv:$faltam"

# Com o claro trazido no CSV, nada se deriva: a medida (base mais luminoso que
# text) acha o claro, e o `derivados` não aparece.
saida="$(amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/duas.csv" 2>/dev/null)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *'"claros": ['*'"papel"'* ]] && [[ "$saida" != *'"derivados"'* ]] \
  && ok "com o claro no CSV, ele é reconhecido pela medida e nada é derivado" \
  || falha "o CSV com claro próprio foi derivado mesmo assim (rc=$rc)" "$saida"

# AS RECUSAS DIZEM A LINHA. Slot desconhecido com o número e o nome; slot
# faltando com a lista; hex torto; slot repetido; cabeçalho ausente. E o STDOUT
# fica vazio: quem redirecionou para um paleta.json não recebe meio arquivo.
# E o prefixo é do CSV, não de pack: "pack recusado" com pack nenhum envolvido
# mandava a pessoa procurar o defeito num pack.json que ela nem escreveu.
#
# O CSV ENTRA POR `< <(...)`, E NÃO POR PIPE [23/09/2026, revisão da P16]. Do
# lado direito de um `|` a função roda num subshell, e o `falhas` que ela soma
# morre com ele: as seis recusas imprimiam FALHOU e a suíte saía 0 — medido ao
# escrever o teste do prefixo, com seis FALHOU e "1 achado(s)" no rodapé.
recusa_csv() {  # <rótulo> <texto esperado na mensagem> — o CSV vem do stdin
  cat > "$T/ruim.csv"
  local out err rc
  out="$(amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/ruim.csv" 2> "$T/ruim.err")"; rc=$?
  err="$(cat "$T/ruim.err")"
  [ "$rc" = "1" ] && [ -z "$out" ] && [[ "$err" == *"$2"* ]] \
    && [[ "$err" == "  erro o CSV não virou paleta: "* ]] \
    && ok "recusa $1 (rc=1): $2" \
    || falha "não recusou $1 como devia (rc=$rc)" "$err"
}
recusa_csv "o slot desconhecido" "ruim.csv:5: slot desconhecido 'mauv'" < <(sed 's/^mauve,/mauv,/' "$T/cores.csv")
recusa_csv "o slot faltando" "não tem 2 slot(s):
      teal, crust" < <(sed '/^crust,/d; /^teal,/d' "$T/cores.csv")
recusa_csv "o hex sem #" "ruim.csv:16: text = 'F8F8F2' não é #RRGGBB" < <(sed 's/^text,tinta,#/text,tinta,/' "$T/cores.csv")
recusa_csv "o slot repetido" "já veio na linha 25" < <(cat "$T/cores.csv"; printf 'base,tinta,#000000\n')
recusa_csv "o CSV sem cabeçalho" "ruim.csv:1: a primeira linha tem de ser o cabeçalho" < <(tail -n +2 "$T/cores.csv")
# A mensagem diz "uma palavra só", e 'Meu Tema' passava: o flavor com espaço
# vira FLAVOR="Meu Tema" no meow.conf e "Meu Tema-mauve" no nome do tema.
recusa_csv "o flavor com espaço" "ruim.csv:2: flavor 'Meu Tema' — uma palavra só" < <(sed 's/,tinta,/,Meu Tema,/' "$T/cores.csv")
# E "sem espaço" não bastava [revisão da P16, 23/09/2026]: 'x$(id)' passava, e
# o meow.conf é lido com `.` — no FLAVOR=, o '$(id)' é comando. O `\$` abaixo é
# para ESTE shell não rodá-lo ao montar a expectativa.
recusa_csv "o flavor com \$(…)" "ruim.csv:2: flavor 'x\$(id)' — uma palavra só, em minúsculas" < <(sed 's/,tinta,/,x$(id),/' "$T/cores.csv")
recusa_csv "o flavor com maiúscula" "ruim.csv:2: flavor 'Tinta' — uma palavra só" < <(sed 's/,tinta,/,Tinta,/' "$T/cores.csv")
# E UMA VEZ SÓ: o nome está nas 26 linhas, e 26 recusas iguais enterravam o resto.
n="$(grep -c "flavor 'Tinta'" "$T/ruim.err")"
[ "$n" = "1" ] \
  && ok "o flavor recusado sai uma vez, na primeira linha dele" \
  || falha "o flavor recusado saiu $n vez(es), uma por linha" "$(head -6 "$T/ruim.err")"
# O CSV mais provável de chegar é o do Excel em português, com ';'. Ele é
# recusado — adivinhar separador seria um segundo formato —, mas dizendo qual.
recusa_csv "o CSV com ';', dizendo qual é o defeito" "este arquivo usa ';'" < <(sed 's/,/;/g' "$T/cores.csv")

# O HEX SAI EM MAIÚSCULAS, E O `text` REPROVADO SAI UMA VEZ SÓ. Um CSV todo
# minúsculo, com o `text` quase da cor do `base`: reprova na régua absoluta
# (AAA) e na relativa (95% do Latte), e aparecia duas vezes no aviso, com a
# contagem de reprovações uma a mais [revisão da P16, 23/09/2026].
sed 's/#\(.*\)$/#\L\1/; s/^text,tinta,.*/text,tinta,#303240/' "$T/cores.csv" > "$T/minusc.csv"
saida="$(amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/minusc.csv" 2> "$T/minusc.err")"; rc=$?
aviso_csv="$(cat "$T/minusc.err")"
n_text="$(grep -c 'tinta: text/base' "$T/minusc.err")"
[ "$rc" = "0" ] && [ "$n_text" = "1" ] && [[ "$aviso_csv" == *"o \`validar\` recusa o pack"* ]] \
  && ok "o text reprovado nas duas réguas sai uma vez só, dizendo que o validar recusa" \
  || falha "o text reprovado saiu $n_text vez(es) no aviso (rc=$rc)" "$aviso_csv"
[ "$rc" = "0" ] && [[ "$saida" == *'"base": "#282A36"'* ]] && ! grep -q '"#[0-9A-F]*[a-f]' <<< "$saida" \
  && ok "o hex minúsculo do CSV sai em maiúsculas, como nas paletas daqui" \
  || falha "o hex do CSV não saiu em maiúsculas" "$(grep -n '"#[0-9A-F]*[a-f]' <<< "$saida" | head -3)"

# UM CSV SÓ, E O SEGUNDO ARGUMENTO É RECUSADO. `de-csv cores.csv paleta.json`
# tem cara de "converta para lá", e imprimia no terminal deixando o paleta.json
# como estava [revisão da P16, 23/09/2026].
saida="$(env MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" MEOW_ESTADO="$T/estado" \
         "$RAIZ/bin/meow" pack de-csv "$T/cores.csv" "$T/destino.json" 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"um CSV só"* ]] && [ ! -e "$T/destino.json" ] \
  && ok "meow pack de-csv com dois argumentos recusa, e diz que o destino vai pelo '>'" \
  || falha "meow pack de-csv aceitou um segundo argumento (rc=$rc)" "$saida"

# --- 23. o pack que viaja não leva o nome de ninguém — 23/09/2026, P30 -------
#
#   MEDIDO: as quatro capturas versionadas dos dois packs diziam
#   `origem: /home/<nome>/.config/cosmic`, com dois nomes de duas máquinas, e
#   todo `.meowpack` exportado os levava. A causa era o `capturar_tema.sh`, que
#   gravava o `$HOME` expandido; a régua do `validar` é o que impede de voltar.
#   Esta seção confere as três pontas: quem ESCREVE a captura grava `~`; a
#   régua RECUSA a casa de alguém, dizendo o arquivo e a linha, e deixa passar
#   o `~/`, o binário e o oculto; e as três portas de quem publica ou recebe —
#   o `novo --de-csv`, o `importar` (de `.meowpack` ou de `.csv`) e o
#   `exportar` — a herdam, porque rodam o `validar` inteiro.
#
#   A CASA É DE NINGUÉM, E A LINHA NÃO A ESCREVE INTEIRA. O `fulano` é o nome de
#   mentira, e ele entra por variável SEM a barra final: o
#   tests/portabilidade.sh (regra 1) acusa `/home/<nome>/` em linha de código,
#   e com razão — lá é receita que só roda na bancada de quem escreveu. Aqui é
#   o dado que a régua tem de recusar, e a barra vem na hora de escrevê-lo.
CASA_ALHEIA="/home/fulano"
MAC_ALHEIO="/Users/fulano"

# Os dois packs do repositório passam na régua — é o "depois: 0" da sprint.
for p in catppuccin dracula; do
  saida="$(viaja "$RAIZ/bin/meow" pack validar "$RAIZ/packs/$p" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "o pack $p do repositório valida com a régua do nome de usuário (rc=0)" \
    || falha "o pack $p do repositório não valida (rc=$rc)" "$saida"
done

# O CSV MORA NUMA CASA, E A CASA NÃO ENTRA NO PACK. Das duas portas que montam
# um pack de CSV — o `novo --de-csv` e o `importar` de um `.csv` —, só o NOME
# do arquivo chega ao pack (o `_comentario` da paleta e o CREDITOS.md). Se o
# caminho inteiro entrasse, a régua, que roda no `validar` do `_instalar_pack`,
# recusaria o próprio pack que acabou de ser montado: o rc 0 é a prova das duas
# coisas de uma vez.
CASA_CSV="$T$CASA_ALHEIA"
mkdir -p "$CASA_CSV"
cp "$T/cores.csv" "$CASA_CSV/casa-tinta.csv"
CASA_ID="$ID-casa"; CASA_DIR="$PACKS/$CASA_ID"
saida="$(viaja "$RAIZ/bin/meow" pack novo "$CASA_ID" --de-csv "$CASA_CSV/casa-tinta.csv" 2>&1)"; rc=$?
vazou="$(grep -rn "/home/" "$CASA_DIR" 2>/dev/null)"
[ "$rc" = "0" ] && [ -f "$CASA_DIR/pack.json" ] && [ -z "$vazou" ] \
  && ok "o novo --de-csv de um CSV dentro de uma casa passa na régua, e a casa não entra no pack" \
  || falha "o novo --de-csv de um CSV dentro de uma casa recusou, ou levou a casa (rc=$rc)" "$saida
$vazou"
saida="$(viaja "$RAIZ/bin/meow" pack importar "$CASA_CSV/casa-tinta.csv" 2>&1)"; rc=$?
vazou="$(grep -rn "/home/" "$DA_PESSOA/casa-tinta" 2>/dev/null)"
[ "$rc" = "0" ] && [ -d "$DA_PESSOA/casa-tinta" ] && [ -z "$vazou" ] \
  && ok "o importar do mesmo .csv passa na régua, e a casa não entra no pack" \
  || falha "o importar de um .csv dentro de uma casa recusou, ou levou a casa (rc=$rc)" "$saida
$vazou"
rm -rf "${DA_PESSOA:?}/casa-tinta"

# QUEM ESCREVE A CAPTURA GRAVA `~`. O `capturar_tema.sh` de verdade, com o HOME
# na casa de mentira e o COSMIC no lugar padrão dela (sem `MEOW_COSMIC_DIR`),
# gravando no pack de CSV acima pelo `MEOW_PACK_DIR`. Antes da P30 a linha
# `origem:` saía com o caminho absoluto — e aqui ele traria a casa do fulano.
# (Por extenso nem neste comentário: o pre-commit avisa de caminho de casa em
# qualquer linha de `.sh`, e o aviso voltaria a cada commit deste arquivo.)
mkdir -p "$CASA_CSV/.config/cosmic/com.system76.CosmicTheme.Mode/v1"
printf 'true' > "$CASA_CSV/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
saida="$(amb env -u MEOW_COSMIC_DIR HOME="$CASA_CSV" MEOW_ESTADO="$T/estado" \
         MEOW_PACK_DIR="$CASA_DIR" bash "$RAIZ/scripts/capturar_tema.sh" tinta-mauve </dev/null 2>&1)"; rc=$?
origem="$(sed -n 's/^origem: //p' "$CASA_DIR/temas/capturados/tinta-mauve/captura.txt" 2>/dev/null)"
# shellcheck disable=SC2088  # o "~" é o texto esperado na linha, não caminho a expandir
[ "$rc" = "0" ] && [ "$origem" = "~/.config/cosmic" ] \
  && ok "o capturar_tema.sh grava origem: ~/.config/cosmic, e não a casa de quem capturou" \
  || falha "a captura não gravou a origem com ~ (rc=$rc, origem=$origem)" "$saida"

# O QUE PASSA: o `~/`, o `<nome>` de um texto que ensina a forma, o binário (o
# PNG com a casa depois de um byte nulo) e o oculto (o `.git/` de um clone).
# Nenhum deles viaja com nome de ninguém, ou nem viaja.
printf '\nlido de ~/Desenvolvimento/tinta/logo.svg\nforma: /home/<nome>/.config/cosmic\n' \
  >> "$CASA_DIR/CREDITOS.md"
printf '\x89PNG\r\n\x1a\n\0\0\0\0%s/Imagens/tela.png\n' "$CASA_ALHEIA" > "$CASA_DIR/tela.png"
mkdir -p "$CASA_DIR/.git"
printf '[remote]\n\turl = %s/tinta.git\n' "$CASA_ALHEIA" > "$CASA_DIR/.git/config"
saida="$(viaja "$RAIZ/bin/meow" pack validar "$CASA_ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a régua deixa passar o ~/, o <nome> de exemplo, o binário e o oculto (rc=0)" \
  || falha "a régua recusou o que não leva nome de ninguém (rc=$rc)" "$saida"

# O QUE NÃO PASSA, E TUDO DE UMA VEZ: a casa no Linux num .md e a do macOS
# dentro de um SVG, cada uma com o arquivo e a linha.
printf 'lido de %s/Downloads/tinta.csv\n' "$CASA_ALHEIA" >> "$CASA_DIR/CREDITOS.md"
n_cred="$(wc -l < "$CASA_DIR/CREDITOS.md")"
svg="$(cd "$CASA_DIR" && find icones -name '*.svg' | LC_ALL=C sort | head -n1)"
printf '<!-- exportado de %s/Desktop/tinta.svg -->\n' "$MAC_ALHEIO" >> "$CASA_DIR/$svg"
n_svg="$(wc -l < "$CASA_DIR/$svg")"
saida="$(viaja "$RAIZ/bin/meow" pack validar "$CASA_ID" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"2 linha(s) com a casa de alguém"* ]] \
  && [[ "$saida" == *"CREDITOS.md:$n_cred: $CASA_ALHEIA/"* ]] \
  && [[ "$saida" == *"$svg:$n_svg: $MAC_ALHEIO/"* ]] \
  && ok "o validar recusa /home/<nome>/ e /Users/<nome>/, dizendo arquivo e linha, os dois de uma vez" \
  || falha "o validar não recusou a casa de alguém como devia (rc=$rc)" "$saida"
# O motor não cobra: o pack pessoal com o próprio caminho continua vestindo o
# desktop, como na vitrine e no logo.
amb python3 "$RAIZ/scripts/pack.py" caminho "$CASA_ID" id >/dev/null 2>&1 \
  && ok "a régua é da porta de quem publica: a sonda do motor ainda vê o pack" \
  || falha "a régua tirou o pack do motor"
rm -f "$T/casa.meowpack"
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$CASA_ID" "$T/casa.meowpack" 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"CREDITOS.md:$n_cred:"* ]] && [ ! -e "$T/casa.meowpack" ] \
  && ok "o exportar herda a régua: recusa, diz a linha, e não escreve o arquivo (rc=$rc)" \
  || falha "o exportar levou a casa de alguém, ou não disse onde (rc=$rc)" "$saida"

# E o `importar` de um `.meowpack`: o da 20, que importou limpo, com UM texto a
# mais trazendo a casa de alguém — e o MANIFESTO acertado, para que a recusa
# seja pela régua e não por um sha que não bate.
python3 "$T/forja.py" "$T/$NOVO.meowpack" "$T/forjado.meowpack" extra nota-casa.md \
  "lido de $CASA_ALHEIA/tema/logo.svg" || exit 2
saida="$(viaja "$RAIZ/bin/meow" pack importar "$T/forjado.meowpack" 2>&1)"; rc=$?
restos="$(ls -A "$DA_PESSOA" 2>/dev/null)"
[ "$rc" != "0" ] && [[ "$saida" == *"nota-casa.md:1: $CASA_ALHEIA/"* ]] && [ -z "$restos" ] \
  && ok "o importar herda a régua: recusa o .meowpack com a casa de alguém, e nada é escrito (rc=$rc)" \
  || falha "o importar aceitou a casa de alguém, ou deixou rastro (rc=$rc)" "$saida
restos: $restos"

# --- 24. o script e o painel respondem a mesma coisa — 23/09/2026, P35 -------
#
#   As duas anotações da P12: "com FLAVOR=alucard e PACK vazio o painel adota
#   dracula e o shell adota o padrão", e "`cursor.sh listar` só lista `-cursors`,
#   o painel lista também nomes exatos". As duas eram a mesma lição que a P17
#   pagou duas vezes: uma regra escrita em shell e de novo em Python, e as
#   cópias divergindo. A adoção agora é UMA (`pack.py adocao`) e as duas listas
#   perguntam à mesma resolução; o que prende isso é rodar os DOIS lados no
#   mesmo HOME de brinquedo e comparar as respostas. Os poucos valores escritos
#   abaixo (`alucard` -> dracula, o sabor do pack de mentira -> ele) são o que a
#   sprint prometeu, e estão lá só para os dois lados não concordarem no erro.
#
#   AS DUAS METADES SE AMARRAM NO PONTEIRO DO PACK. O conf da parte B tem PACK
#   vazio e o FLAVOR claro do pack de mentira: só a adoção pelo SABOR chega ao
#   `$ID`, e só por ela o ponteiro dele entra na lista. Um lado que voltasse a
#   adotar só pelo nome perderia o ponteiro, e a lista dele sairia outra.
#
#   OS MUTANTES, MEDIDOS AO ESCREVER, cada um numa cópia da árvore:
#     o `meow_pack_dir` de volta à adoção só pelo nome        cai A e B
#     o `_pack_adotado` de volta a `PACK or FLAVOR`, cru      cai A e B
#     o `_cursor_temas_instalados` de volta a `*-cursors`     cai B
#     o `sort` do `cursor.sh` sem `LC_ALL=C`                  cai B
#     o `cursor.sh` sem o `dotglob`                           cai B
#   O do `sort` só cai onde houver um locale que não ordene por código de
#   caractere — o `pt_BR.UTF-8` que vai no ambiente abaixo. Numa máquina sem
#   ele o `sort` cai no C e a ordem deixa de ser cobrada: o conjunto continua.
#
#   A casa e as raízes de pack são PRÓPRIAS: as seções de cima deixam outros
#   packs em `$PACKS`, e um que declarasse o mesmo flavor e viesse antes na
#   ordem alfabética mudaria a resposta das duas metades juntas — o teste
#   continuaria verde, e mediria outra coisa.
P35="$T/p35"; H35="$P35/casa"; mkdir -p "$P35/packs" "$H35"
cp -a "$PACK_DIR" "$P35/packs/$ID"
PADRAO_ID="$(basename "$(amb python3 "$RAIZ/scripts/pack.py" padrao)")"
dos_dois() {  # o ambiente dos dois lados: o mesmo HOME, as mesmas raízes
  env -i PATH="$PATH" HOME="$H35" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$P35/packs" \
    MEOW_CONF="$P35/meow.conf" NO_COLOR=1 "$@"
}

# A. A ADOÇÃO, com PACK vazio. O shell diz o diretório (vazio = o padrão); o
#    painel diz o id. Os dois viram id antes de comparar.
SABORES="dracula alucard mocha latte inexistente $ID ${ID}claro"
adocao_shell="$(for f in $SABORES; do
  printf '%s ' "$f"
  dos_dois PACK="" FLAVOR="$f" bash -c '. "$MEOW_RAIZ/lib/comum.sh"
    d="$(meow_pack_dir)"; basename "${d:-$(meow_pack_padrao_dir)}"' 2>&1
done)"
adocao_painel="$(dos_dois python3 - $SABORES <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
for f in sys.argv[1:]:
    with open(servidor.CONF, "w", encoding="utf-8") as fh:
        fh.write('PACK=""\nFLAVOR="%s"\n' % f)
    print(f, servidor._pack_adotado())
PY
)"
if [ "$adocao_shell" = "$adocao_painel" ] \
   && [[ "$adocao_shell" == *"alucard dracula"* ]] && [[ "$adocao_shell" == *"${ID}claro $ID"* ]] \
   && [[ "$adocao_shell" == *"mocha $PADRAO_ID"* ]] && [[ "$adocao_shell" == *"inexistente $PADRAO_ID"* ]]; then
  ok "PACK vazio: shell e painel adotam o mesmo pack para os $(wc -w <<< "$SABORES") sabores, alucard -> dracula"
else
  falha "a adoção do shell e a do painel divergem, ou não adotam pelo sabor declarado" "shell:
$adocao_shell
painel:
$adocao_painel"
fi

# B. A LISTA DE PONTEIROS, na ordem. Cada diretório abaixo é um caso que uma
#    das duas listas já errou ou poderia errar sozinha:
#      foo-cursors/      a convenção do Catppuccin: propõe `foo`
#      Bar/              o nome EXATO — o que o `cursor.sh listar` perdia
#      Zeta-cursors/     a ordem: em C, `Zeta` vem antes de `foo`; em pt_BR, não
#      .oculto/          o nome com ponto, que o `os.listdir` vê e o `*` não
#      Sequestro/        tema de ÍCONES de mesmo nome sequestra `Sequestro-cursors`:
#                        fica de fora dos dois lados
#    E o `/usr/share/icons` é o da máquina, lido pelos dois — o que ele tiver
#    entra igual dos dois lados, e a comparação não depende dele.
for d in ".local/share/icons/foo-cursors" ".icons/Bar" ".local/share/icons/Zeta-cursors" \
         ".icons/.oculto" ".local/share/icons/Sequestro-cursors"; do
  mkdir -p "$H35/$d/cursors"; printf 'Xcur de mentira' > "$H35/$d/cursors/left_ptr"
done
mkdir -p "$H35/.local/share/icons/Sequestro"
printf '[Icon Theme]\nName=Sequestro\nDirectories=48x48/apps\n' > "$H35/.local/share/icons/Sequestro/index.theme"
printf 'PACK=""\nFLAVOR="%s"\n' "${ID}claro" > "$P35/meow.conf"
lista_shell="$(dos_dois PACK="" FLAVOR="${ID}claro" LC_ALL=pt_BR.UTF-8 \
  bash "$RAIZ/scripts/cursor.sh" listar 2> "$P35/listar.err")"
lista_painel="$(dos_dois python3 - <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
print("\n".join(servidor._temas_de_cursor()))
PY
)"
casos="$(grep -xE "Bar|Zeta|foo|\.oculto|$ID-roxo|Sequestro" <<< "$lista_shell" | tr '\n' ' ')"
if [ "$lista_shell" = "$lista_painel" ] && [ "$casos" = ".oculto Bar Zeta foo $ID-roxo " ]; then
  ok "cursor.sh listar e o painel: o mesmo conjunto, na mesma ordem ($(wc -l <<< "$lista_shell") ponteiros, o do pack adotado pelo sabor incluído)"
else
  falha "cursor.sh listar e o painel listam ponteiros diferentes, ou em outra ordem" "os casos, na ordem do shell: $casos
shell:
$lista_shell
$(cat "$P35/listar.err")
painel:
$lista_painel"
fi

# --- 25. os exemplos do docs/PACKS.md validam — 23/09/2026, P34 --------------
#
#   A paleta de exemplo do PACKS.md usava o flavor `meu-tema`, com hífen — o
#   que o `validar` recusa desde 19/09/2026 —, e o `pack.json` do mesmo
#   documento pedia `flavor_padrao: "meutema"`. Quem copiasse os dois ganhava
#   uma recusa na primeira linha. O exemplo errado nasceu porque ninguém o
#   passava pelo `validar`; este bloco passa.
#
#   O QUE ENTRA: todo bloco ```json do documento. Os INTEIROS são separados
#   pelo que são — paleta (`flavors`), pack.json (`formato`) ou desenho autoral
#   (`papeis` + `svg`) — e montados num pack de verdade, com a paleta, os
#   desenhos na pasta de autorais, o CREDITOS.md e o logo do `logo-gerado`
#   (os arquivos que o pack.json do exemplo declara); o `validar` do verbo, o
#   de quem publica, tem de sair 0. Um bloco inteiro que não é nenhum dos três
#   é falha, e diz o que fazer: um exemplo que ninguém confere é o que voltaria
#   errado.
#
#   O MARCADOR É ```json fragmento, NO FONTE DO DOCUMENTO. Metade dos blocos
#   mostra UMA chave (`"vitrine": {…}`) ou o pedaço opcional de um arquivo
#   (o "O resto" do pack.json, com `sha256: "…"`), e não é arquivo nenhum
#   para validar. A palavra fica na linha da cerca, colada ao bloco: um
#   comentário HTML na linha de cima se descolaria dele na primeira edição. A
#   renderização não muda — o realce usa só a primeira palavra. Do fragmento
#   se confere só que é JSON, sozinho ou entre chaves.
saida="$(amb python3 - "$RAIZ" "$T/doc" <<'PY' 2>&1
import json, os, subprocess, sys
raiz, base = sys.argv[1], sys.argv[2]
pack_py = os.path.join(raiz, "scripts", "pack.py")
linhas = open(os.path.join(raiz, "docs", "PACKS.md"), encoding="utf-8").read().split("\n")
blocos, i = [], 0
while i < len(linhas):
    cerca = linhas[i].strip()
    if cerca.startswith("```json"):
        j = i + 1
        while j < len(linhas) and not linhas[j].strip().startswith("```"):
            j += 1
        blocos.append((i + 1, cerca[3:].split()[1:], "\n".join(linhas[i + 1:j])))
        i = j
    i += 1

erros, paletas, packs, desenhos, fragmentos = [], [], [], [], 0
for num, marcas, corpo in blocos:
    if marcas == ["fragmento"]:
        fragmentos += 1
        for texto in (corpo, "{" + corpo + "}"):
            try:
                json.loads(texto)
                break
            except ValueError:
                pass
        else:
            erros.append(f"PACKS.md:{num}: o fragmento não é JSON, nem sozinho nem entre chaves")
        continue
    if marcas:
        erros.append(f"PACKS.md:{num}: marcador {' '.join(marcas)!r} — o único que existe é 'fragmento'")
        continue
    try:
        obj = json.loads(corpo)
    except ValueError as e:
        erros.append(f"PACKS.md:{num}: não é JSON ({e}).\n"
                     f"    Se é um pedaço de arquivo, a cerca é ```json fragmento")
        continue
    if isinstance(obj, dict) and "flavors" in obj:
        paletas.append((num, obj))
    elif isinstance(obj, dict) and "formato" in obj:
        packs.append((num, obj))
    elif isinstance(obj, dict) and "papeis" in obj and "svg" in obj:
        desenhos.append((num, obj))
    else:
        erros.append(f"PACKS.md:{num}: um JSON inteiro que não é pack.json, paleta nem desenho.\n"
                     f"    Ou ele é um pedaço (```json fragmento), ou este teste aprende a validá-lo")
if len(paletas) != 1 or not packs:
    erros.append(f"o PACKS.md tem {len(paletas)} paleta(s) e {len(packs)} pack.json inteiros — "
                 f"o pack do exemplo precisa de uma paleta e de pelo menos um pack.json")

def escrever(d, rel, texto):
    alvo = os.path.join(d, rel)
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    with open(alvo, "w", encoding="utf-8") as fh:
        fh.write(texto)

for num, p in (packs if not erros else []):
    d = os.path.join(base, str(p.get("id")))
    escrever(d, "pack.json", json.dumps(p, ensure_ascii=False, indent=2))
    escrever(d, (p.get("paleta") or {}).get("arquivo") or "paleta.json",
             json.dumps(paletas[0][1], ensure_ascii=False, indent=2))
    if p.get("creditos"):
        escrever(d, p["creditos"], "Tudo aqui é de quem escreveu o exemplo.\n")
    pasta = ((p.get("icones") or {}).get("autorais") or {}).get("desenhos") or "icones/autorais/"
    os.makedirs(os.path.join(d, pasta), exist_ok=True)
    for k, (_n, desenho) in enumerate(desenhos):
        escrever(d, os.path.join(pasta, f"exemplo{k}.json"), json.dumps(desenho, ensure_ascii=False))
    capa = (p.get("vitrine") or {}).get("capa")
    if capa:
        r = subprocess.run([sys.executable, pack_py, "logo-gerado", d], capture_output=True, text=True)
        escrever(d, capa, r.stdout)
    r = subprocess.run([sys.executable, pack_py, "validar", d], capture_output=True, text=True)
    if r.returncode != 0:
        erros.append(f"PACKS.md:{num}, com a paleta da linha {paletas[0][0]} e "
                     f"{len(desenhos)} desenho(s): o validar recusa (rc={r.returncode})\n"
                     + (r.stderr.strip() or r.stdout.strip()))
if erros:
    print("\n".join(erros))
    sys.exit(1)
print(f"{len(packs)} pack.json, {len(paletas)} paleta e {len(desenhos)} desenho validados; "
      f"{fragmentos} fragmento(s) conferidos como JSON")
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "os exemplos do docs/PACKS.md passam pelo validar ($saida)" \
  || falha "um exemplo do docs/PACKS.md não passa pelo validar" "$saida"

# --- 26. os miúdos que as sprints anotaram — 23/09/2026, P34 -----------------
#
#   Quatro anotações pequenas, cada uma com a sua trava. Nenhuma reprova
#   sozinha; juntas, eram o código mentindo devagar.
#
#   O CLARO DA PÁGINA É UMA FUNÇÃO SÓ (P10). O "primeiro claro do pack no ar"
#   estava copiado no `/paleta.css`, na marca do painel e na página exportada.
#   A conta mora no `_flavor_no_modo`, e a trava é dupla: a linha aparece UMA
#   vez no servidor, dentro dela — uma quarta cópia cai aqui —, e a função
#   responde o que as três respondiam.
saida="$(amb python3 - "$RAIZ" <<'PY' 2>&1
import ast, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
fonte = open(servidor.__file__, encoding="utf-8").read()
fn = [n for n in ast.walk(ast.parse(fonte))
      if isinstance(n, ast.FunctionDef) and n.name == "_flavor_no_modo"]
linhas = [i for i, l in enumerate(fonte.splitlines(), 1) if "claros[0]" in l]
erros = []
if not fn or len(linhas) != 1 or not (fn[0].lineno <= linhas[0] <= fn[0].end_lineno):
    erros.append(f"o primeiro claro do pack no ar está fora da função, ou copiado: linhas {linhas}")
else:
    for claros, modo, esperado in ((["papel", "outro"], "claro", "papel"),
                                   (["papel"], "escuro", "tinta"),
                                   ([], "claro", "tinta")):
        servidor._paleta_dados = lambda c=claros: {"claros": c}
        if servidor._flavor_no_modo("tinta", modo) != esperado:
            erros.append(f"claros={claros} modo={modo}: esperava {esperado!r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o claro da página sai de uma função só, e ela responde o que as três cópias respondiam" \
  || falha "o claro da página voltou a ser copiado, ou a função mudou de resposta" "$saida"

# O CARTÃO E O «MAIS SOBRE» DIZEM O PACK PELO NOME (P10). O cartão imprimia o
#   `p.origem` do pack.py, montado pelo id ("herdado de catppuccin"), e o «Mais
#   sobre», logo abaixo, "herdado do Catppuccin". A frase mora no `deOndeVem`,
#   e as duas linhas a chamam; o `p.origem` cru não volta ao cartão. E o
#   «Ver sobre Escuro» dos botões de fundo perde a maiúscula no meio da frase.
cartao="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
linha="$(sed -n '/^function linhaDeOrigem(/,/^}/p' "$RAIZ/app/pagina/app.js")"
fundos="$(sed -n '/^function barraDeFundos(/,/^}/p' "$RAIZ/app/pagina/app.js")"
n_frase="$(grep -c 'herdado d[eo] ${' "$RAIZ/app/pagina/app.js")"
faltam=""
[ "$n_frase" = "1" ] || faltam+=" a frase 'herdado do' está em $n_frase lugares, e é uma só;"
[[ "$cartao" == *"linhaDeOrigem(p)"* && "$cartao" != *"maiuscula(p.origem)"* ]] \
  || faltam+=" o cartão imprime o p.origem cru;"
[[ "$cartao" == *"deOndeVem(c)"* && "$linha" == *"deOndeVem(c)"* ]] \
  || faltam+=" o cartão e o «Mais sobre» não perguntam ao deOndeVem;"
[[ "$fundos" == *'toLocaleLowerCase'* && "$fundos" != *'Ver sobre ${f.rotulo}`'* ]] \
  || faltam+=" o «Ver sobre» mantém a maiúscula no meio da frase;"
[ -z "$faltam" ] \
  && ok "o cartão e o «Mais sobre» dizem o pack pelo nome, da mesma frase, e o «Ver sobre» é minúsculo" \
  || falha "o rótulo de herança voltou a ter duas formas:$faltam"

# O IMPORTAR DIZ O ARQUIVO DELA, E O EXPORTAR AVISA NA TELA (P11). As recusas
#   citavam o temporário do servidor (/tmp/meow-importa-…/envio.meowpack), e o
#   aviso "herda de um pack que não vem com o MeowSystem" morria no stderr do
#   comando. O pack que herda de fora é montado aqui pelo `novo` e apontado
#   para o pack de mentira, que não vem com o MeowSystem. O script vai para um
#   arquivo pelo motivo da 20b: o `viaja` fecha o stdin.
AVISO="$ID-aviso"
cat > "$T/p34-rotas.py" <<'PY'
import base64, json, os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
aviso, pai = sys.argv[1:]
h = servidor.Manipulador.__new__(servidor.Manipulador)
h._json = lambda dados, status=200: (status, dados)
erros = []
for nome, conteudo, esperado in (("Meu Tema.meowpack", b"isto não e zstd",
                                  "Meu Tema.meowpack: não é um .meowpack"),
                                 ("Minha Tinta.csv", b"slot,flavor,hex\n\xff\xfe\n",
                                  "Minha Tinta.csv: não é texto UTF-8")):
    st, r = h._api_pack_importar({"nome": nome, "conteudo": base64.b64encode(conteudo).decode()})
    erro = r.get("erro", "")
    if st != 400 or esperado not in erro or "meow-importa" in erro:
        erros.append(f"a recusa de {nome!r} não diz o arquivo dela: {st} {erro!r}")
st, r = h._api_pack_exportar({"id": [aviso], "medir": ["1"]})
if not (st == 200 and any(f"'{pai}', que não vem com o MeowSystem" in a for a in r.get("avisos", []))):
    erros.append(f"o medir do exportar não traz o aviso do comando: {st} {r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
saida="$(viaja "$RAIZ/bin/meow" pack novo "$AVISO" 2>&1)"; rc=$?
if [ "$rc" != "0" ]; then
  falha "o meow pack novo não montou o pack que herda de fora (rc=$rc)" "$saida"
else
  python3 - "$PACKS/$AVISO/pack.json" "$ID" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
p["heranca"] = sys.argv[2]
json.dump(p, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
  exportou="$(viaja "$RAIZ/bin/meow" pack exportar "$AVISO" "$T/$AVISO.meowpack" --seco 2>&1)"
  saida="$(viaja python3 "$T/p34-rotas.py" "$AVISO" "$ID" 2>&1)"; rc=$?
  [ "$rc" = "0" ] && [[ "$exportou" == *"'$ID', que não vem com o MeowSystem"* ]] \
    && ok "o importar recusa dizendo o arquivo dela, e o aviso do exportar chega à tela como no terminal" \
    || falha "o importar cita o temporário do servidor, ou o aviso do exportar não chega à tela" \
             "$saida$exportou"
  exporta="$(sed -n '/^async function exportarPack(/,/^}/p' "$RAIZ/app/pagina/app.js")"
  [[ "$exporta" == *"m.avisos"* && "$exporta" == *"m.imagens || avisos"* ]] \
    && ok "a caixa do exportar mostra o aviso, e aparece por ele mesmo sem imagens" \
    || falha "a página não mostra o aviso do exportar"
fi
rm -rf "${PACKS:?}/$AVISO"

# O TÍTULO DOS AUTORAIS DIZ O PACK DONO DO FLAVOR (P16b). Era «Catppuccin
#   <Flavor>» cravado, e os onze do Dracula saíam «Catppuccin Dracula». Três
#   travas: nos packs do repositório, o gerador confere o que está versionado
#   (quem mudar o título sem regerar cai aqui) e todo `<title>` abre pelo nome
#   do pack, sem repeti-lo; e num pack de nome «Tom & Jerry» o SVG continua XML
#   — o nome é texto de quem fez o pack, e entra escapado.
mkdir -p "$T/tj/tom-e-jerry"
saida="$(amb python3 - "$RAIZ" "$PACK_DIR" "$T/tj" <<'PY' 2>&1
import json, os, shutil, subprocess, sys
import xml.etree.ElementTree as ET
raiz, fonte, base = sys.argv[1:]
gerador = os.path.join(raiz, "scripts", "gerar_icones_autorais.py")
SVG = "{http://www.w3.org/2000/svg}title"
erros = []

def gerar(dir_pack, *extra):
    amb = dict(os.environ, MEOW_PACK_DIR=dir_pack)
    amb.pop("MEOW_PALETA", None)
    return subprocess.run([sys.executable, gerador, *extra], env=amb, capture_output=True, text=True)

for ident in sorted(os.listdir(os.path.join(raiz, "packs"))):
    d = os.path.join(raiz, "packs", ident)
    pasta = os.path.join(d, "icones", "autorais")
    if not os.path.isdir(pasta) or not any(a.endswith(".svg") for a in os.listdir(pasta)):
        continue
    r = gerar(d, "--conferir", "--saida", pasta)
    if r.returncode != 0:
        erros.append(f"{ident}: o versionado não é o que o gerador desenha:\n"
                     + "\n".join(l for l in r.stdout.splitlines() if "ok " not in l))
    nome = json.load(open(os.path.join(d, "pack.json"), encoding="utf-8"))["nome"]
    for arq in sorted(a for a in os.listdir(pasta) if a.endswith(".svg")):
        t = ET.parse(os.path.join(pasta, arq)).getroot().find(SVG).text or ""
        dono = t.split(" — ", 1)[-1]
        if not dono.startswith(nome) or f"{nome} {nome}" in dono:
            erros.append(f"{ident}/{arq}: o título é {t!r}")

d = os.path.join(base, "tom-e-jerry")
for arq in ("paleta.json", "pack.json"):
    shutil.copy(os.path.join(fonte, arq), d)
p = json.load(open(os.path.join(d, "pack.json"), encoding="utf-8"))
p.update(id="tom-e-jerry", nome="Tom & Jerry")
json.dump(p, open(os.path.join(d, "pack.json"), "w", encoding="utf-8"), ensure_ascii=False)
saida = os.path.join(base, "saida")
r = gerar(d, "--saida", saida)
if r.returncode != 0:
    erros.append(f"o gerador recusou o pack «Tom & Jerry»: {r.stderr or r.stdout}")
else:
    for arq in sorted(os.listdir(saida)):
        try:
            t = ET.parse(os.path.join(saida, arq)).getroot().find(SVG).text or ""
        except ET.ParseError as e:
            erros.append(f"{arq}: não é XML com o nome do pack dentro ({e})")
            continue
        if " — Tom & Jerry " not in t:
            erros.append(f"{arq}: o título é {t!r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o título dos autorais diz o pack dono do flavor, o versionado confere, e um nome com & não quebra o SVG" \
  || falha "o título dos autorais não diz o pack dono, ou o versionado não foi regerado" "$saida"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack de terceiro é honrado de ponta a ponta"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1
