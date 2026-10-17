#!/usr/bin/env bash
# temas-de-apps.sh — os módulos de `assets/temas-de-apps/` obedecem ao PACK.
#
# Zero é o destino, e para spotify e qbittorrent ele já vale HOJE.
#
# Um módulo que ganhe uma citação nova falha aqui; um módulo que perca as suas
# cobra que o número seja baixado.
#
# Linha cujo primeiro caractere não-branco NÃO é `#`.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACERVO="$RAIZ/assets/temas-de-apps"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

# MIGRADOS: perguntam ao pack e não conhecem mais o nome de tema nenhum. Os
# cinco do fim NASCERAM migrados,: são os temas que o Dracula de antes
# aplicava, e cada um lê um MODELO do pack (seções 7 e 8).
MIGRADOS=(spotify qbittorrent kitty gnome-terminal telegram discord onlyoffice)

# A TABELA. Ela só desce.
declare -A TETO=(
  [spotify]=0
  [qbittorrent]=0
  [toolkits-gtk-qt]=0  # nunca teve citação em código; as 5 dele são comentário
  [zapzap]=0
  [heroic]=0
  [btop-bat]=2
  [vscode]=0
  [obsidian]=0
  [kitty]=0
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
  # Os dois módulos migrados nasceram assim, e a procedência chegava vazia em
  # todas as telas deles.
  #
  # Só CÓDIGO, pela mesma régua da seção 1: a linha que conta é a que não começa
  # por `#`.
  if grep -n '\$(meow_app_tema_do_pack' "$arq" | grep -qv '^[0-9]*: *#'; then
    falha "$mod: chama meow_app_tema_do_pack dentro de \$( )" \
          "  \$( ) é subshell: MEOW_APP_TEMA_PACK morre lá dentro e a procedência some."
  else
    ok "$mod: chama meow_app_tema_do_pack direto, sem \$( )"
  fi
done

# 3. AS TRÊS SAÍDAS DE `meow_app_tema_no_ar`
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

# `app/<id>/<arquitetura>/<ramo>/active` apontando para a pasta do commit, que é
# o que o `meow_flatpak_tem` pergunta.
implantar() {  # <raiz da instalação> <id>
  local ramo="$1/app/$2/x86_64/stable"
  mkdir -p "$ramo/0123abcd" && ln -sfn 0123abcd "$ramo/active"
}

tres_saidas() {
  # Subshell com estado de brinquedo: a terceira saída REGISTRA pendência, e
  # pendência é arquivo.
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

# O `apps` do pack padrão é o que faz os módulos terem o que aplicar; o do
# Dracula é a prova de que um segundo pack manda no mesmo módulo.
saida="$(python3 "$RAIZ/scripts/pack.py" app dracula apps.spotify.spicetify_tema 2>&1)"
if printf '%s' "$saida" | grep -qx 'pack=dracula'; then
  ok "pack: o Dracula responde pelo próprio Spotify"
else
  falha "pack: 'app dracula apps.spotify.spicetify_tema' não respondeu pelo dracula" "$saida"
fi

# O qBittorrent do Dracula deixou de ser herdado: o pack traz o tema oficial
# dele. A herança segue provada pelo `vscode-icones`, que o Dracula não
# declara de propósito (`_nota_vscode_icones`).
saida="$(python3 "$RAIZ/scripts/pack.py" app dracula apps.qbittorrent.arquivo 2>&1)"
if printf '%s' "$saida" | grep -qx 'pack=dracula'; then
  ok "pack: o Dracula responde pelo próprio qBittorrent (P74)"
else
  falha "pack: 'app dracula apps.qbittorrent.arquivo' não respondeu pelo dracula" "$saida"
fi
saida="$(python3 "$RAIZ/scripts/pack.py" app dracula apps.vscode-icones.esquema 2>&1)"
if printf '%s' "$saida" | grep -qx 'pack=catppuccin'; then
  ok "pack: o vscode-icones do Dracula é herdado, e o log diz de quem"
else
  falha "pack: a herança de apps.vscode-icones não apontou para o catppuccin" "$saida"
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

# Ela exercita a função e NUNCA o caminho que os módulos usam: perguntar ao pack
# e deixar a resposta chegar sozinha.
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

# A trava do módulo do qBittorrent é um `grep` pelo NOME do pack dentro do
# script do Aurora.
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

# Um hex escrito num modelo é o flavor `dracula` cravado — o `alucard` sairia
# com uma cor escura no meio, e nada acusaria.
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

# Casa, XDG, estado, packs e flatpak de brinquedo; o `env -i` tira o D-Bus da sessão,
# e nem um `dconf` de verdade alcançaria o banco de quem roda.
CASA="$T/casa8"
BIN="$T/bin8"
mkdir -p "$CASA" "$BIN" "$T/packs8"
mod() {  # <módulo> <verbo> [VAR=valor ...]
  local m="$1" v="$2"; shift 2
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" \
      XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$T/packs8" MEOW_RAIZ="$RAIZ" \
      MEOW_ESTADO="$T/estado8" PACK=dracula FLAVOR=dracula NO_COLOR=1 \
      FLATPAK_SYSTEM_DIR="$T/flatpak-sistema" FLATPAK_CONFIG_DIR="$T/flatpak-etc" "$@" \
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
mkdir -p "$K"; printf 'include current-theme.conf\nforeground #ffffff\n' > "$K/kitty.conf"
saida="$(mod kitty aplicar)"; rc=$?
[ "$rc" = 3 ] && [ ! -e "$K/current-theme.conf" ] \
  && ok "kitty: cor escrita no kitty.conf conta como tema dela (rc=3), e nada é escrito" \
  || falha "kitty: sobrescreveu as cores escritas no kitty.conf (rc=$rc)" "$saida"
rm -rf "$K"
# O `include` fora do bloco também é tema dela, quando o incluído pinta — é como
# o dracula/kitty manda instalar (`include dracula.conf`). E o `include` que só
# traz fonte não é tema: aplica, e a linha dela fica.
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
implantar "$CASA/.local/share/flatpak" org.telegram.desktop
TG="$CASA/.local/share/meowsystem/temas-de-apps/telegram/MeowSystem.tdesktop-theme"
saida="$(mod telegram aplicar)"; rc=$?
[ "$rc" = 1 ] && grep -q '^// meowsystem-tema: dracula/dracula' "$TG" 2>/dev/null \
  && ! printf '%s' "$saida" | grep -q 'está sem tema' \
  && ok "telegram: aplicar entrega o tema montado no lugar fixo, e não diz que o app está sem tema" \
  || falha "telegram: o tema não foi entregue, ou a tela disse 'está sem tema' (rc=$rc)" "$saida"
# O que daqui se lê é o ARQUIVO, e não o tema no ar (ele mora no `tdata`): a
# segunda passada diz "entregue", nunca "já está no tema do pack".
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
implantar "$CASA/.local/share/flatpak" com.discordapp.Discord
saida="$(mod discord aplicar)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q 'cliente modificado' \
  && ok "discord: o cliente oficial sozinho é pendência, e o motivo diz o que falta" \
  || falha "discord: sem cliente modificado não saiu pendência com motivo (rc=$rc)" "$saida"
# A tabela do `meow apps` dizia Discord e qBittorrent «não instalado» com os
# dois flatpaks do usuário no disco: a coluna lia o código do `detectar`, e ele
# sai 3 pelo cliente que falta, ou pelo tema que já está no ar.
tabela() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" \
      XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$T/packs8" MEOW_RAIZ="$RAIZ" \
      FLATPAK_SYSTEM_DIR="$T/flatpak-sistema" FLATPAK_CONFIG_DIR="$T/flatpak-etc" \
      PACK=dracula FLAVOR=dracula NO_COLOR=1 APPS_ATIVOS="$1" \
      "$RAIZ/scripts/aplicar_apps.sh" tabela </dev/null 2>/dev/null
}
implantar "$CASA/.local/share/flatpak" org.qbittorrent.qBittorrent
saida="$(tabela discord,qbittorrent | cut -f1-4)"
[ "$saida" = "$(printf 'discord\tdiscord\t0\t3\nqbittorrent\tqbittorrent\t0\t1')" ] \
  && ok "meow apps: Discord e qBittorrent instalados e pendentes saem «instalado» na tabela" \
  || falha "meow apps: a coluna «instalado» ainda não é a do programa no disco" "$saida"
rm -rf "$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent"
# As cinco casas abaixo são as que o flatpak consulta, pelas variáveis dele: a
# do usuário, a do sistema (`FLATPAK_SYSTEM_DIR`) e uma declarada num `.conf`
# de `installations.d` (`FLATPAK_CONFIG_DIR`) — mais a pasta de dados sozinha e
# a pasta do app sem implantação (a sobra de uma remoção), que não são
# instalação nenhuma.
fp() {  # <id> — o código de saída do meow_flatpak_tem nesta casa
  env -i PATH="$PATH" HOME="$CASA" XDG_DATA_HOME="$CASA/.local/share" MEOW_RAIZ="$RAIZ" \
      MEOW_ESTADO="$T/estado8" FLATPAK_SYSTEM_DIR="$T/flatpak-sistema" \
      FLATPAK_CONFIG_DIR="$T/flatpak-etc" \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2; meow_flatpak_tem "$1"' _ "$1" \
      </dev/null >/dev/null 2>&1
  printf '%s' "$?"
}
mkdir -p "$CASA/.var/app/com.exemplo.SoDados/config" "$CASA/.local/share/flatpak/app/com.exemplo.Sobra"
implantar "$CASA/.local/share/flatpak" com.exemplo.Usuario
implantar "$T/flatpak-sistema" com.exemplo.Sistema
mkdir -p "$T/flatpak-etc/installations.d"
printf '[Installation "extra"]\nPath=%s\nDisplayName=Um cartão de brinquedo\n' "$T/flatpak-extra" \
  > "$T/flatpak-etc/installations.d/extra.conf"
implantar "$T/flatpak-extra" com.exemplo.Extra
esperado="" achou=""
for par in com.exemplo.SoDados:1 com.exemplo.Sobra:1 com.exemplo.Usuario:0 \
           com.exemplo.Sistema:0 com.exemplo.Extra:0; do
  esperado+=" $par"
  achou+=" ${par%%:*}:$(fp "${par%%:*}")"
done
[ "$achou" = "$esperado" ] \
  && ok "flatpak instalado é a implantação numa das instalações do flatpak — e a pasta de dados sozinha não é" \
  || falha "flatpak: a regra de «instalado» errou (0 = instalado)" "  esperado:$esperado
  achou:   $achou"
# E A TABELA DIZ O MESMO: o qBittorrent de que sobrou só a pasta de dados sai
# «não instalado» no `meow apps`.
mkdir -p "$CASA/.var/app/org.qbittorrent.qBittorrent/config"
saida="$(tabela qbittorrent)"
[ "$(printf '%s' "$saida" | cut -f3)" = 1 ] \
  && ok "meow apps: o qBittorrent de que sobrou só a pasta de dados sai «não instalado»" \
  || falha "meow apps: a pasta de dados de um app desinstalado ainda conta como instalado" "$saida"
rm -rf "$CASA/.var/app/org.qbittorrent.qBittorrent" "$CASA/.var/app/com.exemplo.SoDados" \
       "$CASA/.local/share/flatpak/app/com.exemplo."*
DC="$CASA/.config/Vencord/themes"
mkdir -p "$DC"
saida="$(mod discord aplicar)"; rc=$?
[ "$rc" = 1 ] && grep -q 'meowsystem-tema: dracula/dracula' "$DC/MeowSystem.theme.css" 2>/dev/null \
  && ok "discord: com o Vencord, o tema vai para a pasta themes/ dele" \
  || falha "discord: o tema não chegou à pasta do Vencord (rc=$rc)" "$saida"
saida="$(mod discord conferir)"; rc=$?
[ "$rc" = 0 ] && ok "discord: depois de aplicar, o conferir dá 0" || falha "discord: conferir devolveu $rc" "$saida"
# O tema vai para a lista `enabledThemes` do `settings/settings.json` do
# Vencord, e o que já estava lá fica; o desfazer o tira da lista junto com o
# arquivo.
VS="$CASA/.config/Vencord/settings/settings.json"
ligado() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(" ".join(d.get("enabledThemes",[])), d.get("outra","-"))' "$VS" 2>&1; }
[ "$(ligado)" = "MeowSystem.theme.css -" ] \
  && ok "discord: o tema do pack sai ligado no Vencord (enabledThemes)" \
  || falha "discord: o tema não foi ligado no settings.json do Vencord" "$(ligado)"
python3 -c 'import json,sys;json.dump({"enabledThemes":["dela.css"],"outra":"fica"},open(sys.argv[1],"w"))' "$VS"
# COM O VESKTOP DO FLATPAK ABERTO, NADA SE ESCREVE: o
# processo dele é `vesktop.bin`, e um `pgrep` que só conhece esse nome tem de
# segurar a escrita — senão ele desfaz a lista na próxima gravação dele.
printf '#!/bin/sh\n[ "$1" = "-x" ] && [ "$2" = "vesktop.bin" ] && exit 0\nexit 1\n' > "$BIN/pgrep"; chmod +x "$BIN/pgrep"
antes_vs="$(cat "$VS")"
saida="$(mod discord aplicar)"; rc_v=$?
falso pgrep 1
[ "$rc_v" = 3 ] && [ "$(cat "$VS")" = "$antes_vs" ] \
  && ok "discord: com o Vesktop do flatpak aberto (vesktop.bin), a lista do cliente não é escrita" \
  || falha "discord: o Vesktop aberto não segurou a escrita do settings.json (rc=$rc_v)" "$saida"
saida="$(mod discord conferir)"; rc_c=$?
saida="$saida$(mod discord aplicar)"; rc_a=$?
[ "$rc_c" = 1 ] && [ "$rc_a" = 1 ] && [ "$(ligado)" = "dela.css MeowSystem.theme.css fica" ] \
  && ok "discord: desligado, o conferir acusa e o aplicar liga, sem tocar no tema e na chave dela" \
  || falha "discord: o tema desligado não foi religado, ou o resto do settings.json mudou (rc $rc_c/$rc_a)" "$(ligado)
$saida"
saida="$(mod discord reverter)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$DC/MeowSystem.theme.css" ] && [ "$(ligado)" = "dela.css fica" ] \
  && ok "discord: desfazer tira o tema da pasta e da lista do cliente" \
  || falha "discord: desfazer não tirou o tema (rc=$rc)" "$saida
$(ligado)"

# --- OnlyOffice ----------------------------------------------------------
#   O conf é de mentira mas tem a forma do de verdade: `appdata` é um JSON em
#   base64 dentro de `@ByteArray(...)`, e a escolha mora nele e no `UITheme`.
implantar "$CASA/.local/share/flatpak" org.onlyoffice.desktopeditors
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
# próprio tema como de terceiro na segunda passagem.
printf '[General]\nUITheme=theme-dark\n' > "$OO_CONF"
mod onlyoffice aplicar >/dev/null; rc1=$?
saida="$(mod onlyoffice aplicar)"; rc2=$?
mod onlyoffice reverter >/dev/null
[ "$rc1" = 1 ] && [ "$rc2" = 0 ] && [ "$(cat "$OO_CONF")" = "$(printf '[General]\nUITheme=theme-dark')" ] \
  && ok "onlyoffice: sem appdata, o caminho no UITheme é lido pelo id do JSON — o nosso segue sendo o nosso" \
  || falha "onlyoffice: sem appdata o próprio tema virou terceiro (rc=$rc1 e $rc2)" "$saida$(cat "$OO_CONF")"
# NUNCA ABERTO: sem o conf, a escolha não tem onde morar. O tema vai para a
# pasta e a escolha espera, dita como pendência nas duas passadas e no conferir.
rm -f "$OO_CONF"
saida="$(mod onlyoffice aplicar)"; rc1=$?
saida="$saida$(mod onlyoffice aplicar)"; rc2=$?
saida="$saida$(mod onlyoffice conferir)"; rc3=$?
[ "$rc1" = 3 ] && [ "$rc2" = 3 ] && [ "$rc3" = 3 ] && [ -f "$OO_ARQ" ] && [ ! -e "$OO_CONF" ] \
  && ! printf '%s' "$saida" | grep -qE 'já está no tema do pack|tema do pack aplicado' \
  && ok "onlyoffice: nunca aberto, o tema vai para a pasta e a escolha é pendência — no aplicar e no conferir (rc=3)" \
  || falha "onlyoffice: nunca aberto, a tela e os códigos discordam (aplicar=$rc1 e $rc2, conferir=$rc3)" "$saida"
mod onlyoffice reverter >/dev/null

# A linha passa a levar o comando (é o que acende os botões na Home), e a
# resposta chega pelo ambiente: `manter` grava e cala a pendência nas passagens
# seguintes; `trocar` troca, e esquece o `manter`.
pend() { awk -F'\t' -v i="$1" '$1 == i { print $4 }' "$T/estado8/pendencias.tsv" 2>/dev/null; }
mantidos="$T/estado8/temas-mantidos.tsv"
oo_conf theme-de-alguem
antes="$(cat "$OO_CONF")"
faltam=""
saida="$(mod onlyoffice aplicar)"; rc=$?
[ "$rc" = 3 ] && [ "$(pend onlyoffice-tema-de-terceiro)" = "meow apps aplicar onlyoffice" ] \
  && ! printf '%s' "$saida" | grep -q 'de um terminal' \
  || faltam+=" a pendência não leva o comando, ou ainda manda ao terminal (rc=$rc);"
saida="$(mod onlyoffice aplicar MEOW_TEMA_DE_TERCEIRO=manter)"; rc=$?
[ "$rc" = 3 ] && [ "$(cat "$OO_CONF")" = "$antes" ] && [ -z "$(pend onlyoffice-tema-de-terceiro)" ] \
  && grep -qxF "$(printf 'onlyoffice\ttheme-de-alguem')" "$mantidos" 2>/dev/null \
  || faltam+=" «Manter o meu» não gravou, mexeu no conf, ou deixou a pendência (rc=$rc: $saida);"
saida="$(mod onlyoffice aplicar)"; rc=$?
[ "$rc" = 3 ] && [ -z "$(pend onlyoffice-tema-de-terceiro)" ] && printf '%s' "$saida" | grep -q 'como você escolheu' \
  || faltam+=" depois do «Manter o meu» a pendência voltou (rc=$rc: $saida);"
# Outro tema que não veio daqui é pergunta nova; mantido também, ele SOMA ao
# primeiro, e não o apaga — é o caso do Discord, uma pergunta por pasta.
oo_conf theme-outro-dela
saida="$(mod onlyoffice aplicar)"; rc=$?
[ "$rc" = 3 ] && [ -n "$(pend onlyoffice-tema-de-terceiro)" ] \
  || faltam+=" outro tema de terceiro não perguntou de novo (rc=$rc: $saida);"
saida="$(mod onlyoffice aplicar MEOW_TEMA_DE_TERCEIRO=manter)"; rc=$?
[ "$(grep -c '^onlyoffice' "$mantidos" 2>/dev/null)" = 2 ] \
  || faltam+=" o segundo «Manter o meu» apagou o primeiro ($(cat "$mantidos" 2>/dev/null | tr '\t\n' ' |'));"
oo_conf theme-de-alguem
saida="$(mod onlyoffice aplicar MEOW_TEMA_DE_TERCEIRO=trocar MEOW_DRY_RUN=1)"; rc=$?
[ "$(cat "$OO_CONF")" = "$antes" ] && grep -q '^onlyoffice' "$mantidos" \
  || faltam+=" o ensaio do «Trocar» escreveu (rc=$rc: $saida);"
saida="$(mod onlyoffice aplicar MEOW_TEMA_DE_TERCEIRO=trocar)"; rc=$?
[ "$rc" = 1 ] && [ "$(oo_escolha)" = theme-meowsystem ] && ! grep -q '^onlyoffice' "$mantidos" \
  || faltam+=" «Trocar pelo tema do pack» não trocou, ou não esqueceu o «Manter» (rc=$rc: $saida);"
mod onlyoffice reverter >/dev/null
[ -z "$faltam" ] \
  && ok "onlyoffice: a escolha vem do painel — «Manter o meu» grava e cala, «Trocar» troca, e o ensaio não escreve" \
  || falha "onlyoffice: a escolha do painel não cumpre:$faltam"

# O resumo do `aplicar_apps.sh` segue o tempo verbal do seco, e a frase da
# pendência cita o que o `--onde` do servidor diz dela — o nome dos botões não
# vem escrito aqui.
apps8() {  # <verbo> <apps> [VAR=valor ...] — o `aplicar_apps.sh` nesta casa
  local v="$1" a="$2"; shift 2
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" \
      XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$T/packs8" MEOW_RAIZ="$RAIZ" \
      MEOW_ESTADO="$T/estado8" PACK=dracula FLAVOR=dracula NO_COLOR=1 APPS_ATIVOS="$a" \
      FLATPAK_SYSTEM_DIR="$T/flatpak-sistema" FLATPAK_CONFIG_DIR="$T/flatpak-etc" "$@" \
      "$RAIZ/scripts/aplicar_apps.sh" "$v" </dev/null 2>&1
}
faltam=""
oo_conf theme-de-alguem
antes="$(cat "$OO_CONF")"
saida="$(apps8 aplicar onlyoffice MEOW_TEMA_DE_TERCEIRO=trocar MEOW_DRY_RUN=1)"; rc=$?
[ "$rc" = 1 ] && [ "$(cat "$OO_CONF")" = "$antes" ] && printf '%s' "$saida" | grep -q 'aplicaria: onlyoffice' \
  && ! printf '%s' "$saida" | grep -q 'aplicados:' \
  || faltam+=" o ensaio do «Trocar» não terminou em «aplicaria» (rc=$rc: $saida);"
onde="$(env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" \
          python3 "$RAIZ/app/servidor.py" --onde onlyoffice-tema-de-terceiro 2>/dev/null)"
