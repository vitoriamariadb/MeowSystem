#!/usr/bin/env bash
# temas-de-apps.sh — os módulos de `assets/temas-de-apps/` obedecem ao PACK.
#
# POR QUE ESTE ARQUIVO NASCEU EM 22/09/2026 (sprint P18)
#   Uma contagem mediu, naquele acervo, 446 citações da palavra `catppuccin`
#   espalhadas por oito módulos — e ZERO consultas ao pack ativo:
#
#     módulo            citações   lê o pack ativo?
#     btop-bat              58            não
#     heroic               246            não
#     obsidian              48            não
#     qbittorrent           28            não
#     spotify               39            não
#     toolkits-gtk-qt        5            não
#     vscode                19            não
#     zapzap                 3            não
#                        -----        --------
#                          446         0 de 8
#
#   `assets/temas-de-apps/` é ANTERIOR ao sistema de packs e nunca soube que ele
#   existe. O preço estava na tela desta máquina em 21/09/2026: o pack ativo era
#   o Dracula e o módulo do Obsidian anunciou «Catppuccin Mocha já estava
#   aplicado». O único dos oito que "deu certo" foi o que aplicou o tema do
#   OUTRO pack e chamou de sucesso.
#
# O TETO É POR MÓDULO, E NÃO UM ZERO SÓ — E ISSO NÃO É INDULGÊNCIA
#   A sprint escreveu «o teste fixa o teto em zero para código». Zero é o
#   destino, e para spotify e qbittorrent ele já vale HOJE. Para os outros seis
#   não: são 27 linhas de código em cinco módulos, e o heroic sozinho traz 59
#   arquivos de arte upstream cujo NOME contém a palavra — um teto de zero sobre
#   a árvore inteira seria impossível de alcançar, e teste impossível é teste
#   que alguém desliga.
#
#   Então o teto é uma TABELA que só pode descer. Um módulo que ganhe uma
#   citação nova falha aqui; um módulo que perca as suas cobra que o número seja
#   baixado. É a mesma disciplina do `tests/numeros.sh`: o número medido fica
#   escrito, e mentir sobre ele custa vermelho.
#
# O QUE CONTA COMO CÓDIGO
#   Linha cujo primeiro caractere não-branco NÃO é `#`. Comentário histórico
#   continua valendo — a regra da casa é que a história do defeito fica escrita
#   onde o defeito morava, e um teste que apagasse isso apagaria o porquê.
#   Só `manifesto.sh`: é onde mora a decisão. `upstream/`, `PROCEDENCIA.md` e
#   `SHA256SUMS` nomeiam arte de terceiro, e renomear arte de terceiro seria
#   perder a procedência dela.
#
#   0 = os módulos obedecem ao pack · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACERVO="$RAIZ/assets/temas-de-apps"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

# ---------------------------------------------------------------------------
# 1. O TETO POR MÓDULO
# ---------------------------------------------------------------------------
# MIGRADOS: perguntam ao pack e não conhecem mais o nome de tema nenhum.
# Os cinco do fim NASCERAM migrados, em 24/09/2026 (P42): são os temas que o
# Dracula de antes aplicava, e cada um lê um MODELO do pack (seções 7 e 8).
MIGRADOS=(spotify qbittorrent kitty gnome-terminal telegram discord onlyoffice)

# A TABELA. Medida em 22/09/2026, depois da P18. Ela só desce.
declare -A TETO=(
  [spotify]=0          # migrado na P18
  [qbittorrent]=0      # migrado na P18
  [toolkits-gtk-qt]=0  # nunca teve citação em código; as 5 dele são comentário
  [zapzap]=1
  [heroic]=5           # 246 citações no total; 241 são nomes de arte upstream
  [btop-bat]=6
  [vscode]=6
  [obsidian]=9         # o módulo da prova pelo avesso, e o próximo da fila
  [kitty]=0            # os cinco da P42 (24/09/2026) nasceram com teto zero
  [gnome-terminal]=0
  [telegram]=0
  [discord]=0
  [onlyoffice]=0
)

citacoes_em_codigo() {
  grep -in catppuccin "$1" 2>/dev/null | grep -vc '^[0-9]*: *#'
}

mapfile -t MODULOS < <(find "$ACERVO" -maxdepth 2 -name manifesto.sh -printf '%h\n' | xargs -r -n1 basename | sort)
[ "${#MODULOS[@]}" -gt 0 ] || { falha "não achei manifesto.sh nenhum em $ACERVO"; exit 2; }

for mod in "${MODULOS[@]}"; do
  # A ARMADILHA Nº 3 DA CASA: toda lista fixa é uma lista que alguém esquece.
  # Um módulo NOVO sem linha na tabela faz este teste falhar, e é de propósito —
  # senão ele nasceria fora do teto sem ninguém notar.
  if [ -z "${TETO[$mod]+x}" ]; then
    falha "módulo '$mod' não tem teto declarado em tests/temas-de-apps.sh" \
          "  Meça com: grep -in catppuccin $ACERVO/$mod/manifesto.sh | grep -vc '^[0-9]*: *#'"
    continue
  fi
  n="$(citacoes_em_codigo "$ACERVO/$mod/manifesto.sh")"
  teto="${TETO[$mod]}"
  if [ "$n" -gt "$teto" ]; then
    falha "$mod: $n citação(ões) de 'catppuccin' em código, e o teto é $teto" \
          "  O tema vem do pack: use meow_app_tema_do_pack (ver lib/comum.sh)."
  elif [ "$n" -lt "$teto" ]; then
    falha "$mod: o teto diz $teto e hoje são $n — baixe o número na tabela" \
          "  Teto que não desce vira teto decorativo."
  else
    ok "$mod: $n citação(ões) em código, teto $teto"
  fi
done

# ---------------------------------------------------------------------------
# 2. MÓDULO MIGRADO PERGUNTA AO PACK
# ---------------------------------------------------------------------------
# Teto zero sozinho não prova nada: um módulo sem a palavra e sem a pergunta
# continua aplicando o que estiver cravado em outro nome.
for mod in "${MIGRADOS[@]}"; do
  arq="$ACERVO/$mod/manifesto.sh"
  if grep -q 'meow_app_tema_do_pack' "$arq"; then
    ok "$mod: pergunta ao pack qual tema aplicar"
  else
    falha "$mod: está na lista de migrados e não chama meow_app_tema_do_pack"
  fi
  if grep -q 'meow_app_tema_no_ar' "$arq"; then
    ok "$mod: lê o que está no ar antes de escrever"
  else
    falha "$mod: está na lista de migrados e não chama meow_app_tema_no_ar" \
          "  Aplicar sem ler é sobrescrever calado o que a pessoa fez à mão."
  fi
  # O `$( )` É PROIBIDO, E FOI UM DEFEITO MEDIDO — 22/09/2026, revisão da P18
  #   `tema="$(meow_app_tema_do_pack …)"` é o jeito natural de escrever isto em
  #   shell, e é o jeito errado: `$( )` é subshell, e o `MEOW_APP_TEMA_PACK` que
  #   a função atribui morre com ele. Os dois módulos migrados nasceram assim, e
  #   a procedência chegava vazia em todas as telas deles. Esta linha é o que
  #   impede o nono módulo de copiar a mesma armadilha do documento.
  #
  #   Só CÓDIGO, pela mesma régua da seção 1: a linha que conta é a que não
  #   começa por `#`. O padrão errado tem de continuar escrito nos comentários
  #   dos dois módulos — é lá que mora a história do defeito.
  if grep -n '\$(meow_app_tema_do_pack' "$arq" | grep -qv '^[0-9]*: *#'; then
    falha "$mod: chama meow_app_tema_do_pack dentro de \$( )" \
          "  \$( ) é subshell: MEOW_APP_TEMA_PACK morre lá dentro e a procedência some."
  else
    ok "$mod: chama meow_app_tema_do_pack direto, sem \$( )"
  fi
