#!/usr/bin/env bash
# prompt.sh — o prompt do zsh, e a única etapa deste projeto que termina com um
# comando na mão DELA em vez de um arquivo no disco.
#
# POR QUE ESTA É A ETAPA PARTIDA AO MEIO
#   O prompt do zsh mora em `~/.config/zsh/env.zsh`, que é o repositório do
#   Ritual da Aurora — com auto-commit a cada 10 minutos. A TRAVA 1 do
#   `lib/comum.sh` recusa aquele caminho POR CAMINHO (`vizinhos.conf`), e está
#   certa: um arquivo largado ali vira commit no repositório PRIVADO dela sem
#   ninguém apertar nada.
#
#   Só que a configuração do starship NÃO mora lá. Ela mora em
#   `~/.config/starship.toml`, que é um caminho comum do XDG e não pertence a
#   vizinho nenhum — medido: `meow_destino_permitido` o aceita. Então a sprint se
#   parte exatamente onde a fronteira parte:
#
#     NOSSO   ~/.config/starship.toml   -> este script instala e confere
#     DELA    ~/.config/zsh/env.zsh     -> sai como `assets/prompt/aurora.patch`
#
#   Isso não é meio-trabalho: é a única divisão que não mente. Um script que
#   escrevesse as duas metades atravessaria a fronteira; um que não escrevesse
#   nenhuma deixaria na mão dela um arquivo de 260 linhas para copiar.
#
# A OUTRA METADE SAIU DAQUI EM 24/09/2026 (P39), E O PARÁGRAFO ACIMA É HISTÓRIA
#   A regra do dono, de 23/09: o que o MeowSystem lê do Spellbook migra para cá
#   ou sai daqui, sem "integração opcional" que continue lendo o
#   `~/.config/zsh` quando ele existe. Este arquivo lia o `env.zsh` de lá três
#   vezes (o `starship init`, o `ZSH_THEME` e o `FZF_DEFAULT_OPTS`) e mandava
#   aplicar nele o `assets/prompt/aurora.patch`, que carregava até o nome de
#   quem o gerou. O que era do produto já morava aqui — o `starship.toml`. O
#   resto era a máquina de uma pessoa: saiu, o patch junto.
#
#   A LINHA QUE LIGA O STARSHIP É DE QUEM USA, e este arquivo só a DIZ, no
#   `aplicar` e no `mostrar`. Ele não a procura: numa máquina qualquer não há
#   `env.zsh`, e ler o `.zshrc` de alguém seria adivinhar uma cadeia de
#   `source` — nesta casa mesmo, o `.zshrc` não tem a linha, quem a tem é um
#   arquivo que ele carrega. Um conferidor que adivinha acusa errado. O 4
#   ("falta a metade dela") saiu com a leitura: o doctor passa a conferir o que
#   é nosso, e o que é nosso é o arquivo e o binário.
#
# O QUE FOI MEDIDO ANTES DE ESCREVER ISTO (25/08/2026)
#   - `starship` NÃO está no apt do Pop!_OS 24.04 (noble). `apt-cache policy
#     starship` devolve VAZIO e `apt-cache show starship` diz "Nenhum pacote
#     encontrado". O que existe no universe são as CAIXAS de Rust
#     (`librust-starship-module-config-derive-dev`), que são fonte para
#     compilar outra coisa, não o binário. Instala por script oficial ou cargo.
#   - O prompt em uso NÃO era o `agnoster`. O `ZSH_THEME="agnoster"` da linha 9
#     era carregado pelo oh-my-zsh e SOBRESCRITO pelo `export PS1` da linha 135
#     do mesmo arquivo. Medido no shell vivo:
#       zsh -i -c 'print -r -- $PROMPT'
#     devolve o PS1 de fundo azul, nunca um segmento do agnoster.
#   - A Nerd Font dela é `JetBrainsMono Nerd Font Mono`, instalada pelo
#     `scripts/instalar_fontes.sh` em ~/.local/share/fonts/MeowSystem, e é a
#     mesma que o `cosmic-term` usa (chave `font_name`). Os 44 codepoints
#     não-ASCII do nosso `starship.toml` existem nela — conferido com
#     `fc-query -f '%{charset}'`.
#
# POR QUE NÃO EXISTE `--reverter` QUE DESFAÇA TUDO
#   Aqui o "reverter" do MeowSystem é o oposto do caso do applet de mídia. Lá,
#   apagar a sombra devolvia o applet de fábrica e a dock voltava a funcionar.
#   Aqui, apagar só a NOSSA metade (o `starship.toml`) com o `env.zsh` ainda
#   chamando o starship não devolve o prompt antigo: devolve o prompt PADRÃO do
#   starship, que ninguém escolheu. Por isso `PROMPT_STARSHIP="nao"` no meow.conf quer
#   dizer "não mexo", e não "desfaz" — e o `remover` existe, mas avisa alto e é
#   comando de mão, nunca de timer.
#
# USO
#   prompt.sh conferir   0 = conforme · 1 = divergente (nosso) · 3 = falta
#                        dependência (o 4 saiu em 24/09/2026 — ver acima)
#   prompt.sh aplicar    instala ~/.config/starship.toml e diz a linha do shell
#   prompt.sh mostrar    imprime a linha que liga o starship no shell
#   prompt.sh remover    tira o NOSSO arquivo (leia o aviso acima antes)
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# A CHAVE NÃO SE CHAMA `PROMPT`, E O MOTIVO É MEDIDO
#   `PROMPT` é a variável do prompt no zsh. O meow.conf é sourceado por bash
#   (`bin/meow` e `install.sh` são os dois `#!/usr/bin/env bash`), onde o nome é
#   inofensivo — mas basta alguém dar um `. ~/.config/meow/meow.conf` num zsh
#   para inspecionar o arquivo e o prompt daquele terminal virar "sim". Um nome
#   com dois caracteres a mais custa menos que esse susto.
PROMPT_STARSHIP="${PROMPT_STARSHIP:-sim}"
PROMPT_FONTE="$MEOW_RAIZ/assets/prompt/starship.toml"
PROMPT_ALVO="${PROMPT_ALVO:-$HOME/.config/starship.toml}"
# O `PROMPT_ZDOT`, o `PROMPT_ENV` e o `PROMPT_PATCH` saíram em 24/09/2026 (P39):
# eram o `env.zsh` do Spellbook e o patch para ele. O padrão do `PROMPT_ZDOT`
# ainda dizia que `~/.config/zsh` é "a convenção" — não é: sem `ZDOTDIR`, o zsh
# lê do `$HOME`. Era a convenção de uma casa.