saida="$(apps8 aplicar onlyoffice)"; rc=$?
[ "$rc" = 0 ] && [ -n "$onde" ] \
  && printf '%s' "$saida" | grep -qF "resolve: no painel, $onde" \
  && ! printf '%s' "$saida" | grep -qF "resolve: meow apps aplicar" \
  || faltam+=" a gaveta não aponta os botões da Início (rc=$rc, --onde «$onde»: $saida);"
mod onlyoffice aplicar MEOW_TEMA_DE_TERCEIRO=trocar >/dev/null
saida="$(apps8 reverter onlyoffice MEOW_DRY_RUN=1)"; rc=$?
[ "$rc" = 1 ] && [ "$(oo_escolha)" = theme-meowsystem ] && printf '%s' "$saida" | grep -q 'desfaria: onlyoffice' \
  && ! printf '%s' "$saida" | grep -q 'desfeitos:' \
  || faltam+=" o ensaio do desfazer não terminou em «desfaria», ou escreveu (rc=$rc: $saida);"
mod onlyoffice reverter >/dev/null
[ -z "$faltam" ] \
  && ok "P62: o ensaio do OnlyOffice diz «aplicaria» e «desfaria», e a gaveta cita os botões que o --onde dá" \
  || falha "P62: o ensaio ou a gaveta do OnlyOffice:$faltam"

