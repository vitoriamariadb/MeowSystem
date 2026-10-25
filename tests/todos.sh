#!/usr/bin/env bash
# todos.sh — A PERGUNTA "A SUÍTE PASSA?" PASSA A TER UMA RESPOSTA.
#
# Metade desta suíte roda em qualquer lugar — HOME de brinquedo, `env -i`,
# `MEOW_IGNORA_DESKTOP=1`, nada além de bash e python3.
#
# Misturar os dois faz o CI ficar vermelho por AUSÊNCIA e não por defeito — e
# vermelho que não significa nada é a coisa que este arquivo veio matar, não
# criar.
#
#     ./tests/todos.sh              tudo, que é o que se roda na bancada dela
#     ./tests/todos.sh --portatil   só o que roda em máquina sem COSMIC (o CI)
#     ./tests/todos.sh --maquina    só o que exige a máquina dela
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TESTES="$RAIZ/tests"

# A CLASSIFICAÇÃO, com o motivo de cada linha
#
# PORTÁTIL: só bash, python3 e o que está versionado aqui.
PORTATIL=(
  numeros.sh             # lê o repositório e conta; nada mais
  orfaos.sh              # idem
  portabilidade.sh       # grep no que está versionado; nada além de git e bash
  arvore.sh              # pergunta ao `git ls-files` quem é dono de qual arquivo
  pack.sh                # pack de terceiro num MEOW_PACKS temporário; não instala nada
  fonte-unica.sh         # mapas do repositório + packs e HOME de brinquedo; só bash e python3
  sem-dracula-os-theme.sh # tokenize no código versionado + a camada Dracula num HOME de brinquedo; bash e python3
  sem-receita-no-log.sh  # grep nos .sh versionados; nada além de bash
  temas-de-apps.sh       # grep nos manifestos + pack.py; estado de brinquedo
  leitura-fonte-unica.sh # o meow leitura adotar e o servidor num HOME de brinquedo; bash e python3
  flavor-padrao.sh       # o lib/comum.sh, quatro scripts que só leem, dois manifestos, o conf do painel e o meow icones num HOME de brinquedo; bash e python3
  git-limpo.sh           # acervo, HOME e estado de brinquedo; só git e bash
  higiene.sh             # o gancho do repositório num clone --shared, HOME e git de brinquedo
  app.sh                 # compara o esquema do painel com o do wizard; python3
  estilo.sh              # régua da caneta contra o acervo Arcticons DAQUI (pede numpy)
  reversao.sh            # grep no desinstalador + install.sh com MEOW_IGNORA_DESKTOP=1
  seco.sh                # o cabeçalho dele exige rodar "inclusive num CI sem sessão gráfica"
  convergencia.sh        # instalador em HOME de brinquedo, cinco passagens (~70s)
  instalacao.sh          # o laço das passagens, com etapas falsas; não toca em nada
  midia.sh               # HOME de brinquedo com binário falso; nunca compila
  jogos-heroic.sh        # HOME de brinquedo com biblioteca falsa do Heroic
  um-cartao-por-jogo.sh  # HOME de brinquedo com manifesto falso da Steam
  doctor-so-le.sh        # o doctor inteiro num HOME de brinquedo, sudo/pkill/kill falsos (~15s)
  chaves-aposentadas.sh  # o migrar_conf.py e o doctor num HOME de brinquedo, sudo falso: a chave aposentada não volta
  doctor-veredito.sh
  fzf-da-paleta.sh       # paleta inventada e os dois packs daqui num HOME de brinquedo; bash e python3
  acento.sh              # COSMIC, pack e HOME de brinquedo; as etapas gerar e tema do install.sh; bash e python3
  vidro-do-cosmic.sh     # COSMIC, packs, HOME e TMPDIR de brinquedo; o alpha_map vai escrito no teste
  seletor-do-pack.sh     # cópia da árvore e HOME de brinquedo; as rotas da ficha e o passo do pack; bash, git e python3
  acervo-da-ficha.sh     # as rotas da ficha no processo, HOME de brinquedo; conta o disco e o git contra a ficha; bash, git e python3
  variante.sh            # COSMIC, os dois packs e HOME de brinquedo; as etapas gerar, tema e modo; bash e python3
  claro-do-pack.sh       # COSMIC, os dois packs e HOME de brinquedo; a foto só é lida; bash e python3
  notas-de-funcao.sh     # COSMIC, packs, HOME e estado de brinquedo; as etapas do install.sh e os passos de ícone; bash e python3
  frases-velhas.sh       # lê o que está versionado e pergunta ao git a idade da folha dos resgatados; bash, git e python3
  pack-dracula-completo.sh # o pack Dracula completo e exportável, packs e HOME de brinquedo; bash e python3
  compositor-shim.sh     # shim do compositor com dpkg-query e binários falsos, HOME de brinquedo; só bash
  decisoes.sh            # uma decisão, um teste: o resolvedor de ícones, o servidor, o app.js no node, o run.sh com getent falso e a troca de pack, HOME de brinquedo; bash, python3 e node
  precisa-de-gente.sh    # os verbos, o degrau 4 do garantir_builds, o servidor e o app.js no node, HOME de brinquedo; bash, python3 e node
  sentinela.sh           # apt falso,.deb e fontes de brinquedo, HOME de brinquedo: a fila medida uma vez, o cartão de «precisa de gente»; bash e dpkg-deb
  cosmic-prever.sh       # .deb e fontes de brinquedo do cosmic-comp, sem apt nem rede; bash e dpkg-deb
  pos-apt.sh             # pós-apt do COSMIC com dpkg-query e passos falsos, HOME de brinquedo; só bash
  garantir-builds.sh     # a função dos builds com dpkg-query e builds falsos, HOME de brinquedo, falsos que recusam; só bash
  cadeia-de-atualizacao.sh # a cadeia apt/topgrade/limpar_cache com dpkg, apt-get, make, just e cargo falsos e os scripts de verdade, HOME de brinquedo; bash, patch e tar
  volta-do-cosmic.sh     # guarda do.deb e do fonte com dpkg-query, apt e sudo falsos, HOME de brinquedo; só bash
  contrato-cosmic.sh     # /usr/share/cosmic e COSMIC de brinquedo com v2; seis escritores e o pré-voo; bash e python3
  oraculo-tema.sh        # saídas do oráculo guardadas em tests/oraculo/ contra a cópia em Python; só python3
  applet-pino.sh         # dois Cargo.lock falsos e um cargo falso; o leitura_build.sh num HOME de brinquedo; só bash
  escala-kdl.sh          # cosmic-randr falso com KDL fixo; só o saidas() do escala.sh; só bash
  backoff-do-supervisor.sh # journalctl falso com as duas formas do log do cosmic-session; só bash
  pack-malicioso.sh      # pack de terceiro com '..', absoluto, symlink e script; painel num HOME de brinquedo; bash, python3 e curl
  casa-real.sh           # o migrar_conf, o doctor e a troca de pack num HOME e COSMIC de brinquedo, sudo falso; bash e python3
  nada-manda-digitar.sh  # grep nas mensagens versionadas e a tabela de pendências do painel; bash e python3
  achados-tecnicos.sh    # mapa CRLF, BOM, vidro, modo do mascote e favoritas num HOME, COSMIC e packs de brinquedo; bash e python3
  miudos-do-install.sh   # o compositor que compilou sai 0, e a linha dos aplicativos do doctor nunca sai vazia; HOME, cache e fonte de brinquedo, make e dpkg-query falsos; só bash
  restaurar.sh           # cada ação do painel que escreve, e o Restaurar dela, numa árvore e HOME de brinquedo com falsos que recusam; bash e python3
  trabalho-vivo.sh       # o Trabalho do painel com a janela entre a morte e o desfecho aberta à força, HOME de brinquedo; bash e python3
  reler-uma-vez.sh       # a lib com getent, pgrep e painel.sh falsos numa raiz e HOME de brinquedo; um reler por passada, e o passo de traço de verdade; bash e python3
  derivados.sh           # alterou o desenho, o tema se atualiza: cópia da árvore e HOME de brinquedo, sem systemd; bash, git e python3
  tres-pastas.sh         # o formato de três pastas: os três packs, a quarta pasta, o.meowpack de antes convertido, packs e HOME de brinquedo; bash, python3 e zstd
  migracao-do-painel.py  # cada chave, ação e gesto do painel de antes tem lugar no novo (lugares.js no node, o esquema do servidor numa casa de brinquedo)
  vizinhos.sh            # o inventário dos vizinhos e o desligar com volta, numa casa de brinquedo com zsh, systemd, apt e repositório falsos; só bash
  lancador-do-meow.sh    # pontes de app_id, lançador órfão, mimeinfo.cache e o ocultar fora de /usr/share, numa casa de brinquedo com flatpak e update-desktop-database falsos; bash e python3
  flatpak-tema.sh        # o override do Flatpak do usuário, o global do sistema pela cópia da ponte e os dois scripts do NitroKit, com flatpak, sudo e gsettings falsos, casa de brinquedo; bash e python3
  escritorio.sh          # o OnlyOffice do Flathub no lugar do LibreOffice, a ponte root de brinquedo e o desinstalador que devolve, com flatpak, dpkg-query, apt-get e sudo falsos, casa de brinquedo; só bash
  apps-em-todo-pack.sh   # cada app x pack numa casa de brinquedo, dconf e flatpak falsos e falsos que recusam; bash e python3
)

