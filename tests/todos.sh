#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TESTES="$RAIZ/tests"

PORTATIL=(
  numeros.sh
  readme.sh
  ganchos.sh
  orfaos.sh
  portabilidade.sh
  arvore.sh
  pack.sh
  fonte-unica.sh
  sem-dracula-os-theme.sh
  temas-de-apps.sh
  spotify-atualizado.sh
  discord-vencord.sh
  apps-frases.sh
  temas-por-app.sh
  leitura-fonte-unica.sh
  flavor-padrao.sh
  git-limpo.sh
  caminhos-do-manual.sh
  higiene.sh
  app.sh
  modificacoes.sh
  modificacoes-no-install.sh
  logo-do-programa.sh
  fastfetch-altura.sh
  etapa-sem-pulo-verde.sh
  logo-do-pack-pessoal.sh
  logo.sh
  estilo.sh
  chave-do-acervo.sh
  reversao.sh
  seco.sh
  convergencia.sh
  chave-etapa.sh
  instalacao.sh
  midia.sh
  jogos-heroic.sh
  um-cartao-por-jogo.sh
  doctor-so-le.sh
  chaves-aposentadas.sh
  doctor-veredito.sh
  fzf-da-paleta.sh
  acento.sh
  vidro-do-cosmic.sh
  seletor-do-pack.sh
  acervo-da-ficha.sh
  acervo-do-pack-em-edicao.sh
  desenho-no-pack.sh
  gerador-dracula.sh
  variante.sh
  claro-do-pack.sh
  pack-pessoal-tem-tema.sh
  par-do-pack.sh
  notas-de-funcao.sh
  frases-velhas.sh
  pack-dracula-completo.sh
  pack-pessoal-veste-o-pai.sh
  biblioteca-em-portugues.sh
  trava-herdada.sh
  autostart.sh
  arquivos-filhos.sh
  icones-do-sistema.sh
  vagas-novas.sh
  compositor-shim.sh
  janela-sem-app-id.sh
  nomes-nas-duas-telas.sh
  decisoes.sh
  precisa-de-gente.sh
  sentinela.sh
  cosmic-prever.sh
  pos-apt.sh
  garantir-builds.sh
  patch-que-sobe.sh
  cadeia-de-atualizacao.sh
  volta-do-cosmic.sh
  contrato-cosmic.sh
  esquema-do-tema.sh
  oraculo-tema.sh
  applet-pino.sh
  extensoes.sh
  extensoes-install.sh
  extensoes-gesto.sh
  escala-kdl.sh
  backoff-do-supervisor.sh
  pack-malicioso.sh
  casa-real.sh
  nada-manda-digitar.sh
  achados-tecnicos.sh
  miudos-do-install.sh
  etapa-compositor.sh
  restaurar.sh
  trabalho-vivo.sh
  reler-uma-vez.sh
  derivados.sh
  tres-pastas.sh
  procedencia-em-dado.sh
  migracao-do-painel.py
  vizinhos.sh
  qbittorrent-tema-do-pack.sh
  segunda-passada-sem-rede.sh
  maquina-nova.sh
  lancador-do-meow.sh
  flatpak-tema.sh
  escritorio.sh
  fotos-do-pack.sh
  perfil.sh
  apps-em-todo-pack.sh
  pack-traz-o-que-usa.sh
  sons-do-pack.sh
  ponte-reparo.sh
  ponte-so-reserva.sh
  painel-janela-propria.sh
  painel-sobrevive-ao-lancador.sh
  areas-em-cada-tela.sh
  margem-no-teto.sh
  ponte-cosmic-comp.sh
  painel-fantasma.sh
  criar-tema-leva.sh
  mesmo-horario.sh
  apagar-papel.sh
  mapas-fim-de-linha.sh
  dado-sem-comentario.sh
  migrar-caminhos.sh
  wallpaper-base.sh
  papel-em-par.sh
  creditos-dos-papeis.sh
  semente-dos-papeis.sh
  papeis-por-pack.sh
  gpu-do-compositor.sh
  graficos.sh
  dock.sh
  deb.sh
  espaco.sh
  levantamento.sh
  glossario.sh
  pacotes-numa-lista.sh
  comum-carrega-limpo.sh
  destrava.sh
  navegadores-gtk.sh
  atualiza.sh
  autoreparo-na-sessao.sh
  unidade-que-falhou.sh
  preflight-so-da-conta.sh
  flatpak-override-vigia.sh
  botoes-lado.sh
  completion-dos-verbos.sh
  valores-de-antes.sh
  cache-do-lancador.sh
)

