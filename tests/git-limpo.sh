#!/usr/bin/env bash
# git-limpo.sh — usar o programa não pode sujar o repositório.
#
# POR QUE ESTE ARQUIVO NASCEU EM 21/09/2026
#   Uma auditoria do git daquele dia achou a coisa mais cara que um "produto
#   para qualquer um" pode ter: o painel gravava DENTRO do clone versionado.
#   A prova estava no `git status` dele, sem precisar de teoria nenhuma —
#
#       M assets/papeis-de-parede/BANIDOS.txt     +47 linhas
#       M assets/papeis-de-parede/lado.tsv         -3 linhas
#
#   Ele tinha clicado em "Tirar" e em "Dia"/"Noite" às 17h09 e 17h10. Ninguém
#   programou nada. USAR O PRODUTO ERA UM COMMIT PENDENTE.
#
#   E já doía em DUAS PESSOAS REAIS: são três remotos entre as duas máquinas
#   (`origin`, `fork` e um caminho local), dois desktops, dois carrosséis de
#   papel de parede. Cada `git pull` entre elas era conflito de merge num
#   arquivo que nenhuma das duas editou de propósito. O `merge=ours` do
#   `.gitattributes` prometia cobrir isso e era INERTE em qualquer clone novo:
#   a declaração estava versionada, o driver só existia no `.git/config` dele.
#
# A ÚNICA CONFERÊNCIA QUE PEGA A PRÓXIMA OCORRÊNCIA
#   Consertar as sete escritas de hoje não impede a oitava. O que impede é uma
#   pergunta que a suíte faça toda vez: EXECUTAR UMA AÇÃO DE CURADORIA MUDA O
#   `git status`? Enquanto a resposta for não, o produto pode ser usado por
#   quem clonou sem virar um repositório sujo.
#
# COMO ELE MEDE, E POR QUE NÃO TOCA EM NADA DELA
#   O acervo de papel de parede, o HOME e o diretório de estado são TODOS de
#   brinquedo, criados em `mktemp -d` e apagados no fim. O que é de verdade é o
#   REPOSITÓRIO — tem de ser, porque é justamente nele que a sujeira apareceria.
#
#   A comparação é por DELTA e não por "o git status está vazio": na bancada
#   dela quase sempre há trabalho em curso, e um teste que só passa com a árvore
#   limpa é um teste que ninguém consegue rodar. O que este arquivo cobra é que
#   a lista de antes e a de depois sejam IGUAIS.
#
# ELE NÃO CONSERTA O QUE ACHAR, e isso é decisão e não preguiça: desfazer
# mudança em árvore de trabalho alheia é a forma mais rápida de apagar duas
# horas de alguém. Quando falha, ele NOMEIA os caminhos e para.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = passou · 1 = falhou · 2 = erro deste teste.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'pulado: %s não é um clone git\n' "$RAIZ"; exit 0; }

# O `-uno` DEIXA O NÃO RASTREADO DE FORA, e de propósito: a pasta de trabalho
# dela tem rascunho, e um arquivo novo que o teste não criou não é sujeira
# NOSSA. O que este teste persegue é o arquivo VERSIONADO que muda sozinho — e,
# para o arquivo que acabou de sair do git, é a regra do `.gitignore` que o
# segura, conferida logo abaixo pelo `check-ignore`.
estado_git() { git -C "$RAIZ" status --porcelain -uno | LC_ALL=C sort; }

TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
limpar() { rm -rf "$TMP"; }
trap limpar EXIT

printf '\n--- 1/4 uma ação de curadoria não pode mudar o git status ---\n'

ANTES="$TMP/antes"; DEPOIS="$TMP/depois"
estado_git > "$ANTES"

# O acervo de brinquedo. Duas imagens porque são dois gestos diferentes: uma
# para banir (que sai de `ativos/`) e outra para escolher o lado (que precisa
# CONTINUAR em `ativos/` para o comando aceitar).
ACERVO="$TMP/acervo"
mkdir -p "$ACERVO/ativos" || exit 2
printf 'não e uma imagem de verdade, e não precisa ser\n' > "$ACERVO/ativos/teste-banir.jpg"
printf 'não e uma imagem de verdade, e não precisa ser\n' > "$ACERVO/ativos/teste-lado.jpg"