# MÁQUINA: a resposta depende do que está INSTALADO nela. Fora do CI não por
# preguiça — por honestidade: lá eles sairiam "pulado" e engordariam o placar.
MAQUINA=(
  conversor.sh           # traça a partir de /usr/share/icons/Papirus; muda com a versão do pacote
  afinador.sh            # precisa de rsvg-convert e do `compare` do ImageMagick
  previa-cerca.sh        # painel numa casa de brinquedo; serve um.svg do Papirus da máquina
  app-navegador.py       # Playwright com Chromium, a página usada como ela usaria
  app-acessibilidade.py  # Playwright com Chromium; sobe o painel
  oficina.sh             # lê os .desktop da máquina: o desenho de pack que veste um deles tem cartão
  pastas-do-pack.sh      # parte do Papirus-Dark de /usr/share/icons e do papirus-folders baixado
  restos-do-painel.sh    # a ficha de ícone e a gaveta no vm do node, sem navegador; sem node, conta e pula
  folha-dos-resgatados.sh # acervo e raiz de brinquedo; pede rsvg-convert e o ImageMagick, sem eles pula
  app-completo.py        # Playwright com Chromium: TODA aba, TODO controle — o gate de merge
  app-uso-real.py
  app-texto-visivel.py
  gate-link-externo.py   # Playwright com Chromium: o «Créditos» do gate aguenta a repintura entre o censo e o clique
)