done

# ---------------------------------------------------------------------------
# 3. AS TRÊS SAÍDAS DE `meow_app_tema_no_ar`
# ---------------------------------------------------------------------------
# Elas são o coração da sprint, e as três aparecem na tela:
#   já está no tema do pack · está sem tema · está num tema que não veio daqui.
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

tres_saidas() {
  # Subshell com estado de brinquedo: a terceira saída REGISTRA pendência, e
  # pendência é arquivo. Sem esta gaiola o teste sujaria o
  # ~/.local/state/meowsystem de quem o roda — o mesmo cuidado que o
  # `aplicar_apps.sh tabela` documenta.
  (
    export MEOW_RAIZ="$RAIZ"
    export MEOW_ESTADO="$T/estado"
    # shellcheck disable=SC1091
    . "$RAIZ/lib/comum.sh" || exit 2
    meow_app_tema_no_ar app-de-teste "$1" "$2" "pack-de-teste" 2>&1
    printf 'rc=%s\n' "$?"
  )
}

# a) já está no tema do pack
saida="$(tres_saidas "/x/tema-do-pack" "/x/tema-do-pack")"
if printf '%s' "$saida" | grep -q 'rc=0' && printf '%s' "$saida" | grep -q 'já está no tema do pack'; then
  ok "saída 1: já está no tema do pack -> nada a fazer, e diz qual"
else
  falha "saída 1 não é 'já está no tema do pack' com rc=0" "$saida"
fi

# b) está sem tema
saida="$(tres_saidas "" "/x/tema-do-pack")"
if printf '%s' "$saida" | grep -q 'rc=1' && printf '%s' "$saida" | grep -q 'está sem tema'; then
  ok "saída 2: está sem tema -> aplica (rc=1, divergente)"
else
  falha "saída 2 não é 'está sem tema' com rc=1" "$saida"
fi

# c) está num tema que não veio daqui — PERGUNTA, não sobrescreve
#    O caminho sai do `$T` e não de um `/home/<nome>/…` escrito à mão: o
#    `tests/portabilidade.sh` cobra home cravado até em valor de brinquedo, e
#    cobra com razão — é assim que uma receita presa à máquina de quem escreveu
#    entra no repositório sem ninguém notar.
saida="$(tres_saidas "$T/themes/outro.qbtheme" "/x/tema-do-pack")"
if printf '%s' "$saida" | grep -q 'rc=3' && printf '%s' "$saida" | grep -q 'que não veio daqui'; then
  ok "saída 3: tema de terceiro -> 3, e o arquivo dele fica intocado"
else
  falha "saída 3 não é 'que não veio daqui' com rc=3" "$saida"
fi

# E a terceira precisa DEIXAR RASTRO: fora da tela ela vira pendência acionável,
# senão o caso some e o trabalho que ela fez à mão continua invisível.
if grep -q 'app-de-teste-tema-de-terceiro' "$T/estado/pendencias.tsv" 2>/dev/null; then
  ok "saída 3: a pendência acionável foi registrada"
else
  falha "saída 3 não registrou pendência em $T/estado/pendencias.tsv" \
        "  Sem tela ninguém responde a pergunta; sem pendência ninguém lembra dela."
fi

# ---------------------------------------------------------------------------
# 4. O PACK RESPONDE, E A HERANÇA DIZ DE QUEM HERDOU
# ---------------------------------------------------------------------------
# O `apps` do pack padrão é o que faz os módulos terem o que aplicar; o do
# Dracula é a prova de que um segundo pack manda no mesmo módulo.
saida="$(python3 "$RAIZ/scripts/pack.py" app dracula apps.spotify.spicetify_tema 2>&1)"
if printf '%s' "$saida" | grep -qx 'pack=dracula'; then
  ok "pack: o Dracula responde pelo próprio Spotify"
else
  falha "pack: 'app dracula apps.spotify.spicetify_tema' não respondeu pelo dracula" "$saida"
fi

saida="$(python3 "$RAIZ/scripts/pack.py" app dracula apps.qbittorrent.arquivo 2>&1)"
if printf '%s' "$saida" | grep -qx 'pack=catppuccin'; then
  ok "pack: o qBittorrent do Dracula é herdado, e o log diz de quem"
else
  falha "pack: a herança de apps.qbittorrent não apontou para o catppuccin" "$saida"
fi

# A HERANÇA É POR APLICATIVO, E NÃO POR CHAVE. Um pack que declara o bloco
# responde por ele inteiro: uma chave que falte é ausência, nunca empréstimo do
# vizinho. Sem isto o Spotify sairia com o tema de um pack e o esquema de outro.
if python3 "$RAIZ/scripts/pack.py" app dracula apps.spotify.acento_no_color_ini >/dev/null 2>&1; then
  falha "pack: chave ausente no bloco do Dracula foi buscada na herança" \
        "  Tema de um pack com esquema de outro é a divergência silenciosa de volta."
else
  ok "pack: chave ausente num bloco declarado é ausência, não herança"
fi

# ---------------------------------------------------------------------------
# 5. A PROCEDÊNCIA CHEGA AO MÓDULO — E É O CAMINHO QUE O MÓDULO USA
# ---------------------------------------------------------------------------
# POR QUE ESTA SEÇÃO NASCEU — 22/09/2026, na revisão da P18
#   A seção 3 acima passa "pack-de-teste" como 4º argumento, à mão. Ela exercita
#   a função e NUNCA o caminho que os módulos usam: perguntar ao pack e deixar a
#   resposta chegar sozinha. E era exatamente ali que estava o defeito — a
#   pergunta era feita dentro de `$( )`, o `MEOW_APP_TEMA_PACK` morria no
#   subshell, e o sufixo "(do pack …)" nunca aparecia na tela. Teste que só
#   chama a função pela porta de teste não vê a porta da frente.
prova_da_procedencia() {
  (
    export MEOW_RAIZ="$RAIZ"
    export MEOW_ESTADO="$T/estado5"
    export PACK=dracula
    # shellcheck disable=SC1091
    . "$RAIZ/lib/comum.sh" || exit 2
    # O caminho do módulo, inteiro: pergunta, guarda, e deixa o 4º argumento
    # cair no padrão (que é o `MEOW_APP_TEMA_PACK`).
    meow_app_tema_do_pack spotify.spicetify_tema || exit 3
    printf 'tema=%s\n' "$MEOW_APP_TEMA"
    meow_app_tema_no_ar spotify "$MEOW_APP_TEMA" "$MEOW_APP_TEMA" 2>&1
  )
}
saida="$(prova_da_procedencia)"
if printf '%s' "$saida" | grep -q 'tema=Sleek'; then
  ok "procedência: o valor chega ao módulo sem \$( )"