# Agora ele é o escritor: sem tema no app, o tema do pack entra e as duas
# chaves do conf apontam para ele, e o resto do conf fica; com o app aberto,
# nada se escreve (ele reescreve o conf ao sair); e vestido por ela, o conf
# dela fica, e a linha diz o fato.
falso flatpak
implantar "$CASA/.local/share/flatpak" org.qbittorrent.qBittorrent
QB="$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
mkdir -p "$QB"
printf '[BitTorrent]\nSession\\Port=6881\n\n[Preferences]\nGeneral\\Locale=pt_BR\nGeneral\\UseCustomUITheme=false\n' > "$QB/qBittorrent.conf"
falso pgrep 0
saida="$(mod qbittorrent aplicar)"; rc0=$?
aberto="$(cat "$QB/qBittorrent.conf")"
falso pgrep 1
saida="$saida$(mod qbittorrent aplicar)"; rc1=$?
tinha="$(awk -F'\t' '$1 == "qbittorrent-conf-fora-de-escopo"' "$T/estado8/pendencias.tsv" 2>/dev/null)"
alvo_qb="$QB/themes/dracula.qbtheme"
escrito_ok=0
grep -qxF 'General\UseCustomUITheme=true' "$QB/qBittorrent.conf" \
  && grep -qxF "General\\CustomUIThemePath=$alvo_qb" "$QB/qBittorrent.conf" \
  && grep -qxF 'General\Locale=pt_BR' "$QB/qBittorrent.conf" && grep -qxF 'Session\Port=6881' "$QB/qBittorrent.conf" \
  && cmp -s "$alvo_qb" "$RAIZ/packs/dracula/apps/dracula.qbtheme" && escrito_ok=1
saida="$saida$(mod qbittorrent aplicar)"; rc1b=$?
printf '[Preferences]\nGeneral\\CustomUIThemePath=%s/.themes/dela.qbtheme\nGeneral\\UseCustomUITheme=true\n' \
  "$CASA" > "$QB/qBittorrent.conf"
antes="$(cat "$QB/qBittorrent.conf")"
saida="$saida$(mod qbittorrent aplicar)"; rc2=$?
ficou="$(awk -F'\t' '$1 == "qbittorrent-conf-fora-de-escopo"' "$T/estado8/pendencias.tsv" 2>/dev/null)"
[ "$rc0" = 3 ] && [[ "$aberto" == *"UseCustomUITheme=false"* ]] \
  && [ "$rc1" = 1 ] && [ "$escrito_ok" = 1 ] && [ -z "$tinha" ] && [ "$rc1b" = 0 ] \
  && [ "$rc2" = 3 ] && [ -z "$ficou" ] \
  && [ "$(cat "$QB/qBittorrent.conf")" = "$antes" ] && printf '%s' "$saida" | grep -q 'já está vestido' \
  && ok "qbittorrent: sem o Aurora o conf é escrito aqui (com o app fechado, só as duas chaves), a 2ª passada é 0, e o vestido por ela fica" \
  || falha "qbittorrent: o escritor próprio do conf (aberto: rc=$rc0, sem tema: rc=$rc1 escrito=$escrito_ok, 2ª: rc=$rc1b, vestido: rc=$rc2)" \
           "$saida
conf: $(cat "$QB/qBittorrent.conf")
pendência antes: $tinha
pendência depois: $ficou"
# Sem motivo, o `--` de antes; com ele, «não veste» e as palavras do módulo na
# linha de baixo.
mv "$CASA/.config/Vencord" "$T/vencord-de-lado"
printf 'PACK="dracula"\nFLAVOR="dracula"\nACCENT="mauve"\nAPPS_ATIVOS="discord,qbittorrent"\n' > "$T/meow8.conf"
saida="$(env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" \
           XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$T/packs8" MEOW_RAIZ="$RAIZ" \
           MEOW_ESTADO="$T/estado8" MEOW_CONF="$T/meow8.conf" TMPDIR="$T" NO_COLOR=1 \
           FLATPAK_SYSTEM_DIR="$T/flatpak-sistema" FLATPAK_CONFIG_DIR="$T/flatpak-etc" \
           "$RAIZ/bin/meow" apps </dev/null 2>&1)"
faltam=""
printf '%s\n' "$saida" | grep -qE '^  qbittorrent +sim +não veste +qbittorrent$' \
  && printf '%s\n' "$saida" | grep -A1 -E '^  qbittorrent ' | tail -n 1 \
       | grep -qE "^ {21}qBittorrent: .*'$CASA/\.themes/dela\.qbtheme', que não veio daqui" \
  || faltam+=" o qBittorrent vestido por ela não saiu «não veste» com o motivo embaixo;"
printf '%s\n' "$saida" | grep -qE '^  discord +sim +não veste +discord$' \
  && printf '%s\n' "$saida" | grep -A1 -E '^  discord ' | tail -n 1 | grep -qE '^ {21}Discord: .*cliente modificado' \
  || faltam+=" o Discord não saiu «não veste» com o motivo do detectar embaixo;"
[ "$(printf '%s\n' "$saida" | grep -cE '^  [a-z-]+ +sim +não veste ')" \
  = "$(printf '%s\n' "$saida" | grep -cE '^ {21}[^ ]')" ] \
  || faltam+=" há «não veste» sem a linha do motivo;"
[ -z "$faltam" ] \
  && ok "meow apps: «não veste» só com o motivo embaixo — o qBittorrent vestido por ela diz o tema que está nele, o Discord diz o cliente que falta" \
  || falha "meow apps: a tabela diz «não veste» sem motivo, ou perde o motivo guardado:$faltam" "$saida"
mv "$T/vencord-de-lado" "$CASA/.config/Vencord"
rm -rf "$CASA/.var/app/org.qbittorrent.qBittorrent" "$BIN/flatpak" \
       "$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent"

# --- GNOME Terminal ------------------------------------------------------
# O `dconf` de mentira guarda cada chave numa linha do HOME de brinquedo, e
# imita os cinco verbos que o módulo usa.
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
dc write "$GT/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/use-theme-colors" false
dc write "$GT/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/visible-name" "'Dracula'"
saida="$(mod gnome-terminal aplicar)"; rc=$?
[ "$rc" = 3 ] && [ -z "$(dc read "$GT/default")" ] && printf '%s' "$saida" | grep -q "perfil 'Dracula'" \
  && ok "gnome-terminal: um perfil padrão com cores próprias fica, e vira pendência (rc=3)" \
  || falha "gnome-terminal: trocou o perfil padrão dela (rc=$rc)" "$saida"

# O mapa de nomes é vazio: um nome encurtado chamaria o `meow_lancador_reler`, que
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
# na mesma passada, o `meow_lancador_reler` roda antes do erro. O `chmod` de
# mentira falha só no `trava.desktop`.
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

# O `aplicar` ficou certo.
#
#   A casa de brinquedo tem DOIS cofres, de nomes inventados, e três tempos:
#     1. o `aplicar` tematiza o A, o único que o obsidian.json conhece;
#     2. a pessoa abre o B (fica `open`, com o `ts` maior) e escolhe um tema dela;
#     3. o `reverter`.
#   O A tem de voltar, arquivo por arquivo, ao que era antes do MeowSystem, e o
#   appearance.json tematizado tem de ficar num backup. O B tem de ficar byte a
#   byte como ela o deixou.
C="$T/casa7"
A="$C/Cofre Alfa"
B="$C/cofre-beta"
OBS_JSON="$C/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
mkdir -p "$C/bin" "$(dirname "$OBS_JSON")" "$A/.obsidian" "$B/.obsidian/snippets" \
         "$B/.obsidian/themes/Tema de Brinquedo"
implantar "$C/.local/share/flatpak" md.obsidian.Obsidian
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

