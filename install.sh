#!/usr/bin/env bash
# install.sh — instala o MeowSystem inteiro. Sem flag nenhuma.
#
#   ./install.sh              faz tudo
#   MEOW_DRY_RUN=1 ./install.sh   mostra o que faria, sem escrever nada
#
# POR QUE NÃO TEM FLAG
#   A §5.1 do RELATORIO propunha 14 flags (--tema, --icones, --logo, --all...).
#   Está declarada histórica: quem decide o que instalar é o `meow.conf`, não a
#   linha de comando. Uma flag a menos é uma decisão a menos na hora de usar.
#   O `--dry-run` sobrevive como MEOW_DRY_RUN=1 — invisível no uso normal,
#   disponível para auditar antes de deixar rodar.
#
# FALHA POR UNIDADE, NUNCA GLOBAL (regra 8 do contrato)
#   Cada etapa é uma função que RETORNA código; nenhuma chama `exit`. Um app
#   ausente vira "pulado" e o resto continua. É por isso que este script NÃO usa
#   `set -e`: com ele, uma etapa que devolvesse != 0 abortaria tudo e deixaria a
#   máquina em estado parcial — que é pior do que não ter começado.
#
# O QUE ELE NUNCA FAZ
#   - `apt upgrade` / `dist-upgrade`, nem tocar em pacote `cosmic-*`. O
#     /usr/bin/cosmic-comp desta máquina está patchado DUAS vezes (workspace
#     vazio e night light) e uma versão nova mata os dois de uma vez, derrubando
#     os workspaces alfinetados Meow e OS.
#   - escrever em /usr/share, no repo Andromeda ou nos atalhos de teclado.
#     A trava está em lib/comum.sh e recusa por caminho, não por boa intenção.
#   - sudo perto de ~/.config: um arquivo de dono root ali faz a GUI de tema
#     falhar EM SILÊNCIO, e o sintoma só aparece dias depois.

MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

CONF_PADRAO="$MEOW_RAIZ/meow.conf.exemplo"
CONF="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"

declare -a FEITOS=() CONFEREM=() PULADOS=() FALHOS=()
PASSO=0
TOTAL=8

passo() { PASSO=$((PASSO+1)); meow_passo "[$PASSO/$TOTAL] $*"; }

# Registra o resultado de uma etapa sem deixar o código dela derrubar o script.
#
# `0` E `1` SÃO COISAS DIFERENTES, E JUNTÁ-LOS ERA UMA MENTIRA DE RELATÓRIO
#   A versão anterior punha os dois em FEITOS. O resultado: a SEGUNDA execução
#   — que não escreve um único byte, e o README promete isso — terminava
#   anunciando "feito: conf cli pacotes gerar tema modo ... " com as dezenove
#   etapas, como se tivesse refeito a instalação inteira. Quem lesse o resumo
#   não tinha como saber que nada mudou; a única prova era contar as linhas
#   `~~` na tela.
#
#   É o mesmo pecado que o `wallpaper.sh` já tinha corrigido no tempo verbal do
#   modo seco: dizer no passado uma coisa que não aconteceu. Aqui a separação é
#   o que torna a idempotência VISÍVEL em vez de prometida.
# O 4 É INFORMAÇÃO, NÃO FALHA — e esquecê-lo aqui já custou uma etapa "vermelha"
#   `4` = divergente por ESCOLHA DELA, sem conserto possível: hoje é a captura de
#   tema que ficou velha porque ela mexeu em Aparência, e o vidro cuja cor
#   derivada não corresponde mais ao slider. Sem esta linha, o instalador
#   anunciava `falhou: vidro` num sistema em que nada falhou — e sair 2 no fim
#   ainda faria a unidade do systemd marcar o serviço como falho todo dia.
concluir() {
  local nome="$1" rc="$2"
  case "$rc" in
    0) CONFEREM+=("$nome") ;;                     # já estava certo: nada escrito
    1) FEITOS+=("$nome") ;;                       # divergia e foi consertado
    3|4) PULADOS+=("$nome") ;;
    *) FALHOS+=("$nome") ;;
  esac
}