else
  falha "procedência: meow_app_tema_do_pack não devolveu o tema em MEOW_APP_TEMA" "$saida"
fi
if printf '%s' "$saida" | grep -q '(do pack dracula)'; then
  ok "procedência: o 4º argumento cai no padrão e a tela diz de quem veio o tema"
else
  falha "procedência: a linha da tela não diz de qual pack veio o tema" \
        "$saida
  Sem isto o item 2 da sprint não se cumpre em produção: o log cala a origem."
fi

# ---------------------------------------------------------------------------
# 6. PACK SEM TEMA PARA O APP NÃO DESTRAVA O qBITTORRENT
# ---------------------------------------------------------------------------
# A trava do módulo do qBittorrent é um `grep` pelo NOME do pack dentro do
# script do Aurora. Com o nome vazio o padrão vira `^[[:space:]]*\)`, que casa
# qualquer fechamento de subshell indentado — medidos 32 dos `.sh` deste
# repositório. O módulo se daria por destravado sozinho e chamaria o script de
# terceiro com `--tema ''`. Vazio tem de ser NÃO-destravado.
cat > "$T/aurora-de-brinquedo.sh" <<'FIM'
#!/usr/bin/env bash
case "$1" in
  dracula) echo dracula ;;
esac
(
  echo subshell
)
FIM
destrava_com_nome_vazio() {
  (
    export MEOW_RAIZ="$RAIZ"
    export MEOW_ESTADO="$T/estado6"
    # shellcheck disable=SC1091
    . "$RAIZ/lib/comum.sh" || exit 2
    # shellcheck disable=SC1091
    . "$ACERVO/qbittorrent/manifesto.sh" >/dev/null 2>&1 || exit 2
    MEOW_QBT_NOME_AURORA=""
    MEOW_QBT_AURORA_FONTE="$T/aurora-de-brinquedo.sh"
    _meow_qbt_aurora_destravado
  )
}
if destrava_com_nome_vazio; then
  falha "qbittorrent: pack sem tema para o app passou por 'Aurora destravado'" \
        "  O grep casou um ')' indentado. Seria --tema '' num script de terceiro."
else
  ok "qbittorrent: nome de pack vazio não destrava (o ')' indentado não conta)"
fi

# ---------------------------------------------------------------------------
# 7. OS MODELOS DO PACK NÃO TRAZEM COR ESCRITA, E MONTAM EM TODO FLAVOR
# ---------------------------------------------------------------------------
# POR QUE ESTA SEÇÃO NASCEU — 24/09/2026, sprint P42
#   Os temas de kitty, GNOME Terminal, Telegram, Discord e OnlyOffice entraram
#   no pack Dracula como MODELO: o papel da cor no lugar dela, e quem põe o hex é
#   o `assets/temas-de-apps/modelo.py`, com a paleta do pack no ar. Um hex
#   escrito num modelo é o flavor `dracula` cravado — o `alucard` sairia com uma
#   cor escura no meio, e nada acusaria. A régua é por PACK, e não pela lista dos
#   cinco: o modelo que o próximo pack trouxer entra nela sozinho.
MODELO_PY="$RAIZ/assets/temas-de-apps/modelo.py"
mapfile -t MODELOS < <(find "$RAIZ/packs" -path '*/apps/*.modelo.*' -type f | sort)
if [ "${#MODELOS[@]}" -eq 0 ]; then
  falha "nenhum modelo em packs/*/apps/ — os temas de aplicativo da P42 sumiram"
fi
for m in "${MODELOS[@]}"; do
  rel="${m#"$RAIZ"/}"
  hexas="$(grep -nE '#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3}([0-9A-Fa-f]{2})?)?\b' "$m")"
  if [ -n "$hexas" ]; then
    falha "$rel: cor escrita no modelo — a cor sai da paleta, pelo papel" "$hexas"
  else
    ok "$rel: nenhum hex escrito"
  fi
  pal="$(dirname "$(dirname "$m")")/paleta.json"
  pack_id="$(basename "$(dirname "$(dirname "$m")")")"
  for flavor in $(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["flavors"]))' "$pal"); do
    saida="$(python3 "$MODELO_PY" "$m" "$pal" "$flavor" "$pack_id" 2>&1)"; rc=$?
    if [ "$rc" = 0 ] && ! printf '%s' "$saida" | grep -q '{{'; then
      ok "$rel: monta com o flavor $flavor"
    else
      falha "$rel: não montou com o flavor $flavor (rc=$rc)" "$(printf '%s\n' "$saida" | head -5)"
    fi
  done
done
# E o papel que a paleta não tem é recusa, não texto literal dentro do tema.
printf 'cor: {{azul}}\n' > "$T/modelo-errado.conf"
if python3 "$MODELO_PY" "$T/modelo-errado.conf" "$RAIZ/packs/dracula/paleta.json" dracula dracula >/dev/null 2>&1; then
  falha "modelo.py aceitou um papel que a paleta não tem ({{azul}})"
else
  ok "modelo.py recusa o papel que a paleta não tem, em vez de deixá-lo no tema"
fi

# ---------------------------------------------------------------------------
# 8. CADA TEMA APLICA, CONFERE E DESFAZ — NUMA CASA DE BRINQUEDO
# ---------------------------------------------------------------------------
# A casa é outra por inteiro: HOME, XDG, estado e packs de brinquedo, e o PATH
# começa por um `bin/` com os aplicativos de mentira — o kitty, o GNOME
# Terminal e o `dconf` são scripts que só existem aqui, e o `pgrep` também,
# para "o OnlyOffice está aberto?" responder o que o teste manda e não o que a
# máquina de quem roda tiver aberto. O `env -i` tira o D-Bus da sessão do
# ambiente: sem ele, nem um `dconf` de verdade que escapasse do PATH alcançaria
# o banco de quem roda o teste.
CASA="$T/casa8"
BIN="$T/bin8"
mkdir -p "$CASA" "$BIN" "$T/packs8"
mod() {  # <módulo> <verbo> [VAR=valor ...]
  local m="$1" v="$2"; shift 2
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" \
      XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$T/packs8" MEOW_RAIZ="$RAIZ" \
      MEOW_ESTADO="$T/estado8" PACK=dracula FLAVOR=dracula NO_COLOR=1 "$@" \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/assets/temas-de-apps/$0/manifesto.sh" || exit 2
               meow_app_$1' "$m" "$v" </dev/null 2>&1
}
falso() { printf '#!/bin/sh\nexit %s\n' "${2:-0}" > "$BIN/$1"; chmod +x "$BIN/$1"; }
# "Nada aberto" é o padrão; o caso do OnlyOffice aberto troca este por um que diz sim.
falso pgrep 1