# `env -i` não: o script precisa de PATH e de um bash utilizável. O que se troca
# é só o que decide ONDE ele escreve — e `MEOW_IGNORA_DESKTOP=1` é o mesmo
# acordo que o `reversao.sh` e o `convergencia.sh` já usam para não mexer na
# sessão gráfica de quem roda a suíte.
rodar_curadoria() {
  HOME="$TMP/home" \
  XDG_STATE_HOME="$TMP/home/.local/state" \
  MEOW_ESTADO="$TMP/estado" \
  MEOW_IGNORA_DESKTOP=1 \
  WALLPAPER_BASE="$ACERVO" \
    "$RAIZ/scripts/wallpaper.sh" "$@"
}
mkdir -p "$TMP/home" || exit 2

rodar_curadoria banir "$ACERVO/ativos/teste-banir.jpg" >"$TMP/log-banir" 2>&1
rodar_curadoria lado  "teste-lado.jpg" noite           >"$TMP/log-lado"  2>&1

# A PROVA POSITIVA VEM ANTES DA NEGATIVA, e sem ela este teste seria uma
# fraude cara: um `wallpaper.sh` que saísse com erro na primeira linha também
# deixaria o `git status` intacto, e o teste diria verde para um programa que
# não faz nada. Primeiro se confere que a curadoria ACONTECEU; depois, onde.
BANIDOS_ESTADO="$TMP/estado/papeis-de-parede/BANIDOS.txt"
LADO_ESTADO="$TMP/estado/papeis-de-parede/lado.tsv"

if [ -f "$BANIDOS_ESTADO" ] && grep -qxF 'teste-banir.jpg' "$BANIDOS_ESTADO"; then
  ok "o banimento foi registrado em \$MEOW_ESTADO/papeis-de-parede/BANIDOS.txt"
else
  falha "o banimento NÃO chegou em $BANIDOS_ESTADO"
  printf '       log: %s\n' "$(tail -3 "$TMP/log-banir" 2>/dev/null | tr '\n' ' ')" >&2
fi

if [ -f "$LADO_ESTADO" ] && grep -q 'teste-lado.jpg' "$LADO_ESTADO"; then
  ok "o lado escolhido foi registrado em \$MEOW_ESTADO/papeis-de-parede/lado.tsv"
else
  falha "o lado escolhido NÃO chegou em $LADO_ESTADO"
  printf '       log: %s\n' "$(tail -3 "$TMP/log-lado" 2>/dev/null | tr '\n' ' ')" >&2
fi

# A SEMENTE TAMBÉM É COBRADA: sem ela o arquivo de estado nasceria só com a
# linha que o teste acabou de acrescentar, e a curadoria de fábrica — as 231
# imagens que ela tirou em 24/08/2026 — voltaria no primeiro `semear` de uma
# máquina nova. É o `.padrao` cumprindo o papel que o arquivo versionado tinha.
if [ -f "$BANIDOS_ESTADO" ] && grep -qxF 'cat-dithered-barn.png' "$BANIDOS_ESTADO"; then
  ok "o estado foi semeado do BANIDOS.txt.padrao versionado"
else
  falha "o estado NÃO trouxe a lista de fábrica do BANIDOS.txt.padrao"
fi

estado_git > "$DEPOIS"
if diff -u "$ANTES" "$DEPOIS" > "$TMP/diff" 2>&1; then
  ok "git status idêntico antes e depois da curadoria"
else
  falha "a curadoria MUDOU o git status do repositório:"
  sed 's/^/       /' "$TMP/diff" >&2
  printf '       este é o defeito que a P21 veio matar — o painel voltou a\n' >&2
  printf '       escrever dentro do clone. NADA foi desfeito: confira à mão.\n' >&2
fi

printf '\n--- 2/4 os dois arquivos de curadoria fora do índice ---\n'

