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
#   mentiu uma vez [23/09/2026, revisão da P15]: o `pack.py` e o docs/PACKS.md
#   diziam que a capa ausente não tirava o pack do motor, e com a P25 tira — a
#   capa é o `logo.svg`, e o logo é cobrado em toda porta. O resto da vitrine é
#   só de quem PUBLICA: uma frase acima do teto não pode derrubar o `caminho`,
#   a sonda de existência do `meow_pack_dir`. As três afirmações do documento
#   viram três conferências abaixo, para a próxima divergência aparecer aqui.
mkdir -p "$PACK_DIR/capturas"
printf '# %s\n\nHistória com <script>alert(1)</script> e **negrito**.\n' "$ID" > "$PACK_DIR/LEIA-ME.md"
printf '\x89PNG\r\n\x1a\n' > "$PACK_DIR/capturas/tela.png"
cp "$PACK_DIR/logo.svg" "$T/logo-guardado.svg"
# Um SVG são, dentro do pack, que NÃO é o logo: a capa que aponta para ele
# tem de ser recusada mesmo passando em extensão, cerca e existência.
cp "$PACK_DIR/logo.svg" "$PACK_DIR/outra-capa.svg"
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

# A capa ausente é o logo ausente: a recusa é a do logo, e ela nomeia o arquivo.
rm -f "$PACK_DIR/logo.svg"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  falha "sem a capa, o pack validou" "$saida"
else
  case "$saida" in
    *logo.svg*) ok "sem a capa, validar recusa (rc=$rc) e nomeia o arquivo que falta" ;;
    *) falha "a recusa sem capa não nomeou o arquivo" "$saida" ;;
  esac
fi
# E NO MOTOR TAMBÉM — é o que o docs/PACKS.md diz agora ("a capa ausente tira o
# pack do desktop"). Se um dia o logo sair da porta do motor, esta linha cai e
# manda corrigir o documento junto.
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && falha "sem a capa o motor ainda vê o pack — o docs/PACKS.md diz o contrário" \
  || ok "sem a capa o motor deixa de ver o pack: a capa é o logo, e o logo é estrutura"
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
{"capa": "outra-capa.svg"}|não é o logo.svg do pack|a capa que é outro SVG, e não o logo
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

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack de terceiro é honrado de ponta a ponta"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1