MAQUINA=(
  conversor.sh
  afinador.sh
  previa-cerca.sh
  app-navegador.py
  grava-ao-soltar.py
  app-acessibilidade.py
  app-layout.py
  rodape-do-tema.py
  galeria-do-papel.py
  criar-e-aprimorar.py
  oficina.sh
  icones-por-pack.py
  personalizar-pagina.py
  soberana-pagina.py
  sistema-latte-e-rotulos.py
  pastas-do-pack.sh
  retirados-do-pack.sh
  restos-do-painel.sh
  app-completo.py
  app-uso-real.py
  manter-sem-pendencias.py
  p113-navegador.py
  gate-link-externo.py
  extensoes-pagina.py
  espaco-pagina.py
  modificacoes-pagina.py
  logo-pagina.py
  resultado-na-linha.py
  faixa-de-fabrica.py
  logo-do-pack-pessoal-pagina.py
  zapzap-tema-de-conversa.py
  graficos-fonte-real.sh
  dock-fonte-real.sh
  icone-e-fonte-no-tema.sh
  palco.sh
  area-os.sh
  nomes-dos-applets.sh
)

SEM_PULO=(
  app-completo.py
  app-uso-real.py
  extensoes-pagina.py
  espaco-pagina.py
  modificacoes-pagina.py
  logo-pagina.py
  resultado-na-linha.py
  faixa-de-fabrica.py
  logo-do-pack-pessoal-pagina.py
  soberana-pagina.py
)

FILA_INSTALL=(
  convergencia.sh
  seco.sh
  perfil.sh
  casa-real.sh
  maquina-nova.sh
)

FILA_PALCO=(
  palco.sh
  area-os.sh
)

FILA_PAINEL_LONGO=(
  app-completo.py
)

LARGAM_PRIMEIRO=(
  restaurar.sh
  deb.sh
  pastas-do-pack.sh
  pack-dracula-completo.sh
)

MODO="tudo"
EM_SERIE=0
TRABALHADORES=""
for arg in "$@"; do
  case "$arg" in
    --tudo)      MODO="tudo" ;;
    --portatil)  MODO="portatil" ;;
    --maquina)   MODO="maquina" ;;
    --so=?*)     MODO="so"; SO_LISTA="${arg#--so=}" ;;
    --em-serie)  EM_SERIE=1 ;;
    --trabalhadores=[1-9]|--trabalhadores=[1-9][0-9]) TRABALHADORES="${arg#--trabalhadores=}" ;;
    -h|--ajuda|--help)
      printf './tests/todos.sh              tudo, que é o que se roda na bancada dela\n'
      printf './tests/todos.sh --portatil   só o que roda em máquina sem COSMIC (o CI)\n'
      printf './tests/todos.sh --maquina    só o que exige a máquina dela\n'
      printf './tests/todos.sh --so=a.sh,b.sh  só esses, com os mesmos falsos e o mesmo HOME de mentira\n'
      printf './tests/todos.sh --em-serie   um teste por vez, todos na mesma casa de mentira\n'
      printf './tests/todos.sh --trabalhadores=N  quantos testes ao mesmo tempo (padrão: metade dos núcleos)\n'
      exit 0 ;;
    *) printf 'uso: %s [--tudo|--portatil|--maquina|--so=a.sh,b.sh] [--em-serie] [--trabalhadores=N]\n' "$(basename "$0")" >&2; exit 2 ;;
  esac