# DOIS, E NÃO CINCO: este título dizia "os cinco arquivos" e conferia dois.
# Os três `.map` de ícone continuam versionados de propósito — a leitura deles
# atravessa doze arquivos que a P21 não autorizou a tocar, e movê-los pela
# metade deixaria clone novo sem ícone de aplicativo. O adiamento está declarado
# na mensagem do commit, e o bloco de PENDENTE lá embaixo o conta na tela toda
# vez, para a suíte nunca dizer mais do que mede.
for alvo in assets/papeis-de-parede/BANIDOS.txt assets/papeis-de-parede/lado.tsv; do
  if git -C "$RAIZ" ls-files --error-unmatch "$alvo" >/dev/null 2>&1; then
    falha "$alvo ainda está no índice do git"
  else
    ok "$alvo fora do índice"
  fi
  if git -C "$RAIZ" check-ignore -q "$alvo"; then
    ok "$alvo coberto pelo .gitignore (o cinto do 'git add -A' distraído)"
  else
    falha "$alvo NÃO está no .gitignore — um 'git add -A' o traz de volta"
  fi
  if [ -f "$RAIZ/$alvo.padrao" ]; then
    ok "$alvo.padrao versionado (a receita de fábrica sobreviveu)"
  else
    falha "falta $alvo.padrao — clone novo perde a curadoria de fábrica"
  fi
done

printf '\n--- 3/4 o .gitignore barra o que ele promete barrar ---\n'

# CONFERIDO COM A FERRAMENTA, E NÃO POR LEITURA — e a diferenca custou caro.
# Até 21/09/2026 as linhas diziam `assets/fontes/locais/*.otf`, e o LEIA-ME
# versionado morava em `assets/fontes/fonts/locais/`; a regra foi mudada para a
# pasta do LEIA-ME, e o instalador seguiu lendo a outra. Eram duas pastas, e
# este teste registrava a divergência em vez de medi-la.
#
# A PASTA CERCADA É A QUE O INSTALADOR LÊ — 24/09/2026, sprint P40
#   A decisão de 23/09 ficou com `assets/fontes/locais/`, a do leitor. O
#   caminho sai do `ACERVO_LOCAL` do `scripts/instalar_fontes.sh`, e não de um
#   nome escrito aqui: se um dia o instalador mudar de pasta e a regra não, as
#   faces abaixo deixam de ser barradas e este bloco reprova, em vez de seguir
#   conferindo a pasta velha. O LEIA-ME tem de estar versionado NESSA pasta —
#   é o que diz a quem abre o acervo o que soltar ali.
ACERVO_FONTES="$(sed -n 's|^ACERVO_LOCAL="\$RAIZ/\(.*\)"$|\1|p' "$RAIZ/scripts/instalar_fontes.sh")"
if [ -z "$ACERVO_FONTES" ]; then
  falha "não achei o ACERVO_LOCAL no scripts/instalar_fontes.sh — a pasta de fontes não foi conferida"
else
  for face in teste.otf teste.ttf teste.ttc teste.OTF teste.TTF teste.TTC; do
    alvo="$ACERVO_FONTES/$face"
    if regra="$(git -C "$RAIZ" check-ignore -v "$alvo" 2>/dev/null)"; then
      ok "$alvo barrado por ${regra%%$'\t'*}"
    else
      falha "$alvo NÃO é barrado — binário de fonte com EULA própria entra no commit"
    fi
  done

  # O LEIA-ME TEM DE CONTINUAR ENTRANDO: a regra é por EXTENSÃO, e não por
  # diretório, exatamente para isso. Um `assets/fontes/locais/*` barraria as
  # fontes e quebraria a outra metade da decisão, calado.
  if git -C "$RAIZ" check-ignore -q "$ACERVO_FONTES/LEIA-ME.txt"; then
    falha "o LEIA-ME do acervo de fontes ficou de fora do git — a regra pegou demais"
  elif ! git -C "$RAIZ" ls-files --error-unmatch "$ACERVO_FONTES/LEIA-ME.txt" >/dev/null 2>&1; then
    falha "$ACERVO_FONTES/LEIA-ME.txt não está versionado — o acervo que o instalador lê ficou sem explicação"
  else
    ok "$ACERVO_FONTES/LEIA-ME.txt versionado, na pasta que o instalador lê"
  fi
fi