# ---------------------------------------------------------------------------
etapa_conf() {
  passo "Configuração"
  local fonte="$CONF"
  if [ -f "$CONF" ]; then
    meow_ok "meow.conf já existe em $CONF"
    # "Já existe" NÃO É "está completo" — ver scripts/migrar_conf.py. Chave nova
    # no exemplo jamais chegava a uma máquina que já tinha rodado o projeto, e o
    # recurso funcionava do mesmo jeito (todo script tem padrão), então nada
    # avisava. O sintoma era ela abrir o meow.conf para mexer numa coisa e não
    # achar a linha.
    if meow_tem python3; then
      local migrar=("$MEOW_RAIZ/scripts/migrar_conf.py" "$CONF" "$CONF_PADRAO")
      if meow_seco; then
        local pendente
        if pendente="$(python3 "${migrar[@]}" --conferir 2>/dev/null)"; then :; else
          meow_muda "$pendente"
        fi
      else
        local saida
        saida="$(python3 "${migrar[@]}" 2>&1)"
        case $? in
          0) [ -n "$saida" ] && meow_ok "$saida" ;;
          *) meow_aviso "não consegui conferir as chaves novas do meow.conf" ;;
        esac
      fi
    fi
  else
    local conteudo; conteudo="$(cat "$CONF_PADRAO")"
    meow_escrever "$CONF" "$conteudo" 644
    case $? in
      0) meow_ok "meow.conf criado em $CONF" ;;
      1) if meow_seco; then
           # No seco o arquivo NÃO foi criado — ler dele daria "arquivo
           # inexistente" e, pior, deixaria FLAVOR/ACCENT sem valor para as
           # etapas seguintes, que morreriam com "variável não associada".
           # O exemplo é a mesma coisa que seria escrita, então serve de fonte.
           meow_info "no seco, lendo os valores de meow.conf.exemplo"
           fonte="$CONF_PADRAO"
         else
           meow_ok "meow.conf criado em $CONF"
         fi ;;
      *) meow_erro "não consegui criar $CONF"; return "$MEOW_ERRO" ;;
    esac
  fi
  # shellcheck disable=SC1090
  . "$fonte" || { meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }
  for v in FLAVOR ACCENT MODO LOGO; do
    if [ -z "${!v:-}" ]; then
      meow_erro "$v não está definida em $fonte"
      return "$MEOW_ERRO"
    fi
  done
  meow_info "flavor=$FLAVOR accent=$ACCENT modo=$MODO logo=$LOGO"
  return 0
}

# ---------------------------------------------------------------------------
# A CLI E AS COMPLETIONS
#
# POR QUE ESTA ETAPA VEM LOGO DEPOIS DA CONFIGURAÇÃO
#   Se o apt falhar, se faltar o Papirus, se a captura do tema ainda não
#   existir — ela continua ficando com o `meow` na mão para descobrir o que
#   houve. Instalar a ferramenta de diagnóstico DEPOIS das etapas que podem
#   falhar é deixar quem mais precisa dela sem ela.
#
# O PONTEIRO DA RAIZ NÃO É ENFEITE
#   O `meow` instalado vive em `~/.local/bin/meow`, fora do repo, e não tem como
#   deduzir onde está o clone a partir do próprio caminho. O ponteiro em
#   `~/.local/state/meowsystem/raiz` é o que responde isso — para a CLI e para a
#   completion do zsh, que lê o mesmo arquivo para listar as capturas de tema.
#   Sem ele, `meow` só funcionaria com `MEOW_RAIZ=` na frente.
#
# ─────────────────────────────────────────────────────────────────────────────
# A COMPLETION É A ÚNICA ESCRITA DESTE PROJETO DENTRO DO REPO ANDROMEDA
# ─────────────────────────────────────────────────────────────────────────────
#   A TRAVA 1 do `lib/comum.sh` recusa qualquer escrita em `~/.config/zsh`, e com
#   razão: é o repo dela, com auto-commit a cada 10 minutos, e tema não tem nada
#   que fazer lá. Só que o `$fpath` desta máquina foi lido, não adivinhado
#   (`~/.config/zsh/.zcompdump`, linha `#omz fpath:`), e os ÚNICOS diretórios de
#   completion graváveis pelo usuário estão todos dentro de `~/.config/zsh` —
#   o que o `env.zsh` acrescenta na linha 20 e os do oh-my-zsh. Os de fora
#   (`/usr/local/share/zsh/site-functions`) pedem root e são território do
#   Ritual da Aurora.
#
#   Ou seja: ou a completion mora lá, ou ela não existe. Então esta função NÃO
#   usa `meow_escrever` — a trava continua intacta para todo o resto do projeto,
#   e a exceção fica visível em UM lugar só, com o mesmo cuidado atômico.
#   A consequência é dita em voz alta na tela quando o arquivo é gravado: ele vai
#   virar um commit no repositório privado dela. Quem não quiser, roda com
#   MEOW_SEM_COMPLETIONS=1 e perde só o TAB.
#
#   O arquivo leva `# OVERRIDE` na segunda linha: é o contrato do próprio
#   Andromeda (completions/CONVENCAO.md) para completion escrita à mão, e o
#   gerador de lá preserva quem tem esse marcador nas 3 primeiras linhas.
COMPLETIONS_DIR="${MEOW_COMPLETIONS_DIR:-$HOME/.config/zsh/completions}"