# --- kitty ---------------------------------------------------------------
falso kitty
K="$CASA/.config/kitty"
saida="$(mod kitty conferir)"; rc=$?
[ "$rc" = 1 ] && ok "kitty: sem tema, o conferir diverge (rc=1)" || falha "kitty: conferir sem tema devolveu $rc" "$saida"
saida="$(mod kitty aplicar)"; rc=$?
if [ "$rc" = 1 ] && grep -q '^# meowsystem-tema: dracula/dracula' "$K/current-theme.conf" 2>/dev/null \
   && grep -qx 'include current-theme.conf' "$K/kitty.conf" 2>/dev/null; then
  ok "kitty: aplicar escreve o tema do pack e o include no kitty.conf"
else
  falha "kitty: aplicar não deixou tema e include (rc=$rc)" "$saida"
fi
saida="$(mod kitty conferir)"; rc=$?
[ "$rc" = 0 ] && ok "kitty: depois de aplicar, o conferir dá 0" || falha "kitty: conferir depois de aplicar devolveu $rc" "$saida"
saida="$(mod kitty aplicar FLAVOR=alucard)"; rc=$?
[ "$rc" = 1 ] && grep -q '^# meowsystem-tema: dracula/alucard' "$K/current-theme.conf" \
  && ok "kitty: trocar o flavor atualiza o NOSSO tema sem perguntar" \
  || falha "kitty: o tema não acompanhou o flavor alucard (rc=$rc)" "$saida"
saida="$(mod kitty reverter)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$K/current-theme.conf" ] && [ ! -e "$K/kitty.conf" ] \
  && ok "kitty: desfazer tira o tema e o kitty.conf que só tinha o bloco" \
  || falha "kitty: desfazer deixou sobra (rc=$rc)" "$saida$(ls -la "$K" 2>&1)"
# O tema DELA: um current-theme.conf sem a marca fica intocado, e vira pendência.
mkdir -p "$K"; printf 'background #000000\n' > "$K/current-theme.conf"
saida="$(mod kitty aplicar)"; rc=$?
[ "$rc" = 3 ] && [ "$(cat "$K/current-theme.conf")" = 'background #000000' ] \
  && grep -q 'kitty-tema-de-terceiro' "$T/estado8/pendencias.tsv" 2>/dev/null \
  && ok "kitty: o tema dela fica como está, e a pergunta vira pendência (rc=3)" \
  || falha "kitty: o tema de terceiro não foi respeitado (rc=$rc)" "$saida"
rm -rf "$K"
# Cor escrita no próprio kitty.conf também é escolha dela — é o caso da máquina
# onde esta sprint nasceu, com as dezesseis cores logo abaixo do include.
mkdir -p "$K"; printf 'include current-theme.conf\nforeground #ffffff\n' > "$K/kitty.conf"
saida="$(mod kitty aplicar)"; rc=$?
[ "$rc" = 3 ] && [ ! -e "$K/current-theme.conf" ] \
  && ok "kitty: cor escrita no kitty.conf conta como tema dela (rc=3), e nada é escrito" \
  || falha "kitty: sobrescreveu as cores escritas no kitty.conf (rc=$rc)" "$saida"
rm -rf "$K"
# O `include` fora do bloco também é tema dela, quando o incluído pinta — é como
# o dracula/kitty manda instalar (`include dracula.conf`). A primeira versão lia
# isso como "sem tema" e punha o nosso bloco no fim, onde ele vence: o tema dela
# trocado calado (revisão da P42, 24/09/2026). E o `include` que só traz fonte
# não é tema: aplica, e a linha dela fica.
mkdir -p "$K"; printf 'font_size 12\ninclude gruvbox.conf\n' > "$K/kitty.conf"
printf 'background #282828\nforeground #ebdbb2\n' > "$K/gruvbox.conf"
antes="$(cat "$K/kitty.conf")"
saida="$(mod kitty conferir)"; rc1=$?
saida="$saida$(mod kitty aplicar)"; rc2=$?
[ "$rc1" = 3 ] && [ "$rc2" = 3 ] && [ "$(cat "$K/kitty.conf")" = "$antes" ] && [ ! -e "$K/current-theme.conf" ] \
  && printf '%s' "$saida" | grep -q 'gruvbox.conf (incluído pelo kitty.conf)' \
  && ok "kitty: um include fora do bloco que pinta é tema dela (rc=3), e o kitty.conf fica intocado" \
  || falha "kitty: o include dela foi lido como 'sem tema' (conferir=$rc1, aplicar=$rc2)" "$saida$(cat "$K/kitty.conf")"
rm -f "$K/gruvbox.conf"
printf 'font_family Fira Code\n' > "$K/fontes.conf"; printf 'font_size 12\ninclude fontes.conf\n' > "$K/kitty.conf"
saida="$(mod kitty aplicar)"; rc=$?
[ "$rc" = 1 ] && [ "$(tail -n 1 "$K/kitty.conf")" = '# END_KITTY_THEME' ] && grep -qx 'include fontes.conf' "$K/kitty.conf" \
  && ok "kitty: um include que só traz fonte não é tema — aplica, e o include dela fica" \
  || falha "kitty: um include sem cor travou o tema (rc=$rc)" "$saida"
mod kitty reverter >/dev/null
rm -rf "$K" "$BIN/kitty"
saida="$(mod kitty detectar)"; rc=$?
[ "$rc" = 3 ] && ok "kitty: sem o kitty, o detectar dá pendente" \
  || { command -v kitty >/dev/null 2>&1 \
       && printf 'pulado: kitty ausente — esta máquina tem um kitty de verdade no PATH\n' \
       || falha "kitty: sem o kitty o detectar devolveu $rc" "$saida"; }

# --- Telegram ------------------------------------------------------------
mkdir -p "$CASA/.local/share/flatpak/app/org.telegram.desktop"
TG="$CASA/.local/share/meowsystem/temas-de-apps/telegram/MeowSystem.tdesktop-theme"
saida="$(mod telegram aplicar)"; rc=$?
[ "$rc" = 1 ] && grep -q '^// meowsystem-tema: dracula/dracula' "$TG" 2>/dev/null \
  && ! printf '%s' "$saida" | grep -q 'está sem tema' \
  && ok "telegram: aplicar entrega o tema montado no lugar fixo, e não diz que o app está sem tema" \
  || falha "telegram: o tema não foi entregue, ou a tela disse 'está sem tema' (rc=$rc)" "$saida"
# O que daqui se lê é o ARQUIVO, e não o tema no ar (ele mora no `tdata`): a
# segunda passada diz "entregue", nunca "já está no tema do pack" (revisão da P42).
saida="$(mod telegram aplicar)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q 'já está entregue' && ! printf '%s' "$saida" | grep -q 'já está no tema do pack' \
  && ok "telegram: a segunda passada diz que o arquivo está entregue (rc=0)" \
  || falha "telegram: a segunda passada disse o que não sabe (rc=$rc)" "$saida"
