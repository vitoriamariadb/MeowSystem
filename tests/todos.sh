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
  sem-receita-no-log.sh
  temas-de-apps.sh
  leitura-fonte-unica.sh
  flavor-padrao.sh
  git-limpo.sh
  higiene.sh
  app.sh
  estilo.sh
  reversao.sh
  seco.sh
  convergencia.sh
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
  notas-de-funcao.sh
  frases-velhas.sh
  pack-dracula-completo.sh
  compositor-shim.sh
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
  oraculo-tema.sh
  applet-pino.sh
  escala-kdl.sh
  backoff-do-supervisor.sh
  pack-malicioso.sh
  casa-real.sh
  nada-manda-digitar.sh
  achados-tecnicos.sh
  miudos-do-install.sh
  restaurar.sh
  trabalho-vivo.sh
  reler-uma-vez.sh
  derivados.sh
  tres-pastas.sh
  migracao-do-painel.py
  vizinhos.sh
  lancador-do-meow.sh
  flatpak-tema.sh
  escritorio.sh
  fotos-do-pack.sh
  perfil.sh
  apps-em-todo-pack.sh
  ponte-reparo.sh
  ponte-so-reserva.sh
  criar-tema-leva.sh
  mesmo-horario.sh
  desbanir.sh
  mapas-fim-de-linha.sh
)

MAQUINA=(
  conversor.sh
  afinador.sh
  previa-cerca.sh
  app-navegador.py
  app-acessibilidade.py
  oficina.sh
  pastas-do-pack.sh
  restos-do-painel.sh
  folha-dos-resgatados.sh
  app-completo.py
  app-uso-real.py
  app-texto-visivel.py
  gate-link-externo.py
)

SEM_PULO=(
  app-completo.py
  app-uso-real.py
)

MODO="tudo"
case "${1:-}" in
  ''|--tudo)   MODO="tudo" ;;
  --portatil)  MODO="portatil" ;;
  --maquina)   MODO="maquina" ;;
  -h|--ajuda|--help)
    printf './tests/todos.sh              tudo, que é o que se roda na bancada dela\n'
    printf './tests/todos.sh --portatil   só o que roda em máquina sem COSMIC (o CI)\n'
    printf './tests/todos.sh --maquina    só o que exige a máquina dela\n'
    exit 0 ;;
  *) printf 'uso: %s [--tudo|--portatil|--maquina]\n' "$(basename "$0")" >&2; exit 2 ;;
esac

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
trap 'rm -rf "$SUITE_TMP"' EXIT
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
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MEOW_CONF MEOW_ESTADO
printf 'casa de brinquedo da suíte: %s (sudo, pkexec e su recusam e registram)\n' "$HOME"
printf 'sem barramento da sessão; pkill, killall, notify-send, systemd-run, loginctl, apt, apt-get e xdg-open recusam; systemctl, gsettings, dconf e busctl só leem\n\n'

VERDES=0; PULADOS=0; VERMELHOS=()
for nome in "${ALVOS[@]}"; do
  arq="$TESTES/$nome"
  if [ ! -x "$arq" ]; then
    printf 'FALHOU  %-22s não é executável\n' "$nome"
    VERMELHOS+=("$nome")
    continue
  fi
  inicio="$(date +%s)"
  if [[ $nome == *.py ]] && [ -n "$PY_NAVEGADOR" ]; then
    saida="$("$PY_NAVEGADOR" "$arq" 2>&1)"; rc=$?
  else
    saida="$("$arq" 2>&1)"; rc=$?
  fi
  seg=$(( $(date +%s) - inicio ))

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
done

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
