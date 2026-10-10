#!/usr/bin/env bash
# assets/temas-de-apps/gnome-terminal/manifesto.sh — o tema do pack no GNOME Terminal.
#
# POR QUE ESTE MÓDULO NASCEU — 24/09/2026, sprint P42
#   A P37 pôs o GNOME Terminal entre os temas que o Dracula de antes aplicava e
#   o MeowSystem nunca migrou. Medido para esta sprint, o que aquele tema fazia
#   era outra coisa: um `dconf load` de um perfil chamado "Dracula" POR CIMA do
#   perfil de fábrica do GNOME Terminal (`b1dcc9dd-5262-4d8d-a863-c897e6d979b9`,
#   o id que todo GNOME Terminal usa quando ninguém criou outro), e as cores
#   daquele perfil não são Dracula — fundo rgb(42,44,57), texto verde
#   rgb(146,181,156), e nenhuma das dezesseis da paleta é do tema. É o que está
#   no dconf desta máquina hoje (`dconf dump`, 24/09/2026).
#
#   Não havia o que copiar. O modelo do pack (`apps.gnome-terminal.arquivo`)
#   tem as cores por PAPEL, na ordem do dracula/kitty, e o
#   `assets/temas-de-apps/modelo.py` põe o hex.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Nada de `exit`, nada de `set -e`.
#
# UM PERFIL PRÓPRIO, E NÃO O DE FÁBRICA POR CIMA
#   O perfil do MeowSystem tem id próprio (o `_GT_UUID`, abaixo), entra na lista
#   de perfis e vira o PADRÃO. Os perfis que ela já tinha ficam como estavam — é
#   o que faz o `reverter` ser só "volta o padrão de antes e tira o nosso", sem
#   ter de reconstruir perfil de ninguém.
#
# AS TRÊS SAÍDAS DA LEITURA (P18), SOBRE O PERFIL PADRÃO
#   sem tema       o padrão usa as cores do sistema (`use-theme-colors`, que é
#                  verdadeiro de fábrica)
#   do pack        o padrão é o nosso perfil
#   de terceiro    o padrão tem cores próprias — é o caso desta máquina, com o
#                  perfil "Dracula" de antes —, e a resposta é perguntar ou
#                  deixar pendência.
#
# CONFERIR É "AS NOSSAS CHAVES ESTÃO LÁ", E NÃO "O PERFIL É IGUAL"
#   `dconf load` acrescenta chaves e não apaga as outras. Se ela trocar a fonte
#   no nosso perfil pelas preferências do app, a chave nova é dela, e cobrar um
#   perfil idêntico ao modelo acusaria divergência para sempre.

_GT_BASE="/org/gnome/terminal/legacy/profiles:"
# O id do nosso perfil. Fixo, para o `reverter` achá-lo: são os bytes de
# "meowsystem-term1" em hex, no formato de UUID que o GNOME Terminal exige.
_GT_UUID="6d656f77-7379-4374-656d-2d7465726d31"
_GT_FABRICA="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"
_GT_ANTES="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/gnome-terminal/padrao.antes"
_GT_MODELO_PY="$MEOW_RAIZ/assets/temas-de-apps/modelo.py"

# O valor de uma chave `s` do dconf sem as aspas simples do GVariant.
_gt_ler_s() { dconf read "$1" 2>/dev/null | sed "s/^'//; s/'\$//"; }

# O perfil padrão: o escrito, ou o de fábrica quando ninguém escreveu.
_gt_padrao() {
  local p; p="$(_gt_ler_s "$_GT_BASE/default")"
  printf '%s' "${p:-$_GT_FABRICA}"
}

# As linhas `chave=valor` do modelo montado, sem comentário nem cabeçalho.
_gt_chaves() { grep -vE '^[[:space:]]*(#|\[|$)' <<< "$_GT_DESEJADO"; }

# Toda chave do modelo está no nosso perfil, com o mesmo valor?
_gt_perfil_em_dia() {
  local dump linha
  dump="$(dconf dump "$_GT_BASE/:$_GT_UUID/" 2>/dev/null)"
  [ -n "$dump" ] || return 1
  while IFS= read -r linha; do
    grep -qxF -- "$linha" <<< "$dump" || return 1
  done <<< "$(_gt_chaves)"
  return 0
}