# ESCOLHER ÍCONE NO PAINEL NÃO SUJA O REPOSITÓRIO — 09/10/2026, P73 (I3)
#   A regressão I3: desde a P60 o «Usar este ícone» gravava no `apps.map` do
#   pack, e o do traço no `apps-arcticons.map` (com o glifo copiado para
#   `arcticons-apps/`). Medido no dev em 09/10: ` M packs/dracula/icones/
#   apps.map`, a linha do ghostwriter. O `tests/seletor-do-pack.sh` não via
#   porque roda numa CÓPIA da árvore; este roda as rotas de verdade contra o
#   repositório de verdade — é a prova que a spec da P73 pede —, com o HOME de
#   brinquedo, e escolhe três ícones de três jeitos: um desenho da biblioteca do
#   Dracula, um resgatado do motor e um glifo de traço. E roda o passo que a
#   ficha dispara depois (o do pack), que escreve no HOME de brinquedo.
printf '\n--- 3b escolher três ícones no painel não muda o git status ---\n'
ANTES_I="$TMP/antes-icones"; DEPOIS_I="$TMP/depois-icones"
estado_git > "$ANTES_I"
CASA_I="$TMP/casa-icones"
mkdir -p "$CASA_I/.config/meow" "$CASA_I/.local/share/applications" "$CASA_I/.local/state/meowsystem" \
  || exit 2
cp "$RAIZ/meow.conf.exemplo" "$CASA_I/.config/meow/meow.conf" || exit 2
printf '\nPACK="dracula"\nFLAVOR="dracula"\nICONES_DRACULA="sim"\n' >> "$CASA_I/.config/meow/meow.conf"
for par in "um-navegador:Um Navegador" "um-chat:Um Chat" "um-editor:Um Editor"; do
  printf '[Desktop Entry]\nName=%s\nExec=true\nIcon=%s\nType=Application\n' "${par#*:}" "${par%%:*}" \
    > "$CASA_I/.local/share/applications/${par%%:*}.desktop"
done
env -u MEOW_PACK_DIR -u PACK -u FLAVOR -u ICONES_DRACULA -u MEOW_ICONES_ESCOLHAS -u MEOW_ICONES_TRACO \
    HOME="$CASA_I" MEOW_CONF="$CASA_I/.config/meow/meow.conf" XDG_CONFIG_HOME="$CASA_I/.config" \
    XDG_DATA_HOME="$CASA_I/.local/share" XDG_STATE_HOME="$CASA_I/.local/state" \
    MEOW_ESTADO="$CASA_I/.local/state/meowsystem" PYTHONDONTWRITEBYTECODE=1 \
    python3 - "$RAIZ" "$CASA_I" <<'PY'
import os, subprocess, sys
raiz, casa = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402
M = servidor.Manipulador
M.DIRS_DESKTOP = ((os.path.join(casa, ".local", "share", "applications"), "pessoal"),)
m = M.__new__(M)
r = {}
m._json = lambda d, c=200: r.update(d=d, c=c)
falhou = 0
for corpo in ({"app": "um-navegador", "arquivo": "packs/dracula/icones/biblioteca/alien.svg"},
              {"app": "um-chat", "arquivo": "assets/icones/resgatados/discord.svg"},
              {"app": "um-editor", "arquivo": "assets/icones/arcticons-apps/firefox.svg",
               "glifo": "firefox", "cor": "mauve"}):
    r.clear()
    m._api_app_icone(corpo)
    if r.get("c") != 200:
        falhou = 1
        print("  NÃO  a escolha %r foi recusada: %r" % (corpo, r.get("d")), file=sys.stderr)
amb = dict(os.environ)
amb.update(servidor.conf_exportada() or {})
subprocess.run([os.path.join(raiz, "scripts", "icones_apps_dracula.sh"), "aplicar"], env=amb,
               capture_output=True, timeout=120)
sys.exit(falhou)
PY
[ "$?" = "0" ] || falha "o painel recusou uma das três escolhas de ícone"
estado_git > "$DEPOIS_I"
if cmp -s "$ANTES_I" "$DEPOIS_I"; then
  ok "três ícones escolhidos (biblioteca, resgatado, traço) e o git status é o mesmo"
else
  falha "escolher ícone no painel mudou o git status:"
  diff "$ANTES_I" "$DEPOIS_I" | sed 's/^/        /' >&2
fi
for arq in icones-escolhidos.map icones-traco.map; do
  [ -s "$CASA_I/.config/meow/$arq" ] && ok "a escolha foi para ~/.config/meow/$arq, no estado de quem usa" \
    || falha "~/.config/meow/$arq não recebeu a escolha"