# 9. A LISTA DO SPICETIFY SE SEPARA POR `|`
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

# 10. OS APLICATIVOS VESTEM O PACK NO AR

# OS TRÊS PERGUNTAM AO PACK, SEM O `$( )`, e não estão na lista MIGRADOS da
# seção 2: eles não leem o que está no ar antes de escrever (a segunda função).
for mod in obsidian vscode heroic; do
  arq="$ACERVO/$mod/manifesto.sh"
  if grep -n 'meow_app_tema_do_pack' "$arq" | grep -qv '^[0-9]*: *#' \
     && ! grep -n '\$(meow_app_tema_do_pack' "$arq" | grep -qv '^[0-9]*: *#'; then
    ok "$mod: pergunta ao pack qual tema aplicar, direto e sem \$( )"
  else
    falha "$mod: não pergunta ao pack qual tema aplicar, ou pergunta dentro de \$( )"
  fi
done

T10="$T/p55"; CASA10="$T10/casa"; BIN10="$T10/bin"; REDE10="$T10/rede"
PACKS10="$T10/packs"; MERCADO10="$T10/mercado"; COFRE10="$CASA10/Cofre de Brinquedo"
HD10="$CASA10/.var/app/com.heroicgameslauncher.hgl/config/heroic"
VSC10="$CASA10/.config/Code/User/settings.json"
BAIXADOS10="$CASA10/.local/share/meowsystem/temas-de-apps/obsidian"
mkdir -p "$BIN10" "$REDE10" "$PACKS10/noite" "$PACKS10/sem-apps" "$PACKS10/torto" "$MERCADO10" "$T10/tmp"
for f in pgrep:1 flatpak:0 update-desktop-database:0; do
  printf '#!/bin/sh\nexit %s\n' "${f#*:}" > "$BIN10/${f%%:*}"; chmod +x "$BIN10/${f%%:*}"
done
cat > "$BIN10/curl" <<'C'
#!/bin/sh
# curl de mentira do tests/temas-de-apps.sh (P55): nunca abre a rede.
dest=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) dest="$2"; shift 2 ;;
    --proto|--proto-redir|--connect-timeout|--max-time|--retry|--retry-delay) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\n' "$url" >> "$REDE/.chamadas"
arq="$REDE/$(basename "$url")"
[ -f "$arq" ] || exit 22
cp "$arq" "$dest"
C
cat > "$BIN10/code" <<'CODE'
#!/usr/bin/env python3
# code de mentira (P55): as extensões moram em ~/.vscode/extensions, como no de verdade.
import json, os, shutil, sys, zipfile
ext = os.path.join(os.environ["HOME"], ".vscode", "extensions")
a = sys.argv[1:] or [""]
def pastas():
    return sorted(d for d in os.listdir(ext) if os.path.isdir(os.path.join(ext, d))) if os.path.isdir(ext) else []
def id_de(d):
    p = json.load(open(os.path.join(ext, d, "package.json")))
    return ("%s.%s" % (p["publisher"], p["name"])).lower()
if a[0] == "--version":
    print("1.99.0")
elif a[0] == "--list-extensions":
    for d in pastas():
        print(id_de(d))
elif a[0] == "--install-extension":
    alvo = a[1] if a[1].endswith(".vsix") else os.path.join(os.environ["MERCADO"], a[1].lower() + ".vsix")
    if not os.path.isfile(alvo):
        sys.exit(1)
    z = zipfile.ZipFile(alvo)
    p = json.loads(z.read("extension/package.json"))
    dest = os.path.join(ext, ("%s.%s-%s" % (p["publisher"], p["name"], p["version"])).lower())
    for n in z.namelist():
        if n.startswith("extension/") and not n.endswith("/"):
            os.makedirs(os.path.dirname(os.path.join(dest, n[len("extension/"):])), exist_ok=True)
            open(os.path.join(dest, n[len("extension/"):]), "wb").write(z.read(n))
elif a[0] == "--uninstall-extension":
    for d in pastas():
        if id_de(d) == a[1].lower():
            shutil.rmtree(os.path.join(ext, d))
            sys.exit(0)
    sys.exit(1)
CODE
chmod +x "$BIN10/curl" "$BIN10/code"

vsix10() {  # <arquivo> <publisher> <nome> <versão> <contributes em JSON>
  python3 - "$@" <<'PY'
import json, sys, zipfile
arq, pub, nome, ver, contrib = sys.argv[1:6]
with zipfile.ZipFile(arq, "w") as z:
    z.writestr("extension.vsixmanifest", "<PackageManifest/>")
    z.writestr("extension/package.json", json.dumps({
        "name": nome, "publisher": pub, "version": ver,
        "engines": {"vscode": "^1.13.0"}, "contributes": json.loads(contrib)}))
    z.writestr("extension/tema.json", "{}")
PY
}
vsix10 "$MERCADO10/catppuccin.catppuccin-vsc.vsix" Catppuccin catppuccin-vsc 3.19.0 \
  '{"themes": [{"label": "Catppuccin Mocha"}]}'
vsix10 "$MERCADO10/catppuccin.catppuccin-vsc-icons.vsix" Catppuccin catppuccin-vsc-icons 1.26.0 \
  '{"iconThemes": [{"id": "catppuccin-mocha"}]}'
vsix10 "$REDE10/tema-noite.vsix" noite tema-noite 1.0.0 '{"themes": [{"label": "Noite Escura"}]}'
# A MESMA EXTENSÃO NA LOJA, noutra versão: o pack importado `noite` pina um.vsix
# pela URL dele, e o gesto consente pelo NOME; o que se instala tem de ser o da
# loja, pelo id — nunca a URL que o pack escolheu.
vsix10 "$MERCADO10/noite.tema-noite.vsix" noite tema-noite 2.0.0 '{"themes": [{"label": "Noite Escura"}]}'
mkdir -p "$T10/pacote/noite-obsidian-1a2b"
printf '.theme-dark { --background-primary: var(--color-base-00); }\n' > "$T10/pacote/noite-obsidian-1a2b/theme.css"
printf '{\n  "name": "Noite Pinada",\n  "version": "1.0.0"\n}\n' > "$T10/pacote/noite-obsidian-1a2b/manifest.json"
printf 'o resto do repositório\n' > "$T10/pacote/noite-obsidian-1a2b/README.md"
tar -czf "$REDE10/obsidian-noite.tar.gz" -C "$T10/pacote" noite-obsidian-1a2b || exit 2
SHA_OBS10="$(sha256sum < "$REDE10/obsidian-noite.tar.gz" | cut -d' ' -f1)"
SHA_VSIX10="$(sha256sum < "$REDE10/tema-noite.vsix" | cut -d' ' -f1)"

# Os packs de brinquedo. O `noite` pina o tema do Obsidian e a extensão do VS
# Code, e não declara Heroic nem ícones: a herança leva ao Catppuccin, e o
# módulo tem de recusar.
for p in noite sem-apps torto; do
  cp "$RAIZ/packs/dracula/logo.svg" "$PACKS10/$p/"
  python3 - "$RAIZ/packs/dracula/paleta.json" "$PACKS10/$p/paleta.json" "$p" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
nome = sys.argv[3].replace("-", " ").title()
d["nomes"] = {"dracula": nome, "alucard": nome + " Claro"}
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
done
printf '{"formato": 1, "id": "noite", "nome": "Noite", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"},
 "apps": {"obsidian": {"esquema": "Noite Pinada", "origem": {
            "url": "https://exemplo.invalid/p55/obsidian-noite.tar.gz",
            "sha256": "%s", "pasta": "noite-obsidian-1a2b"}},
          "vscode": {"esquema": "Noite Escura", "origem": {"extensao": "noite.tema-noite",
            "url": "https://exemplo.invalid/p55/tema-noite.vsix", "sha256": "%s"}}}}\n' \
  "$SHA_OBS10" "$SHA_VSIX10" > "$PACKS10/noite/pack.json"
printf '{"formato": 1, "id": "sem-apps", "nome": "Sem Apps", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"}}\n' \
  > "$PACKS10/sem-apps/pack.json"
printf '{"formato": 1, "id": "torto", "nome": "Torto", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"},
 "apps": {"obsidian": {"esquema": ".."},
          "vscode": {"esquema": "Torto", "origem": {"extensao": "--uninstall-extension=ms-python.python"}}}}\n' \
  > "$PACKS10/torto/pack.json"