saida="$(mod telegram conferir)"; rc=$?
[ "$rc" = 0 ] && ok "telegram: depois de aplicar, o conferir dá 0" || falha "telegram: conferir devolveu $rc" "$saida"
saida="$(mod telegram reverter)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$TG" ] && ok "telegram: desfazer tira o arquivo entregue" \
  || falha "telegram: desfazer não tirou o arquivo (rc=$rc)" "$saida"

# --- Discord -------------------------------------------------------------
mkdir -p "$CASA/.local/share/flatpak/app/com.discordapp.Discord"
saida="$(mod discord aplicar)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q 'cliente modificado' \
  && ok "discord: o cliente oficial sozinho é pendência, e o motivo diz o que falta" \
  || falha "discord: sem cliente modificado não saiu pendência com motivo (rc=$rc)" "$saida"
DC="$CASA/.config/Vencord/themes"
mkdir -p "$DC"
saida="$(mod discord aplicar)"; rc=$?
[ "$rc" = 1 ] && grep -q 'meowsystem-tema: dracula/dracula' "$DC/MeowSystem.theme.css" 2>/dev/null \
  && ok "discord: com o Vencord, o tema vai para a pasta themes/ dele" \
  || falha "discord: o tema não chegou à pasta do Vencord (rc=$rc)" "$saida"
saida="$(mod discord conferir)"; rc=$?
[ "$rc" = 0 ] && ok "discord: depois de aplicar, o conferir dá 0" || falha "discord: conferir devolveu $rc" "$saida"
saida="$(mod discord reverter)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$DC/MeowSystem.theme.css" ] && ok "discord: desfazer tira o tema da pasta" \
  || falha "discord: desfazer não tirou o tema (rc=$rc)" "$saida"

# --- OnlyOffice ----------------------------------------------------------
#   O conf é de mentira mas tem a forma do de verdade: `appdata` é um JSON em
#   base64 dentro de `@ByteArray(...)`, e a escolha mora nele e no `UITheme`.
OO="$CASA/.var/app/org.onlyoffice.desktopeditors"
OO_CONF="$OO/config/onlyoffice/DesktopEditors.conf"
OO_ARQ="$OO/data/onlyoffice/desktopeditors/uithemes/meowsystem.json"
oo_conf() {  # <uitheme> — escreve o conf de mentira com aquela escolha
  mkdir -p "$(dirname "$OO_CONF")"
  printf '[General]\nUITheme=%s\nappdata="@ByteArray(%s)"\nmaximized=true\n' "$1" \
    "$(printf '{"langid":"pt-BR","uitheme":"%s","usegpu":true}' "$1" | base64 -w0)" > "$OO_CONF"
}
oo_escolha() { sed -n 's/^appdata="@ByteArray(\(.*\))"$/\1/p' "$OO_CONF" | base64 -d | python3 -c 'import json,sys; print(json.load(sys.stdin)["uitheme"])'; }
mkdir -p "$OO/data/onlyoffice/desktopeditors/uithemes"
oo_conf theme-dark
saida="$(mod onlyoffice aplicar)"; rc=$?
if [ "$rc" = 1 ] && [ "$(oo_escolha)" = theme-meowsystem ] && grep -qx "UITheme=$OO_ARQ" "$OO_CONF" \
   && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(d["id"]!="theme-meowsystem")' "$OO_ARQ" \
   && grep -qx 'maximized=true' "$OO_CONF"; then
  ok "onlyoffice: tema de fábrica é 'sem tema' — aplicar põe o JSON e escolhe, e o resto do conf fica"
else
  falha "onlyoffice: aplicar não deixou o tema escolhido (rc=$rc)" "$saida$(cat "$OO_CONF")"
fi
saida="$(mod onlyoffice conferir)"; rc=$?
[ "$rc" = 0 ] && ok "onlyoffice: depois de aplicar, o conferir dá 0" || falha "onlyoffice: conferir devolveu $rc" "$saida"
saida="$(mod onlyoffice reverter)"; rc=$?
[ "$rc" = 1 ] && [ "$(oo_escolha)" = theme-dark ] && grep -qx 'UITheme=theme-dark' "$OO_CONF" && [ ! -e "$OO_ARQ" ] \
  && ok "onlyoffice: desfazer devolve a escolha de antes e tira o JSON" \
  || falha "onlyoffice: desfazer não devolveu a escolha (rc=$rc, escolha=$(oo_escolha))" "$saida"
oo_conf theme-de-alguem
antes="$(cat "$OO_CONF")"
saida="$(mod onlyoffice aplicar)"; rc=$?
[ "$rc" = 3 ] && [ "$(cat "$OO_CONF")" = "$antes" ] \
  && ok "onlyoffice: um tema de terceiro escolhido fica, e vira pendência (rc=3)" \
  || falha "onlyoffice: trocou a escolha dela (rc=$rc)" "$saida"
oo_conf theme-light
falso pgrep 0
antes="$(cat "$OO_CONF")"
saida="$(mod onlyoffice aplicar)"; rc=$?
[ "$rc" = 3 ] && [ "$(cat "$OO_CONF")" = "$antes" ] && [ -f "$OO_ARQ" ] \
  && ok "onlyoffice: com o app aberto o tema vai para a pasta e a escolha espera (rc=3)" \
  || falha "onlyoffice: escreveu o conf com o app aberto (rc=$rc)" "$saida"
falso pgrep 1
mod onlyoffice reverter >/dev/null
# Sem o `appdata`, o que diz o tema no ar é o `UITheme` — e ele guarda o
# CAMINHO do JSON. A primeira versão comparava esse caminho com o id e lia o
# próprio tema como de terceiro na segunda passagem (medido aqui, 24/09/2026).
printf '[General]\nUITheme=theme-dark\n' > "$OO_CONF"
mod onlyoffice aplicar >/dev/null; rc1=$?
saida="$(mod onlyoffice aplicar)"; rc2=$?
mod onlyoffice reverter >/dev/null
[ "$rc1" = 1 ] && [ "$rc2" = 0 ] && [ "$(cat "$OO_CONF")" = "$(printf '[General]\nUITheme=theme-dark')" ] \
  && ok "onlyoffice: sem appdata, o caminho no UITheme é lido pelo id do JSON — o nosso segue sendo o nosso" \
  || falha "onlyoffice: sem appdata o próprio tema virou terceiro (rc=$rc1 e $rc2)" "$saida$(cat "$OO_CONF")"
# NUNCA ABERTO: sem o conf, a escolha não tem onde morar. O tema vai para a
# pasta e a escolha espera, dita como pendência nas duas passadas e no conferir.
# A primeira versão dizia "aplicado" na 1ª e "já está no tema do pack" com rc=0
# na 2ª, enquanto o conferir dava 1 — e o doctor nunca convergia (revisão da
# P42, 24/09/2026). E o conf continua sem ser criado: é do app.
rm -f "$OO_CONF"
saida="$(mod onlyoffice aplicar)"; rc1=$?
saida="$saida$(mod onlyoffice aplicar)"; rc2=$?
saida="$saida$(mod onlyoffice conferir)"; rc3=$?
[ "$rc1" = 3 ] && [ "$rc2" = 3 ] && [ "$rc3" = 3 ] && [ -f "$OO_ARQ" ] && [ ! -e "$OO_CONF" ] \
  && ! printf '%s' "$saida" | grep -qE 'já está no tema do pack|tema do pack aplicado' \
  && ok "onlyoffice: nunca aberto, o tema vai para a pasta e a escolha é pendência — no aplicar e no conferir (rc=3)" \
  || falha "onlyoffice: nunca aberto, a tela e os códigos discordam (aplicar=$rc1 e $rc2, conferir=$rc3)" "$saida"