done
if [ -z "$TRABALHADORES" ]; then
  TRABALHADORES=$(( $(nproc 2>/dev/null || echo 2) / 2 ))
  [ "$TRABALHADORES" -ge 1 ] || TRABALHADORES=1
fi
[ "$EM_SERIE" -eq 1 ] && TRABALHADORES=1

conhecido() {
  local alvo="$1" i
  for i in "${PORTATIL[@]}" "${MAQUINA[@]}"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

mapfile -t ENCONTRADOS < <(
  find "$TESTES" -maxdepth 1 -type f \
       \( -perm -u+x -o -name '*.sh' -o -name '*.py' \) -printf '%f\n' | sort
)
DESCONHECIDOS=()
for nome in "${ENCONTRADOS[@]:-}"; do
  [ -n "$nome" ] || continue
  [ "$nome" = "todos.sh" ] && continue
  conhecido "$nome" || DESCONHECIDOS+=("$nome")
done
if [ "${#DESCONHECIDOS[@]}" -gt 0 ]; then
  printf 'FALHOU: teste sem classificação em tests/todos.sh: %s\n' "${DESCONHECIDOS[*]}" >&2
  printf 'Diga se ele roda em qualquer máquina (PORTATIL) ou só na dela (MAQUINA).\n' >&2
  printf 'Sem isso este runner diria verde sem ter rodado o arquivo novo.\n' >&2
  exit 2
fi

case "$MODO" in
  tudo)     ALVOS=("${PORTATIL[@]}" "${MAQUINA[@]}"); QUAL="todos os $(( ${#PORTATIL[@]} + ${#MAQUINA[@]} ))" ;;
  portatil) ALVOS=("${PORTATIL[@]}");                 QUAL="os ${#PORTATIL[@]} portáteis (sem COSMIC, sem Papirus, sem navegador)" ;;
  maquina)  ALVOS=("${MAQUINA[@]}");                  QUAL="os ${#MAQUINA[@]} que exigem a máquina dela" ;;
  so)
    IFS=, read -ra ALVOS <<< "$SO_LISTA"
    for i in "${ALVOS[@]}"; do
      conhecido "$i" || { printf 'FALHOU: %s não está no PORTATIL nem no MAQUINA\n' "$i" >&2; exit 2; }
    done
    QUAL="os ${#ALVOS[@]} pedidos" ;;
esac

printf '== suíte MeowSystem: %s ==\n' "$QUAL"

PY_NAVEGADOR=""
TEM_PY=0
for nome in "${ALVOS[@]}"; do [[ $nome == *.py ]] && TEM_PY=1; done
if [ "$TEM_PY" -eq 1 ]; then
  mapfile -t CANDIDATOS < <(
    type -ap python3
    command -v pyenv >/dev/null 2>&1 && pyenv which python3 2>/dev/null
    printf '%s\n' "$HOME/.local/share/meowsystem/venv-testes/bin/python3"
  )
  for py in "${CANDIDATOS[@]}"; do
    [ -x "$py" ] || continue
    "$py" -c 'import playwright.sync_api' >/dev/null 2>&1 && { PY_NAVEGADOR="$py"; break; }
  done
  printf 'python dos testes de navegador: %s\n' \
         "${PY_NAVEGADOR:-nenhum python3 com Playwright nesta máquina}"
fi
printf '\n'

CASA_REAL="$HOME"
export SUITE_CASA_REAL="$CASA_REAL"
SUITE_TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$SUITE_TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$SUITE_TMP/falso" "$SUITE_TMP/casa" || exit 2
export SUITE_SUDO_LOG="$SUITE_TMP/sudo.log"; : > "$SUITE_SUDO_LOG"
for c in sudo pkexec su; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*" >> "$SUITE_SUDO_LOG"\nexit 1\n' \
    > "$SUITE_TMP/falso/$c"
  chmod 755 "$SUITE_TMP/falso/$c"