implantar10() {  # <id> — o flatpak instalado na casa, na forma de um de verdade (ver o topo da seção)
  local app="$CASA10/.local/share/flatpak/app/$1"
  mkdir -p "$app/x86_64/stable/0123abcd" && ln -sfn 0123abcd "$app/x86_64/stable/active" \
    && ln -sfn x86_64/stable "$app/current"
}
semear10() {  # a casa de novo, do zero: um cofre, o settings.json dela, o Heroic e o ZapZap
  rm -rf "$CASA10" "$T10/estado"; rm -f "$REDE10/.chamadas"
  mkdir -p "$COFRE10/.obsidian/snippets" "$CASA10/.var/app/md.obsidian.Obsidian/config/obsidian" \
           "$CASA10/.config/Code/User" "$CASA10/.vscode/extensions" "$HD10/store"
  implantar10 md.obsidian.Obsidian; implantar10 com.heroicgameslauncher.hgl; implantar10 com.rtosta.zapzap
  printf '{\n  "theme": "obsidian",\n  "cssTheme": "",\n  "enabledCssSnippets": [\n    "dracula_background",\n    "%s",\n    "fonte"\n  ]\n}' \
    "${1:-catppuccin_realce}" > "$COFRE10/.obsidian/appearance.json"
  printf 'body{}' > "$COFRE10/.obsidian/snippets/dracula_background.css"
  printf '{"vaults":{"c1":{"path":"%s","ts":1000,"open":true}}}' "$COFRE10" \
    > "$CASA10/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
  printf '{\n    // o editor dela\n    "editor.fontSize": 14\n}\n' > "$VSC10"
  printf '{\n  "defaultSettings": {\n    "language": "pt"\n  }\n}' > "$HD10/config.json"
  printf '{\n\t"theme": "midnightMirage"\n}' > "$HD10/store/config.json"
  # O `.desktop` mora dentro da pasta do commit, e o export aponta pelo
  # `current/active` — o caminho que o flatpak escreve no link.
  local zz="$CASA10/.local/share/flatpak/app/com.rtosta.zapzap/x86_64/stable/0123abcd/export/share/applications"
  mkdir -p "$zz" "$CASA10/.local/share/flatpak/exports/share/applications" \
           "$CASA10/.var/app/com.rtosta.zapzap/config/ZapZap"
  printf '[Desktop Entry]\nName=ZapZap\nIcon=com.rtosta.zapzap\nExec=flatpak run com.rtosta.zapzap\n' \
    > "$zz/com.rtosta.zapzap.desktop"
  ln -s "$CASA10/.local/share/flatpak/app/com.rtosta.zapzap/current/active/export/share/applications/com.rtosta.zapzap.desktop" \
    "$CASA10/.local/share/flatpak/exports/share/applications/com.rtosta.zapzap.desktop"
  printf '[system]\ntray_theme=default\n' > "$CASA10/.var/app/com.rtosta.zapzap/config/ZapZap/ZapZap.conf"
}
mod10() {  # <módulo> <verbo> <PACK> <FLAVOR> [VAR=valor ...]
  local m="$1" v="$2" p="$3" f="$4"; shift 4
  env -i PATH="$BIN10:$PATH" HOME="$CASA10" XDG_CONFIG_HOME="$CASA10/.config" \
      XDG_DATA_HOME="$CASA10/.local/share" MEOW_PACKS="$PACKS10" MEOW_RAIZ="$RAIZ" RAIZ="$RAIZ" \
      MEOW_ESTADO="$T10/estado" REDE="$REDE10" MERCADO="$MERCADO10" TMPDIR="$T10/tmp" \
      PACK="$p" FLAVOR="$f" ACCENT=mauve NO_COLOR=1 "$@" \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/assets/temas-de-apps/$0/manifesto.sh" || exit 2
               meow_app_$1' "$m" "$v" </dev/null 2>&1
}
chamadas10() { if [ -s "$REDE10/.chamadas" ]; then grep -c . "$REDE10/.chamadas"; else printf '0'; fi; }
aparencia10() {  # "cssTheme | snippets ligados"
  python3 -c 'import json, sys; d = json.load(open(sys.argv[1]))
print(d.get("cssTheme"), "|", ",".join(d.get("enabledCssSnippets") or []))' "$COFRE10/.obsidian/appearance.json"
}
# A impressão da casa sem o estado (backup, log e manifesto são do MeowSystem), e
# os arquivos que mudaram desde uma impressão com "catppuccin" dentro.
impressao10() {
  (cd "$CASA10" && find . -type f ! -path './.local/state/*' -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum)
}
mudaram_com_catppuccin10() {  # <impressão de antes>
  impressao10 | diff <(printf '%s\n' "$1") - | sed -n 's/^> [0-9a-f]*  //p' \
    | while IFS= read -r arq; do grep -qil catppuccin "$CASA10/$arq" && printf '%s\n' "$arq"; done
}

# --- a) COM O CATPPUCCIN NO AR, O DE SEMPRE --------------------------------
# Aqui ficam as pontas que a tela e o disco mostram, para a próxima mudança
# não as mover.
semear10
faltam=""
saida="$(mod10 obsidian aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && [ "$(aparencia10)" = "Catppuccin | catppuccin_realce,fonte" ] \
  && [ "$(cat "$COFRE10/.obsidian/themes/Catppuccin/theme.css")" = "$(cat "$ACERVO/obsidian/vendor/Catppuccin/theme.css")" ] \
  || faltam+=" obsidian (rc=$rc, $(aparencia10));"
saida="$(mod10 obsidian conferir catppuccin mocha)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q 'obsidian: Catppuccin Mocha já aplicado' \
  || faltam+=" obsidian conferir (rc=$rc: $saida);"
saida="$(mod10 vscode aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && [ -d "$CASA10/.vscode/extensions/catppuccin.catppuccin-vsc-3.19.0" ] \
  && [ -d "$CASA10/.vscode/extensions/catppuccin.catppuccin-vsc-icons-1.26.0" ] \
  && grep -q '"workbench.colorTheme": "Catppuccin Mocha"' "$VSC10" && grep -q '"workbench.iconTheme": "catppuccin-mocha"' "$VSC10" \
  && grep -q '// o editor dela' "$VSC10" \
  || faltam+=" vscode (rc=$rc: $saida);"
saida="$(mod10 heroic aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && grep -q '"theme": "catppuccin-mocha-mauve.css"' "$HD10/store/config.json" \
  && [ "$(find "$HD10/themes" -name '*.css' | wc -l)" = 56 ] \
  && grep -q '^body.catppuccin-mocha-mauve {' "$HD10/themes/catppuccin-mocha-mauve.css" \
  || faltam+=" heroic (rc=$rc: $saida);"