# A linha de instalação do starship, escrita uma vez só.
#
# ATÉ 22/09/2026 ELA NÃO ERA RODADA POR NINGUÉM — era impressa, e a pessoa que
# copiasse. A sprint P2 inverteu isso: quem a roda agora é o
# `cmd_instalar_starship`, aqui embaixo, e ela continua sendo UMA linha só para
# que o que a tela promete e o que o botão executa nunca possam divergir.
#
# O `--yes` entrou junto e é obrigatório: quem chama pelo painel não tem
# terminal, e um instalador que pergunta pendura o trabalho para sempre.
# O `--bin-dir` continua sendo o ponto todo — sem `sudo`, no diretório dela.
PROMPT_INSTALAR='curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"'
PROMPT_INSTALAR_ALT='cargo install starship --locked'

# --- as quatro perguntas, cada uma respondida por medição -------------------

# O STARSHIP É UM SÓ, E ELE NÃO DEPENDE DE QUEM PERGUNTA — 24/09/2026, sprint
# P54 (achado 48)
#   Medido no painel de verdade: a pendência «o prompt do terminal precisa do
#   starship» estava na Início com o starship JÁ instalado em ~/.cargo/bin, e o
#   «Resolver» respondia «o starship já está instalado». As duas pontas chamam
#   esta mesma função; o que mudava era o PATH de quem chamava. Quem cria a
#   pendência é o `aplicar`, e ele roda também pelo `meow-doctor.timer`, cujo
#   PATH é o do systemd de usuário (medido: `~/.local/bin` e os do sistema, e
#   nenhum `~/.cargo/bin`); o «Resolver» roda pelo painel, que herdou o PATH do
#   terminal que o abriu. A mesma pergunta, duas respostas.
#   A regra é a da P49 (`meow_app_instalado`): o programa está onde quer que
#   o jeito de instalá-lo o ponha, e não só onde o PATH de agora alcança — é o
#   `_kitty_instalado` com o `~/.local/kitty.app`. Aqui são dois lugares: o
#   `~/.local/bin`, que é onde o nosso «Instalar o starship» o põe, e o
#   `~/.cargo/bin`, que é onde o `cargo install starship` (a receita
#   alternativa, `PROMPT_INSTALAR_ALT`) o põe.
#   Imprime ONDE achou, porque o «já está instalado» diz o caminho: com o
#   `command -v` de antes, o starship que só o cargo conhece sairia com o
#   caminho vazio.
_prompt_onde_starship() {
  local lugar
  for lugar in "$(command -v starship 2>/dev/null)" \
               "$HOME/.local/bin/starship" "$HOME/.cargo/bin/starship"; do
    [ -n "$lugar" ] && [ -x "$lugar" ] && { printf '%s' "$lugar"; return 0; }
  done
  return 1
}
_prompt_tem_starship() { _prompt_onde_starship >/dev/null; }

