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
MIGRADOS=(spotify qbittorrent)

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
printf '\n'
if [ "$falhas" -gt 0 ]; then
  printf '%s achado(s).\n' "$falhas" >&2
  exit 1
fi
printf 'Os módulos migrados obedecem ao pack, e os três caminhos da leitura funcionam.\n'
exit 0