mod onlyoffice reverter >/dev/null

# --- GNOME Terminal ------------------------------------------------------
#   O `dconf` de mentira guarda cada chave numa linha do HOME de brinquedo, e
#   imita os cinco verbos que o módulo usa. O formato do `dump` (as chaves em
#   ordem, `chave=valor` com as aspas simples do GVariant) é o do dconf de
#   verdade — conferido uma vez num D-Bus privado com HOME de brinquedo, em
#   24/09/2026, e não aqui, onde um D-Bus que escapasse chegaria ao banco de
#   quem roda.
falso gnome-terminal
cat > "$BIN/dconf" <<'DCONF'
#!/usr/bin/env python3
import os, sys
banco = os.path.join(os.environ["HOME"], ".dconf-de-mentira")
d = {}
if os.path.exists(banco):
    for l in open(banco, encoding="utf-8"):
        k, v = l.rstrip("\n").split("\t", 1)
        d[k] = v
def salvar():
    open(banco, "w", encoding="utf-8").write("".join(f"{k}\t{v}\n" for k, v in sorted(d.items())))
verbo = sys.argv[1]
if verbo == "read":
    if sys.argv[2] in d:
        print(d[sys.argv[2]])
elif verbo == "write":
    d[sys.argv[2]] = sys.argv[3]; salvar()
elif verbo == "reset":
    if sys.argv[2] == "-f":
        for k in [k for k in d if k.startswith(sys.argv[3])]:
            del d[k]
    else:
        d.pop(sys.argv[2], None)
    salvar()
elif verbo == "dump":
    p = sys.argv[2]
    ks = sorted(k for k in d if k.startswith(p) and "/" not in k[len(p):])
    if ks:
        print("[/]")
        for k in ks:
            print(f"{k[len(p):]}={d[k]}")
elif verbo == "load":
    for l in sys.stdin:
        l = l.rstrip("\n")
        if l and not l.startswith(("#", "[")):
            k, v = l.split("=", 1)
            d[sys.argv[2] + k] = v
    salvar()
else:
    sys.exit(1)
DCONF
chmod +x "$BIN/dconf"
GT="/org/gnome/terminal/legacy/profiles:"
UUID="6d656f77-7379-4374-656d-2d7465726d31"
dc() { HOME="$CASA" "$BIN/dconf" "$@"; }
saida="$(mod gnome-terminal aplicar)"; rc=$?
if [ "$rc" = 1 ] && [ "$(dc read "$GT/default")" = "'$UUID'" ] \
   && dc read "$GT/list" | grep -q "b1dcc9dd-5262-4d8d-a863-c897e6d979b9', '$UUID'" \
   && [ "$(dc read "$GT/:$UUID/use-theme-colors")" = false ]; then
  ok "gnome-terminal: aplicar cria o perfil do pack, põe na lista ao lado do de fábrica e faz dele o padrão"
else
  falha "gnome-terminal: aplicar não deixou o perfil como padrão (rc=$rc)" "$saida$(cat "$CASA/.dconf-de-mentira" 2>&1)"
fi
saida="$(mod gnome-terminal conferir)"; rc=$?
[ "$rc" = 0 ] && ok "gnome-terminal: depois de aplicar, o conferir dá 0" || falha "gnome-terminal: conferir devolveu $rc" "$saida"
saida="$(mod gnome-terminal conferir FLAVOR=alucard)"; rc=$?
[ "$rc" = 1 ] && ok "gnome-terminal: com outro flavor, o perfil nosso diverge" || falha "gnome-terminal: conferir com alucard devolveu $rc" "$saida"
saida="$(mod gnome-terminal reverter)"; rc=$?
[ "$rc" = 1 ] && [ -z "$(dc read "$GT/default")" ] && [ -z "$(dc read "$GT/list")" ] && [ -z "$(dc dump "$GT/:$UUID/")" ] \
  && ok "gnome-terminal: desfazer devolve o padrão e a lista de fábrica, e apaga o perfil" \
  || falha "gnome-terminal: desfazer deixou sobra (rc=$rc)" "$saida$(cat "$CASA/.dconf-de-mentira" 2>&1)"
# O perfil de fábrica com cores próprias é o que o tema de antes deixou na
# máquina onde esta sprint nasceu: é escolha dela, e fica.
dc write "$GT/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/use-theme-colors" false
dc write "$GT/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/visible-name" "'Dracula'"
saida="$(mod gnome-terminal aplicar)"; rc=$?
[ "$rc" = 3 ] && [ -z "$(dc read "$GT/default")" ] && printf '%s' "$saida" | grep -q "perfil 'Dracula'" \
  && ok "gnome-terminal: um perfil padrão com cores próprias fica, e vira pendência (rc=3)" \
  || falha "gnome-terminal: trocou o perfil padrão dela (rc=$rc)" "$saida"

# ---------------------------------------------------------------------------
# 9. O `.desktop` DO HOME VOLTA A 644 — E O DOCTOR CONFERE
# ---------------------------------------------------------------------------
# O caso que o hook do apt do tema de antes consertava, e que saiu com ele em
# 24/09/2026: `.desktop` em `~/.local/share/applications` com 600. Quem conserta
# agora é o `scripts/nomes_apps.sh` (o doctor o confere com `--conferir` e o
# conserta com `--sem-sudo`). O mapa de nomes é de brinquedo e VAZIO: o teste
# mede a permissão, e um nome encurtado chamaria o `meow_lancador_reler`, que
# derruba o lançador da sessão de quem roda.
AP="$T/casa9/.local/share/applications"
mkdir -p "$AP"
for n in seiscentos seiscentos-e-quarenta-e-quatro setecentos; do
  printf '[Desktop Entry]\nName=%s\n' "$n" > "$AP/$n.desktop"
done
chmod 600 "$AP/seiscentos.desktop"; chmod 644 "$AP/seiscentos-e-quarenta-e-quatro.desktop"
chmod 755 "$AP/setecentos.desktop"
ln -s seiscentos-e-quarenta-e-quatro.desktop "$AP/link.desktop"
printf '# vazio\n' > "$T/mapa9"
nomes() {
  env -i PATH="$PATH" HOME="$T/casa9" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado9" \
      MEOW_NOMES_MAPA="$T/mapa9" NO_COLOR=1 "$RAIZ/scripts/nomes_apps.sh" "$@" </dev/null 2>&1
}
modos() { stat -c '%a' "$AP/seiscentos.desktop" "$AP/seiscentos-e-quarenta-e-quatro.desktop" "$AP/setecentos.desktop" | paste -sd' '; }
saida="$(nomes --conferir)"; rc=$?
[ "$rc" = 1 ] && [ "$(modos)" = "600 644 755" ] && printf '%s' "$saida" | grep -q 'seiscentos.desktop está com permissão 600' \
  && ok "permissão: o conferir acusa o 600 e o 755, e não escreve" \
  || falha "permissão: o conferir não acusou, ou escreveu (rc=$rc, modos=$(modos))" "$saida"