_gt_no_ar() {
  local padrao cores nome
  _GT_NO_AR=""; _GT_NOSSO=0
  padrao="$(_gt_padrao)"
  if [ "$padrao" = "$_GT_UUID" ]; then
    _GT_NOSSO=1; _GT_NO_AR="$_GT_UUID"; return 0
  fi
  cores="$(dconf read "$_GT_BASE/:$padrao/use-theme-colors" 2>/dev/null)"
  [ "$cores" = "false" ] || return 0
  nome="$(_gt_ler_s "$_GT_BASE/:$padrao/visible-name")"
  _GT_NO_AR="o perfil '${nome:-$padrao}'"
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { meow_tem gnome-terminal; }

# O MODELO DO PACK SÓ LEVA COR — conferência da P78, 09/10/2026
#   O tema montado vai inteiro para o `dconf load` do perfil, e o perfil vira o
#   padrão. Num pack de terceiro, `use-custom-command=true` com
#   `custom-command='…'` faria o GNOME Terminal rodar o comando do pack em toda
#   janela nova; e uma seção que não seja `[/]` escreveria fora do perfil. Fica
#   só linha vazia, comentário, a seção `[/]` e as chaves de cor e de nome; o
#   resto (e tudo o que vier sob outra seção) é pulado e contado — como no kitty.
_GT_CHAVES_DE_COR='^(visible-name|background-color|foreground-color|bold-color|bold-color-same-as-fg|bold-is-bright|cursor-background-color|cursor-foreground-color|cursor-colors-set|highlight-background-color|highlight-foreground-color|highlight-colors-set|palette|use-theme-colors|use-theme-transparency|use-transparent-background|background-transparency-percent)$'
_gt_so_cor() {
  local filtro fora
  filtro='
    /^[ \t]*(#|$)/ { if (!ruim) print; next }
    /^\[/ { ruim = ($0 != "[/]"); if (ruim) n++; else print; next }
    { k = $0; sub(/=.*/, "", k); gsub(/[ \t]/, "", k)
      if (ruim || k !~ re) { n++; next } print }
    END { if (conta) print n + 0 }'
  fora="$(printf '%s\n' "$_GT_DESEJADO" | awk -v re="$_GT_CHAVES_DE_COR" -v conta=1 "$filtro" | tail -1)"
  _GT_DESEJADO="$(printf '%s\n' "$_GT_DESEJADO" | awk -v re="$_GT_CHAVES_DE_COR" -v conta=0 "$filtro")"
  [ "${fora:-0}" -gt 0 ] && meow_aviso "GNOME Terminal: $fora linha(s) do modelo do pack $_GT_DE que não são cor ficaram de fora"
  return 0
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "GNOME Terminal: não está instalado"; return; }
  meow_tem dconf || { meow_app_sem "GNOME Terminal: falta o dconf, que guarda os perfis dele"; return; }
  meow_tem python3 || { meow_app_sem "GNOME Terminal: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack gnome-terminal.arquivo
  _GT_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "GNOME Terminal: o pack no ar não declara tema para ele"; return; }
  _GT_DESEJADO="$(python3 "$_GT_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_GT_DE" 2>&1)" \
    || { meow_app_sem "GNOME Terminal: o modelo do pack $_GT_DE não montou — $_GT_DESEJADO"; return; }
  _gt_so_cor
  _GT_QUERO="$_GT_UUID"
  _GT_NOME="$(python3 "$_GT_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null) (MeowSystem)"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _gt_no_ar
  if [ "$_GT_NOSSO" != 1 ]; then
    if [ -z "$_GT_NO_AR" ]; then
      meow_muda "GNOME Terminal: o perfil padrão usa as cores do sistema — o pack $_GT_DE traz '$_GT_NOME'"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "GNOME Terminal: o padrão é $_GT_NO_AR, que não veio daqui — trocar é decisão sua"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _gt_perfil_em_dia; then
    meow_muda "GNOME Terminal: o perfil do MeowSystem é o padrão, mas as cores dele não são as do pack de agora"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "GNOME Terminal: já está no tema do pack (do pack $_GT_DE) — $_GT_NOME"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente gnome-terminal; return; }
  _gt_no_ar
  local mudou=0 lista padrao_antes
  if [ "$_GT_NOSSO" = 1 ]; then
    meow_app_tema_no_ar gnome-terminal "$_GT_NO_AR" "$_GT_QUERO" "$_GT_DE" >/dev/null
  else
    meow_app_tema_no_ar gnome-terminal "$_GT_NO_AR" "$_GT_QUERO" "$_GT_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! _gt_perfil_em_dia; then
    if meow_seco; then
      meow_muda "carregaria o perfil '$_GT_NOME' em $_GT_BASE/:$_GT_UUID/"
    else
      dconf load "$_GT_BASE/:$_GT_UUID/" <<< "$_GT_DESEJADO" \
        || { meow_erro "GNOME Terminal: o dconf recusou o perfil do pack"; return "$MEOW_ERRO"; }
    fi
    mudou=1
  fi

  # Na lista de perfis, senão o app não o mostra. Lista vazia é a de fábrica,
  # que tem só o perfil de fábrica — e ele continua nela.
  lista="$(dconf read "$_GT_BASE/list" 2>/dev/null)"
  if ! grep -q "$_GT_UUID" <<< "$lista"; then
    local ids novo
    ids="$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$lista")"
    [ -n "$ids" ] || ids="$_GT_FABRICA"
    novo="[$(printf "'%s', " $ids)'$_GT_UUID']"
    if meow_seco; then meow_muda "poria o perfil do pack na lista do GNOME Terminal"
    else dconf write "$_GT_BASE/list" "$novo" || { meow_erro "GNOME Terminal: o dconf recusou a lista de perfis"; return "$MEOW_ERRO"; }
    fi
    mudou=1
  fi

  if [ "$_GT_NOSSO" != 1 ]; then
    # O padrão de antes fica guardado uma vez só, antes da troca: é o que o
    # `reverter` devolve. Vazio quer dizer "ninguém tinha escrito" — e é isso
    # que se devolve, e não o id de fábrica escrito por extenso.
    padrao_antes="$(_gt_ler_s "$_GT_BASE/default")"
    if [ ! -f "$_GT_ANTES" ] && ! meow_seco; then
      mkdir -p "$(dirname "$_GT_ANTES")" && printf '%s\n' "$padrao_antes" > "$_GT_ANTES" \
        || { meow_erro "GNOME Terminal: não consegui guardar o perfil padrão de antes"; return "$MEOW_ERRO"; }
    fi
    if meow_seco; then meow_muda "faria do perfil '$_GT_NOME' o padrão"
    else dconf write "$_GT_BASE/default" "'$_GT_UUID'" || { meow_erro "GNOME Terminal: o dconf recusou o perfil padrão"; return "$MEOW_ERRO"; }
    fi
    mudou=1
  fi

  [ "$mudou" = 0 ] && { meow_ok "GNOME Terminal: já está no tema do pack (do pack $_GT_DE) — $_GT_NOME"; return "$MEOW_OK"; }
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "GNOME Terminal: tema do pack aplicado — '$_GT_NOME' é o perfil padrão (vale na próxima janela)"
  return "$MEOW_DIVERGENTE"
}