# Um gate que sai "pulado" quando falta o Playwright deixaria a suíte dizer "0
# vermelhos" sem ele ter rodado — e "pulado não é verde" é a regra deste
# arquivo desde o primeiro dia.
SEM_PULO=(
  app-completo.py
  app-uso-real.py
)

# ---------------------------------------------------------------------------
# Modo
# ---------------------------------------------------------------------------
MODO="tudo"
case "${1:-}" in
  ''|--tudo)   MODO="tudo" ;;
  --portatil)  MODO="portatil" ;;
  --maquina)   MODO="maquina" ;;
  -h|--ajuda|--help)
    # Escrito à mão, e não recortado do cabeçalho com `sed -n 'N,Mp'`: número
    # de linha dentro do próprio arquivo é a primeira coisa que envelhece.
    printf './tests/todos.sh              tudo, que é o que se roda na bancada dela\n'
    printf './tests/todos.sh --portatil   só o que roda em máquina sem COSMIC (o CI)\n'
    printf './tests/todos.sh --maquina    só o que exige a máquina dela\n'
    exit 0 ;;
  *) printf 'uso: %s [--tudo|--portatil|--maquina]\n' "$(basename "$0")" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# A guarda da lista: todo arquivo de teste tem de estar classificado
# ---------------------------------------------------------------------------
conhecido() {
  local alvo="$1" i
  for i in "${PORTATIL[@]}" "${MAQUINA[@]}"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

# Agora entra todo arquivo de `tests/` que seja EXECUTÁVEL (que é o que um teste
# é aqui) ou que tenha as duas extensões de sempre.
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

# ---------------------------------------------------------------------------
# A corrida
# ---------------------------------------------------------------------------
case "$MODO" in
  tudo)     ALVOS=("${PORTATIL[@]}" "${MAQUINA[@]}"); QUAL="todos os $(( ${#PORTATIL[@]} + ${#MAQUINA[@]} ))" ;;
  portatil) ALVOS=("${PORTATIL[@]}");                 QUAL="os ${#PORTATIL[@]} portáteis (sem COSMIC, sem Papirus, sem navegador)" ;;
  maquina)  ALVOS=("${MAQUINA[@]}");                  QUAL="os ${#MAQUINA[@]} que exigem a máquina dela" ;;
esac

printf '== suíte MeowSystem: %s ==\n' "$QUAL"

# Os dois testes de navegador são `#!/usr/bin/env python3`, e o `env` pega o
# PRIMEIRO python3 do PATH.
#
# O primeiro que responder roda os `.py`.
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
  # A tela diz qual interpretador rodou os `.py`, pelo mesmo motivo de dizer
  # qual subconjunto: um "ok" que não diz com quê não se reproduz.
  printf 'python dos testes de navegador: %s\n' \
         "${PY_NAVEGADOR:-nenhum python3 com Playwright nesta máquina}"
fi
printf '\n'