done

# --- 3c o «Usar» da oficina grava no estado de quem usa — P82, item 5 --------
#   A oficina gravava `retoques/<app>.svg`, o construído e a linha
#   `<app>:mao:<cor>` dentro do clone (`assets/icones/`): usar o produto virava
#   arquivo por commitar (decisão 15). Agora os três vão para a casa: a linha
#   no `~/.config/meow/icones-convertidos.map`, o retoque e o construído em
#   `~/.local/share/meowsystem/`.
printf '\n--- 3c o «Usar» da oficina não muda o git status ---\n'
CASA_O="$TMP/casa-oficina"; ANTES_O="$TMP/antes-o"; DEPOIS_O="$TMP/depois-o"
# Com os não rastreados: o retoque nasce como arquivo novo.
estado_com_novos() { git -C "$RAIZ" status --porcelain --untracked-files=all | LC_ALL=C sort; }
mkdir -p "$CASA_O/.config/meow" "$CASA_O/.local/share/applications"
cp "$RAIZ/meow.conf.exemplo" "$CASA_O/.config/meow/meow.conf"
printf '[Desktop Entry]\nName=Um Desenho\nExec=true\nIcon=um-desenho\nType=Application\n' \
  > "$CASA_O/.local/share/applications/um-desenho.desktop"
estado_com_novos > "$ANTES_O"
env -u MEOW_PACK_DIR -u PACK -u FLAVOR -u MEOW_ICONES_TRACO -u MEOW_ICONES_CONVERTIDOS \
    HOME="$CASA_O" MEOW_CONF="$CASA_O/.config/meow/meow.conf" XDG_CONFIG_HOME="$CASA_O/.config" \
    XDG_DATA_HOME="$CASA_O/.local/share" XDG_STATE_HOME="$CASA_O/.local/state" \
    MEOW_ESTADO="$CASA_O/.local/state/meowsystem" PYTHONDONTWRITEBYTECODE=1 \
    python3 - "$RAIZ" "$CASA_O" <<'PY'
import os, sys
raiz, casa = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402
M = servidor.Manipulador
M.DIRS_DESKTOP = ((os.path.join(casa, ".local", "share", "applications"), "pessoal"),)
m = M.__new__(M)
r = {}
m._json = lambda d, c=200: r.update(d=d, c=c)
cor = (servidor._paleta_dados().get("ordem") or ["mauve"])[0]
svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" '
       'stroke="currentColor"><circle cx="24" cy="24" r="16"/></svg>')
m._api_app_desenho({"app": "um-desenho", "acao": "salvar", "svg": svg, "cor": cor, "fonte": "texto"})
if r.get("c") != 200:
    print("  NÃO  o salvar da oficina foi recusado: %r" % (r.get("d"),), file=sys.stderr)
    sys.exit(1)
PY
[ "$?" = "0" ] || falha "a oficina recusou salvar o desenho"
estado_com_novos > "$DEPOIS_O"
if cmp -s "$ANTES_O" "$DEPOIS_O"; then
  ok "salvar um desenho na oficina deixa o git status como estava"
else
  falha "salvar na oficina mudou o git status:"
  diff "$ANTES_O" "$DEPOIS_O" | sed 's/^/        /' >&2
fi
if grep -q '^um-desenho:mao:' "$CASA_O/.config/meow/icones-convertidos.map" 2>/dev/null \
   && [ -s "$CASA_O/.local/share/meowsystem/retoques/um-desenho.svg" ] \
   && [ -s "$CASA_O/.local/share/meowsystem/convertidos-apps/um-desenho.svg" ]; then
  ok "a linha, o retoque e o construído foram para o estado de quem usa"
else
  falha "a oficina não gravou no estado de quem usa (mapa, retoque e construído)"
fi
# E O CONSTRUTOR LÊ AS DUAS FONTES: sem o construído, o `construir_convertidos.sh`
# o refaz do retoque de quem usa, na casa, e o clone não muda.
rm -f "$CASA_O/.local/share/meowsystem/convertidos-apps/um-desenho.svg"
estado_com_novos > "$ANTES_O"
env -i PATH="$PATH" HOME="$CASA_O" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  MEOW_CONF="$CASA_O/.config/meow/meow.conf" XDG_DATA_HOME="$CASA_O/.local/share" \
  "$RAIZ/scripts/construir_convertidos.sh" --so-mao > /dev/null 2>&1