# As três perguntas ao `env.zsh` (o `starship init`, o `ZSH_THEME` e o
# `FZF_DEFAULT_OPTS`) saíram daqui em 24/09/2026 — ver o cabeçalho.

# COMPARAÇÃO PELO CRITÉRIO DO ESCRITOR, NUNCA `cmp`
#   `meow_escrever` grava com `printf '%s'` e come o `\n` final do arquivo. Um
#   `cmp -s` entre a fonte (que termina em nova linha) e o destino (que não
#   termina) acusaria divergência para SEMPRE, num arquivo perfeito — é o mesmo
#   defeito que o `chk_mimetypes` do `bin/meow` já documenta. As duas
#   substituições de comando abaixo aparam a nova linha final dos dois lados.
# A PALETA DO PROMPT É A DO PACK NO AR — 09/10/2026, P74 item 7 (T1)
#   O preset traz uma paleta só, a `catppuccin_mocha`, e este script copiava o
#   arquivo como estava: com o Dracula no ar o `~/.config/starship.toml` dizia
#   `palette = 'catppuccin_mocha'`, e o prompt era o único pedaço da tela em
#   Catppuccin (01-regressoes.md, T1, ×5). O desenho do preset fala por PAPEL
#   (`bg:mauve`, `fg:crust`), então trocar o bloco `[palettes.*]` pelos 26
#   slots da paleta do pack, no flavor da máquina, veste o prompt inteiro sem
#   tocar no desenho. O nome da paleta é `<pack>_<flavor>`: com o Catppuccin
#   Mocha no ar ele é `catppuccin_mocha`, e o arquivo sai IGUAL ao preset,
#   byte a byte (os hex em minúsculas, como lá) — o `tests/pack-dracula-
#   completo.sh` cobra isso.
_PROMPT_PACK="$(meow_pack_dir)"
[ -n "$_PROMPT_PACK" ] || _PROMPT_PACK="$(meow_pack_padrao_dir 2>/dev/null || true)"
_PROMPT_PACK="$(basename "${_PROMPT_PACK:-catppuccin}")"

_prompt_desejado() {
  python3 -I - "$PROMPT_FONTE" "$(meow_paleta)" "$(meow_flavor)" "$_PROMPT_PACK" <<'PY'
import json, re, sys
fonte, paleta, flavor, pack = sys.argv[1:5]
with open(fonte, encoding="utf-8") as fh:
    texto = fh.read()
with open(paleta, encoding="utf-8") as fh:
    dados = json.load(fh)
cores = dados["flavors"][flavor]
nome = re.sub(r"[^a-z0-9_]", "_", f"{pack}_{flavor}".lower())
# A PALETA É DADO NÃO CONFIÁVEL, E O DESTINO É CÓDIGO — conferência da P74
#   (alerta de segurança de 09/10/2026). O `validar` confere o hex dos 26
#   slots e mais nada: um pack importado pode pôr na `ordem_canonica` um slot a
#   mais cujo valor fecha a aspa e abre um `[custom.x]` com `command = ...` —
#   e o starship roda esse comando a cada prompt. Só entra linha cujo nome é
#   uma palavra simples e cujo valor é `#RRGGBB`.
hexa = re.compile(r"^#[0-9A-Fa-f]{6}$")
bloco = f"[palettes.{nome}]\n" + "".join(
    f'{s} = "{cores[s].lower()}"\n' for s in (dados.get("ordem_canonica") or list(cores))
    if isinstance(s, str) and re.fullmatch(r"[a-z0-9]+", s)
    and isinstance(cores.get(s), str) and hexa.match(cores[s]))
texto = re.sub(r"^palette = '[^']*'$", f"palette = '{nome}'", texto, count=1, flags=re.M)
texto = re.sub(r'^\[palettes\.[^\]]+\]\n(?:[a-z0-9]+ = "#[0-9a-fA-F]{6}"\n)+', lambda _m: bloco,
               texto, count=1, flags=re.M)
sys.stdout.write(texto)
PY
}