saida="$(nomes --so-sistema)"; rc=$?
[ "$(modos)" = "600 644 755" ] \
  && ok "permissão: o gatilho do apt (--so-sistema, que roda como root) não chega ao home" \
  || falha "permissão: o --so-sistema mexeu no home (modos=$(modos))" "$saida"
saida="$(nomes --sem-sudo)"; rc=$?
[ "$rc" = 1 ] && [ "$(modos)" = "644 644 644" ] \
  && ok "permissão: o conserto do doctor (--sem-sudo) devolve 644" \
  || falha "permissão: o --sem-sudo não devolveu 644 (rc=$rc, modos=$(modos))" "$saida"
saida="$(nomes --conferir)"; rc=$?
[ "$rc" = 0 ] && ok "permissão: depois do conserto, o conferir dá 0" || falha "permissão: conferir depois do conserto devolveu $rc" "$saida"
chmod 600 "$AP/seiscentos.desktop"
saida="$(nomes --aplicar --so-flatpak)"; rc=$?
[ "$rc" = 1 ] && [ "$(stat -c '%a' "$AP/seiscentos.desktop")" = 644 ] \
  && ok "permissão: o gatilho do flatpak (--so-flatpak) também conserta — é o evento que deixa o 600" \
  || falha "permissão: o --so-flatpak não consertou (rc=$rc)" "$saida"
# O chmod que falha é erro, mas não pode calar o lançador: com um nome encurtado
# na mesma passada, o `meow_lancador_reler` roda antes do erro (revisão da P42,
# 24/09/2026). O `chmod` de mentira falha só no `trava.desktop`.
#   O LANÇADOR É DE MENTIRA, E HÁ DOIS — 24/09/2026, depois do conserto do
#   `meow_lancador_reler`: ele deixou de ser `pkill -f` na máquina inteira e
#   passou a mirar só o processo deste usuário E deste HOME. Então a prova é o
#   comportamento: um `cosmic-launcher` de mentira com o HOME da casa tem de
#   morrer, e um com outro HOME tem de continuar vivo. O de quem roda o teste
#   (HOME de verdade) está no mesmo caso do segundo.
BIN9="$T/bin9"; mkdir -p "$BIN9"
printf '#!/bin/sh\ncase "$*" in *trava.desktop*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v chmod)" > "$BIN9/chmod"
chmod +x "$BIN9/chmod"
mkdir -p "$T/casa9" "$T/outra9"
lancador_de_mentira() {  # $1 = HOME dele · $2 = arquivo do PID
  setsid -f env -i HOME="$1" bash -c 'echo $$ > "$0"; exec -a cosmic-launcher sleep 300' "$2"
}
lancador_de_mentira "$T/casa9" "$T/pid-casa9"; lancador_de_mentira "$T/outra9" "$T/pid-outra9"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$T/pid-casa9" ] && [ -s "$T/pid-outra9" ] && break; sleep 0.2; done
printf '[Desktop Entry]\nName=Um Nome Comprido Demais\n' > "$AP/meow-teste-longo.desktop"
printf '[Desktop Entry]\nName=trava\n' > "$AP/trava.desktop"; chmod 600 "$AP/trava.desktop"
printf 'meow-teste-longo:Curto\n' > "$T/mapa9b"
saida="$(env -i PATH="$BIN9:$PATH" HOME="$T/casa9" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado9" \
    MEOW_NOMES_MAPA="$T/mapa9b" NO_COLOR=1 "$RAIZ/scripts/nomes_apps.sh" --sem-sudo </dev/null 2>&1)"; rc=$?
sleep 0.5
casa_morreu=0; kill -0 "$(cat "$T/pid-casa9")" 2>/dev/null || casa_morreu=1
outra_viva=0; kill -0 "$(cat "$T/pid-outra9")" 2>/dev/null && outra_viva=1
kill "$(cat "$T/pid-casa9")" "$(cat "$T/pid-outra9")" 2>/dev/null
[ "$rc" = 2 ] && grep -qx 'Name=Curto' "$AP/meow-teste-longo.desktop" && [ "$casa_morreu" = 1 ] \
  && ok "permissão: o chmod que falha é erro (rc=2), mas só depois de o lançador reler o nome encurtado" \
  || falha "permissão: o chmod que falhou calou o lançador (rc=$rc, lançador da casa morreu=$casa_morreu)" "$saida"
[ "$outra_viva" = 1 ] \
  && ok "lançador: o reler só alcança o lançador desta casa — o de outro HOME ficou vivo" \
  || falha "lançador: o reler matou o lançador de outro HOME — o sinal saiu da casa"

# ---------------------------------------------------------------------------
# 8. O DESFAZER DO OBSIDIAN SÓ VOLTA O QUE É DELE, E EM TODOS OS COFRES
# ---------------------------------------------------------------------------
# POR QUE ESTA SEÇÃO NASCEU — 24/09/2026, na revisão da P43
#   O item 5 da P43 tirou do módulo o cofre escrito por extenso: o cofre passou
#   a sair do `obsidian.json`, o que o Obsidian abriu por último. O `aplicar`
#   ficou certo. O `reverter` herdou a mesma pergunta e ficou errado: com o
#   cofre A tematizado, bastava a pessoa abrir o cofre B e escolher ali um tema
#   dela para o desfazer ir ao B — zerava o `cssTheme` dela, tirava o snippet,
#   sem backup, dizia que tinha tirado o tema e deixava o A tematizado. Com o
#   doctor diário tematizando o cofre da vez, o `--uninstall` deixava o tema em
#   todos os cofres de antes.
#
#   A casa de brinquedo tem DOIS cofres, de nomes inventados, e três tempos:
#     1. o `aplicar` tematiza o A, o único que o obsidian.json conhece;
#     2. a pessoa abre o B (fica `open`, com o `ts` maior) e escolhe um tema dela;
#     3. o `reverter`.
#   O A tem de voltar, arquivo por arquivo, ao que era antes do MeowSystem, e o
#   appearance.json tematizado tem de ficar num backup. O B tem de ficar byte a
#   byte como ela o deixou.
#
#   O flatpak e o pgrep daqui são de brinquedo: basta existirem, e o pgrep que
#   sai 1 é "o Obsidian está fechado". Sem ele, um Obsidian aberto na máquina de
#   quem roda o teste faria o módulo recusar, e a seção falharia por fora. O
#   XDG_CONFIG_HOME vai para dentro da casa pelo mesmo motivo que o HOME: é por
#   ali que o módulo acharia o obsidian.json de verdade.
C="$T/casa7"
A="$C/Cofre Alfa"
B="$C/cofre-beta"
OBS_JSON="$C/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
mkdir -p "$C/bin" "$(dirname "$OBS_JSON")" "$A/.obsidian" "$B/.obsidian/snippets" \
         "$B/.obsidian/themes/Tema de Brinquedo"