done

export SUITE_FALSOS_LOG="$SUITE_TMP/falsos.log"; : > "$SUITE_FALSOS_LOG"
for c in pkill killall notify-send systemd-run loginctl apt apt-get xdg-open; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*" >> "$SUITE_FALSOS_LOG"\nexit 1\n' \
    > "$SUITE_TMP/falso/$c"
  chmod 755 "$SUITE_TMP/falso/$c"
done
_so_leitura() {
  local c="$1" verbos="$2" real
  real="$(command -v "$c" 2>/dev/null)" || real=""
  cat > "$SUITE_TMP/falso/$c" <<FIM
#!/bin/sh
verbo=""
for a in "\$@"; do case "\$a" in -*) ;; *) verbo="\$a"; break ;; esac; done
case " \$verbo " in
  "  "|$verbos)
    [ -n "$real" ] && exec "$real" "\$@"
    exit 1 ;;
esac
printf "%s %s\\n" "$c" "\$*" >> "\$SUITE_FALSOS_LOG"
exit 1
FIM
  chmod 755 "$SUITE_TMP/falso/$c"
}
_so_leitura systemctl '" is-active "|" is-enabled "|" is-failed "|" is-system-running "|" status "|" show "|" cat "|" list-units "|" list-unit-files "|" list-timers "|" list-jobs "|" list-dependencies "|" get-default "|" show-environment "'
_so_leitura gsettings '" get "|" list-schemas "|" list-relocatable-schemas "|" list-keys "|" list-children "|" list-recursively "|" range "|" describe "|" writable "|" help "'
_so_leitura dconf '" read "|" list "|" dump "|" help "'
_so_leitura busctl '" list "|" status "|" tree "|" introspect "|" get-property "|" help "'
_so_leitura flatpak '" list "|" info "|" remotes "|" remote-ls "|" ps "|" --version "'
_flatpak_real="$(command -v flatpak 2>/dev/null)" || _flatpak_real=""
sed -i "2a case \" \$* \" in *\" override\"*\" --user \"*|*\" --user\"*\" override \"*) [ -n \"$_flatpak_real\" ] \&\& exec \"$_flatpak_real\" \"\$@\"; exit 1 ;; esac" \
  "$SUITE_TMP/falso/flatpak"
unset DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY DISPLAY
[ -d "$CASA_REAL/.cache/ms-playwright" ] && \
  export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-$CASA_REAL/.cache/ms-playwright}"
[ -d "$CASA_REAL/.pyenv" ] && export PYENV_ROOT="${PYENV_ROOT:-$CASA_REAL/.pyenv}"
export PYTHONUSERBASE="${PYTHONUSERBASE:-$CASA_REAL/.local}"
export PATH="$SUITE_TMP/falso:$PATH" HOME="$SUITE_TMP/casa"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MEOW_CONF MEOW_ESTADO ZDOTDIR
printf 'casa de brinquedo da suíte: %s (sudo, pkexec e su recusam e registram)\n' "$HOME"
printf 'sem barramento da sessão; pkill, killall, notify-send, systemd-run, loginctl, apt, apt-get e xdg-open recusam; systemctl, gsettings, dconf e busctl só leem\n\n'

VERDES=0; PULADOS=0; VERMELHOS=()
RES="$SUITE_TMP/res"
mkdir -p "$RES" "$SUITE_TMP/casas" || exit 2