# Com `NOPASSWD: ALL` na máquina, um teste que chama `sudo` não falha: ESCREVE
# em /usr e em /etc.
#
# Cada teste se protegia por conta própria (o `doctor-so-le.sh`, o
# `previa-cerca.sh`), e um que esquecesse escrevia no sistema de verdade — já
# custou restauração à mão duas vezes.
#
# Agora a proteção é do runner, e vale para todo teste, inclusive o que for
# escrito amanhã: `sudo`, `pkexec` e `su` no começo do PATH registram a chamada
# e recusam, e o HOME de todos é uma casa de brinquedo.
CASA_REAL="$HOME"
# A casa de verdade fica dita, só para leitura, a quem precisa PERGUNTAR algo
# dela (o `doctor-so-le.sh` confere que o reciclo acha o painel da sessão).
export SUITE_CASA_REAL="$CASA_REAL"
SUITE_TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
trap 'rm -rf "$SUITE_TMP"' EXIT
# O sinal vira saída, para o EXIT de cima rodar: o bash morto por TERM ou INT
# sem tratador não roda o EXIT, e a casa de brinquedo ficava em /tmp.
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$SUITE_TMP/falso" "$SUITE_TMP/casa" || exit 2
export SUITE_SUDO_LOG="$SUITE_TMP/sudo.log"; : > "$SUITE_SUDO_LOG"
for c in sudo pkexec su; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*" >> "$SUITE_SUDO_LOG"\nexit 1\n' \
    > "$SUITE_TMP/falso/$c"
  chmod 755 "$SUITE_TMP/falso/$c"
done

# O RESTO DO ENVOLTÓRIO, QUE MORAVA FORA DAQUI
export SUITE_FALSOS_LOG="$SUITE_TMP/falsos.log"; : > "$SUITE_FALSOS_LOG"
for c in pkill killall notify-send systemd-run loginctl apt apt-get xdg-open; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*" >> "$SUITE_FALSOS_LOG"\nexit 1\n' \
    > "$SUITE_TMP/falso/$c"
  chmod 755 "$SUITE_TMP/falso/$c"
done
# O verbo que só lê, de cada um. O primeiro argumento que não começa com `-` é
# o verbo; sem verbo nenhum (`systemctl --version`) também é leitura.
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
# O instalador numa casa de brinquedo pedia ao flatpak de verdade o OnlyOffice
# do Flathub (centenas de MB por rodada). Só a leitura passa, e o override
# do usuário, que cai na casa de brinquedo.
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

  # `pulado` no começo de uma linha é o idioma da casa para "não dava para
  # conferir aqui". O rc=3 é o mesmo em número (regra 7 do contrato).
  #
  # Um runner que esconde vermelho atrás de um pulado é o defeito que este
  # arquivo veio matar, com o crachá de quem veio consertá-lo.
  disse_pulado=0
  [[ $saida == pulado* || $saida == *$'\n'pulado* ]] && disse_pulado=1
  disse_falhou=0
  [[ $saida == *FALHOU* ]] && disse_falhou=1

  sem_pulo=0
  for i in "${SEM_PULO[@]}"; do [ "$i" = "$nome" ] && sem_pulo=1; done
  if [ "$sem_pulo" -eq 1 ] && [[ $nome == *.py ]] && [ -z "$PY_NAVEGADOR" ]; then
    # Sem python com Playwright o teste nem chega a subir o painel: é aqui que
    # a receita aparece, e não num "pulado" que o placar esconderia.
    estado="FALHOU"; VERMELHOS+=("$nome")
    # A receita vai em linhas com FALHOU porque é o que o filtro do vermelho,
    # lá embaixo, deixa passar: uma instrução que some da tela não instrui.
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

  # Quem falhou mostra o que disse. Quem passou não polui a tela: o placar
  # responde, e o detalhe de um teste verde ninguém lê.
  #
  # O `conversor.sh` imprime 48 linhas de `ok:` em volta de UMA de `FALHOU:`
  # — despejar as 48 esconde a única que interessa no meio do verde, que é a
  # forma mais boba de um log ilegível.
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

# ---------------------------------------------------------------------------
printf '\n== %s · %s verde(s), %s pulado(s), %s vermelho(s) ==\n' \
       "$QUAL" "$VERDES" "$PULADOS" "${#VERMELHOS[@]}"
# Quem tentou o sudo, e o que pediu: recusado e registrado, nunca executado.
if [ -s "$SUITE_SUDO_LOG" ]; then
  printf 'sudo/pkexec/su recusados durante a suíte: %s chamada(s)\n' "$(grep -c . "$SUITE_SUDO_LOG")"
  LC_ALL=C sort "$SUITE_SUDO_LOG" | uniq -c | sort -rn | head -10 | sed 's/^/    /'
else
  printf 'nenhum teste chamou sudo, pkexec ou su\n'
fi
# E os outros falsos, um por um: quantas vezes cada escrita foi parada.
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