printf '#!/bin/sh\nexit 1\n' > "$C/bin/flatpak"
printf '#!/bin/sh\nexit 1\n' > "$C/bin/pgrep"
chmod +x "$C/bin/flatpak" "$C/bin/pgrep"

# O A antes do MeowSystem, gravado como o Obsidian grava: indentação de 2 e sem
# \n no fim. O `cssTheme` vazio é o padrão do app, que é para onde o desfazer
# devolve.
printf '{\n  "theme": "obsidian",\n  "cssTheme": "",\n  "baseFontSize": 16\n}' \
  > "$A/.obsidian/appearance.json"

impressao() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum); }

modulo_obsidian() {
  (
    export HOME="$C" XDG_CONFIG_HOME="$C/.config"
    export MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$C/estado" NO_COLOR=1
    export PATH="$C/bin:$PATH"
    unset MEOW_OBSIDIAN_VAULT
    # shellcheck disable=SC1091
    . "$RAIZ/lib/comum.sh" || exit 2
    # shellcheck disable=SC1091
    . "$ACERVO/obsidian/manifesto.sh" || exit 2
    "meow_app_$1" 2>&1
    printf 'rc=%s\n' "$?"
  )
}

a_antes="$(impressao "$A")"

# 1. o aplicar tematiza o A
printf '{"vaults":{"a1":{"path":"%s","ts":1000,"open":true}}}' "$A" > "$OBS_JSON"
saida="$(modulo_obsidian aplicar)"
if printf '%s' "$saida" | grep -q 'rc=1' && [ -f "$A/.obsidian/themes/Catppuccin/theme.css" ] \
   && grep -q '"cssTheme": "Catppuccin"' "$A/.obsidian/appearance.json"; then
  ok "obsidian: o aplicar tematiza o cofre que o obsidian.json conhece"
else
  falha "obsidian: o aplicar não tematizou o cofre A da casa de brinquedo" "$saida"
fi
a_tematizado="$(sha256sum < "$A/.obsidian/appearance.json" | cut -d' ' -f1)"

# 2. a pessoa abre o B e escolhe um tema dela, com o snippet dela ligado
printf '{\n  "theme": "obsidian",\n  "cssTheme": "Tema de Brinquedo",\n  "enabledCssSnippets": [\n    "dracula_background"\n  ]\n}' \
  > "$B/.obsidian/appearance.json"
printf '.theme-dark { --background-primary: #101010; }' > "$B/.obsidian/themes/Tema de Brinquedo/theme.css"
printf 'body { background: #202020; }' > "$B/.obsidian/snippets/dracula_background.css"
printf '{"vaults":{"a1":{"path":"%s","ts":1000},"b2":{"path":"%s","ts":2000,"open":true}}}' \
  "$A" "$B" > "$OBS_JSON"
b_antes="$(impressao "$B")"

# 3. o desfazer
saida="$(modulo_obsidian reverter)"
if [ "$(impressao "$B")" = "$b_antes" ]; then
  ok "obsidian: o desfazer não toca no cofre que o MeowSystem nunca tematizou"
else
  falha "obsidian: o desfazer mexeu no cofre B, que tinha um tema escolhido pela pessoa" \
        "$saida
$(diff <(printf '%s\n' "$b_antes") <(impressao "$B"))"
fi
if [ "$(impressao "$A")" = "$a_antes" ]; then
  ok "obsidian: o desfazer devolve o cofre tematizado ao que era antes do MeowSystem"
else
  falha "obsidian: o cofre A não voltou ao que era antes do MeowSystem" \
        "$saida
$(diff <(printf '%s\n' "$a_antes") <(impressao "$A"))"
fi
if find "$C/estado/backups" -path '*/obsidian/*' -type f -exec sha256sum {} + 2>/dev/null \
   | grep -q "^$a_tematizado "; then
  ok "obsidian: o appearance.json tematizado ficou num backup antes de ser desfeito"
else
  falha "obsidian: nenhum backup guarda o appearance.json tematizado do A" "$saida"
fi

# E desfeito é desfeito: a segunda passada não tem nada a fazer, e diz 0.
saida="$(modulo_obsidian reverter)"
if printf '%s' "$saida" | grep -q 'rc=0' && [ "$(impressao "$B")" = "$b_antes" ]; then
  ok "obsidian: o segundo desfazer não acha nada a fazer (rc=0)"
else
  falha "obsidian: o segundo desfazer não devolveu 0, ou mexeu no B" "$saida"
fi

# ---------------------------------------------------------------------------
# 9. A LISTA DO SPICETIFY SE SEPARA POR `|`
# ---------------------------------------------------------------------------
# POR QUE ESTA SEÇÃO NASCEU — 24/09/2026, na instalação
#   O `config-xpui.ini` guarda as listas com `|` (`custom_apps = a|b|c`), e o
#   `_spot_mp_registrado` procurava `,marketplace,`. Com um CustomApp só, a
#   lista era a própria palavra e passava; com quatro, a máquina que instalou
#   em 24/09 ouviu "o spicetify não gravou o custom_apps" com o Marketplace lá.
CASA9="$T/casa9"; mkdir -p "$CASA9/.config/spicetify"
spot_registrado() {  # <valor do custom_apps>
  printf '[AdditionalOptions]\ncustom_apps           = %s\n' "$1" > "$CASA9/.config/spicetify/config-xpui.ini"
  env -i PATH="$PATH" HOME="$CASA9" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado9" NO_COLOR=1 \
    bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
             . "$MEOW_RAIZ/assets/temas-de-apps/spotify/manifesto.sh" >/dev/null 2>&1 || exit 2
             _spot_mp_registrado' </dev/null >/dev/null 2>&1
}
f9=""
spot_registrado "marketplace|lyrics-plus|reddit|new-releases" || f9+=" [no começo de uma lista com |]"
spot_registrado "lyrics-plus|marketplace" || f9+=" [no fim]"
spot_registrado "marketplace" || f9+=" [sozinho]"
spot_registrado "lyrics-plus, marketplace" || f9+=" [com vírgula]"
spot_registrado "lyrics-plus|reddit" && f9+=" [ausente dado como presente]"
spot_registrado "marketplace-extra|lyrics" && f9+=" [um nome que só começa com marketplace]"
[ -z "$f9" ] \
  && ok "spotify: o Marketplace é achado no custom_apps, com a lista separada por |" \
  || falha "spotify: a leitura do custom_apps errou:$f9"

# ---------------------------------------------------------------------------
printf '\n'
if [ "$falhas" -gt 0 ]; then
  printf '%s achado(s).\n' "$falhas" >&2
  exit 1
fi
printf 'Os módulos migrados obedecem ao pack, e os três caminhos da leitura funcionam.\n'
exit 0