rodar_um() {
  local idx="$1" nome="$2" arq="$TESTES/$2" inicio rc=0
  if [ ! -x "$arq" ]; then
    : > "$RES/$idx.saida"
    printf -- '- 0\n' > "$RES/$idx.fim"
    return 0
  fi
  if [ "$EM_SERIE" -eq 0 ]; then
    export HOME="$SUITE_TMP/casas/$idx"
    mkdir -p "$HOME"
  fi
  inicio="$(date +%s)"
  if [[ $nome == *.py ]] && [ -n "$PY_NAVEGADOR" ]; then
    "$PY_NAVEGADOR" "$arq" > "$RES/$idx.saida" 2>&1 < /dev/null || rc=$?
  else
    "$arq" > "$RES/$idx.saida" 2>&1 < /dev/null || rc=$?
  fi
  printf '%s %s\n' "$rc" "$(( $(date +%s) - inicio ))" > "$RES/$idx.parcial"
  mv "$RES/$idx.parcial" "$RES/$idx.fim"
}

relatar() {
  local idx="$1" nome="$2" saida rc seg estado sem_pulo i disse_pulado disse_falhou vermelho
  read -r rc seg < "$RES/$idx.fim"
  if [ "$rc" = "-" ]; then
    printf 'FALHOU  %-22s não é executável\n' "$nome"
    VERMELHOS+=("$nome")
    return 0
  fi
  saida="$(cat "$RES/$idx.saida")"

  disse_pulado=0
  [[ $saida == pulado* || $saida == *$'\n'pulado* ]] && disse_pulado=1
  disse_falhou=0
  [[ $saida == *FALHOU* ]] && disse_falhou=1

  sem_pulo=0
  for i in "${SEM_PULO[@]}"; do [ "$i" = "$nome" ] && sem_pulo=1; done
  if [ "$sem_pulo" -eq 1 ] && [[ $nome == *.py ]] && [ -z "$PY_NAVEGADOR" ]; then
    estado="FALHOU"; VERMELHOS+=("$nome")
    saida="FALHOU: $nome é gate de merge e nenhum python3 desta máquina tem o Playwright.
FALHOU: instale:  python3 -m venv ~/.local/share/meowsystem/venv-testes
FALHOU:           ~/.local/share/meowsystem/venv-testes/bin/pip install playwright
FALHOU:           ~/.local/share/meowsystem/venv-testes/bin/playwright install chromium
$saida"
  elif [ "$sem_pulo" -eq 1 ] && [ "$disse_pulado" -eq 1 ]; then
    estado="FALHOU"; VERMELHOS+=("$nome")
    saida="FALHOU: $nome é gate de merge, e pulado aqui é vermelho
$saida"
  elif [ "$disse_pulado" -eq 1 ] && [ "$disse_falhou" -eq 0 ] \
     && { [ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]; }; then
    estado="pulado"; PULADOS=$((PULADOS + 1))
  elif [ "$rc" -eq 0 ]; then
    estado="ok"; VERDES=$((VERDES + 1))
  else
    estado="FALHOU"; VERMELHOS+=("$nome")
  fi
  printf '%-7s %-22s rc=%-3s %3ss\n' "$estado" "$nome" "$rc" "$seg"

  if [ "$estado" = "FALHOU" ]; then
    vermelho="$(printf '%s\n' "$saida" | awk '
      /FALHOU|^Erro|^ *XX / { print; next }
      /^Traceback/           { tb = 1; print; next }
      tb && /^  File ".*\/tests\// { print; if ((getline l) > 0) print l; next }
      tb && /^[^ \t]/        { print; tb = 0 }')"
    [ -n "$vermelho" ] || vermelho="$saida"
    printf '%s\n' "$vermelho" | sed 's/^/        | /'
  fi
}

fila_de() {
  local nome="$1" i
  for i in "${FILA_INSTALL[@]}"; do [ "$i" = "$nome" ] && { printf 'install'; return; }; done
  for i in "${FILA_PALCO[@]}"; do [ "$i" = "$nome" ] && { printf 'palco'; return; }; done
  for i in "${FILA_PAINEL_LONGO[@]}"; do [ "$i" = "$nome" ] && { printf 'painel-longo'; return; }; done
  [[ $nome == *.py ]] && { printf 'painel'; return; }
  printf 'solto'
}