# Escrita atômica igual à da meow_escrever, sem a trava de território: o
# temporário nasce DENTRO do diretório de destino, porque o repo mora em
# /mnt/Apate e o destino em /home, e `mv` entre sistemas de arquivos não é
# atômico.
instalar_completion() {
  local origem="$MEOW_RAIZ/zsh/_meow" destino="$COMPLETIONS_DIR/_meow" tmp

  if [ "${MEOW_SEM_COMPLETIONS:-0}" = "1" ]; then
    meow_pula "completions do zsh puladas (MEOW_SEM_COMPLETIONS=1)"
    return "$MEOW_OK"
  fi
  [ -f "$origem" ] || { meow_erro "falta $origem"; return "$MEOW_ERRO"; }
  if [ ! -d "$COMPLETIONS_DIR" ]; then
    meow_pula "não achei $COMPLETIONS_DIR — sem lugar no \$fpath para a completion"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ -f "$destino" ] && cmp -s "$origem" "$destino"; then
    meow_ok "completion do zsh já instalada em $destino"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "instalaria a completion em $destino"
    return "$MEOW_DIVERGENTE"
  fi

  tmp="$(mktemp -p "$COMPLETIONS_DIR" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  if ! cat "$origem" > "$tmp"; then rm -f "$tmp"; return "$MEOW_ERRO"; fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

  meow_ok "completion do zsh instalada em $destino"
  # O aviso só sai quando o destino é MESMO o repo dela — com
  # MEOW_COMPLETIONS_DIR apontando para outro lugar (é assim que isto foi
  # testado) ele seria uma mentira.
  case "$(readlink -m -- "$destino")" in
    "$HOME/.config/zsh"/*)
      meow_aviso "esse arquivo está no repo Andromeda: o auto-commit dela vai versioná-lo" ;;
  esac
  meow_info "para não instalar: MEOW_SEM_COMPLETIONS=1 ./install.sh"
  meow_info "o TAB só passa a funcionar no próximo terminal (o compinit lê o fpath no início)"
  return "$MEOW_DIVERGENTE"
}

etapa_cli() {
  passo "CLI meow e completions"
  local mudou=0 rc

  # O `meow` é copiado, não linkado: um symlink para /mnt/Apate deixaria a CLI
  # inútil no dia em que o Ápate não montar — justamente o dia em que ela mais
  # precisaria de um `meow doctor` para entender o que houve. A cópia roda e diz
  # "não achei o repositório", que é uma resposta.
  meow_escrever "$HOME/.local/bin/meow" "$(cat "$MEOW_RAIZ/bin/meow")" 755
  rc=$?
  case "$rc" in
    0) meow_ok "~/.local/bin/meow já está atualizado" ;;
    1) mudou=1; meow_seco || meow_ok "~/.local/bin/meow instalado" ;;
    *) meow_erro "não consegui instalar ~/.local/bin/meow"; return "$MEOW_ERRO" ;;
  esac
  # A meow_escrever não corrige o modo de um arquivo cujo CONTEÚDO já confere —
  # ela sai antes de chegar no chmod. Um `meow` sem bit de execução seria um
  # "command not found" inexplicável, então o bit é reafirmado aqui.
  if ! meow_seco && [ -f "$HOME/.local/bin/meow" ] && [ ! -x "$HOME/.local/bin/meow" ]; then
    chmod 755 "$HOME/.local/bin/meow"
    mudou=1
  fi

  # O ponteiro da raiz, para a CLI e para a completion acharem o clone.
  meow_escrever "$MEOW_ESTADO/raiz" "$MEOW_RAIZ" 644
  rc=$?
  [ "$rc" -ge 2 ] && { meow_erro "não consegui gravar $MEOW_ESTADO/raiz"; return "$MEOW_ERRO"; }
  [ "$rc" = "1" ] && mudou=1

  # 3 AQUI É "NÃO HÁ ONDE PÔR", E ISSO NÃO É FALHA DESTA ETAPA
  #   A `instalar_completion` devolve 3 quando o diretório de completions não
  #   existe — numa máquina que não é esta, `~/.config/zsh/completions` pode
  #   simplesmente não estar lá. O `-ge 2` que estava aqui engolia esse 3 junto
  #   com o 2 e devolvia erro: MEDIDO num HOME de teste sem o diretório, o
  #   `install.sh` terminava com "falhou: cli" tendo instalado o `meow` inteiro
  #   e funcionando. O que se perde sem completion é o TAB, e o `meow_pula`
  #   acima já disse isso na tela. É o mesmo veredito que MEOW_SEM_COMPLETIONS=1
  #   já produzia — pular de um jeito não pode falhar e do outro não.
  instalar_completion
  rc=$?
  case "$rc" in
    1)   mudou=1 ;;
    0|3) ;;
    *)   return "$MEOW_ERRO" ;;
  esac

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) meow_aviso "~/.local/bin não está no \$PATH — o comando 'meow' não vai ser achado" ;;
  esac

  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return 0
}

# ---------------------------------------------------------------------------
# O ÚNICO BLOCO COM sudo DO INSTALADOR INTEIRO.
#
# POR QUE ELE VEM CEDO, E NÃO NO FIM
#   A recomendação instintiva seria deixar o apt por último, longe das escritas
#   de configuração. Aqui é o contrário, por dois motivos concretos:
#   1. O `papirus-icon-theme` é PRÉ-REQUISITO da etapa de pastas. Instalado
#      depois, a etapa de pastas já teria se pulado e só funcionaria na
#      execução seguinte — "rodei e não ficou pronto" é um péssimo primeiro uso.
#   2. Todo `apt` desta máquina dispara o hook do Ritual da Aurora, que roda o
#      self-heal COMPLETO e reconcilia configuração. Rodando o apt ANTES, esse
#      self-heal acontece antes das nossas escritas. Rodando depois, ele poderia
#      reverter o que acabamos de aplicar.
#
# O QUE ELE NUNCA FAZ
#   `upgrade`, `dist-upgrade`, `full-upgrade`, nem tocar em pacote `cosmic-*`.
#   O `/usr/bin/cosmic-comp` desta máquina está patchado duas vezes (workspace
#   vazio e night light) e uma versão nova mata os dois de uma vez, derrubando
#   junto os workspaces alfinetados. `install <pacote>` explícito e mais nada.
#
# FALTA DE sudo NÃO É ERRO
#   Devolve 3 e diz o comando exato. O resto do tema continua sendo aplicado —
#   ficam de fora só as pastas coloridas e os temas de `bat`/`btop`.
etapa_pacotes() {
  passo "Pacotes do sistema"

  # binário que testa presença -> pacote que o instala
  local -A NECESSARIOS=(
    [rsvg-convert]=librsvg2-bin
    [convert]=imagemagick
    [gtk-update-icon-cache]=libgtk-3-bin
    [python3]=python3
    [git]=git
    [btop]=btop
    # No Debian/Ubuntu o `bat` instala como `batcat`: o nome `bat` já pertence ao
    # bacula-console-qt. Testar por `bat` faria o instalador reinstalar o pacote
    # a cada execução, para sempre, sem nunca ficar satisfeito.
    [batcat]=bat
  )
  # O Papirus não tem binário — testa-se pelo diretório do tema.
  local faltam=()
  local b
  for b in "${!NECESSARIOS[@]}"; do
    meow_tem "$b" || faltam+=("${NECESSARIOS[$b]}")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || faltam+=(papirus-icon-theme)

  if [ ${#faltam[@]} -eq 0 ]; then
    meow_ok "todos os pacotes necessários já estão instalados"
    return 0
  fi

  meow_info "faltam: ${faltam[*]}"
  if meow_seco; then
    meow_muda "rodaria: sudo apt-get install -y --no-install-recommends ${faltam[*]}"
    return "$MEOW_DIVERGENTE"
  fi

  if ! meow_tem sudo; then
    meow_aviso "sudo não encontrado — instale à mão:"
    meow_info "  apt install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # Dizer em voz alta o que vai rodar como root, ANTES de rodar. Um instalador
  # que pede senha sem explicar o que vai fazer com ela não merece a senha.
  meow_info "vou rodar como root, e só isto:"
  printf '      sudo apt-get install -y --no-install-recommends %s\n' "${faltam[*]}"

  if ! sudo apt-get install -y --no-install-recommends "${faltam[@]}" >/dev/null 2>&1; then
    meow_aviso "a instalação falhou (sem sudo? sem rede?) — seguindo sem esses pacotes"
    meow_info "  sudo apt-get install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_ok "instalados: ${faltam[*]}"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
etapa_gerar() {
  passo "Gerar temas e ícones a partir da paleta"
  local rc=0
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" --conferir >/dev/null 2>&1 || rc=1
  python3 "$MEOW_RAIZ/scripts/gerar_gato.py" --conferir >/dev/null 2>&1 || rc=1
  if [ "$rc" = "0" ]; then
    meow_ok "temas e gatos já correspondem à paleta"
    return 0
  fi
  if meow_seco; then
    meow_muda "regeraria temas e gatos"
    return "$MEOW_DIVERGENTE"
  fi
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" | sed 's/^/  /' || return "$MEOW_ERRO"
  python3 "$MEOW_RAIZ/scripts/gerar_gato.py" --accent "$ACCENT" | sed 's/^/  /' || return "$MEOW_ERRO"
  meow_ok "regenerados a partir de palette/"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# O tema é a única coisa deste instalador que já precisou de um humano — uma vez.
# O COSMIC não deriva o tema aplicado a partir do que a GUI edita: MEDIDO em
# 04/08/2026, escrever em Dark.Builder/v1/accent não moveu Dark/v1/accent nem em
# 4s nem depois; o cosmic-settings-daemon estava vivo e não derivou. Quem deriva
# é o app gráfico. Então a captura tem de nascer de um import manual.
# Depois disso a captura vai para o git e QUALQUER máquina a recebe por cópia,
# com zero clique — é uma vez na vida do projeto, não uma vez por máquina.
etapa_tema() {
  passo "Tema"
  local alvo="${FLAVOR}-${ACCENT}"
  local captura="$MEOW_RAIZ/state/tema/$alvo"

  if [ ! -d "$captura" ]; then
    meow_aviso "ainda não há captura para '$alvo'"
    meow_info "importe themes/meowsystem-$alvo.ron uma vez em"
    meow_info "  Configurações > Área de trabalho > Aparência > Importar"
    meow_info "e depois rode: ./scripts/capturar_tema.sh $alvo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # `--respeitar-gui`: rodar o instalador de novo é MANUTENÇÃO, e manutenção não
  # desfaz o que ela ajustou em Aparência. Foi assim que o ajuste de vidro dela
  # das 17:59 de 05/08 morreu às 18:00:36. Ver a fronteira por árvore no
  # aplicar_tema.sh. Quem impõe a captura é o comando explícito (`meow tema X`).
  local rc
  MEOW_DRY_RUN=0 "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --respeitar-gui --conferir >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) meow_ok "tema '$alvo' já aplicado"; return 0 ;;
    4) meow_pula "tema '$alvo': a captura está velha — você mexeu em Aparência"
       meow_info "para fixar o que está na tela: meow tema capturar $alvo"
       return 0 ;;
  esac
  if meow_seco; then
    meow_muda "aplicaria o tema '$alvo'"
    return "$MEOW_DIVERGENTE"
  fi
  "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --respeitar-gui | sed 's/^/  /'
  rc="${PIPESTATUS[0]}"
  case "$rc" in 0|4) ;; *) return "$MEOW_ERRO" ;; esac
  meow_notificar "MeowSystem" "Tema $alvo aplicado."
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
etapa_modo() {
  passo "Modo claro/escuro"
  local arq="$HOME/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
  local desejado
  case "$MODO" in
    escuro) desejado=true ;;
    claro)  desejado=false ;;
    # Claro e escuro NÃO são dois temas: as capturas mocha-mauve e latte-mauve
    # diferem em exatamente UM arquivo, e é este `is_dark`. Então "auto" é só
    # escolher o valor pelo horário — sem reaplicar árvore e sem piscar a
    # interface. O que torna isso possível é cada captura já trazer as DUAS
    # árvores em Catppuccin; sem isso, virar o dia devolveria o tema claro de
    # fábrica.
    auto)
      local hora; hora="$(date +%-H)"
      local ini="${MODO_AUTO_CLARO_DE:-7}" fim="${MODO_AUTO_CLARO_ATE:-18}"
      if [ "$hora" -ge "$ini" ] && [ "$hora" -lt "$fim" ]; then
        desejado=false
      else
        desejado=true
      fi
      meow_info "modo automático: ${hora}h → $([ "$desejado" = true ] && echo escuro || echo claro)"
      ;;
    *)      meow_aviso "MODO='$MODO' desconhecido — esperado escuro|claro|auto"; return "$MEOW_ERRO" ;;
  esac
  meow_escrever "$arq" "$desejado" 644
  case $? in
    0) meow_ok "modo $MODO já ativo" ;;
    1) meow_ok "modo $MODO aplicado" ;;
    *) return "$MEOW_ERRO" ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Os dois gatos e o tema de ícones saem juntos: a logo do painel é caminho de
# arquivo e o botão do dock é tema de ícones, mas os dois vêm do mesmo SVG e
# reiniciam o mesmo processo. Separá-los custaria dois piscar de painel.
etapa_icones() {
  passo "Ícones e logo"
  FLAVOR="$FLAVOR" LOGO="$LOGO" ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_icones.sh"
  local rc=$?
  [ "$rc" = "1" ] && meow_notificar "MeowSystem" "Ícones e logo atualizados."
  return "$rc"
}

# As pastas coloridas vêm de terceiros (Papirus + catppuccin/papirus-folders) e
# pesam ~2 MB de SVG. Ficam numa etapa própria porque dependem de rede e do
# pacote do apt: sem qualquer um dos dois, o resto do tema continua de pé.
# A Nerd Font e o completar de icones vem depois do upstream: os dois dependem de
# rede e de terceiro pinado, e nenhum deles deixa outra etapa de pe ou não.
etapa_fontes() {
  passo "Fontes"
  "$MEOW_RAIZ/scripts/instalar_fontes.sh"
  return $?
}

# Os ícones que nenhum tema da cadeia cobre — incluindo os dois aplicativos dela,
# que não existem em tema nenhum do mundo e precisam de desenho autoral.
etapa_completar_icones() {
  passo "Ícones que faltavam"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/completar_icones.sh"
  return $?
}

# Os TIPOS DE ARQUIVO, vestidos pelo pack Catppuccin — o que o cosmic-files
# desenha ao abrir uma pasta. Etapa separada da anterior porque o alvo é outro
# (`mimetypes/`, não `apps/`) e a fonte é outra (o pack de terceiro, não desenho
# nosso). Vem DEPOIS do `etapa_icones`, que é quem escreve o `index.theme`: sem a
# declaração `scalable/mimetypes` lá, estes arquivos existiriam no disco e não
# seriam encontrados por ninguém.
# Os ícones do LANÇADOR, do acervo Catppuccin de aplicativo. Depois do
# `etapa_icones` pelo mesmo motivo da etapa irmã: quem declara `512x512/apps` no
# index.theme é aquele, e sem a declaração estes PNG não são achados por ninguém.
etapa_icones_apps() {
  passo "Ícones dos aplicativos"
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps.sh"
  return $?
}

etapa_mimetypes() {
  passo "Ícones de tipo de arquivo"
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_mimetypes.sh"
  return $?
}

# O SOM. O alcance inteiro desta etapa e UM arquivo -- o som de mudanca de volume,
# o unico que o COSMIC realmente toca (medido: `pw-play` aparece em 2 dos 41
# binarios cosmic-*, e canberra em nenhum). Fica em etapa propria porque nao
# depende de nada e nada depende dela.
# Os aplicativos que ela nunca vai abrir. Depende de sudo porque a unica coisa
# que funciona e marcar o arquivo do SISTEMA -- ver o cabecalho do script.
etapa_ocultar() {
  passo "Aplicativos ocultos do lançador"
  "$MEOW_RAIZ/scripts/ocultar_apps.sh"
  return $?
}

etapa_som() {
  passo "Som de evento"
  "$MEOW_RAIZ/scripts/som.sh" aplicar
  return $?
}

# O vidro fosco que continuava ao maximizar e se perdeu. Duas chaves, e o painel
# vigia os dois diretórios por inotify — então isto vale sem reiniciar nada.
etapa_vidro() {
  passo "Vidro ao maximizar"
  VIDRO_AO_MAXIMIZAR="${VIDRO_AO_MAXIMIZAR:-sim}" "$MEOW_RAIZ/scripts/vidro.sh"
  return $?
}

# O `index.theme` do hicolor DELA, que escondia os próprios ícones — entre eles
# as logos de dois jogos da Steam. Vem antes do `completar_icones` de propósito:
# é a base da cadeia, e completar ícone com a base quebrada é remendar por cima.
etapa_hicolor() {
  passo "Fim da cadeia de ícones (hicolor do usuário)"
  "$MEOW_RAIZ/scripts/hicolor.sh"
  return $?
}

# As capas dos jogos. Depende do `hicolor` acima: com o index.theme quebrado, os
# atalhos apareceriam sem ícone — e "apareceu sem ícone" é um sintoma pior que
# "não apareceu", porque parece que a arte do jogo se perdeu.
etapa_jogos() {
  passo "Jogos da Steam"
  "$MEOW_RAIZ/scripts/jogos_steam.sh"
  return $?
}

# A tela de LOGIN — a única superfície que continuava de fábrica. Depende de sudo
# e do tema já capturado, por isso vem depois de `etapa_tema`.
etapa_greeter() {
  passo "Tela de login"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/greeter.sh"
  return $?
}

etapa_upstream() {
  passo "Upstream de terceiros (commits pinados)"
  "$MEOW_RAIZ/scripts/baixar_upstream.sh"
  return $?
}

etapa_pastas() {
  passo "Pastas na cor do flavor"
  ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    ICONES_PASTAS="${ICONES_PASTAS:-cat-${FLAVOR}-${ACCENT}}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_pastas.sh"
  return $?
}

etapa_apps() {
  passo "Aplicativos"
  APPS_ATIVOS="${APPS_ATIVOS:-}" "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar
  return $?
}

# ---------------------------------------------------------------------------
# O AUTO-REPARO — UM TIMER DIÁRIO, E NENHUM HOOK DE APT
#
#   O Ritual da Aurora já roda o self-heal completo depois de todo apt
#   (/etc/apt/apt.conf.d/99-ritual-aurora-self-heal). Pendurar um segundo reparador
#   no mesmo evento colocaria dois programas mexendo em tema e ícone ao mesmo tempo,
#   com dois avisos capazes de se contradizer na tela dela. Decisão tomada: timer
#   diário e mais nada. O porquê completo está no cabeçalho de
#   systemd/meow-doctor.timer.
#
# AS UNIDADES VÃO POR CÓPIA, SEM SUBSTITUIÇÃO NENHUMA
#   Elas usam o especificador `%h` do systemd em vez do caminho literal do `$HOME`.
#   Assim o arquivo instalado é byte a byte igual ao do repositório, e o
#   `meow_escrever` consegue comparar por conteúdo — que é o que impede este passo
#   de reescrever e recarregar o systemd em toda execução.
#
# NÃO É UM LINK SIMBÓLICO PARA /mnt/Apate DE PROPÓSITO
#   O disco Ápate é um NVMe separado. Uma unidade do systemd apontando para lá
#   desapareceria da sessão no dia em que ele não montasse, e o erro apareceria como
#   "unidade não encontrada", sem dizer por quê. Cópia resolve; a divergência com o
#   repositório é reconciliada aqui, a cada `install.sh`.
etapa_autoreparo() {
  passo "Auto-reparo diário (systemd --user)"
  local origem="$MEOW_RAIZ/systemd"
  local destino="$HOME/.config/systemd/user"
  local estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

  # Desligar tem de DESLIGAR: só deixar de instalar manteria vivo o timer que uma
  # execução anterior já tinha ligado, e ela veria o reparo continuar acontecendo
  # depois de ter desligado a chave AUTO_REPARO no meow.conf.
  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if [ -f "$destino/meow-doctor.timer" ]; then
      if meow_seco; then
        meow_muda "removeria o timer (AUTO_REPARO=\"${AUTO_REPARO:-}\")"
        return "$MEOW_DIVERGENTE"
      fi
      systemctl --user disable --now meow-doctor.timer >/dev/null 2>&1
      rm -f "$destino/meow-doctor.timer" "$destino/meow-doctor.service"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"$AUTO_REPARO\" — timer desligado e removido"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" no meow.conf — sem reparo automático"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o auto-reparo fica de fora"
    meow_info "  rode 'meow doctor --consertar' na mão quando quiser"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # O diretório do log tem de existir ANTES de o systemd abrir o
  # `StandardOutput=append:` — MEDIDO em 2026-08-04: o append: é montado antes de
  # qualquer comando do serviço e antes até do `StateDirectory=`, e sem o diretório
  # a unidade morre com "Failed to set up standard output". Este mkdir é o que
  # garante o primeiro disparo numa máquina recém-instalada.
  if ! meow_seco && ! mkdir -p "$estado"; then
    meow_erro "não consegui criar $estado (é lá que fica o log do auto-reparo)"
    return "$MEOW_ERRO"
  fi

  local mudou=0 u
  for u in meow-doctor.service meow-doctor.timer; do
    if [ ! -f "$origem/$u" ]; then
      meow_erro "falta $origem/$u — repositório incompleto"
      return "$MEOW_ERRO"
    fi
    meow_escrever "$destino/$u" "$(cat "$origem/$u")" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;;
    esac
  done

  if meow_seco; then
    [ "$mudou" = "1" ] && meow_muda "instalaria as unidades e ligaria meow-doctor.timer"
    [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
    meow_ok "auto-reparo já instalado"
    return 0
  fi

  [ "$mudou" = "1" ] && systemctl --user daemon-reload

  # Ligar só quando precisa. Um `enable --now` incondicional reescreveria o link em
  # timers.target.wants e reiniciaria o timer a cada execução — o que zera a conta
  # do `Persistent=` e faz o reparo disparar de novo sem motivo.
  if [ "$(systemctl --user is-enabled meow-doctor.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-doctor.timer 2>/dev/null)" != "active" ]; then
    if ! systemctl --user enable --now meow-doctor.timer >/dev/null 2>&1; then
      meow_erro "não consegui ligar o meow-doctor.timer"
      return "$MEOW_ERRO"
    fi
    mudou=1
  fi

  # Aviso honesto, não falha: as unidades ficam instaladas e o timer ligado, mas
  # cada disparo será PULADO pelo `ConditionFileIsExecutable=` até o `meow` existir.
  if [ ! -x "$HOME/.local/bin/meow" ]; then
    meow_aviso "o timer está ligado, mas ~/.local/bin/meow ainda não existe"
    meow_info "  até ele aparecer, cada disparo é pulado (o journal diz o caminho)"
  fi

  if [ "$mudou" = "0" ]; then
    meow_ok "auto-reparo já ligado (todo dia às 5h, com até 20min de folga)"
    return 0
  fi
  meow_ok "auto-reparo ligado: todo dia às 5h, log em $estado/doctor.log"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# A LOGO E A ROTAÇÃO DE GATOS
#
# A INSTALAÇÃO DO ACERVO É INCONDICIONAL; SÓ O TIMER OBEDECE À CHAVE
#   Os gatos vão para o disco mesmo com LOGO_ROTACAO="nao" — sem isso,
#   `meow logo girar` na mão não teria para onde apontar, e ligar a rotação
#   depois exigiria uma rodada extra do instalador antes de funcionar.
#   O que a chave liga e desliga é o RELÓGIO, não o acervo.
etapa_logo() {
  passo "Gatos do painel"
  local destino="$HOME/.config/systemd/user" mudou=0 rc

  FLAVOR="$FLAVOR" LOGO="$LOGO" "$MEOW_RAIZ/scripts/logo.sh"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$rc"

  # Desligar tem de DESLIGAR (mesma disciplina do auto-reparo): deixar de
  # instalar manteria vivo o timer que uma execução anterior ligou, e ela veria
  # o gato continuar trocando depois de ter desligado a chave.
  if [ "${LOGO_ROTACAO:-nao}" != "sim" ]; then
    if [ -f "$destino/meow-logo.timer" ]; then
      meow_seco && { meow_muda "removeria o timer da rotação"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-logo.timer >/dev/null 2>&1
      rm -f "$destino/meow-logo.timer" "$destino/meow-logo.service"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "LOGO_ROTACAO=\"${LOGO_ROTACAO:-nao}\" — rotação desligada"
      return "$MEOW_DIVERGENTE"
    fi
    meow_info "rotação desligada (LOGO_ROTACAO=\"${LOGO_ROTACAO:-nao}\") — o acervo está no lugar"
    return "$([ "$mudou" = "1" ] && echo "$MEOW_DIVERGENTE" || echo 0)"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user aqui — a rotação fica de fora"
    meow_info "  troque na mão com 'meow logo girar'"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local u conteudo
  for u in meow-logo.service meow-logo.timer; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    # O intervalo é do meow.conf, não do arquivo da unidade: mudar a cadência
    # tem de ser editar UMA linha da conf, como tudo mais neste projeto.
    # UM GATO POR DIA, E NAO A CADA 5 MINUTOS
    # O cosmic-panel tem SEIS watches de inotify -- as tres configs de painel e
    # as tres de tema -- e NENHUM sobre arquivo de icone. Ele carrega o gato do
    # dock uma vez, ao iniciar a sessao, e nao rele. Girar mais rapido seriam
    # centenas de escritas por dia sem um pixel de diferenca na tela. O applet
    # Logo Menu resolveria ao vivo, mas ela recusou com razao: nasce AO LADO do
    # botao do dock, e ficariam dois gatos iguais na barra.
    [ "$u" = "meow-logo.timer" ] && conteudo="${conteudo//OnUnitActiveSec=30min/OnUnitActiveSec=${LOGO_INTERVALO:-1d}}"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  if meow_seco; then
    [ "$mudou" = "1" ] && { meow_muda "ligaria a rotação a cada ${LOGO_INTERVALO:-1d}"; return "$MEOW_DIVERGENTE"; }
    meow_ok "rotação de gatos já ligada"
    return 0
  fi

  [ "$mudou" = "1" ] && systemctl --user daemon-reload
  if [ "$(systemctl --user is-enabled meow-logo.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-logo.timer 2>/dev/null)" != "active" ]; then
    systemctl --user enable --now meow-logo.timer >/dev/null 2>&1 \
      || { meow_erro "não consegui ligar o meow-logo.timer"; return "$MEOW_ERRO"; }
    mudou=1
  fi

  [ "$mudou" = "0" ] && { meow_ok "rotação de gatos já ligada (a cada ${LOGO_INTERVALO:-30m})"; return 0; }
  meow_ok "os gatos giram a cada ${LOGO_INTERVALO:-30m} — 'meow logo listar' mostra o acervo"
  return "$MEOW_DIVERGENTE"
}

etapa_wallpaper() {
  passo "Papéis de parede"
  WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."
  return "$rc"
}

# ---------------------------------------------------------------------------
main() {
  meow_titulo "MeowSystem — Catppuccin para o COSMIC"
  meow_seco && meow_aviso "MEOW_DRY_RUN=1 — nada será escrito"

  meow_travar || return 2

  # O auto-reparo é o ÚLTIMO de propósito: ele só faz sentido depois que tudo já foi
  # aplicado uma vez. Ligado antes, o primeiro disparo pegaria a máquina no meio da
  # instalação e "consertaria" o que ainda estava sendo escrito.
  # A CLI vem em segundo, logo depois da configuração: se qualquer etapa daqui
  # para baixo falhar, ela fica com o `meow doctor` na mão para descobrir por quê.
  local etapas=(etapa_conf etapa_cli etapa_pacotes etapa_gerar etapa_tema
                etapa_modo etapa_greeter etapa_vidro etapa_upstream etapa_fontes
                etapa_icones etapa_pastas etapa_hicolor etapa_completar_icones
                etapa_mimetypes etapa_icones_apps etapa_jogos
                etapa_logo etapa_wallpaper etapa_ocultar etapa_som etapa_apps
                etapa_autoreparo)
  TOTAL=${#etapas[@]}

  for e in "${etapas[@]}"; do
    "$e"; local rc=$?
    concluir "${e#etapa_}" "$rc"
    # A configuração é a única etapa que não é opcional: sem FLAVOR e ACCENT as
    # seguintes não têm o que aplicar. Parar aqui é honesto; seguir seria morrer
    # com "variável não associada" três etapas adiante, escondendo a causa.
    if [ "$e" = "etapa_conf" ] && [ "$rc" -ge 2 ]; then
      meow_erro "sem configuração válida não há o que instalar — parando"
      break
    fi
  done

  meow_passo "Resultado"
  [ ${#FEITOS[@]}   -gt 0 ] && meow_muda  "mexeu:  ${FEITOS[*]}"
  [ ${#CONFEREM[@]} -gt 0 ] && meow_ok    "confere: ${CONFEREM[*]}"
  [ ${#PULADOS[@]}  -gt 0 ] && meow_pula  "pulado: ${PULADOS[*]}"
  [ ${#FALHOS[@]}   -gt 0 ] && meow_erro  "falhou: ${FALHOS[*]}"

  meow_registrar "install.sh mexeu=${#FEITOS[@]} conferem=${#CONFEREM[@]} pulados=${#PULADOS[@]} falhos=${#FALHOS[@]}"

  if [ ${#FALHOS[@]} -gt 0 ]; then
    printf '\n  %sAlgumas etapas falharam. Nada foi deixado pela metade —%s\n' "$C_AMARELO" "$C_ZERO"
    printf '  %scada etapa é independente, e o resto foi aplicado.%s\n\n' "$C_AMARELO" "$C_ZERO"
    return 2
  fi
  # A frase muda conforme o que de fato aconteceu. "Nada é escrito duas vezes" é
  # uma promessa; dizer que NENHUMA etapa mexeu em nada é a prova dela, na tela,
  # sem ela precisar contar linha nenhuma.
  if [ ${#FEITOS[@]} -eq 0 ]; then
    printf '\n  %sPronto.%s Nenhuma etapa precisou escrever nada — já estava tudo no lugar.\n\n' \
      "$C_VERDE$C_FORTE" "$C_ZERO"
  else
    printf '\n  %sPronto.%s Rode de novo quando quiser: nada é escrito duas vezes.\n\n' \
      "$C_VERDE$C_FORTE" "$C_ZERO"
  fi
  return 0
}

main "$@"