estado_com_novos > "$DEPOIS_O"
if [ -s "$CASA_O/.local/share/meowsystem/convertidos-apps/um-desenho.svg" ] && cmp -s "$ANTES_O" "$DEPOIS_O"; then
  ok "o construir_convertidos.sh refaz o desenho de quem usa na casa, e o clone não muda"
else
  falha "o construir_convertidos.sh não leu o mapa de quem usa, ou escreveu no clone"
  diff "$ANTES_O" "$DEPOIS_O" | sed 's/^/        /' >&2
fi
# O que a versão de antes gravava no clone volta ao que era (o teste não deixa resto).
git -C "$RAIZ" checkout -q -- assets/icones/apps-convertidos.map 2>/dev/null
rm -f "$RAIZ/assets/icones/convertidos-apps/um-desenho.svg" "$RAIZ/assets/icones/convertidos-apps/retoques/um-desenho.svg"

# --- 4/4 o painel em uso, e o repositório INTEIRO — P75, 09/10/2026 --------
#   As seções 1 a 3 exercitam UM caminho de escrita: o `wallpaper.sh` (a 3b,
#   da P73, chama as rotas do painel direto, sem ele de pé). A
#   regra da P21 é sobre o produto inteiro, e o painel achou outra porta sem
#   que nada acusasse: o «Usar este ícone» com um desenho do pack gravava a
#   escolha no `packs/<id>/icones/apps.map` versionado (`171dedb`, 25/09), e o
#   `git status` do dev de 09/10 mostrava ` M packs/dracula/icones/apps.map`
#   (01-regressoes.md, I3). O `tests/seletor-do-pack.sh` cobra essa mesma
#   rota, mas numa CÓPIA da árvore — e a cópia nunca vê o `git status` daqui.
#
#   Aqui o painel sobe de verdade, sobre ESTE repositório, numa casa de
#   brinquedo com sudo falso, e recebe os gestos de quem usa: gravar uma
#   chave, escolher um desenho do pack para um aplicativo. A régua é o
#   `git status` do repositório inteiro, versionado E não rastreado, antes e
#   depois.
#
#   E O QUE O TESTE SUJOU, ELE DEVOLVE. O "não conserta o que achar" do
#   cabeçalho é sobre o trabalho de quem roda; aqui a sujeira é do próprio
#   teste, e deixá-la seria o teste fazendo o defeito que veio pegar. Só volta
#   o que estava limpo antes (`git checkout` do HEAD, que era o conteúdo de
#   antes) e o arquivo não rastreado que nasceu durante o teste. Um arquivo que
#   já estava sujo e mudou volta ao conteúdo guardado antes do painel subir
#   [conferência da P75, 09/10/2026: até aqui ele ficava, nomeado — e nem era
#   visto, ver o `estado_todo`].
printf '\n--- 4/4 o painel em uso não suja o repositório inteiro ---\n'
if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  printf '  --   sem python3 ou curl — o painel não foi exercitado\n'
else
  # A LINHA DO STATUS E O CONTEÚDO — conferência da P75, 09/10/2026. Só a
  #   linha do `git status` não vê um arquivo que JÁ estava sujo e o painel
  #   sujou de novo: ` M packs/dracula/icones/apps.map` antes e depois é a
  #   mesma linha. É o estado do checkout onde o produto é usado (o dev de
  #   09/10 tinha esse ` M`), e ali esta seção passava verde com o painel
  #   gravando no mapa. O hash do conteúdo vai junto de cada linha.
  estado_todo() {
    git -C "$RAIZ" status --porcelain -unormal | LC_ALL=C sort | while IFS= read -r l; do
      printf '%s\t%s\n' "$l" "$(git -C "$RAIZ" hash-object -- "${l:3}" 2>/dev/null || printf 'sem-hash')"
    done
  }
  estado_todo > "$TMP/antes-painel"
  # O conteúdo de quem já estava sujo fica guardado, para a devolução abaixo
  # repor o arquivo dela como estava — e não o do HEAD, que apagaria o trabalho.
  while IFS=$'\t' read -r linha _; do
    [ -f "$RAIZ/${linha:3}" ] || continue
    mkdir -p "$TMP/guarda/$(dirname "${linha:3}")" && cp -p -- "$RAIZ/${linha:3}" "$TMP/guarda/${linha:3}"
  done < "$TMP/antes-painel"
  P_CASA="$TMP/casa-painel"; P_FALSO="$TMP/falso-painel"; P_LOG="$TMP/painel.log"
  mkdir -p "$P_CASA/.config/meow" "$P_CASA/.local/share/applications" "$P_FALSO" || exit 2
  for c in sudo pkexec pkill killall systemctl notify-send; do
    printf '#!/bin/sh\nexit 1\n' > "$P_FALSO/$c"; chmod 755 "$P_FALSO/$c"
  done
  cp "$RAIZ/meow.conf.exemplo" "$P_CASA/.config/meow/meow.conf"
  printf '\nPACK="dracula"\nFLAVOR="dracula"\nICONES_DRACULA="sim"\n' >> "$P_CASA/.config/meow/meow.conf"
  printf '[Desktop Entry]\nName=Teste do git-limpo\nExec=true\nIcon=org.meow.GitLimpo\nType=Application\n' \
    > "$P_CASA/.local/share/applications/org.meow.GitLimpo.desktop"
  env -i PATH="$P_FALSO:$PATH" HOME="$P_CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
    MEOW_CONF="$P_CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe \
    "$RAIZ/app/run.sh" --sem-abrir > "$P_LOG" 2>&1 &
  P_PID=$!
  url=""
  for _ in $(seq 1 40); do
    url="$(grep -o 'http://127\.0\.0\.1:[0-9]*/?t=[A-Za-z0-9_-]*' "$P_LOG" | head -1)"
    [ -n "$url" ] && break
    sleep 1
  done
  if [ -z "$url" ]; then
    falha "o painel não subiu — nada foi exercitado"; tail -5 "$P_LOG" | sed 's/^/       /' >&2
  else
    P_BASE="${url%%/\?t=*}"; P_TOK="${url##*t=}"
    poste() { curl -s -o "$TMP/resposta" -w '%{http_code}' -H "X-Meow-Token: $P_TOK" \
                -H 'Content-Type: application/json' --data "$2" "$P_BASE$1"; }
    desenho="$(cd "$RAIZ/packs/dracula/icones" && ls apps/*.svg 2>/dev/null | head -1)"
    c1="$(poste /api/definir '{"chave":"LOGO_INTERVALO","valor":"7d"}')"
    # O CORPO É O QUE O «USAR ESTE ÍCONE» MANDA DESDE A P73 — integração da leva
    #   G, 09/10/2026. Esta seção nasceu na P75 com `pack` + `desenho`, que era o
    #   corpo do botão antes da P73. Depois dela, esse corpo é o do «Levar para o
    #   pack», o gesto explícito que grava no `apps.map` versionado DE PROPÓSITO
    #   (P73 item 6), e a seção passava a cobrar do painel o contrário do que ele
    #   promete. O gesto de uso é `arquivo`, com o caminho que a ficha oferece.
    c2="$(poste /api/app-icone "{\"app\":\"org.meow.GitLimpo\",\"arquivo\":\"packs/dracula/icones/$desenho\"}")"
    # A prova positiva, como na seção 1: os gestos chegaram ao servidor e
    # foram aceitos. Um painel que recusasse tudo deixaria o git limpo também.
    if [ "$c1" = "200" ] && grep -q '^LOGO_INTERVALO="7d"' "$P_CASA/.config/meow/meow.conf"; then
      ok "o painel gravou a chave na casa de brinquedo"
    else
      falha "o painel não gravou a chave (HTTP $c1)"
    fi
    if [ "$c2" = "200" ]; then
      ok "o painel aceitou o desenho do pack para o aplicativo ($desenho)"
    else
      falha "o painel recusou a escolha de ícone (HTTP $c2): $(head -c 200 "$TMP/resposta")"
    fi
  fi
  kill "$P_PID" 2>/dev/null; wait "$P_PID" 2>/dev/null
  estado_todo > "$TMP/depois-painel"
  if diff -u "$TMP/antes-painel" "$TMP/depois-painel" > "$TMP/diff-painel" 2>&1; then
    ok "git status do repositório inteiro idêntico antes e depois do painel"
  else
    falha "o painel em uso MUDOU o git status do repositório:"
    grep '^[-+][^-+]' "$TMP/diff-painel" | sed 's/^/       /' >&2
    # A devolução: só o que nasceu do teste (ver o bloco acima). O que já
    # aparecia no status de antes volta ao conteúdo guardado lá em cima.
    while IFS=$'\t' read -r linha _; do
      cam="${linha:3}"
      if cut -f1 "$TMP/antes-painel" | cut -c4- | grep -qxF -- "$cam"; then
        if [ -f "$TMP/guarda/$cam" ] && cp -p -- "$TMP/guarda/$cam" "$RAIZ/$cam"; then
          printf '       devolvido: %s (como estava antes do teste, já sujo)\n' "$cam" >&2
        else
          printf '       NÃO devolvido: %s (já estava sujo antes do teste — confira à mão)\n' "$cam" >&2
        fi
        continue
      fi
      case "${linha:0:2}" in
        '??') rm -rf -- "${RAIZ:?}/$cam" && printf '       devolvido: %s (nasceu no teste)\n' "$cam" >&2 ;;
        *)    git -C "$RAIZ" checkout -q -- "$cam" && printf '       devolvido: %s (estava limpo antes)\n' "$cam" >&2 ;;
      esac
    done < <(LC_ALL=C comm -13 "$TMP/antes-painel" "$TMP/depois-painel")
  fi