INICIO_DA_SUITE="$(date +%s)"
if [ "$EM_SERIE" -eq 1 ]; then
  printf 'em série: um teste por vez, todos na mesma casa\n\n'
  for idx in "${!ALVOS[@]}"; do
    rodar_um "$idx" "${ALVOS[idx]}"
    relatar "$idx" "${ALVOS[idx]}"
  done
else
  printf 'em paralelo: %s ao mesmo tempo, cada teste na casa dele; install, palco e painel em fila própria\n\n' "$TRABALHADORES"
  declare -A DA_FILA=()
  SOLTOS=()
  for idx in "${!ALVOS[@]}"; do
    f="$(fila_de "${ALVOS[idx]}")"
    [ "$f" = solto ] || { DA_FILA[$f]="${DA_FILA[$f]:-}$idx "; continue; }
    for i in "${LARGAM_PRIMEIRO[@]}"; do
      [ "$i" = "${ALVOS[idx]}" ] && { SOLTOS=("$idx" "${SOLTOS[@]:+${SOLTOS[@]}}"); continue 2; }
    done
    SOLTOS+=("$idx")
  done
  PROXIMO=0
  EM_VOO=0
  descarregar() {
    while [ "$PROXIMO" -lt "${#ALVOS[@]}" ] && [ -f "$RES/$PROXIMO.fim" ]; do
      relatar "$PROXIMO" "${ALVOS[PROXIMO]}"
      PROXIMO=$((PROXIMO + 1))
    done
  }
  esperar_vaga() {
    while [ "$EM_VOO" -ge "$TRABALHADORES" ]; do
      wait -n
      EM_VOO=$((EM_VOO - 1))
      descarregar
    done
  }
  for f in install palco painel-longo painel; do
    [ -n "${DA_FILA[$f]:-}" ] || continue
    esperar_vaga
    ( for idx in ${DA_FILA[$f]}; do rodar_um "$idx" "${ALVOS[idx]}"; done ) &
    EM_VOO=$((EM_VOO + 1))
  done
  for idx in "${SOLTOS[@]:-}"; do
    [ -n "$idx" ] || continue
    esperar_vaga
    rodar_um "$idx" "${ALVOS[idx]}" &
    EM_VOO=$((EM_VOO + 1))
  done
  while [ "$EM_VOO" -gt 0 ]; do
    wait -n
    EM_VOO=$((EM_VOO - 1))
    descarregar
  done
  descarregar
fi
printf '\ntempo de parede: %ss\n' "$(( $(date +%s) - INICIO_DA_SUITE ))"

printf '\n== %s · %s verde(s), %s pulado(s), %s vermelho(s) ==\n' \
       "$QUAL" "$VERDES" "$PULADOS" "${#VERMELHOS[@]}"
if [ -s "$SUITE_SUDO_LOG" ]; then
  printf 'sudo/pkexec/su recusados durante a suíte: %s chamada(s)\n' "$(grep -c . "$SUITE_SUDO_LOG")"
  LC_ALL=C sort "$SUITE_SUDO_LOG" | uniq -c | sort -rn | head -10 | sed 's/^/    /'
else
  printf 'nenhum teste chamou sudo, pkexec ou su\n'
fi
if [ -s "$SUITE_FALSOS_LOG" ]; then
  printf 'escritas paradas nos falsos: %s chamada(s)\n' "$(grep -c . "$SUITE_FALSOS_LOG")"
  awk '{print $1}' "$SUITE_FALSOS_LOG" | LC_ALL=C sort | uniq -c | sort -rn | sed 's/^/    /'
else
  printf 'nenhuma escrita parada nos outros falsos\n'
fi
if [ "${#VERMELHOS[@]}" -gt 0 ]; then
  printf 'vermelhos: %s\n' "${VERMELHOS[*]}" >&2
  exit 1
fi
[ "$PULADOS" -gt 0 ] && printf 'atenção: %s teste(s) pulado(s) não são verde — falta dependência nesta máquina.\n' "$PULADOS"
exit 0
