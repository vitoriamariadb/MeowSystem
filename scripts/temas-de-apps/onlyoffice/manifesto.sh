#!/usr/bin/env bash
# scripts/temas-de-apps/onlyoffice/manifesto.sh — o tema do pack no OnlyOffice.
#
# POR QUE ESTE MÓDULO NASCEU — 24/09/2026, sprint P42
#   A P37 pôs o OnlyOffice entre os temas que o Dracula de antes aplicava e o
#   MeowSystem nunca migrou. Medido para esta sprint, a premissa só vale pela
#   metade: aquele repositório NÃO tinha tema de OnlyOffice — só um README
#   dizendo "não há automação", porque o autor achou que o app só tinha temas
#   fechados. O app tem mais que isso: desde a 7.2 o OnlyOffice Desktop lê temas
#   de interface em JSON de uma pasta `uithemes/`, e esta máquina tem um lá
#   (`dracula_only_office.json`, id `theme-dracula-dark-ajustado-2`, de
#   12/08/2025, sem procedência), escolhido no `DesktopEditors.conf`.
#
#   Então o que migrou foi o FORMATO, não um arquivo: o modelo do pack
#   (`apps.onlyoffice.arquivo`) tem as 125 chaves daquele tema, cada uma com o
#   papel da cor no lugar dela, e o `scripts/temas-de-apps/modelo.py` põe o hex.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Nada de `exit`, nada de `set -e`.
#
# DUAS ESCRITAS, E SÓ A PRIMEIRA É NOSSA
#   1. `uithemes/meowsystem.json` — o tema, com id `theme-meowsystem`. É nosso:
#      vai pela `meow_escrever`, e o desinstalador o leva.
#   2. A ESCOLHA, no `DesktopEditors.conf` do app. Ele é do OnlyOffice, e a
#      escolha mora nele em DOIS lugares, medidos no desta máquina: a chave
#      `UITheme` (o caminho do JSON) e o campo `uitheme` de dentro de `appdata`,
#      que é um JSON em base64 (`@ByteArray(...)`) — o que o app manda para os
#      editores. Os dois são escritos juntos, e o resto do arquivo passa intacto.
#      Sem manifesto, pelo motivo do kitty.conf: o arquivo é do app, e o
#      `--uninstall` não pode apagá-lo.
#
# O APP ABERTO REESCREVE O CONF AO SAIR
#   É o que o Qt faz com as configurações dele, e é a armadilha que o módulo do
#   Obsidian mediu com o `appearance.json`. Com o OnlyOffice aberto a escolha
#   NÃO é escrita: o tema entra na pasta e a escolha fica para a próxima
#   passagem. O processo é `DesktopEditors` (o `desktopeditors` do flatpak faz
#   `exec ./DesktopEditors`), e `pgrep -x` casa o nome exato — não pega o
#   próprio shell, que era o defeito do `pgrep -f` que o Obsidian documenta.
#
# AS TRÊS SAÍDAS DA LEITURA (P18)
#   sem tema       nenhuma escolha, ou um dos temas de fábrica — os oito ids que
#                  o binário 9.4.0 traz: theme-system, theme-light,
#                  theme-classic-light, theme-dark, theme-contrast-dark,
#                  theme-gray, theme-white e theme-night (medido por `strings`)
#   do pack        a escolha é `theme-meowsystem`
#   de terceiro    qualquer outro tema de `uithemes/` — é o caso desta máquina,
#                  e a resposta é perguntar ou deixar pendência.

_OO_ID="org.onlyoffice.desktopeditors"
_OO_TEMA_ID="theme-meowsystem"
_OO_FABRICA=" theme-system theme-light theme-classic-light theme-dark theme-contrast-dark theme-gray theme-white theme-night "
_OO_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"
# O que estava escolhido antes do nosso, para o `reverter` devolver.
_OO_ANTES="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/onlyoffice/escolha.antes"

# Onde o app guarda as coisas: o flatpak (o desta máquina) no ~/.var/app, o
# nativo no XDG. Preenche `_OO_DADOS` e `_OO_CONF`, ou falha.
_oo_lugares() {
  if meow_flatpak_tem "$_OO_ID"; then
    _OO_DADOS="$HOME/.var/app/$_OO_ID/data/onlyoffice/desktopeditors"
    _OO_CONF="$HOME/.var/app/$_OO_ID/config/onlyoffice/DesktopEditors.conf"
  elif meow_tem onlyoffice-desktopeditors || meow_tem desktopeditors \
       || [ -x /opt/onlyoffice/desktopeditors/DesktopEditors ]; then
    _OO_DADOS="${XDG_DATA_HOME:-$HOME/.local/share}/onlyoffice/desktopeditors"
    _OO_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/onlyoffice/DesktopEditors.conf"
  else
    return 1
  fi
  _OO_ARQ="$_OO_DADOS/uithemes/meowsystem.json"
}