_prompt_toml_confere() {
  [ -f "$PROMPT_ALVO" ] || return 1
  [ "$(_prompt_desejado)" = "$(cat "$PROMPT_ALVO")" ]
}

# O `_prompt_avisar_trava` saiu com o `env.zsh`, em 24/09/2026: ele perguntava
# se o `~/.config/zsh` estava no `vizinhos.conf`, que é a mesma adivinhação de
# vizinho que o `bin/meow` e o `install.sh` deixaram de fazer no mesmo dia.

# A RECUSA FICA GRAVADA, E ESSA É A METADE QUE FALTAVA — 22/09/2026, sprint P2
#   A regra da P2 é "ou faz, ou oferece um botão que faz". Mas instalar o
#   starship BAIXA DA INTERNET, e isso é escolha genuína — então a outra metade
#   da regra vale junto: a tela pergunta UMA vez. Sem este arquivo, um "não
#   quero" viraria a mesma pergunta amanhã, e a pendência que volta todo dia é
#   a notificação que a pessoa aprende a ignorar.
#
#   Mora no estado, e não no meow.conf, porque não é ajuste: é a resposta a uma
#   pergunta. Apagar o arquivo faz a pergunta voltar, que é o desfazer óbvio.
PROMPT_RECUSA="$MEOW_ESTADO/starship-recusado"

_prompt_dizer_falta_starship() {
  if [ -f "$PROMPT_RECUSA" ]; then
    # Nem pendência: ela já respondeu. O `meow_info` fica porque o código de
    # saída (3) precisa de um porquê na tela, e este é o porquê.
    #
    # E SEM O `!!` — conferência da P75, 09/10/2026. Desde a P75 o pulado que
    # avisa (`!!`) pesa no veredito do doctor (`pulado_com_aviso`, bin/meow), e
    # com o `meow_aviso` aqui o «não quero» dela virava «há divergências» todo
    # dia, e o auto-reparo das 5h terminava vermelho nomeando o `prompt`. A
    # recusa é escolha dela: a linha é a do pulado de rotina.
    meow_pula "o starship não está instalado, e você disse que não o quer"
    meow_info "  apague $PROMPT_RECUSA para reabrir a pergunta"
    return 0
  fi
  # O STARSHIP É OPCIONAL — 15/10/2026, P82 (item 2; decisão 14). Eram dois
  #   `meow_aviso`, e o `!!` pesa no veredito do doctor (`pulado_com_aviso`):
  #   com o PROMPT_STARSHIP de fábrica, a falta de um opcional deixava o
  #   auto-reparo vermelho todo dia. O doctor não o instala (baixar o que é
  #   opcional pede gesto, decisão 7); a pendência de baixo é o botão.
  meow_pula "o starship não está instalado — ele é opcional, e não vem no apt do Pop!_OS"
  # A RECEITA SAIU DA TELA E VIROU O VERBO ABAIXO. Ela continua existindo, em
  # `$PROMPT_INSTALAR`, mas agora como algo que este script EXECUTA — e não
  # como um parágrafo que manda a pessoa executar.
  MEOW_PENDENCIA_ROTINA=1 meow_pendencia_acionavel starship-ausente \
    "O prompt do terminal precisa do starship, e ele não vem no apt do Pop!_OS" \
    "./scripts/prompt.sh instalar-starship"
}

# A LINHA DO SHELL, DITA E NÃO ESCRITA. É a que a documentação do starship dá
# para cada shell, e é a única coisa que falta do lado de quem usa. O zsh vem
# primeiro porque é o shell que este projeto conhece; o bash, porque é o
# padrão do Pop!_OS.
_prompt_dizer_ligacao() {
  meow_info "para o prompt aparecer, o seu shell precisa iniciar o starship — é uma linha sua:"
  meow_info "  zsh  (no seu .zshrc):   eval \"\$(starship init zsh)\""
  meow_info "  bash (no seu .bashrc):  eval \"\$(starship init bash)\""
  meow_info "o MeowSystem não lê nem escreve arquivo de shell"
}