mod10 zapzap aplicar catppuccin mocha >/dev/null
saida="$(mod10 zapzap conferir catppuccin mocha)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q "como 'WhatsApp' com o ícone Catppuccin" \
  || faltam+=" zapzap (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P55: com o Catppuccin no ar os quatro vestem o de sempre, e a tela diz o de sempre" \
  || falha "P55: com o Catppuccin no ar, o de sempre mudou:$faltam"

# --- b) COM O DRACULA NO AR: O DRACULA, OU PENDENTE COM O MOTIVO -----------
# Sem rede: o Obsidian e o VS Code ficam pendentes dizendo por quê, e nada deles
# é escrito. O Heroic veste o Dracula que ele mesmo traz, só pela chave.
semear10 fonte_grande
antes="$(impressao10)"
faltam=""
saida="$(mod10 obsidian aplicar dracula dracula)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q "não consegui baixar o tema 'Dracula Official' do pack Dracula (sem rede?)" \
  && [ ! -e "$COFRE10/.obsidian/themes" ] && [ "$(aparencia10)" = " | dracula_background,fonte_grande,fonte" ] \
  || faltam+=" obsidian sem rede (rc=$rc: $saida);"
saida="$(mod10 vscode aplicar dracula dracula)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q 'não consegui baixar a extensão dracula-theme.theme-dracula do pack Dracula (sem rede?)' \
  && [ -z "$(ls -A "$CASA10/.vscode/extensions")" ] && ! grep -q workbench "$VSC10" \
  || faltam+=" vscode sem rede (rc=$rc: $saida);"
saida="$(mod10 heroic aplicar dracula dracula)"; rc=$?
[ "$rc" = 1 ] && grep -q '"theme": "dracula"' "$HD10/store/config.json" && [ ! -e "$HD10/themes" ] \
  && ! grep -q customThemesPath "$HD10/config.json" \
  || faltam+=" heroic (rc=$rc: $saida);"
saida="$(mod10 heroic conferir dracula dracula)$(mod10 heroic aplicar dracula dracula)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q 'Heroic com dracula aplicado' \
  || faltam+=" heroic na segunda passada (rc=$rc: $saida);"
mod10 zapzap aplicar dracula dracula >/dev/null
saida="$(mod10 zapzap conferir dracula dracula)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q "com o ícone Dracula" \
  || faltam+=" zapzap (rc=$rc: $saida);"
saida="$(mod10 obsidian reverter dracula dracula)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q 'obsidian: já estava sem o Dracula' \
  || faltam+=" o desfazer do obsidian não diz o pack no ar (rc=$rc: $saida);"
com_catppuccin="$(mudaram_com_catppuccin10 "$antes")"
[ -z "$com_catppuccin" ] || faltam+=" arquivos que receberam catppuccin: $com_catppuccin;"
[ -z "$faltam" ] \
  && ok "P55: com o Dracula no ar, o Heroic veste o dele, o Obsidian e o VS Code pendem com o motivo, e nada recebe catppuccin" \
  || falha "P55: com o Dracula no ar:$faltam"

# O PINO MORDE: um pacote que não é o pinado, servido no endereço do Dracula de
#   verdade, é recusado (2) sem escrever nada — nem no cofre, nem na pasta do
#   que desceu, nem no editor.
cp "$REDE10/obsidian-noite.tar.gz" "$REDE10/ddb95ec25babe3ef21907b8b612bbdb9fc2904c9.tar.gz"
cp "$REDE10/tema-noite.vsix" "$REDE10/dracula-theme.theme-dracula-2.25.1.vsix"
semear10
saida="$(mod10 obsidian aplicar dracula dracula)"; rc1=$?
saida="$saida$(mod10 vscode aplicar dracula dracula)"; rc2=$?
[ "$rc1" = 2 ] && [ "$rc2" = 2 ] && [ ! -e "$COFRE10/.obsidian/themes" ] \
  && [ -z "$(ls -A "$BAIXADOS10" 2>/dev/null)" ] && [ -z "$(ls -A "$CASA10/.vscode/extensions")" ] \
  && [ "$(printf '%s' "$saida" | grep -c 'não bate com o que o pack Dracula pinou')" = 2 ] \
  && [ -z "$(ls -A "$T10/tmp")" ] \
  && ok "P55: o pacote que não é o pinado é recusado pelo sha256, e nada é escrito" \
  || falha "P55: um pacote fora do pino passou, ou deixou sobra (obsidian=$rc1, vscode=$rc2)" "$saida"
rm -f "$REDE10/ddb95ec25babe3ef21907b8b612bbdb9fc2904c9.tar.gz" "$REDE10/dracula-theme.theme-dracula-2.25.1.vsix"

# --- c) O TEMA PINADO DESCE, E A TROCA DE PACK LEVA O DE ANTES -------------
# A casa sai do Catppuccin para o `noite`. O Obsidian baixa uma vez, confere,
# veste; o snippet com o nome de outro pack sai (o do Catppuccin também, agora
# que ele é o outro).
semear10
mod10 obsidian aplicar catppuccin mocha >/dev/null
mod10 vscode aplicar catppuccin mocha >/dev/null
faltam=""
saida="$(mod10 obsidian aplicar noite dracula)"; rc=$?
[ "$rc" = 1 ] && [ "$(chamadas10)" = 1 ] && grep -qx "sha256=$SHA_OBS10" "$BAIXADOS10/$SHA_OBS10/.meow-origem" 2>/dev/null \
  && [ "$(cat "$COFRE10/.obsidian/themes/Noite Pinada/theme.css")" = "$(cat "$T10/pacote/noite-obsidian-1a2b/theme.css")" ] \
  && [ "$(aparencia10)" = "Noite Pinada | fonte" ] \
  || faltam+=" obsidian aplicar (rc=$rc, chamadas=$(chamadas10), $(aparencia10): $saida);"
saida="$(mod10 obsidian conferir noite dracula)$(mod10 obsidian aplicar noite dracula)"; rc=$?
[ "$rc" = 0 ] && [ "$(chamadas10)" = 1 ] && printf '%s' "$saida" | grep -q 'obsidian: Noite já aplicado' \
  || faltam+=" obsidian na segunda passada (rc=$rc, chamadas=$(chamadas10): $saida);"
rm -f "$REDE10/.chamadas"
# DECISÃO 9: o `noite` é pack IMPORTADO (mora no MEOW_PACKS, fora do `packs/` do
# repositório), e extensão é código que roda a cada abertura do editor.
antes_vsc="$(cat "$VSC10")"
saida="$(mod10 vscode aplicar noite dracula)$(mod10 vscode aplicar noite dracula MEOW_VSCODE_EXTENSAO=outro.tema)"; rc=$?
[ "$rc" = 3 ] && [ "$(chamadas10)" = 0 ] && [ ! -e "$CASA10/.vscode/extensions/noite.tema-noite-1.0.0" ] \
  && [ "$(cat "$VSC10")" = "$antes_vsc" ] \
  && grep -q '^vscode-extensao-de-terceiro	.*noite\.tema-noite' "$T10/estado/pendencias.tsv" 2>/dev/null \
  || faltam+=" vscode instalou extensão de pack importado sem o gesto (rc=$rc, chamadas=$(chamadas10): $saida);"
saida="$(mod10 vscode conferir noite dracula)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q 'noite.tema-noite, do pack importado .* espera o seu gesto' \
  || faltam+=" o conferir chama de divergência a extensão que espera o gesto (rc=$rc: $saida);"
# O BOTÃO DO GESTO, NO PAINEL: a pendência traz um botão por extensão que o
# pack no ar pede, com o selo de rede; a ação só aceita uma extensão da lista e
# a entrega ao módulo pelo ambiente.
gesto10() {  # <PACK> — imprime o que o painel diria; o trabalho não nasce
  printf 'PACK="%s"\nFLAVOR="dracula"\n' "$1" > "$T10/gesto.conf"
  env -i PATH="$PATH" HOME="$CASA10" XDG_DATA_HOME="$CASA10/.local/share" MEOW_PACKS="$PACKS10" \
      MEOW_ESTADO="$T10/estado" MEOW_CONF="$T10/gesto.conf" \
      python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
nasceu = []
servidor.Trabalho = lambda acao, argv, amb, rot, ao_terminar=None: nasceu.append((argv, amb)) or type("T", (), {"id": "x", "vivo": lambda s: False})()
print("lista=" + ",".join(servidor.PROVEDORES["extensoes_de_terceiro"]()))
for p in servidor.pendencias():
    if p["id"] == "vscode-extensao-de-terceiro":
        print("botoes=" + ",".join("%s:%s" % (e["acao"], e["argumento"]) for e in p["escolha"]))
        print("rede=%s" % p["rede"])
_t, erro = servidor.iniciar("vscode_instalar_extensao", "outro.tema", confirmado=True)
print("fora=%s" % bool(erro))
_t, erro = servidor.iniciar("vscode_instalar_extensao", "noite.tema-noite", confirmado=True)
print("gesto=%s" % (nasceu[-1][1].get("MEOW_VSCODE_EXTENSAO") if nasceu else erro))
PY
}
saida="$(gesto10 noite)"
printf '%s\n' "$saida" | grep -qx 'lista=noite.tema-noite' \
  && printf '%s\n' "$saida" | grep -qx 'botoes=vscode_instalar_extensao:noite.tema-noite' \
  && printf '%s\n' "$saida" | grep -qx 'rede=True' && printf '%s\n' "$saida" | grep -qx 'fora=True' \
  && printf '%s\n' "$saida" | grep -qx 'gesto=noite.tema-noite' \
  || faltam+=" o painel não oferece o gesto da extensão ($saida);"
saida="$(gesto10 dracula)"
printf '%s\n' "$saida" | grep -qx 'lista=' || faltam+=" o pack do repositório pede gesto ($saida);"
saida="$(mod10 vscode aplicar noite dracula MEOW_VSCODE_EXTENSAO=noite.tema-noite)"; rc=$?
[ "$rc" = 1 ] && [ "$(chamadas10)" = 0 ] && [ -d "$CASA10/.vscode/extensions/noite.tema-noite-2.0.0" ] \
  && [ ! -e "$CASA10/.vscode/extensions/noite.tema-noite-1.0.0" ] \
  && grep -q '"workbench.colorTheme": "Noite Escura"' "$VSC10" && grep -q '"workbench.iconTheme": "vs-seti"' "$VSC10" \
  && [ -z "$(ls -A "$T10/tmp")" ] \
  && ! grep -q '^vscode-extensao-de-terceiro	' "$T10/estado/pendencias.tsv" 2>/dev/null \
  || faltam+=" vscode aplicar com o gesto: tem de vir da loja pelo id, e não da URL do pack (rc=$rc, chamadas=$(chamadas10): $saida);"
saida="$(mod10 vscode conferir noite dracula)$(mod10 vscode aplicar noite dracula)"; rc=$?
[ "$rc" = 0 ] && [ "$(chamadas10)" = 0 ] && printf '%s' "$saida" | grep -q 'VS Code: Noite Escura já no lugar' \
  || faltam+=" vscode na segunda passada (rc=$rc: $saida);"
saida="$(mod10 heroic aplicar noite dracula)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q "sem tema neste pack (Noite)" \
  && grep -q '"theme": "midnightMirage"' "$HD10/store/config.json" \
  || faltam+=" heroic herdou do Catppuccin (rc=$rc: $saida);"
saida="$(mod10 obsidian reverter noite dracula)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$COFRE10/.obsidian/themes/Noite Pinada" ] && [ ! -e "$COFRE10/.obsidian/themes/Catppuccin" ] \
  && [ ! -e "$BAIXADOS10/$SHA_OBS10" ] && [ "$(aparencia10)" = " | fonte" ] \
  && printf '%s' "$saida" | grep -q 'obsidian: sem o Noite' \
  || faltam+=" obsidian reverter (rc=$rc, $(aparencia10): $saida);"
saida="$(mod10 vscode reverter noite dracula)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$CASA10/.vscode/extensions/noite.tema-noite-2.0.0" ] \
  && [ -d "$CASA10/.vscode/extensions/catppuccin.catppuccin-vsc-3.19.0" ] \
  && grep -q '"workbench.colorTheme": "Default Dark Modern"' "$VSC10" && grep -q '"workbench.iconTheme": "vs-seti"' "$VSC10" \
  && grep -q '// o editor dela' "$VSC10" \
  || faltam+=" vscode reverter (rc=$rc: $saida);"
saida="$(mod10 obsidian reverter noite dracula)$(mod10 vscode reverter noite dracula)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -q 'obsidian: já estava sem o Noite' \
  && printf '%s' "$saida" | grep -q 'VS Code já estava sem o Noite' \
  || faltam+=" o segundo desfazer (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P55: o tema pinado desce uma vez, veste, confere sem rede, e o desfazer tira o que é do pack no ar" \
  || falha "P55: a troca de pack com o tema pinado:$faltam"

# --- d) PACK SEM TEMA: NADA, E O MOTIVO ------------------------------------
# O `sem-apps` herda do Catppuccin e não declara aplicativo nenhum. O que a
# herança traz é recusado, dito, e a casa fica como estava.
semear10
antes="$(impressao10)"
faltam=""
for m in obsidian vscode heroic; do
  saida="$(mod10 "$m" aplicar sem-apps dracula)"; rc=$?
  [ "$rc" = 3 ] && printf '%s' "$saida" | grep -q 'sem tema neste pack (Sem Apps)' \
    || faltam+=" $m aplicar (rc=$rc: $saida);"
  case "$saida" in *'<accent>'*) faltam+=" $m mostra o molde cru ($saida);" ;; esac
  saida="$(mod10 "$m" conferir sem-apps dracula)"; rc=$?
  [ "$rc" = 3 ] && printf '%s' "$saida" | grep -q 'sem tema neste pack (Sem Apps)' \
    || faltam+=" $m conferir (rc=$rc: $saida);"
done
[ "$(impressao10)" = "$antes" ] || faltam+=" a casa mudou;"
# E o `meow apps conferir` diz a mesma frase, uma vez por aplicativo: é a saída
#   dos módulos que ele mostra, pelo `aplicar_apps.sh`.
saida="$(env -i PATH="$BIN10:$PATH" HOME="$CASA10" XDG_CONFIG_HOME="$CASA10/.config" \
           XDG_DATA_HOME="$CASA10/.local/share" MEOW_PACKS="$PACKS10" MEOW_RAIZ="$RAIZ" \
           MEOW_ESTADO="$T10/estado" TMPDIR="$T10/tmp" PACK=sem-apps FLAVOR=dracula ACCENT=mauve \
           NO_COLOR=1 APPS_ATIVOS=obsidian,vscode,heroic "$RAIZ/scripts/aplicar_apps.sh" conferir </dev/null 2>&1)"
[ "$(printf '%s\n' "$saida" | grep -c 'sem tema neste pack (Sem Apps)')" = 3 ] \
  || faltam+=" meow apps conferir não disse três vezes «sem tema neste pack» ($saida);"
# O `meow apps` sem verbo, que é o «Quais programas estão vestidos» do painel,
# pintava os três de `--`.
printf 'PACK="sem-apps"\nFLAVOR="dracula"\nACCENT="mauve"\nAPPS_ATIVOS="obsidian,vscode,heroic"\n' \
  > "$T10/meow.conf"
saida="$(env -i PATH="$BIN10:$PATH" HOME="$CASA10" XDG_CONFIG_HOME="$CASA10/.config" \
           XDG_DATA_HOME="$CASA10/.local/share" MEOW_PACKS="$PACKS10" MEOW_RAIZ="$RAIZ" \
           MEOW_ESTADO="$T10/estado" MEOW_CONF="$T10/meow.conf" TMPDIR="$T10/tmp" NO_COLOR=1 \
           "$RAIZ/bin/meow" apps </dev/null 2>&1)"