# O leitor e o escritor do DesktopEditors.conf, num python só — duas leituras
# do mesmo formato em dois lugares discordariam no dia em que uma mudasse.
#   ler <conf>                         imprime `UITheme=<v>`, `uitheme=<v>` e
#                                      `id_do_UITheme=<v>` (ver abaixo)
#   escolher <conf> <uitheme> <UITheme> imprime o conf inteiro com os dois trocados
_oo_py() {
  python3 -I - "$@" <<'PY'
import base64, json, os, re, sys

modo, caminho = sys.argv[1], sys.argv[2]
try:
    linhas = open(caminho, encoding="utf-8").read().split("\n")
except OSError:
    linhas = []
RE_APP = re.compile(r'^appdata="@ByteArray\(([A-Za-z0-9+/=]*)\)"$')


def appdata(linha):
    m = RE_APP.match(linha)
    return json.loads(base64.b64decode(m.group(1)).decode("utf-8")) if m else None


secao = None
if modo == "ler":
    ui, dados = "", ""
    for l in linhas:
        if l.startswith("["):
            secao = l.strip()
        elif secao == "[General]" and l.startswith("UITheme="):
            ui = l[len("UITheme="):]
        elif secao == "[General]" and l.startswith("appdata="):
            # Ilegível NÃO é "sem tema": seria o caminho para escrever por cima
            # de uma escolha que só não soubemos ler. Vira um nome que não é de
            # fábrica, e cai na saída de terceiro — pergunta, ou pendência.
            try:
                d = appdata(l)
            except (ValueError, UnicodeDecodeError):
                d = {"uitheme": "(appdata ilegível)"}
            dados = (d or {}).get("uitheme", "") if isinstance(d, dict) else ""
    # O `UITheme` guarda o CAMINHO do JSON quando o tema é de `uithemes/` — é o
    # que o conf desta máquina tem. Sem o `appdata`, é por ele que se sabe qual
    # tema está no ar, e o que o identifica é o `id` de dentro do arquivo, não o
    # caminho: comparar caminho com id fazia o nosso próprio tema parecer de
    # terceiro (medido na casa de brinquedo, 24/09/2026).
    ui_id = ui
    if ui.endswith(".json") and os.path.isfile(ui):
        try:
            ui_id = json.load(open(ui, encoding="utf-8")).get("id") or ui
        except (OSError, ValueError, AttributeError):
            ui_id = ui
    print(f"UITheme={ui}")
    print(f"uitheme={dados}")
    print(f"id_do_UITheme={ui_id}")
    sys.exit(0)

if modo == "escolher":
    novo_id, novo_ui = sys.argv[3], sys.argv[4]
    saida, viu_ui, viu_geral = [], False, False
    for l in linhas:
        if l.startswith("["):
            if secao == "[General]" and not viu_ui:
                saida.append(f"UITheme={novo_ui}")
                viu_ui = True
            secao = l.strip()
            viu_geral = viu_geral or secao == "[General]"
        elif secao == "[General]" and l.startswith("UITheme="):
            l, viu_ui = f"UITheme={novo_ui}", True
        elif secao == "[General]" and l.startswith("appdata="):
            d = appdata(l)
            if isinstance(d, dict):
                d["uitheme"] = novo_id
                # O mesmo JSON compacto que o app escreve, e a ordem das chaves
                # dele preservada: só o valor da escolha muda.
                cru = json.dumps(d, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
                l = f'appdata="@ByteArray({base64.b64encode(cru).decode()})"'
        saida.append(l)
    if not viu_ui:
        if not viu_geral:
            saida = ["[General]"] + saida
            viu_geral = True
        pos = saida.index("[General]") + 1
        saida.insert(pos, f"UITheme={novo_ui}")
    sys.stdout.write("\n".join(saida).rstrip("\n") + "\n")
    sys.exit(0)

sys.exit(2)
PY
}

# O que está escolhido: `_OO_NO_AR` é o id (vazio = sem tema, ou tema de
# fábrica), e `_OO_ESCOLHA` guarda as duas chaves como estavam, para o antes.
_oo_no_ar() {
  local lido ui dados ui_id
  _OO_NO_AR=""; _OO_ESCOLHA=""
  [ -f "$_OO_CONF" ] || return 0
  lido="$(_oo_py ler "$_OO_CONF" 2>/dev/null)"
  ui="$(sed -n 's/^UITheme=//p' <<< "$lido")"
  dados="$(sed -n 's/^uitheme=//p' <<< "$lido")"
  ui_id="$(sed -n 's/^id_do_UITheme=//p' <<< "$lido")"
  _OO_ESCOLHA="$(printf '%s\t%s' "$dados" "$ui")"
  _OO_NO_AR="${dados:-$ui_id}"
  case "$_OO_FABRICA" in *" $_OO_NO_AR "*) _OO_NO_AR="" ;; esac
  return 0
}