# Volta o padrão de antes (ou o de fábrica, dito na tela, quando não há antes
# guardado), tira o nosso da lista e apaga o nosso perfil. Não depende do pack.
meow_app_reverter() {
  meow_tem dconf || { meow_ok "GNOME Terminal: sem dconf, não há perfil nosso a desfazer"; return "$MEOW_OK"; }
  local mudou=0 antes lista ids resto
  if [ "$(_gt_ler_s "$_GT_BASE/default")" = "$_GT_UUID" ]; then
    antes=""
    [ -f "$_GT_ANTES" ] && antes="$(head -n 1 "$_GT_ANTES")"
    if meow_seco; then
      meow_muda "GNOME Terminal: devolveria o perfil padrão de antes"
    elif [ -n "$antes" ]; then
      dconf write "$_GT_BASE/default" "'$antes'" || { meow_erro "GNOME Terminal: não consegui devolver o padrão"; return "$MEOW_ERRO"; }
      meow_ok "GNOME Terminal: o perfil padrão voltou a ser o de antes"
    else
      dconf reset "$_GT_BASE/default" || { meow_erro "GNOME Terminal: não consegui devolver o padrão"; return "$MEOW_ERRO"; }
      meow_ok "GNOME Terminal: o perfil padrão voltou ao de fábrica"
    fi
    mudou=1
  fi
  lista="$(dconf read "$_GT_BASE/list" 2>/dev/null)"
  if grep -q "$_GT_UUID" <<< "$lista"; then
    ids="$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$lista" | grep -vx "$_GT_UUID")"
    if meow_seco; then
      meow_muda "GNOME Terminal: tiraria o perfil do pack da lista"
    elif [ -z "$ids" ] || [ "$ids" = "$_GT_FABRICA" ]; then
      # Sobrou só o de fábrica: a lista volta a não estar escrita, que é como
      # ela era antes de haver um segundo perfil.
      dconf reset "$_GT_BASE/list"
    else
      resto="[$(printf "'%s', " $ids)"; resto="${resto%, }]"
      dconf write "$_GT_BASE/list" "$resto"
    fi
    mudou=1
  fi
  if [ -n "$(dconf dump "$_GT_BASE/:$_GT_UUID/" 2>/dev/null)" ]; then
    if meow_seco; then meow_muda "GNOME Terminal: apagaria o perfil do pack"
    else dconf reset -f "$_GT_BASE/:$_GT_UUID/" && meow_ok "GNOME Terminal: o perfil do pack saiu"
    fi
    mudou=1
  fi
  meow_seco || rm -f -- "$_GT_ANTES"
  if [ "$mudou" = 0 ]; then
    meow_ok "GNOME Terminal: nenhum perfil do MeowSystem — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_seco || meow_info "tire 'gnome-terminal' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