# A régua é a linha, e não o número de espaços: sem locale UTF-8 (o `env -i`
# daqui) o `pad` conta bytes, e o «ã» come um espaço do alinhamento.
[ "$(printf '%s\n' "$saida" | grep -cE '^  [a-z-]+ +sim +não veste +[a-z]')" = 3 ] \
  && [ "$(printf '%s\n' "$saida" | grep -c 'sem tema neste pack (Sem Apps)')" = 3 ] \
  || faltam+=" a tabela do meow apps não disse «não veste» e o motivo nos três ($saida);"
[ "$(impressao10)" = "$antes" ] || faltam+=" a tabela mudou a casa;"
[ -z "$faltam" ] \
  && ok "P55: pack sem tema para o app não aplica o de outro pack — diz «sem tema neste pack», no módulo e no meow apps, e não escreve" \
  || falha "P55: pack sem tema:$faltam"

# --- d2) O DOCTOR DIZ O QUE O MÓDULO DO HEROIC GRAVA ------
# O `heroictema` dizia «o módulo grava com o .css» com qualquer pack, e com o
# Dracula no ar o módulo grava o tema que o Heroic já traz, sem extensão.
asar10="$CASA10/.local/share/flatpak/app/com.heroicgameslauncher.hgl/current/active/files/bin/heroic/resources"
chk10() {  # <PACK> <FLAVOR> — o `chk_heroictema` do bin/meow, recortado, nesta casa
  env -i PATH="$BIN10:$PATH" HOME="$CASA10" XDG_DATA_HOME="$CASA10/.local/share" \
      MEOW_PACKS="$PACKS10" MEOW_RAIZ="$RAIZ" RAIZ="$RAIZ" MEOW_ESTADO="$T10/estado" \
      PACK="$1" FLAVOR="$2" NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               eval "$(sed -n "/^chk_heroictema() {/,/^}/p" "$MEOW_RAIZ/bin/meow")"
               chk_heroictema' </dev/null 2>&1
}
semear10
mkdir -p "$asar10"
esq10="$(python3 "$RAIZ/scripts/pack.py" app dracula apps.heroic.esquema 2>/dev/null | sed -n 's/^valor=//p')"
nome10="$(python3 "$RAIZ/scripts/pack.py" adocao dracula dracula 2>/dev/null | sed -n 's/^nome=//p')"
faltam=""
printf 'x path.join(customThemesPath, theme) y' > "$asar10/app.asar"
saida="$(chk10 catppuccin mocha)"; rc=$?
[ "$rc" = 0 ] && [ "$saida" = "o Heroic abre o tema pelo nome do arquivo — o módulo grava com o .css, e está certo" ] \
  || faltam+=" com o Catppuccin a frase mudou (rc=$rc: $saida);"
saida="$(chk10 dracula dracula)"; rc=$?
[ "$rc" = 0 ] && [ -n "$esq10" ] && printf '%s' "$saida" | grep -qF "o pack no ar ($nome10) veste o '$esq10'" \
  && ! printf '%s' "$saida" | grep -qF '.css' \
  || faltam+=" com o Dracula a frase não diz o tema que ele traz (rc=$rc: $saida);"
saida="$(chk10 sem-apps dracula)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -qF 'o módulo não grava nada com o pack no ar: sem tema neste pack (Sem Apps)' \
  || faltam+=" sem tema no pack a frase não diz (rc=$rc: $saida);"
# A frase agora é a recusa do módulo, com as palavras dele.
mkdir -p "$PACKS10/css-fora"
cp "$PACKS10/sem-apps/logo.svg" "$PACKS10/sem-apps/paleta.json" "$PACKS10/css-fora/"
printf '{"formato": 1, "id": "css-fora", "nome": "Css Fora", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"},
 "apps": {"heroic": {"esquema": "fora-do-acervo.css"}}}\n' > "$PACKS10/css-fora/pack.json"
saida="$(chk10 css-fora dracula)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$saida" | grep -qF "o módulo não grava nada com o pack no ar: o pack" \
  && printf '%s' "$saida" | grep -qF "'fora-do-acervo.css', que não está no acervo" \
  && ! printf '%s' "$saida" | grep -qF 'grava com o .css' \
  || faltam+=" com um .css fora do acervo a frase não diz a recusa do módulo (rc=$rc: $saida);"
rm -rf "$PACKS10/css-fora"
printf 'x outra forma y' > "$asar10/app.asar"
saida="$(chk10 dracula dracula)"; rc=$?
[ "$rc" = 1 ] && ! printf '%s' "$saida" | grep -qF 'COM o .css' \
  || faltam+=" com o handler mudado e o Dracula no ar, ainda diz que grava .css (rc=$rc: $saida);"
saida="$(chk10 catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$saida" | grep -qF "o módulo grava 'theme' COM o .css por causa dessa linha" \
  || faltam+=" com o handler mudado e o Catppuccin no ar, a frase de antes sumiu (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P62: o heroictema do doctor diz o que o módulo grava com o pack no ar — .css só no tema de arquivo, e a recusa com as palavras do módulo" \
  || falha "P62: o heroictema:$faltam"

# --- e) O DESFAZER DO VS CODE TIRA SÓ AS EXTENSÕES DO PACK NO AR -----------
# Estar instalada não diz de quem é a extensão: a de outro pack pode ter sido
# posta por ela (a do Dracula, o script dela instala sozinho). O `code` de
# mentira instala do arquivo, como ela instalaria.
semear10
mod10 vscode aplicar catppuccin mocha >/dev/null
env HOME="$CASA10" MERCADO="$MERCADO10" "$BIN10/code" --install-extension "$REDE10/tema-noite.vsix"
saida="$(mod10 vscode reverter catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && [ -d "$CASA10/.vscode/extensions/noite.tema-noite-1.0.0" ] \
  && [ ! -e "$CASA10/.vscode/extensions/catppuccin.catppuccin-vsc-3.19.0" ] \
  && [ ! -e "$CASA10/.vscode/extensions/catppuccin.catppuccin-vsc-icons-1.26.0" ] \
  && grep -q '"workbench.colorTheme": "Default Dark Modern"' "$VSC10" \
  && [ "$(printf '%s\n' "$saida" | grep -c 'extensão removida')" = 2 ] \
  && ok "P55: com o Catppuccin no ar, o desfazer do VS Code tira as duas do Catppuccin, e a extensão de outro pack fica" \
  || falha "P55: o desfazer do VS Code mexeu na extensão de outro pack, ou não tirou as do Catppuccin (rc=$rc)" "$saida"

# --- f) O NOME E O ID QUE O PACK ESCREVE PASSAM PELA RÉGUA -----------------
# O nome do tema do Obsidian vira pasta no cofre, e o id da extensão vai para a
# linha de comando do `code` — e quem os escreve é o pack, que pode ser de
# terceiro.
semear10
mod10 vscode aplicar catppuccin mocha >/dev/null
saida="$(mod10 obsidian aplicar torto dracula)"; rc1=$?
saida="$saida
$(mod10 vscode aplicar torto dracula)"; rc2=$?
saida="$saida
$(mod10 vscode reverter torto dracula)"; rc3=$?
[ "$rc1" = 3 ] && [ "$rc2" = 3 ] && printf '%s' "$saida" | grep -q "nome que não serve de pasta ('..')" \
  && printf '%s' "$saida" | grep -q 'não tem a forma <editor>.<nome>' \
  && ! printf '%s' "$saida" | grep -q 'extensão removida' \
  && [ -d "$CASA10/.vscode/extensions/catppuccin.catppuccin-vsc-3.19.0" ] \
  && [ ! -e "$COFRE10/.obsidian/theme.css" ] && [ "$(aparencia10)" = " | dracula_background,catppuccin_realce,fonte" ] \
  && ok "P55: o nome de pasta e o id de extensão que um pack manda passam pela régua — fora dela, pendência e nada escrito" \
  || falha "P55: um nome ou id torto do pack passou (obsidian=$rc1, vscode=$rc2, desfazer=$rc3)" "$saida"

# --- g) O SNIPPET É DE OUTRO PACK SÓ QUANDO TRAZ O ID INTEIRO --------------
# A régua comparava por PEDAÇO de texto com o id de toda pasta que tivesse um
# pack.json — e o painel importa um CSV com o nome do arquivo como id: `Mar.csv`
# vira o pack `mar`.
mkdir -p "$PACKS10/mar" "$PACKS10/realce"
cp "$PACKS10/sem-apps/logo.svg" "$PACKS10/sem-apps/paleta.json" "$PACKS10/mar/"
printf '{"formato": 1, "id": "mar", "nome": "Mar", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"}}\n' \
  > "$PACKS10/mar/pack.json"
printf '{}' > "$PACKS10/realce/pack.json"
semear10
python3 - "$COFRE10/.obsidian/appearance.json" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["enabledCssSnippets"] = ["dracula_background", "markdown-tables", "margin-fix", "summary-cards",
                           "meu_realce", "Mar Fundo", "sem_apps_borda", "fonte"]
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"), indent=2)
PY
printf 'body{}' > "$COFRE10/.obsidian/snippets/Mar Fundo.css"
printf 'body{}' > "$COFRE10/.obsidian/snippets/summary-extra.css"
faltam=""
env -i PATH="$PATH" HOME="$CASA10" XDG_DATA_HOME="$CASA10/.local/share" MEOW_PACKS="$PACKS10" \
  python3 "$RAIZ/scripts/pack.py" validar mar >/dev/null 2>&1 || faltam+=" o pack mar de brinquedo não passa no validar;"
saida="$(mod10 obsidian aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && [ "$(aparencia10)" = "Catppuccin | markdown-tables,margin-fix,summary-cards,meu_realce,fonte" ] \
  || faltam+=" aplicar (rc=$rc, $(aparencia10): $saida);"
saida="$(mod10 obsidian conferir catppuccin mocha)"; rc=$?
[ "$rc" = 0 ] || faltam+=" conferir depois do aplicar (rc=$rc: $saida);"
saida="$(mod10 obsidian reverter catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$saida" | grep -q "o snippet 'dracula_background' continua no disco" \
  && printf '%s' "$saida" | grep -q "o snippet 'Mar Fundo' continua no disco" \
  && ! printf '%s' "$saida" | grep -q 'summary-extra' \
  || faltam+=" desfazer (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P55: o snippet sai só quando traz o id de outro pack como palavra, e só de pack que passa no validar" \
  || falha "P55: a régua do snippet:$faltam"