_oo_aberto() { pgrep -x DesktopEditors >/dev/null 2>&1; }

# Escreve o conf do APP: atômico, sem manifesto, com o modo dele preservado.
_oo_gravar_conf() {
  local novo="$1" dir tmp
  meow_destino_permitido "$_OO_CONF" || return "$MEOW_ERRO"
  [ -f "$_OO_CONF" ] && [ "$novo" = "$(cat "$_OO_CONF")" ] && return "$MEOW_OK"
  if meow_seco; then meow_muda "escolheria o tema em $_OO_CONF"; return "$MEOW_DIVERGENTE"; fi
  dir="$(dirname "$_OO_CONF")"
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s\n' "$novo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod --reference="$_OO_CONF" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$_OO_CONF" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { _oo_lugares; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "OnlyOffice: não está instalado"; return; }
  # python3 monta o tema e lê o conf; pgrep é o guarda do app aberto — sem ele
  # o guarda falharia para ABERTO e a escolha seria escrita por baixo do app.
  local falta
  for falta in python3 pgrep; do
    meow_tem "$falta" || { meow_app_sem "OnlyOffice: falta '$falta' (sem ele não dá para aplicar com segurança)"; return; }
  done
  meow_app_tema_do_pack onlyoffice.arquivo
  _OO_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "OnlyOffice: o pack no ar não declara tema para o OnlyOffice"; return; }
  _OO_DESEJADO="$(python3 "$_OO_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_OO_DE" 2>&1)" \
    || { meow_app_sem "OnlyOffice: o modelo do pack $_OO_DE não montou — $_OO_DESEJADO"; return; }
  _OO_NOME="$(python3 "$_OO_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null) (MeowSystem)"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _oo_no_ar
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ] && [ -n "$_OO_NO_AR" ]; then
    meow_pula "OnlyOffice: está no tema '$_OO_NO_AR', que não veio daqui — trocar é decisão sua"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  local rc="$MEOW_OK"
  if [ ! -f "$_OO_ARQ" ] || [ "$(cat "$_OO_ARQ")" != "$_OO_DESEJADO" ]; then
    meow_muda "OnlyOffice: o tema do pack não está em $_OO_ARQ, ou é de outro flavor"
    rc="$MEOW_DIVERGENTE"
  fi
  # Sem o conf, a escolha não é divergência que o `aplicar` conserte — é a
  # mesma pendência que ele devolve (ver lá). Com o tema já na pasta, 3; sem
  # ele, o 1 de cima fica, porque a pasta o `aplicar` resolve.
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ] && [ ! -f "$_OO_CONF" ] && [ "$rc" = "$MEOW_OK" ]; then
    meow_pula "OnlyOffice: nunca foi aberto — o tema do pack já está na pasta, e a escolha espera o conf que o app cria ao abrir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ]; then
    meow_muda "OnlyOffice: o tema escolhido é o de fábrica — o pack $_OO_DE traz '$_OO_NOME'"
    rc="$MEOW_DIVERGENTE"
  fi
  [ "$rc" = "$MEOW_OK" ] && meow_ok "OnlyOffice: já está no tema do pack (do pack $_OO_DE) — $_OO_NOME"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente onlyoffice; return; }
  _oo_no_ar
  local mudou=0
  # O nosso já escolhido não pergunta nada; o "já está" só sai no fim, se nada
  # mudou (ver o kitty) — um flavor novo reescreve o JSON com a escolha intacta.
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ]; then
    meow_app_tema_no_ar onlyoffice "$_OO_NO_AR" "$_OO_TEMA_ID" "$_OO_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  # 1. o tema na pasta — com o app aberto também: ele só lê a pasta ao abrir.
  meow_escrever "$_OO_ARQ" "$_OO_DESEJADO" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "OnlyOffice: falhou ao escrever $_OO_ARQ"; return "$MEOW_ERRO" ;; esac

  # 2. a escolha — só com o app fechado, e só se ainda não é a nossa.
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ]; then
    # NUNCA ABERTO É PENDÊNCIA, COMO O ABERTO — 24/09/2026, revisão da P42
    #   A primeira versão só avisava aqui e seguia para o fim: a 1ª passada dizia
    #   "tema do pack aplicado", e a 2ª, sem nada a escrever, caía no "já está no
    #   tema do pack — theme-meowsystem" com rc=0, enquanto o `conferir` dava 1
    #   ("o tema escolhido é o de fábrica"). Medido numa casa de brinquedo com o
    #   flatpak e sem o conf. A tela mentia, e o doctor nunca convergia. O conf
    #   NÃO é criado por nós: é do app, e a forma que ele espera na primeira
    #   abertura não foi medida. Então a escolha espera, dita, como no aberto.
    if [ ! -f "$_OO_CONF" ]; then
      meow_app_sem "OnlyOffice: nunca foi aberto, e sem o conf dele não há onde escolher o tema — ele já está na pasta; a escolha fica para depois da primeira abertura (ou escolha '$_OO_NOME' em Preferências > Aparência)"
      meow_app_pendente onlyoffice
      return "$MEOW_SEM_DEPENDENCIA"
    elif _oo_aberto; then
      meow_app_sem "OnlyOffice: está aberto, e ele reescreve o conf ao sair — o tema já está na pasta; a escolha fica para quando ele estiver fechado"
      meow_app_pendente onlyoffice
      return "$MEOW_SEM_DEPENDENCIA"
    else
      # O que estava escolhido fica guardado ANTES, uma vez só: é o que o
      # `reverter` devolve, e a segunda troca guardaria a nossa por cima.
      if [ ! -f "$_OO_ANTES" ] && ! meow_seco; then
        mkdir -p "$(dirname "$_OO_ANTES")" && printf '%s\n' "$_OO_ESCOLHA" > "$_OO_ANTES" \
          || { meow_erro "OnlyOffice: não consegui guardar a escolha de antes"; return "$MEOW_ERRO"; }
      fi
      local novo
      novo="$(_oo_py escolher "$_OO_CONF" "$_OO_TEMA_ID" "$_OO_ARQ")" \
        || { meow_erro "OnlyOffice: não consegui ler $_OO_CONF"; return "$MEOW_ERRO"; }
      _oo_gravar_conf "$novo"
      case $? in 1) mudou=1 ;; 2) meow_erro "OnlyOffice: falhou ao escrever $_OO_CONF"; return "$MEOW_ERRO" ;; esac
    fi
  fi

  if [ "$mudou" = 0 ]; then
    meow_app_tema_no_ar onlyoffice "$_OO_TEMA_ID" "$_OO_TEMA_ID" "$_OO_DE"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "OnlyOffice: tema do pack aplicado — $_OO_NOME (vale ao abrir o app)"
  return "$MEOW_DIVERGENTE"
}