# --- conferir ---------------------------------------------------------------
# OS TRÊS CÓDIGOS
#   0 tudo no lugar · 1 o NOSSO arquivo divergiu (e o doctor conserta) · 3 falta
#   o starship, ou a etapa está desligada (nada a fazer).
#
#   ERAM QUATRO ATÉ 24/09/2026. O 4 era "o nosso lado está certo e o `env.zsh`
#   não foi patcheado", e existia para impedir o ping-pong de um conserto que
#   não alcança a linha do outro lado. A linha deixou de ser lida (ver o
#   cabeçalho), e com ela o 4 perdeu o que medir.
cmd_conferir() {
  if [ "$PROMPT_STARSHIP" != "sim" ]; then
    meow_pula "prompt desligado no meow.conf (PROMPT_STARSHIP=\"$PROMPT_STARSHIP\")"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$PROMPT_FONTE" ] || { meow_erro "falta $PROMPT_FONTE"; return "$MEOW_ERRO"; }

  local tem_ss=0 toml_ok=0
  _prompt_tem_starship      && tem_ss=1
  _prompt_toml_confere      && toml_ok=1

  if [ "$tem_ss" = "0" ]; then
    _prompt_dizer_falta_starship
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ "$toml_ok" = "0" ]; then
    [ -f "$PROMPT_ALVO" ] && meow_muda "$PROMPT_ALVO divergente do nosso preset" \
                          || meow_muda "$PROMPT_ALVO ausente"
    return "$MEOW_DIVERGENTE"
  fi

  meow_ok "prompt conforme (starship, na paleta do pack $_PROMPT_PACK, flavor $(meow_flavor))"
  return "$MEOW_OK"
}

# --- aplicar ----------------------------------------------------------------
# ESCREVE UM ARQUIVO SÓ, E ELE É NOSSO. A linha do shell sai como texto na tela.
cmd_aplicar() {
  if [ "$PROMPT_STARSHIP" != "sim" ]; then
    meow_pula "prompt desligado no meow.conf (PROMPT_STARSHIP=\"$PROMPT_STARSHIP\")"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$PROMPT_FONTE" ] || { meow_erro "falta $PROMPT_FONTE"; return "$MEOW_ERRO"; }

  # Sem o starship, escrever a configuração dele seria plantar um arquivo que
  # nada lê — e presumir uma instalação que é decisão dela. O 3 é honesto: a
  # etapa se pula, e o `install.sh` a mostra em "pulado" em vez de "mexeu".
  if ! _prompt_tem_starship; then
    _prompt_dizer_falta_starship
    meow_info "depois de instalar, rode de novo: meow doctor --consertar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local rc
  meow_escrever "$PROMPT_ALVO" "$(_prompt_desejado)" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui escrever $PROMPT_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_OK")   meow_ok "$PROMPT_ALVO já estava conforme" ;;
    *)  if meow_seco; then meow_muda "instalaria o preset em $PROMPT_ALVO"
        else meow_muda "prompt na paleta do pack $_PROMPT_PACK ($(meow_flavor)) instalado em $PROMPT_ALVO"
             meow_info "vale no PRÓXIMO prompt — o starship relê o arquivo a cada desenho"
        fi ;;
  esac

  # A linha do shell só é dita quando o arquivo acabou de mudar: é a hora em
  # que alguém está olhando para o prompt. Repeti-la a cada passagem do timer
  # seria o aviso que se aprende a ignorar.
  [ "$rc" = "$MEOW_DIVERGENTE" ] && ! meow_seco && _prompt_dizer_ligacao

  meow_registrar "prompt.sh aplicar rc=$rc"
  return "$rc"
}

# --- mostrar ----------------------------------------------------------------
cmd_mostrar() {
  meow_titulo "A linha que liga o starship — o MeowSystem NÃO a escreve"
  printf '\n'
  _prompt_dizer_ligacao
  meow_info "o preset que ela desenha é o nosso: $PROMPT_ALVO"
  return "$MEOW_OK"
}