# --- h) A EXTENSÃO QUE ESTÁ NO EDITOR TEM DE TRAZER O TEMA -----------------
# A 2.25 do Dracula renomeou o tema de «Dracula» para «Dracula Theme» (ver o
# PROCEDENCIA.md), e o módulo só baixava quando a extensão FALTA.
semear10
vsix10 "$T10/tema-noite-0.9.vsix" noite tema-noite 0.9.0 '{"themes": [{"label": "Noite"}]}'
env HOME="$CASA10" MERCADO="$MERCADO10" "$BIN10/code" --install-extension "$T10/tema-noite-0.9.vsix"
rm -f "$REDE10/.chamadas"
faltam=""
saida="$(mod10 vscode conferir noite dracula)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$saida" | grep -q "tema-noite@0.9.0 não contribui o tema 'Noite Escura' (tem: Noite)" \
  || faltam+=" conferir com a versão velha (rc=$rc: $saida);"
antes="$(impressao10)"
saida="$(mod10 vscode aplicar noite dracula MEOW_VSCODE_EXTENSAO=noite.tema-noite)"; rc=$?
[ "$rc" = 3 ] && [ "$(chamadas10)" = 0 ] && printf '%s' "$saida" | grep -q 'atualize a extensão pelo editor' \
  && [ "$(impressao10)" = "$antes" ] \
  || faltam+=" a versão sem o tema, de pack importado (rc=$rc, chamadas=$(chamadas10): $saida);"
semear10
vsix10 "$T10/catppuccin-velho.vsix" Catppuccin catppuccin-vsc 0.1.0 '{"themes": [{"label": "Catppuccin"}]}'
env HOME="$CASA10" MERCADO="$MERCADO10" "$BIN10/code" --install-extension "$T10/catppuccin-velho.vsix"
antes="$(impressao10)"
saida="$(mod10 vscode aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$saida" | grep -q "catppuccin-vsc@0.1.0 não contribui o tema 'Catppuccin Mocha' (tem: Catppuccin)" \
  && [ "$(impressao10)" = "$antes" ] \
  || faltam+=" sem pino (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P55: a extensão que está no editor e não traz o tema do pack não conta como no lugar — sem pino que valha, pendência e nada escrito" \
  || falha "P55: a extensão sem o tema:$faltam"

# A forma da origem do Obsidian era uma cópia, em shell, da regra do
# `origem_pinada` do scripts/pack.py, e a cópia não conferia a extensão do
# pacote: medido com uma URL.zip de sha256 certo, o módulo baixava e parava em
# «pacote corrompido»
mkdir -p "$PACKS10/zipado"
cp "$PACKS10/sem-apps/logo.svg" "$PACKS10/sem-apps/paleta.json" "$PACKS10/zipado/"
(cd "$T10/pacote" && python3 -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w")
for n in ("theme.css", "manifest.json"):
    z.write("noite-obsidian-1a2b/" + n)' "$REDE10/obsidian-zipado.zip") || exit 2
printf '{"formato": 1, "id": "zipado", "nome": "Zipado", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"},
 "apps": {"obsidian": {"esquema": "Noite Pinada", "origem": {
            "url": "https://exemplo.invalid/p55/obsidian-zipado.zip",
            "sha256": "%s", "pasta": "noite-obsidian-1a2b"}}}}\n' \
  "$(sha256sum < "$REDE10/obsidian-zipado.zip" | cut -d' ' -f1)" > "$PACKS10/zipado/pack.json"
semear10
antes="$(impressao10)"
faltam=""
saida="$(mod10 obsidian aplicar zipado dracula)"; rc=$?
[ "$rc" = 3 ] && [ "$(chamadas10)" = 0 ] && printf '%s' "$saida" | grep -q 'não termina em .tar.gz' \
  && [ "$(impressao10)" = "$antes" ] \
  || faltam+=" a origem .zip (rc=$rc, chamadas=$(chamadas10): $saida);"
mod10 obsidian aplicar noite dracula >/dev/null
mkdir -p "$BAIXADOS10/.meow-descendo.XyZ123/x" && printf 'meio pacote' > "$BAIXADOS10/.meow-descendo.XyZ123/pacote"
saida="$(mod10 obsidian reverter noite dracula)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$BAIXADOS10" ] \
  || faltam+=" o desfazer deixou $(ls -A "$BAIXADOS10" 2>/dev/null | tr '\n' ' ')(rc=$rc: $saida);"
mkdir -p "$BAIXADOS10/.meow-descendo.AbC456"
saida="$(mod10 obsidian reverter noite dracula)"; rc=$?
[ "$rc" = 1 ] && [ ! -e "$BAIXADOS10" ] \
  || faltam+=" a sobra sozinha ficou (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P55: a origem do Obsidian passa pela regra da P41 antes da rede, e o desfazer leva a pasta do que desceu, com a sobra" \
  || falha "P55: a origem e o que desceu:$faltam"

# --- j) O VS CODE CONTA SÓ O PACK QUE PASSA NO VALIDAR ----
# Medido com uma pasta `torta`, cujo pack.json não passa no `validar` (falta o
# `formato`) e declara o tema de ícones `icones-dela`, e o settings.json dela
# nesse tema: o `aplicar` com o `noite` no ar (que não traz ícones) o trocava
# pelo `vs-seti` de fábrica.
mkdir -p "$PACKS10/torta"
printf '{"apps": {"vscode-icones": {"esquema": "icones-dela", "origem": {"extensao": "dela.icones"}}}}\n' \
  > "$PACKS10/torta/pack.json"
semear10
printf '{\n    // o editor dela\n    "editor.fontSize": 14,\n    "workbench.iconTheme": "icones-dela"\n}\n' > "$VSC10"
faltam=""
env -i PATH="$PATH" HOME="$CASA10" XDG_DATA_HOME="$CASA10/.local/share" MEOW_PACKS="$PACKS10" \
  python3 "$RAIZ/scripts/pack.py" validar torta >/dev/null 2>&1 && faltam+=" a torta de brinquedo passa no validar;"
saida="$(mod10 vscode aplicar noite dracula MEOW_VSCODE_EXTENSAO=noite.tema-noite)"; rc=$?
[ "$rc" = 1 ] && grep -q '"workbench.colorTheme": "Noite Escura"' "$VSC10" \
  && grep -q '"workbench.iconTheme": "icones-dela"' "$VSC10" && grep -q '// o editor dela' "$VSC10" \
  || faltam+=" aplicar (rc=$rc, $(grep -o '"workbench.iconTheme": "[^"]*"' "$VSC10"): $saida);"
saida="$(mod10 vscode conferir noite dracula)"; rc=$?
[ "$rc" = 0 ] || faltam+=" conferir depois do aplicar (rc=$rc: $saida);"
for mod in obsidian vscode; do
  arq="$ACERVO/$mod/manifesto.sh"
  grep -n 'pack\.validar(' "$arq" | grep -qv '^[0-9]*: *#' && faltam+=" o $mod chama o validar do pack.py por conta própria;"
  grep -n 'meow_packs_validos' "$arq" | grep -qv '^[0-9]*: *#' || faltam+=" o $mod não pergunta a lista de packs válidos;"
done
[ -z "$faltam" ] \
  && ok "P61: o tema de ícones que só um pack inválido declara não é de pack nenhum, e a régua dos packs válidos é uma só" \
  || falha "P61: o VS Code e o pack inválido:$faltam"

# --- k) O OBSIDIAN NÃO DEIXA PASTA VAZIA NEM SOBRA --------
# Sem rede, o `aplicar` criava a pasta do que desce (o `mkdir` vem antes da
# descida, e tem de vir: o palco mora nela) e a deixava vazia; o desfazer, sem
# nada nosso para tirar, dizia «já estava sem o Dracula» e a deixava.
faltam=""
semear10
saida="$(mod10 obsidian aplicar dracula dracula)"; rc=$?
[ "$rc" = 3 ] && [ ! -e "$BAIXADOS10" ] && [ ! -e "$CASA10/.local/share/meowsystem" ] \
  || faltam+=" o aplicar sem rede deixou [$(cd "$CASA10/.local/share" 2>/dev/null && find meowsystem 2>/dev/null | tr '\n' ' ')] (rc=$rc: $saida);"
mkdir -p "$BAIXADOS10"
saida="$(mod10 obsidian reverter dracula dracula)"; rc=$?
[ "$rc" = 0 ] && [ ! -e "$BAIXADOS10" ] && printf '%s' "$saida" | grep -q 'obsidian: já estava sem o Dracula' \
  || faltam+=" o desfazer deixou a pasta vazia (rc=$rc: $saida);"
saida="$(mod10 obsidian reverter dracula dracula)"; rc=$?
[ "$rc" = 0 ] || faltam+=" o segundo desfazer (rc=$rc: $saida);"
mkdir -p "$BAIXADOS10/.meow-descendo.Velho1/x" && printf 'meio pacote' > "$BAIXADOS10/.meow-descendo.Velho1/pacote"
rm -f "$REDE10/.chamadas"
saida="$(mod10 obsidian aplicar noite dracula)"; rc=$?
[ "$rc" = 1 ] && [ "$(chamadas10)" = 1 ] && [ "$(ls -A "$BAIXADOS10" 2>/dev/null)" = "$SHA_OBS10" ] \
  && [[ "$(aparencia10)" == "Noite Pinada |"* ]] \
  || faltam+=" o aplicar que desce deixou [$(ls -A "$BAIXADOS10" 2>/dev/null | tr '\n' ' ')] (rc=$rc: $saida);"
semear10
mkdir -p "$BAIXADOS10/.meow-descendo.Velho2"
saida="$(mod10 obsidian aplicar dracula dracula)"; rc=$?
[ "$rc" = 3 ] && [ ! -e "$BAIXADOS10" ] && [ -z "$(ls -A "$T10/tmp")" ] \
  || faltam+=" o aplicar sem rede com uma sobra deixou [$(ls -A "$BAIXADOS10" 2>/dev/null | tr '\n' ' ')] (rc=$rc: $saida);"
[ -z "$faltam" ] \
  && ok "P61: o Obsidian sem rede não deixa pasta vazia, o desfazer leva a de antes, e a descida leva as sobras" \
  || falha "P61: a pasta do que desce:$faltam"

# ---------------------------------------------------------------------------
printf '\n'
if [ "$falhas" -gt 0 ]; then
  printf '%s achado(s).\n' "$falhas" >&2
  exit 1
fi
printf 'Os módulos migrados obedecem ao pack, e os três caminhos da leitura funcionam.\n'
exit 0