# Tira o nosso JSON e, se a escolha ainda é a nossa, devolve a de antes — ou a
# de fábrica (`theme-system`), dita na tela, quando não há antes guardado. Não
# depende do pack; depende de saber onde o app guarda as coisas.
meow_app_reverter() {
  if ! _oo_lugares; then
    meow_ok "OnlyOffice: não está instalado — nada a desfazer"
    return "$MEOW_OK"
  fi
  _oo_no_ar
  local mudou=0 antes_id="theme-system" antes_ui="theme-system" linha
  if [ "$_OO_NO_AR" = "$_OO_TEMA_ID" ]; then
    if _oo_aberto; then
      meow_app_sem "OnlyOffice: está aberto, e ele reescreve o conf ao sair — feche-o e desfaça de novo"
      meow_app_pendente onlyoffice
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    if [ -f "$_OO_ANTES" ]; then
      linha="$(head -n 1 "$_OO_ANTES")"
      antes_id="${linha%%$'\t'*}"; antes_ui="${linha#*$'\t'}"
      [ -n "$antes_id" ] || antes_id="$antes_ui"
      [ -n "$antes_ui" ] || antes_ui="$antes_id"
    fi
    [ -n "$antes_id" ] || { antes_id="theme-system"; antes_ui="theme-system"; }
    _oo_gravar_conf "$(_oo_py escolher "$_OO_CONF" "$antes_id" "$antes_ui")"
    case $? in
      1) mudou=1; meow_seco || meow_ok "OnlyOffice: a escolha voltou a '$antes_id'" ;;
      2) meow_erro "OnlyOffice: não consegui devolver a escolha"; return "$MEOW_ERRO" ;;
    esac
  fi
  if [ -f "$_OO_ARQ" ]; then
    if meow_seco; then
      meow_muda "OnlyOffice: tiraria $_OO_ARQ"
    else
      rm -f -- "$_OO_ARQ" || { meow_erro "OnlyOffice: não consegui tirar $_OO_ARQ"; return "$MEOW_ERRO"; }
      meow_ok "OnlyOffice: o tema do pack saiu da pasta uithemes/"
    fi
    mudou=1
  fi
  meow_seco || rm -f -- "$_OO_ANTES"
  if [ "$mudou" = 0 ]; then
    meow_ok "OnlyOffice: nenhum tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_seco || meow_info "tire 'onlyoffice' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