# --- remover ----------------------------------------------------------------
# Não é o inverso do `aplicar`, e o aviso é a parte que importa: ver o cabeçalho.
cmd_remover() {
  if [ ! -f "$PROMPT_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  # Sem ler o shell de ninguém não dá para saber se a linha do starship ainda
  # está lá — então o aviso sai sempre, que é o lado seguro de errar.
  meow_aviso "se o seu shell ainda inicia o starship, tirar este arquivo não devolve"
  meow_aviso "  o prompt antigo — devolve o prompt PADRÃO do starship. Tire a linha antes."
  meow_seco && { meow_muda "removeria $PROMPT_ALVO"; return "$MEOW_DIVERGENTE"; }
  rm -f "$PROMPT_ALVO"
  meow_muda "removido $PROMPT_ALVO"
  meow_registrar "prompt.sh remover"
  return "$MEOW_DIVERGENTE"
}


# --- instalar-starship ------------------------------------------------------
# O CONSERTO QUE ERA UM PARÁGRAFO — 22/09/2026, sprint P2
#   Esta função é a receita que o `_prompt_dizer_falta_starship` imprimia,
#   virada ato. Ela não é esperteza nova: é a MESMA linha, lida da MESMA
#   variável (`PROMPT_INSTALAR`) que o cabeçalho deste arquivo já documentava
#   desde 25/08/2026 — só que agora quem a roda é o projeto.
#
#   BAIXA DA INTERNET, e isso é dito antes de baixar. É o rótulo que os cartões
#   de ação do painel já usam, e a pendência que leva a este verbo o herda.
#
#   SEM SUDO, E ISSO É O DESENHO: o instalador oficial aceita `--bin-dir`, e
#   `~/.local/bin` é da pessoa. Um conserto que pedisse root aqui não poderia
#   ser botão no painel, que roda sem terminal (ver docs/FRONTEIRA.md, a ponte).
cmd_instalar_starship() {
  if _prompt_tem_starship; then
    meow_ok "o starship já está instalado ($(_prompt_onde_starship))"
    meow_pendencia_resolvida starship-ausente
    return "$MEOW_OK"
  fi
  meow_tem curl || { meow_erro "falta o curl, e é ele que busca o instalador"; return "$MEOW_SEM_DEPENDENCIA"; }

  meow_info "BAIXA DA INTERNET: starship.rs, para ~/.local/bin (sem sudo)"
  if meow_seco; then
    meow_muda "instalaria o starship em ~/.local/bin"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$HOME/.local/bin" 2>/dev/null || true
  # `sh -c` SOBRE UMA CONSTANTE DESTE ARQUIVO, e não sobre entrada de ninguém:
  # é o que permite a linha existir uma vez só, dez linhas acima, em vez de uma
  # cópia aqui e outra na frase da tela — que foi como as receitas deste projeto
  # envelheceram até agora.
  if ! sh -c "$PROMPT_INSTALAR"; then
    meow_erro "o instalador do starship falhou (sem rede?)"
    meow_info "a alternativa, pelo cargo: $PROMPT_INSTALAR_ALT"
    return "$MEOW_ERRO"
  fi
  meow_muda "starship instalado em $HOME/.local/bin"
  meow_pendencia_resolvida starship-ausente
  meow_registrar "prompt.sh instalar-starship"
  meow_info "agora rode:  meow doctor --consertar  — é ele que escreve o preset"
  return "$MEOW_DIVERGENTE"
}

# --- nao-quero-starship -----------------------------------------------------
# A OUTRA RESPOSTA, e ela precisa existir para a pergunta ser uma pergunta.
cmd_recusar_starship() {
  meow_seco && { meow_muda "gravaria a recusa em $PROMPT_RECUSA"; return "$MEOW_DIVERGENTE"; }
  mkdir -p "$MEOW_ESTADO" 2>/dev/null || true
  cat > "$PROMPT_RECUSA" <<FIM
Você disse que não quer instalar o starship, em $(date '+%d/%m/%Y %H:%M:%S').

Enquanto este arquivo existir, o MeowSystem não volta a oferecer a instalação:
a etapa do prompt se pula, sem escrever nada, e o resto do tema segue igual.

Para reabrir a pergunta, apague este arquivo.
FIM
  meow_pendencia_resolvida starship-ausente
  meow_muda "recusa gravada — o starship não volta a ser oferecido"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)          cmd_aplicar ;;
  conferir)         cmd_conferir ;;
  mostrar|patch)    cmd_mostrar ;;
  remover)          cmd_remover ;;
  instalar-starship)  cmd_instalar_starship ;;
  nao-quero-starship) cmd_recusar_starship ;;
  # `onde-starship` IMPRIME ONDE O STARSHIP ESTÁ, e sai 1 se em lugar nenhum —
  # revisão da P54. Existe para o pré-voo do `install.sh` perguntar AQUI: com o
  # `meow_tem` dele, que só olha o PATH de agora, eram três donos do «tem
  # starship», e numa passagem com o PATH do systemd o pré-voo dizia «sem
  # starship» na mesma rodada em que esta etapa dizia «conforme».
  onde-starship)      _prompt_onde_starship ;;
  *) meow_erro "uso: prompt.sh {aplicar|conferir|mostrar|remover|instalar-starship|nao-quero-starship|onde-starship}"; exit "$MEOW_ERRO" ;;
esac