fi

# O QUE AINDA NÃO SAIU, CONTADO E NÃO AFIRMADO -- 22/09/2026
#   A P21 nomeia SETE escritas dentro do repositório versionado e esta passagem
#   entregou DUAS. Enquanto isso for verdade, um veredito final dizendo "usar o
#   programa não suja o repositório" seria mentira da suíte inteira: o botão de
#   tirar jogo do carrossel (`servidor.py`, `MAPA_JOGOS`) e o de adicionar gato
#   escrevem dentro do clone AGORA.
#
#   ISTO É CONTADO, E NÃO ESCRITO À MÃO, pela armadilha nº 3 do projeto: uma
#   frase fixa com "faltam cinco" envelhece calada no dia em que alguém mover os
#   `.map`. O laço pergunta ao índice, então a linha some sozinha quando a
#   dívida acabar — e é ela que diz se a P21 pode ser fechada.
printf '\n--- pendente: o que a P21 promete e esta passagem não entregou ---\n'
PENDENTES=0
# [P73, 09/10/2026: o `apps-arcticons.map` e o `arcticons-apps/` saíram da lista
#   — a escolha de traço do painel mora no estado de quem usa, e a seção 3b
#   cobra.]
# [P82, 15/10/2026 (item 5): e o `apps-convertidos.map` e o `convertidos-apps/`
#   também — a oficina grava no estado de quem usa, e a seção 3c cobra. Sobram
#   o `jogos-fora.map` (a decisão de jogo do painel) e o `assets/gatos/` (o
#   «Adicionar gato»), que nenhuma decisão tirou do clone.]
for alvo in assets/icones/jogos-fora.map assets/gatos; do
  n_alvo="$(git -C "$RAIZ" ls-files -- "$alvo" | wc -l)"
  [ "$n_alvo" -gt 0 ] || continue
  PENDENTES=$((PENDENTES + n_alvo))
  printf '  ~~   %s: %s arquivo(s) que o painel escreve e o git ainda vê\n' "$alvo" "$n_alvo"
done
[ "$PENDENTES" -eq 0 ] && printf '  ok   nenhuma escrita da P21 sobrou dentro do repositório\n'

printf '\n'
if [ "$ACHADOS" -eq 0 ]; then
  if [ "$PENDENTES" -gt 0 ]; then
    printf 'ok: a curadoria de papel de parede não suja o repositório\n'
    printf '    (e só ela: %d arquivos das outras escritas da P21 seguem no índice)\n' "$PENDENTES"
  else
    printf 'ok: usar o programa não suja o repositório\n'
  fi
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$ACHADOS" >&2
exit 1
