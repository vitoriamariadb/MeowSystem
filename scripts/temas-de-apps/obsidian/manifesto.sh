#!/usr/bin/env bash
# scripts/temas-de-apps/obsidian/manifesto.sh — o tema do pack no Obsidian (flatpak).
#
# ATÉ 24/09/2026 A PRIMEIRA LINHA DIZIA "Catppuccin Mocha no Obsidian", e era a
# verdade do arquivo: o nome do tema cravado, nenhuma leitura de pack, paleta ou
# flavor, e o snippet tirado pela palavra "dracula". Com o Dracula no ar ele
# tirava o Dracula e punha o Catppuccin. Ver "O TEMA SAI DO PACK NO AR", abaixo.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO: nada de `exit`, nada de `set -e`.
# O `lib/comum.sh` já veio carregado pelo runner (e ele já fez `set -uo pipefail`,
# então toda variável opcional aqui usa `${VAR:-}`).
#
# O QUE ELE FAZ
#   1. instala <vault>/.obsidian/themes/<tema>/{theme.css,manifest.json}, o
#      tema que o pack no ar declara em `apps.obsidian.esquema`;
#   2. aponta "cssTheme" para <tema> em <vault>/.obsidian/appearance.json;
#   3. tira do "enabledCssSnippets" o snippet com o nome de OUTRO pack — o da
#      máquina onde o módulo nasceu é o `dracula_background`, que pinta o fundo
#      por cima do tema e fazia o Catppuccin parecer quebrado.
#   O appearance.json é MESCLADO por python3/json: as outras chaves dela
#   (baseFontSize, nativeMenus, theme, accentColor...) ficam intactas.
#
# O TEMA SAI DO PACK NO AR — 24/09/2026, sprint P55
#   Medido nesta máquina com o Dracula no ar: o cofre estava com `cssTheme:
#   "Catppuccin"`, e este arquivo não lia pack, paleta nem flavor. Agora o nome é
#   o `apps.obsidian.esquema` do pack no ar, e os dois arquivos saem de um de
#   dois lugares:
#     vendor/<tema>/   o que mora no motor e aplica sem rede — o do Catppuccin;
#     `origem`         o pacote que o pack pina (a URL com o commit, o sha256 e a
#                      pasta de dentro, a forma da base de ícones da P41) — o
#                      Dracula oficial. Desce UMA vez, é conferido pelo sha256,
#                      e o theme.css e o manifest.json ficam em
#                      $MEOW_OBSIDIAN_BAIXADOS/<sha256>/: as passadas de hora em
#                      hora comparam com eles e não tocam a rede. O `name` do
#                      manifest tem de ser o `esquema`, porque é ele a pasta em
#                      `themes/` e o `cssTheme`, como a loja do Obsidian instala.
#
#   O TEMA DE OUTRO PACK NUNCA ENTRA. Estes temas têm a cor escrita, e não saem
#   da paleta: herdar o do pack padrão num pack que não declara o Obsidian seria
#   vestir as cores de um com o nome do outro. O `apps.obsidian` que responde tem
#   de ser o do pack no ar; sem ele a saída é pendente, com o motivo «sem tema
#   neste pack», e nada é escrito.
#
#   O NOME NA TELA É O DO FLAVOR PADRÃO DO PACK ("Catppuccin Mocha", "Dracula"),
#   e não o do FLAVOR da máquina: este módulo não escolhe flavor dentro do tema —
#   o do Catppuccin cai no Mocha no modo escuro (armadilha 5), e o Dracula
#   oficial só tem um. Com o Catppuccin no ar, é a frase que a tela já dizia.
#
#   O SNIPPET SAI DO PACK NO AR, E NÃO DA PALAVRA. A regra era "todo snippet com
#   'dracula' no nome"; passou a ser "todo snippet com o id de OUTRO pack do disco
#   no nome", com os packs contados a cada passada. Com o Catppuccin no ar dá no
#   mesmo (o outro é o `dracula`); com o Dracula no ar o `dracula_background` é
#   dele, e fica, e um `catppuccin_…` sairia.
#
#   O ID CONTA COMO PALAVRA, E SÓ O DE PACK QUE VALE — 25/09/2026, revisão da P55
#   A primeira versão comparava por PEDAÇO de texto, com o id de toda pasta que
#   tivesse um pack.json. O painel importa um CSV com o nome do arquivo como id
#   (`Mar.csv` vira o pack `mar`), e medido com ele no disco e o Catppuccin no
#   ar, dos snippets `markdown-tables`, `margin-fix`, `summary-cards` e `fonte`
#   sobrava o `fonte`; uma pasta `e` com `{}` no pack.json desmarcava o
#   `meu_realce` e o `fonte`. E o doctor roda de hora em hora. Agora o id tem de
#   aparecer INTEIRO, como palavra do nome — o que separa as palavras é o que não
#   é letra nem dígito, e o hífen do id também (`sem-apps` casa `sem_apps_borda`)
#   —, sem distinguir maiúscula de minúscula, e só entre os packs que passam no
#   `validar`. A régua é montada num lugar só, o `_meow_obsidian_packs`. O
#   `dracula_background` continua saindo com o Catppuccin no ar; o preço, dito:
#   um nome colado, como `draculabg`, deixou de contar, porque é a mesma forma do
#   `mar` dentro de `markdown`.
#
# ------------------------------------------------------------------ ARMADILHAS
# Tudo abaixo foi MEDIDO nesta máquina em 2026-08-04, não deduzido.
#
# (1) `pgrep -f obsidian` ACUSA O PRÓPRIO SHELL QUE RODA O MÓDULO.
#     Medido: o `pgrep -f obsidian` do teste devolveu, além do app, o PID do zsh
#     cuja linha de comando apenas CITAVA a palavra "obsidian". Um módulo escrito
#     com o padrão ingênuo devolveria 3 ("app aberto") PARA SEMPRE, mesmo com o
#     Obsidian fechado — e nunca aplicaria nada. Por isso o padrão é ANCORADO:
#         ^/app/obsidian( |$)
#     que é a linha de comando real do flatpak (`exec zypak-wrapper /app/obsidian`
#     no `/app/bin/obsidian.sh`). Com o app aberto casou 6 processos, todos com
#     comm=obsidian; sem o app, casa zero. E não casa a si mesmo.
#
# (2) NÃO DÁ PARA USAR `pgrep -x obsidian`.
#     O comm dos processos do flatpak é mesmo "obsidian" (7 chars, escapa do
#     truncamento em 15 do /proc/PID/comm), mas o `~/.local/bin/obsidian` — que é
#     o obsidian-cli, um ELF completamente diferente do app — teria o MESMO comm.
#     A âncora na linha de comando distingue os dois; o `-x` não.
#
# (3) O OBSIDIAN REESCREVE O appearance.json SOZINHO.
#     Medido: só de ABRIR o app o mtime do appearance.json mudou. Ele é dono do
#     arquivo enquanto roda, e regrava ao sair — o que apagaria nossa escrita.
#     Por isso `meow_app_aplicar` recusa (devolve 3, com aviso) se achar o app
#     vivo. `meow_app_conferir` continua respondendo, porque LER é inofensivo.
#
#     MAS o guarda só vale para ESCRITA, e por isso ele vem DEPOIS do
#     levantamento do que está divergente — não antes. Na primeira versão a
#     ordem era a inversa, e o resultado (medido com o app aberto e o tema já
#     aplicado) era `conferir -> 0` e `aplicar -> 3`: o install.sh listava o
#     obsidian em "pulado", com três avisos de "feche o app", a cada hora do
#     self-heal, enquanto NÃO havia nada a fazer. Nada a fazer é 0, sempre.
#
# (3b) A TRAVA 1 DO comum.sh NÃO ALCANÇA QUEM NÃO USA `meow_escrever`.
#     O appearance.json é gravado pelo python (merge), não pela `meow_escrever`,
#     então ele passava ao largo de `meow_destino_permitido`. Provado num vault
#     de teste cujo caminho continha "com.system76.CosmicSettings.Shortcuts": os
#     arquivos do tema foram recusados pela trava, e o appearance.json foi
#     escrito assim mesmo. Quem escreve chama a trava — é a mesma regra que o
#     módulo do qBittorrent segue na cópia binária dele.
#
# (4) O `meow_escrever` TIRA O \n FINAL, e a conferência tem de tirar também.
#     Ele monta o conteúdo com `$(cat ...)` e grava com `printf '%s'`; substituição
#     de comando come as quebras de linha do fim. Medido: o theme.css instalado
#     fica com 2306520 bytes contra 2306521 do arquivo de origem. Se a conferência
#     usasse `cmp`, acusaria divergência eterna e o módulo reescreveria 2,3 MB a
#     cada ciclo. Por isso comparamos com a MESMA semântica de `$(cat ...)` que o
#     escritor usa — é a consistência entre escritor e conferente que garante a
#     idempotência, não o byte a byte com a origem.
#
# (5) MOCHA JÁ É O PADRÃO — não precisa de plugin nem de classe extra.
#     O flavor do tema sai de uma CLASSE no body (`.theme-dark.ctp-mocha`), e o
#     `default: ctp-mocha` mora num bloco de config do plugin Style Settings.
#     Isso levantou a dúvida: sem o plugin, o tema ficaria sem paleta? Não —
#     medido na linha 1547 do theme.css o seletor é `.theme-dark, .theme-dark
#     .ctp-mocha`, ou seja, o Mocha é o FALLBACK do modo escuro puro. E lá o
#     `--ctp-mauve: 203, 166, 247` é exatamente o #CBA6F7 do MeowSystem.
#     Nos dois caminhos ela cai no Mocha: o `"theme": "obsidian"` do vault já é
#     modo escuro, e o `obsidian-style-settings` está instalado e ativo.
#     Por isso NÃO mexemos na chave "theme" nem forçamos classe nenhuma.
#
# (6) O ACENTO DE FÁBRICA DO TEMA É LAVENDER, NÃO MAUVE — e isso ficou assim.
#     Medido: o tema define `--ctp-accent: var(--ctp-lavender)` (#B4BEFE), então
#     bordas de citação, marcador de lista e afins saem lavanda, e não no mauve
#     #CBA6F7 que é a assinatura do MeowSystem. A paleta mauve ESTÁ lá e correta
#     (`--ctp-mauve: 203, 166, 247`), só não é o acento.
#     Não mexemos: alinhar o acento exigiria um snippet novo em
#     `enabledCssSnippets` — justo o array que este módulo está LIMPANDO — e isso
#     está fora do que foi pedido. Se um dia ela quiser, é uma regra só:
#         .theme-dark { --ctp-accent: var(--ctp-mauve); }
#     num snippet próprio, habilitado por ela. Fica registrado como decisão, não
#     como esquecimento.
#
# (7) O COFRE PODE SER UM LINK PARA OUTRO DISCO.
#     Medido na máquina onde este módulo nasceu: o cofre era um link simbólico
#     para uma pasta noutro disco (o mesmo do repositório). Isso não muda nada
#     aqui porque `meow_escrever` já cria o temporário DENTRO do diretório de
#     destino — o mv é atômico em qualquer um dos casos —, mas registra-se para
#     ninguém "otimizar" para um `cp` de fora depois.
#
# ---------------------------------------------------------------------- ORIGEM
# Tema de terceiros, commit PINADO (detalhes em vendor/ORIGEM.md):
#   https://github.com/catppuccin/obsidian  ·  MIT
#   commit a498ec094a8e619e78bbaad93fb89cecd938f6c4  (2026-08-03)
#   manifest 0.4.47, minAppVersion 1.13.0 — e o Obsidian dela é 1.13.4.
# Os arquivos são VENDORADOS em vendor/: aplicar não depende de rede, e o que
# entra no vault é sempre o mesmo byte que foi revisado.
# O do Dracula não mora aqui: o pack o pina e o módulo o baixa (P55); a origem,
# o commit e o sha256 dele estão no packs/dracula/PROCEDENCIA.md.

MEOW_OBSIDIAN_APP_ID="md.obsidian.Obsidian"
# O TEMA E DE ONDE ELE SAI — P55. Nascem vazios, e quem os preenche é o
# `detectar`, perguntando ao pack no ar (ver `_meow_obsidian_do_pack`):
# `MEOW_OBSIDIAN_TEMA` é o nome (o `cssTheme` e a pasta em `themes/`) e
# `MEOW_OBSIDIAN_FONTE` a pasta de onde saem o theme.css e o manifest.json.
MEOW_OBSIDIAN_TEMA=""
MEOW_OBSIDIAN_FONTE=""
# O COFRE SAI DO PRÓPRIO OBSIDIAN — 24/09/2026, P43
#   Até aqui o padrão era um cofre desta casa, escrito por extenso. Na máquina
#   de qualquer outra pessoa o módulo procurava uma pasta que não existe, dizia
#   "vault não encontrado" e não tematizava nada — e o nome de um cofre pessoal
#   viajava dentro do produto. A diretriz do PC autoadaptável: o que a máquina
#   já sabe, se pergunta a ela, e não a uma lista de nomes.
#
#   O Obsidian guarda os cofres que conhece num `obsidian.json`. Medidos nesta
#   máquina em 24/09 os DOIS lugares onde ele mora, e o formato é o mesmo:
#       ~/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json   (flatpak)
#       ~/.config/obsidian/obsidian.json                               (nativo)
#       {"vaults": {"<id>": {"path": "<absoluto>", "ts": <ms>, "open": true}}}
#   O do flatpak traz chaves a mais (`adblock`, `frame`, `cli`), que não
#   importam aqui. `open` só aparece no cofre que está aberto; `ts` é a última
#   vez que ele foi aberto, em milissegundos.
#
#   O ESCOLHIDO É O QUE O OBSIDIAN ABRIU POR ÚLTIMO: o aberto antes do fechado,
#   e o `ts` maior entre iguais, somando os dois arquivos — um cofre é uma
#   pasta, e o `appearance.json` dele vale para os dois apps. Cofre cuja pasta
#   sumiu (sem `.obsidian/`) não conta. O módulo continua tematizando UM cofre
#   por passada, como antes; quem tem vários e quer outro diz qual em
#   `MEOW_OBSIDIAN_VAULT`, que continua vencendo. A pergunta é feita só no
#   `meow_app_detectar`, depois de o python3 e o app estarem confirmados.
#   O DESFAZER NÃO: ele passa por TODOS os cofres — ver o DESFAZER lá embaixo.
MEOW_OBSIDIAN_VAULT="${MEOW_OBSIDIAN_VAULT:-}"
# Ver armadilha (1): o padrão precisa ser ancorado, ou casa o próprio shell.
MEOW_OBSIDIAN_PADRAO_PROC='^/app/obsidian( |$)'

# Raiz do módulo — resolvida a partir deste arquivo, que é `source`.
MEOW_OBSIDIAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# O tema vendorizado mora no pack que o traz.
MEOW_OBSIDIAN_VENDOR="$(cd "$MEOW_OBSIDIAN_DIR/../../.." && pwd)/packs/meowsystem/temas-de-apps/obsidian/vendor"
# O que desce pela rede, uma pasta por pacote, com o sha256 dele no nome — ver
# "O TEMA SAI DO PACK NO AR", no topo. Mesmo endereço onde o módulo do Telegram
# entrega o dele: é arquivo NOSSO, na casa dela, e o desfazer o leva embora.
MEOW_OBSIDIAN_BAIXADOS="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/temas-de-apps/obsidian"

# --- utilitários internos ---------------------------------------------------

# O cofre que o próprio Obsidian abriu por último — ver "O COFRE SAI DO PRÓPRIO
# OBSIDIAN" lá em cima. Não imprime nada quando ele não conhece cofre nenhum.
# Com `todos`, imprime TODOS os cofres dos dois arquivos, cada um terminado por
# NUL (nome de pasta pode ter quebra de linha): é a lista do desfazer.
_meow_obsidian_cofre() {
  python3 -I - "${1:-um}" "$HOME/.var/app/$MEOW_OBSIDIAN_APP_ID/config/obsidian/obsidian.json" \
            "${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json" <<'PYFIM'
import json, os, sys

todos = sys.argv[1] == "todos"
melhor = None
for arquivo in sys.argv[2:]:
    try:
        with open(arquivo, encoding="utf-8") as f:
            dados = json.load(f)
    except (OSError, ValueError):
        continue
    cofres = dados.get("vaults") if isinstance(dados, dict) else None
    if not isinstance(cofres, dict):
        continue
    for cofre in cofres.values():
        if not isinstance(cofre, dict):
            continue
        pasta = cofre.get("path")
        if not isinstance(pasta, str) or not os.path.isdir(os.path.join(pasta, ".obsidian")):
            continue
        if todos:
            sys.stdout.write(pasta + "\0")
            continue
        ts = cofre.get("ts")
        chave = (cofre.get("open") is True, ts if isinstance(ts, (int, float)) else 0)
        if melhor is None or chave > melhor[0]:
            melhor = (chave, pasta)
if melhor:
    print(melhor[1])
PYFIM
}

# O app está aberto? Ver armadilhas (1) e (2).
_meow_obsidian_rodando() {
  pgrep -f "$MEOW_OBSIDIAN_PADRAO_PROC" >/dev/null 2>&1
}

_meow_obsidian_appearance() { printf '%s/.obsidian/appearance.json' "$MEOW_OBSIDIAN_VAULT"; }
_meow_obsidian_tema_dir()   { printf '%s/.obsidian/themes/%s' "$MEOW_OBSIDIAN_VAULT" "$MEOW_OBSIDIAN_TEMA"; }

# --- o pack no ar (P55) -----------------------------------------------------

# O PACK NO AR E OS OUTROS, NUMA PERGUNTA SÓ AO `scripts/pack.py` — importado,
# como o painel o importa, e não um verbo por dado: o id e o nome de tela do pack
# no ar (pela regra única do `adocao`, a mesma do `meow_pack_dir`), o nome do
# flavor padrão dele, que é o que a tela diz (ver o topo), a régua do snippet e
# a origem do tema. A resposta vem pelas variáveis, e não pelo stdout, pelo
# motivo do `meow_app_tema_do_pack`: quem chama direto não a perde num `$( )`.
#
# A RÉGUA DO SNIPPET É MONTADA AQUI, E SÓ AQUI — 25/09/2026, revisão da P55
#   Ver "O ID CONTA COMO PALAVRA", no topo. `_OBS_OUTROS` e `_OBS_PACKS` eram os
#   ids, separados por vírgula, e cada leitor fazia a comparação dele; agora são
#   a EXPRESSÃO pronta — a dos outros packs e a de todos —, e os dois leitores
#   (o `_meow_obsidian_json` e o `_meow_obsidian_snippets_desmarcados`) só a
#   aplicam. Duas cópias da regra são como ela diverge. Vazia quer dizer "pack
#   nenhum": não tira snippet nenhum.
#
# A ORIGEM PASSA PELA REGRA DA P41 — 25/09/2026, revisão da P55
#   A forma da origem era conferida em shell, no `_meow_obsidian_do_pack`, numa
#   cópia das regras do `origem_pinada` (scripts/pack.py) — e a cópia já diferia
#   num ponto: não conferia a extensão do pacote. Medido com uma URL .zip de
#   sha256 certo: o módulo baixava e parava em «pacote corrompido» (2). A origem
#   do Obsidian tem a forma daquela, `{url, sha256, pasta}`, e quem a confere
#   agora é a própria regra, antes de tocar a rede. O bloco é pedido como o
#   `meow_app_tema_do_pack` o pede — o `tema_de_app`, com o diretório que o
#   `adocao` deu, que é o que o `meow_pack_dir` imprime —, e sai em
#   `_OBS_URL`/`_OBS_SHA`/`_OBS_PASTA`, ou, recusado, com o porquê em
#   `_OBS_ORIGEM_RECUSA`. De quem é o bloco quem diz é o `detectar`, pelo
#   `esquema`: o `origem` sai do mesmo bloco.
#   UMA LINHA POR CAMPO é o que a resposta daqui é, e o pack de terceiro escreve
#   o que quiser: um campo da origem com quebra de linha é recusado, e os dois
#   nomes de tela saem numa linha só — nenhum deles inventa um campo a mais.
#
# OS PACKS QUE PASSAM NO `validar` VÊM DO lib/comum.sh — 25/09/2026, P61
#   A conta deles morava aqui dentro, e o VS Code, que pergunta a mesma coisa do
#   tema de ícones, contava toda pasta com um pack.json. Ela foi para o
#   `meow_packs_validos`, sem mudar uma linha, e os dois módulos a perguntam; a
#   régua (a expressão) continua sendo montada aqui, e só aqui.
_OBS_PACK=""; _OBS_PACK_NOME=""; _OBS_EXIBE=""; _OBS_OUTROS=""; _OBS_PACKS=""
_OBS_URL=""; _OBS_SHA=""; _OBS_PASTA=""; _OBS_ORIGEM_RECUSA=""
_meow_obsidian_packs() {
  local saida
  saida="$(PACK="${PACK:-}" FLAVOR="${FLAVOR:-}" MEOW_PACKS_VALIDOS="$(meow_packs_validos)" \
             python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import json, os, re, sys
sys.path.insert(0, sys.argv[1])
import pack

ident, dir_pack, _recusado = pack.adocao(os.environ.get("PACK", ""), os.environ.get("FLAVOR", ""))
nome = pack.campo(ident, "nome") or ident
exibe = nome
try:
    arq = pack.campo(ident, "paleta.arquivo", "paleta.json")
    with open(os.path.join(pack.achar(ident), arq), encoding="utf-8") as fh:
        nomes = json.load(fh).get("nomes") or {}
    exibe = nomes.get(pack.campo(ident, "paleta.flavor_padrao")) or nome
except (OSError, ValueError, TypeError, AttributeError):
    pass
# Só o pack que passa no `validar` conta: uma pasta com um pack.json qualquer
# não é pack, e o id dela não tem por que desmarcar snippet de ninguém. A lista
# é a do `meow_packs_validos` (lib/comum.sh), a mesma que o VS Code pergunta.
validos = set(os.environ.get("MEOW_PACKS_VALIDOS", "").split())

def regua(ids):
    # O id como PALAVRA: nem letra nem dígito colado antes ou depois, e o hífen
    # dele casando qualquer separador. Os ids passaram no RE_ID, inteiros (o `$`
    # do Python aceitaria um `\n` no fim do nome da pasta).
    if not ids:
        return ""
    ids = sorted(r"[\W_]+".join(re.escape(p) for p in i.split("-") if p) for i in ids)
    return r"(?i)(?<![^\W_])(?:%s)(?![^\W_])" % "|".join(ids)

url = sha = pasta = recusa = ""
_quem, origem = pack.tema_de_app("apps.obsidian.origem", ref=dir_pack or None)
if origem is not None:
    try:
        o = pack.origem_pinada(origem, "apps.obsidian.origem")
        url, sha, pasta = o["url"], o["sha256"], o["pasta"]
    except pack.Recusa as e:
        recusa = " ".join(str(e).split())
    if any(c in v for v in (url, sha, pasta) for c in "\r\n"):
        url = sha = pasta = ""
        recusa = "apps.obsidian.origem: um dos campos tem quebra de linha"
print("pack=" + ident)
print("nome=" + " ".join(str(nome).splitlines()))
print("exibe=" + " ".join(str(exibe).splitlines()))
print("outros=" + regua(validos - {ident}))
print("packs=" + regua(validos | {ident}))
print("url=" + url)
print("sha256=" + sha)
print("pasta=" + pasta)
print("recusa=" + recusa)
PYFIM
)" || return 1
  _OBS_PACK="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  _OBS_PACK_NOME="$(printf '%s\n' "$saida" | sed -n 's/^nome=//p')"
  _OBS_EXIBE="$(printf '%s\n' "$saida" | sed -n 's/^exibe=//p')"
  _OBS_OUTROS="$(printf '%s\n' "$saida" | sed -n 's/^outros=//p')"
  _OBS_PACKS="$(printf '%s\n' "$saida" | sed -n 's/^packs=//p')"
  _OBS_URL="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  _OBS_SHA="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  _OBS_PASTA="$(printf '%s\n' "$saida" | sed -n 's/^pasta=//p')"
  _OBS_ORIGEM_RECUSA="$(printf '%s\n' "$saida" | sed -n 's/^recusa=//p')"
  [ -n "$_OBS_PACK" ]
}

# O TEMA QUE O PACK NO AR DECLARA, E DE ONDE ELE SAI. Preenche MEOW_OBSIDIAN_TEMA
# e MEOW_OBSIDIAN_FONTE; quando o tema desce pela rede, o `_meow_obsidian_packs`
# já deixou _OBS_URL, _OBS_SHA e _OBS_PASTA. Sai pelo `meow_app_sem` — é um
# pedaço do `detectar`.
#   A FORMA DA ORIGEM era conferida aqui, em shell; desde a revisão da P55
#   (25/09/2026) quem confere é o `origem_pinada` do pack.py — ver "A ORIGEM
#   PASSA PELA REGRA DA P41", logo acima.
_meow_obsidian_do_pack() {
  MEOW_OBSIDIAN_TEMA=""; MEOW_OBSIDIAN_FONTE=""; _OBS_URL=""; _OBS_SHA=""; _OBS_PASTA=""; _OBS_ORIGEM_RECUSA=""
  _meow_obsidian_packs || { meow_app_sem "obsidian: o scripts/pack.py não disse qual é o pack no ar"; return; }
  # Direto, sem `$( )`: a resposta vem pelas duas variáveis (lib/comum.sh).
  meow_app_tema_do_pack obsidian.esquema
  if [ -z "$MEOW_APP_TEMA" ]; then
    meow_app_sem "obsidian: sem tema neste pack ($_OBS_PACK_NOME) — o Obsidian fica como está"
    return
  fi
  if [ "$MEOW_APP_TEMA_PACK" != "$_OBS_PACK" ]; then
    meow_app_sem "obsidian: sem tema neste pack ($_OBS_PACK_NOME) — o que a herança traz é o '$MEOW_APP_TEMA', do pack $MEOW_APP_TEMA_PACK, e o tema de um pack não veste outro"
    return
  fi
  # O NOME VIRA PASTA em `themes/` (e o `cssTheme`), e quem o escreve é o pack —
  # o `pack.py` devolve nome como veio. Com `/`, ou sendo `.` ou `..`, o tema
  # seria escrito fora da pasta de temas do cofre.
  case "$MEOW_APP_TEMA" in
    */*|.|..|*$'\n'*)
      meow_app_sem "obsidian: o pack $_OBS_PACK_NOME dá ao tema um nome que não serve de pasta ('$MEOW_APP_TEMA') — nada é escrito"
      return ;;
  esac
  MEOW_OBSIDIAN_TEMA="$MEOW_APP_TEMA"
  if [ -n "$_OBS_ORIGEM_RECUSA" ]; then
    meow_app_sem "obsidian: a origem do tema '$MEOW_OBSIDIAN_TEMA' no pack $_OBS_PACK_NOME não serve — $_OBS_ORIGEM_RECUSA"
    return
  fi
  if [ -z "$_OBS_URL" ]; then
    MEOW_OBSIDIAN_FONTE="$MEOW_OBSIDIAN_VENDOR/$MEOW_OBSIDIAN_TEMA"
    # O único motivo daqui que não é da máquina dela: ou o repositório chegou
    # incompleto, ou o pack pede um tema que o motor não traz e não diz de onde
    # ele desce. Nos dois, do lado dela não há o que consertar (3, e não 2).
    if [ ! -f "$MEOW_OBSIDIAN_FONTE/theme.css" ] || [ ! -f "$MEOW_OBSIDIAN_FONTE/manifest.json" ]; then
      meow_app_sem "obsidian: o pack $_OBS_PACK_NOME pede o tema '$MEOW_OBSIDIAN_TEMA', que não está em $MEOW_OBSIDIAN_VENDOR e não tem origem para descer"
      return
    fi
    return "$MEOW_OK"
  fi
  MEOW_OBSIDIAN_FONTE="$MEOW_OBSIDIAN_BAIXADOS/$_OBS_SHA"
  return "$MEOW_OK"
}

# 0 = os dois arquivos do tema estão à mão. O do vendor/ o `detectar` já
# conferiu; o que desceu é conferido pelo CONTEÚDO, a régua da base de ícones
# da P41 — uma pasta com um arquivo apagado ou mexido não é o pacote pinado.
_meow_obsidian_fonte_pronta() {
  [ -n "$_OBS_SHA" ] || return 0
  [ -f "$MEOW_OBSIDIAN_FONTE/.meow-origem" ] \
    && grep -qx "sha256=$_OBS_SHA" "$MEOW_OBSIDIAN_FONTE/.meow-origem" \
    && ( cd "$MEOW_OBSIDIAN_FONTE" && sha256sum --status -c .meow-somas.sha256 ) 2>/dev/null
}

# A descida do pacote pinado, que só o `aplicar` chama. Entra inteiro ou não
# entra: baixa para um palco DENTRO de $MEOW_OBSIDIAN_BAIXADOS (o `mv` final é
# no mesmo disco — TRAVA 2 do lib/comum.sh), confere o sha256, abre, confere que
# a pasta declarada traz o tema com o `name` que o pack pediu, e só então a
# cópia dos dois arquivos vira a fonte, com um `mv` só. Sem rede é pendência e
# fica para o próximo ciclo; sha256 que não bate é ERRO, pelo motivo do
# `construir_icones.sh`: é o arquivo mudando debaixo do pino.
# 1 = desceu · 2 = erro · 3 = sem rede ou sem ferramenta (com o motivo guardado)
#
# A SOBRA DAS DESCIDAS DE ANTES SAI ANTES DESTA — 25/09/2026, P61. O palco de uma
#   descida cortada no meio (`.meow-descendo.*`) só saía pelo desfazer (revisão
#   da P55), e sobrevivia a um `aplicar` que descia de novo: medido com um
#   `.meow-descendo.Velho1` na pasta, o pack de brinquedo `noite` desceu, vestiu
#   o cofre e o deixou lá. Quem desce agora é a única descida — o `aplicar` roda
#   sob a trava do MeowSystem —, e todo palco que já está na pasta é de uma que
#   não terminou. A pasta que a descida deixar vazia, quem leva é o `aplicar`,
#   logo depois dela.
_meow_obsidian_baixar() {
  local palco src nome obtido f sobra
  for f in curl tar sha256sum; do
    meow_tem "$f" || { meow_app_sem "obsidian: falta '$f' para baixar o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME"; return; }
  done
  meow_destino_permitido "$MEOW_OBSIDIAN_FONTE" || return "$MEOW_ERRO"
  mkdir -p "$MEOW_OBSIDIAN_BAIXADOS" || return "$MEOW_ERRO"
  for sobra in "$MEOW_OBSIDIAN_BAIXADOS"/.meow-descendo.*; do
    [ -d "$sobra" ] && rm -rf -- "$sobra"
  done
  palco="$(mktemp -d -p "$MEOW_OBSIDIAN_BAIXADOS" ".meow-descendo.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "obsidian: baixando o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME…"
  # `--proto =https` nos dois sentidos, como no `construir_icones.sh`: a origem é
  # https, e um redirecionamento para http seria a mesma porta por trás.
  if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
       --max-time 300 --retry 3 --retry-delay 2 -o "$palco/pacote" "$_OBS_URL" 2>/dev/null; then
    rm -rf "$palco"
    meow_app_sem "obsidian: não consegui baixar o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME (sem rede?) — fica para o próximo ciclo"
    return
  fi
  if ! echo "$_OBS_SHA  $palco/pacote" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$palco/pacote" | cut -d' ' -f1)"
    rm -rf "$palco"
    meow_erro "obsidian: o sha256 do tema '$MEOW_OBSIDIAN_TEMA' não bate com o que o pack $_OBS_PACK_NOME pinou — nada instalado"
    meow_info "  esperado $_OBS_SHA"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  if ! { mkdir "$palco/x" && tar -xf "$palco/pacote" -C "$palco/x"; } 2>/dev/null; then
    rm -rf "$palco"
    meow_erro "obsidian: o pacote do tema '$MEOW_OBSIDIAN_TEMA' veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi
  src="$palco/x/$_OBS_PASTA"
  # Arquivo de verdade, e não link: o que vai para o cofre é copiado daqui.
  nome=""
  if [ -f "$src/theme.css" ] && [ ! -L "$src/theme.css" ] && [ -f "$src/manifest.json" ] && [ ! -L "$src/manifest.json" ]; then
    nome="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("name", ""))' \
              "$src/manifest.json" 2>/dev/null)"
  fi
  if [ "$nome" != "$MEOW_OBSIDIAN_TEMA" ]; then
    rm -rf "$palco"
    meow_erro "obsidian: o pacote não traz em '$_OBS_PASTA' o theme.css e o manifest.json do tema '$MEOW_OBSIDIAN_TEMA'${nome:+ (o manifest diz '$nome')} — nada instalado"
    return "$MEOW_ERRO"
  fi
  if ! { mkdir "$palco/tema" && cp -- "$src/theme.css" "$src/manifest.json" "$palco/tema/" \
         && ( cd "$palco/tema" && sha256sum theme.css manifest.json > .meow-somas.sha256 ) \
         && printf 'sha256=%s\nurl=%s\n' "$_OBS_SHA" "$_OBS_URL" > "$palco/tema/.meow-origem"; }; then
    rm -rf "$palco"
    meow_erro "obsidian: não consegui guardar o tema baixado em $MEOW_OBSIDIAN_BAIXADOS"
    return "$MEOW_ERRO"
  fi
  # A sobra de uma descida anterior que não conferiu sai antes; a nova entra.
  rm -rf -- "$MEOW_OBSIDIAN_FONTE"
  if ! mv -f -- "$palco/tema" "$MEOW_OBSIDIAN_FONTE"; then
    rm -rf "$palco"
    meow_erro "obsidian: não consegui pôr o tema baixado em $MEOW_OBSIDIAN_FONTE"
    return "$MEOW_ERRO"
  fi
  rm -rf "$palco"
  meow_muda "obsidian: tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME baixado e conferido pelo sha256"
  return "$MEOW_DIVERGENTE"
}

# Compara com a MESMA semântica do meow_escrever — ver armadilha (4).
# 0 = igual, 1 = diferente/ausente.
_meow_obsidian_igual() {
  local origem="$1" destino="$2"
  [ -f "$destino" ] || return 1
  [ "$(cat "$origem" 2>/dev/null)" = "$(cat "$destino" 2>/dev/null)" ]
}

# Backup antes de sobrescrever QUALQUER arquivo que já era dela.
# Um diretório por execução, para dar para desfazer tudo junto.
_meow_obsidian_backup() {
  local arquivo="$1" rotulo="$2" destino
  meow_guardar_antes "$1"
  [ -f "$arquivo" ] || return 0
  meow_seco && return 0
  # ISO sem ':' — é o formato que os outros módulos do MeowSystem já usam nesta
  # mesma pasta de backups (visto em backups/2026-08-04T20-14-44 do módulo Qt).
  : "${MEOW_OBSIDIAN_BACKUP_DIR:=${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  mkdir -p "$destino" || return 1
  cp -p -- "$arquivo" "$destino/$rotulo" || return 1
  return 0
}

# --- O COFRE EM GIT — 09/10/2026, P74 item 8 (T2) ---------------------------
#   O tema oscilava: o cofre dela é git, o `appearance.json` está versionado com
#   `"cssTheme": "Catppuccin"`, e toda operação de git que reescreve a árvore o
#   devolvia, para este módulo trocar de novo na passada seguinte (dez vezes no
#   doctor.log, de 28/09 a 09/10). A cura é o filtro do `filtro_git.py`, ao lado
#   deste arquivo, que conta o mecanismo: o git passa a escrever o tema desta
#   máquina no disco e a guardar o do cofre nos commits. Ele mora só no
#   `.git/config` e no `.git/info/attributes` do cofre — nada versionado, nada
#   que viaje para a outra máquina.
#
# O CAMINHO DO COFRE PODE SER O DO PORTAL DE DOCUMENTOS DO FLATPAK
#   O `obsidian.json` desta máquina guarda `/run/user/1000/doc/<id>/<cofre>`, e o
#   git não roda ali (medido: «unable to get current working directory»). O
#   `flatpak documents` diz a origem de cada documento; o git roda nela.
_meow_obsidian_hospedeiro() {
  local cofre="$1" id resto origem
  case "$cofre" in
    /run/user/*/doc/*/*)
      id="${cofre#/run/user/*/doc/}"; resto="${id#*/}"; id="${id%%/*}"
      origem="$(flatpak documents --columns=id,origin 2>/dev/null \
                | awk -F'\t' -v id="$id" '$1 == id { print $2; exit }')"
      [ -n "$origem" ] || return 1
      # A origem é o próprio documento (a pasta exportada); o resto do caminho
      # depois do id repete o nome dela.
      printf '%s/%s' "$(dirname -- "$origem")" "$resto" ;;
    *) printf '%s' "$cofre" ;;
  esac
}

# conferir | aplicar | renovar | conferir-desfazer | desfazer — o filtro do cofre no ar.
#
# `renovar` É O ÍNDICE SABER QUE NADA MUDOU. Medido num cofre de brinquedo: com
#   o filtro no lugar, o `git diff` do arquivo sai vazio e o `git status` ainda
#   o lista como mudado, porque o tamanho no disco não é o que o índice guardou
#   (o nome do tema mudou de tamanho) e o git não abre o conteúdo nesse caso.
#   Um `git add` do arquivo, só quando o `git diff --quiet` diz que o conteúdo
#   limpo é o do índice, regrava o carimbo e nada mais: o blob é o mesmo, e uma
#   mudança dela no arquivo (que o diff veria) nunca é posta no índice por nós.
# 0 = nada a fazer (ou o cofre não é git, ou o arquivo não está nele) ·
# 1 = divergente / escreveu · 2 = erro.
_meow_obsidian_git() {
  local modo="$1" tema="${2:-}" cofre raiz rel attrs linha filtro limpar vestir
  meow_tem git || return "$MEOW_OK"
  cofre="$(_meow_obsidian_hospedeiro "$MEOW_OBSIDIAN_VAULT")" || return "$MEOW_OK"
  raiz="$(git -C "$cofre" rev-parse --show-toplevel 2>/dev/null)" || return "$MEOW_OK"
  rel="$(realpath -m --relative-to="$raiz" "$cofre/.obsidian/appearance.json")" || return "$MEOW_OK"
  git -C "$raiz" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 || return "$MEOW_OK"
  attrs="$(git -C "$raiz" rev-parse --path-format=absolute --git-path info/attributes 2>/dev/null)" \
    || return "$MEOW_OK"
  filtro="$MEOW_RAIZ/scripts/temas-de-apps/obsidian/filtro_git.py"
  linha="/${rel// /[[:space:]]} filter=meow-obsidian"
  limpar="python3 '$filtro' limpar %f"
  vestir="python3 '$filtro' vestir"

  local tem_linha=0 tem_cfg=0
  grep -qxF -- "$linha" "$attrs" 2>/dev/null && tem_linha=1
  [ "$(git -C "$raiz" config --local --get filter.meow-obsidian.clean 2>/dev/null)" = "$limpar" ] \
    && [ "$(git -C "$raiz" config --local --get filter.meow-obsidian.smudge 2>/dev/null)" = "$vestir" ] \
    && [ "$(git -C "$raiz" config --local --get meow.obsidian-tema 2>/dev/null)" = "$tema" ] && tem_cfg=1

  case "$modo" in
    conferir)
      [ "$tem_linha" = 1 ] && [ "$tem_cfg" = 1 ] && return "$MEOW_OK"
      meow_muda "obsidian: o git do cofre ainda não sabe que o tema é desta máquina ($raiz)"
      return "$MEOW_DIVERGENTE" ;;
    aplicar)
      [ "$tem_linha" = 1 ] && [ "$tem_cfg" = 1 ] && return "$MEOW_OK"
      if meow_seco; then
        meow_muda "obsidian: ensinaria ao git do cofre que o tema é desta máquina ($raiz)"
        return "$MEOW_DIVERGENTE"
      fi
      meow_destino_permitido "$attrs" || return "$MEOW_ERRO"
      git -C "$raiz" config --local filter.meow-obsidian.clean "$limpar" \
        && git -C "$raiz" config --local filter.meow-obsidian.smudge "$vestir" \
        && git -C "$raiz" config --local meow.obsidian-tema "$tema" || return "$MEOW_ERRO"
      if [ "$tem_linha" = 0 ]; then
        mkdir -p -- "$(dirname -- "$attrs")" && printf '%s\n' "$linha" >> "$attrs" || return "$MEOW_ERRO"
      fi
      meow_muda "obsidian: o git do cofre guarda o tema dele e escreve o desta máquina ($raiz)"
      return "$MEOW_DIVERGENTE" ;;
    renovar)
      [ "$tem_linha" = 1 ] && [ "$tem_cfg" = 1 ] || return "$MEOW_OK"
      meow_seco && return "$MEOW_OK"
      git -C "$raiz" diff --quiet -- "$rel" 2>/dev/null && git -C "$raiz" add -- "$rel" 2>/dev/null
      return "$MEOW_OK" ;;
    conferir-desfazer|desfazer)
      [ "$tem_linha" = 0 ] && [ -z "$(git -C "$raiz" config --local --get-regexp '^filter\.meow-obsidian\.|^meow\.obsidian-tema$' 2>/dev/null)" ] \
        && return "$MEOW_OK"
      [ "$modo" = "conferir-desfazer" ] && return "$MEOW_DIVERGENTE"
      if meow_seco; then
        meow_muda "obsidian: tiraria do git do cofre o filtro do tema ($raiz)"
        return "$MEOW_DIVERGENTE"
      fi
      git -C "$raiz" config --local --remove-section filter.meow-obsidian 2>/dev/null
      git -C "$raiz" config --local --unset meow.obsidian-tema 2>/dev/null
      if [ "$tem_linha" = 1 ]; then
        local tmp; tmp="$(mktemp -p "$(dirname -- "$attrs")" .meow.XXXXXX)" || return "$MEOW_ERRO"
        grep -vxF -- "$linha" "$attrs" > "$tmp"; mv -f -- "$tmp" "$attrs" || return "$MEOW_ERRO"
      fi
      meow_muda "obsidian: o filtro do tema saiu do git do cofre ($raiz)"
      return "$MEOW_DIVERGENTE" ;;
  esac
  return "$MEOW_ERRO"
}

# O leitor/mesclador do appearance.json. Fica aqui dentro para o módulo ser um
# arquivo só. Modos: "conferir" (não escreve) e "aplicar"; e, do desfazer,
# "conferir-desfazer" (não escreve) e "desfazer".
# Códigos: 0 = já está certo · 1 = divergente (ou mesclado) · 2 = erro.
#
# O DESFAZER SÓ VOLTA O `cssTheme` QUE FOR DELE — 24/09/2026, revisão da P43
#   Até aqui o desfazer chamava o modo "aplicar" com o tema vazio, e isso fazia
#   o que o "aplicar" faz: punha QUALQUER `cssTheme` no padrão, tirava o snippet
#   com "dracula" no nome e, sem appearance.json, criava um. Num cofre que o
#   MeowSystem tematizou dá no mesmo; num que a pessoa tematizou sozinha, zera a
#   escolha dela. Nos modos do desfazer, `tema` é o NOSSO: o `cssTheme` só volta
#   ao padrão se ainda for ele, o array dos snippets não é tocado e arquivo que
#   não existe continua não existindo.
#
# OS DOIS ARGUMENTOS QUE A P55 MUDOU (24/09/2026)
#   `outros` (o 4º) é a régua do snippet, e sai do pack no ar (ver o topo). E,
#   nos modos do desfazer, `tema` é a LISTA dos nossos, um por linha — o desfazer
#   não depende do pack, e reconhece como nosso qualquer tema que o MeowSystem
#   traga.
#   [25/09/2026, revisão da P55: `outros` eram os ids, e a comparação era aqui,
#   por pedaço de texto; passou a ser a expressão que o `_meow_obsidian_packs`
#   monta — ver "A RÉGUA DO SNIPPET É MONTADA AQUI".]
_meow_obsidian_json() {
  local modo="$1" arquivo="$2" tema="$3" outros="${4:-}"
  MEOW_PY_SECO="$(meow_seco && echo 1 || echo 0)" \
  python3 -I - "$modo" "$arquivo" "$tema" "$outros" <<'PYFIM'
import json, os, re, sys, tempfile

modo, caminho, tema = sys.argv[1], sys.argv[2], sys.argv[3]
outros = sys.argv[4]
seco = os.environ.get("MEOW_PY_SECO") == "1"
desfazer = modo in ("conferir-desfazer", "desfazer")

existia = os.path.exists(caminho)
if existia:
    try:
        with open(caminho, encoding="utf-8") as f:
            texto = f.read()
        dados = json.loads(texto) if texto.strip() else {}
    except (OSError, ValueError) as e:
        sys.stderr.write("appearance.json ilegível (%s)\n" % e)
        sys.exit(2)
    if not isinstance(dados, dict):
        sys.stderr.write("appearance.json não é um objeto JSON\n")
        sys.exit(2)
else:
    dados = {}

# Assinatura do ANTES: se nada mudar, não se escreve nada (regra 5).
antes = json.dumps(dados, sort_keys=True)
motivos = []

if desfazer:
    if dados.get("cssTheme") in [t for t in tema.split("\n") if t]:
        motivos.append("cssTheme=%r -> ''" % dados.get("cssTheme"))
        dados["cssTheme"] = ""
elif dados.get("cssTheme") != tema:
    motivos.append("cssTheme=%r -> %r" % (dados.get("cssTheme"), tema))
    dados["cssTheme"] = tema

# O snippet com o nome de outro pack pinta por cima do tema do pack no ar — o
# "dracula_background" fazia o Catppuccin parecer quebrado. Só mexemos no ARRAY:
# o .css dela continua no disco, então reverter é só remarcar o snippet na
# interface. (O desfazer não toca no array.)
snippets = None if desfazer else dados.get("enabledCssSnippets")
if isinstance(snippets, list) and outros:
    limpos = [s for s in snippets
              if not (isinstance(s, str) and re.search(outros, s))]
    if limpos != snippets:
        removidos = [s for s in snippets if s not in limpos]
        motivos.append("snippets removidos: %s" % ", ".join(map(str, removidos)))
        dados["enabledCssSnippets"] = limpos

if not existia and not desfazer:
    motivos.append("appearance.json não existia")

if json.dumps(dados, sort_keys=True) == antes and (existia or desfazer):
    sys.exit(0)

for m in motivos:
    sys.stderr.write("  %s\n" % m)

if modo in ("conferir", "conferir-desfazer") or seco:
    sys.exit(1)

# O Obsidian grava com indentação de 2 e SEM \n final (medido no arquivo dela);
# e, como é JS, não escapa acento. Imitamos para não gerar ruído de diff.
saida = json.dumps(dados, indent=2, ensure_ascii=False)
pasta = os.path.dirname(caminho) or "."
try:
    os.makedirs(pasta, exist_ok=True)
    # Temporário no MESMO diretório do destino: o os.replace só é atômico
    # dentro do mesmo sistema de arquivos.
    fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".meow-appearance.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(saida)
    os.chmod(tmp, 0o644)
    os.replace(tmp, caminho)
except OSError as e:
    sys.stderr.write("falhou ao gravar appearance.json (%s)\n" % e)
    try:
        os.unlink(tmp)
    except (OSError, NameError):
        pass
    sys.exit(2)
sys.exit(1)
PYFIM
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { meow_flatpak_tem "$MEOW_OBSIDIAN_APP_ID"; }

# --- 1. detectar ------------------------------------------------------------
# Nunca falha: 0 = tem, 3 = não tem. App ausente não é erro.
#
# E A CAUSA SAI DAQUI COM O NÚMERO [21/09/2026]
#   Os `meow_pula` deste bloco diziam a causa CERTA, só que de dentro de quem
#   mede: ela saía onde ninguém a pediu (o modo `tabela` do aplicar_apps.sh
#   joga a saída daqui fora) e faltava onde importava — o `reverter` chutava
#   uma frase própria, "Obsidian não instalado (ou o vault não está onde eu
#   procuro)", que podia não ser nenhuma das cinco causas daqui. As frases não
#   se perderam: viraram o motivo do `meow_app_sem` (lib/comum.sh), e quem as
#   diz agora é quem foi barrado por elas, uma vez só.
meow_app_detectar() {
  # Motivo velho mente com cara de medida: zerar antes de medir é do contrato.
  MEOW_APP_MOTIVO=""
  if ! meow_tem flatpak; then
    meow_app_sem "obsidian: flatpak não está instalado"
    return
  fi
  # python3 faz o merge do appearance.json e pgrep é o guarda do app aberto.
  # Sem eles não há como trabalhar — e isso é dependência faltando (3), não erro
  # (2). Medido num PATH mínimo sem python3: antes desta checagem o `detectar`
  # dizia 0 e o `aplicar` morria com 2, o que joga o obsidian em "falhou" no
  # install.sh por causa de uma dependência ausente. Pior no caso do pgrep: sem
  # ele o guarda do app aberto falharia PARA ABERTO — escreveria com o Obsidian
  # vivo, e o app desfaria tudo ao sair.
  # (python3 PRESENTE mas quebrado continua sendo 2: aí é erro de verdade.)
  local falta
  for falta in python3 pgrep; do
    if ! meow_tem "$falta"; then
      meow_app_sem "obsidian: falta '$falta' (sem ele não dá para aplicar com segurança)"
      return
    fi
  done
  # O teste por DIRETÓRIO cobre usuário, sistema e ~/.var/app — e não cria um
  # repositório ostree inteiro só por perguntar, que é o que `flatpak info`
  # fazia num HOME sem flatpak nenhum (medido em 10/08/2026). Detecção com
  # efeito colateral faz o MEOW_DRY_RUN=1 mentir.
  if ! meow_app_instalado; then
    meow_app_sem "obsidian: $MEOW_OBSIDIAN_APP_ID não instalado"
    return
  fi
  # Sem vault não há o que tematizar — também não é erro. O cofre é perguntado
  # ao Obsidian só aqui, e só quando ninguém disse qual (ver o topo do módulo).
  [ -n "$MEOW_OBSIDIAN_VAULT" ] || MEOW_OBSIDIAN_VAULT="$(_meow_obsidian_cofre)"
  if [ -z "$MEOW_OBSIDIAN_VAULT" ]; then
    meow_app_sem "obsidian: o Obsidian ainda não conhece cofre nenhum (obsidian.json) — abra um cofre nele, ou diga qual em MEOW_OBSIDIAN_VAULT"
    return
  fi
  if [ ! -d "$MEOW_OBSIDIAN_VAULT/.obsidian" ]; then
    meow_app_sem "obsidian: vault '$MEOW_OBSIDIAN_VAULT' não encontrado"
    return
  fi
  # O DESFAZER NÃO DEPENDE DO PACK (P55; ver o DESFAZER lá embaixo): ele pede só
  # o que vem até aqui. O resto — o tema que o pack no ar declara, e de onde ele
  # sai — é do `conferir` e do `aplicar`. O motivo do repositório incompleto,
  # que morava aqui, foi para o `_meow_obsidian_do_pack`, junto com o nome do
  # tema: é lá que se sabe qual pasta do vendor/ devia existir.
  [ "${1:-}" = "sem-pack" ] && return "$MEOW_OK"
  _meow_obsidian_do_pack || return
  return "$MEOW_OK"
}

# --- 2. conferir ------------------------------------------------------------
# 0 = já aplicado · 1 = divergente · 3 = app ausente.
# Ler é inofensivo mesmo com o app aberto, então aqui não se recusa nada.
meow_app_conferir() {
  meow_app_detectar || { meow_app_pendente obsidian; return; }

  local tema_dir divergente=0
  tema_dir="$(_meow_obsidian_tema_dir)"

  if ! _meow_obsidian_fonte_pronta; then
    # O tema de fora ainda não desceu (ou a cópia guardada não confere): não há
    # com que comparar o cofre, e é divergência — quem baixa é o `aplicar`.
    # Conferir não toca a rede.
    meow_muda "obsidian: o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME ainda não desceu"
    divergente=1
  else
    _meow_obsidian_igual "$MEOW_OBSIDIAN_FONTE/theme.css" "$tema_dir/theme.css" \
      || { meow_muda "obsidian: theme.css ausente ou diferente"; divergente=1; }
    _meow_obsidian_igual "$MEOW_OBSIDIAN_FONTE/manifest.json" "$tema_dir/manifest.json" \
      || { meow_muda "obsidian: manifest.json ausente ou diferente"; divergente=1; }
  fi

  _meow_obsidian_json conferir "$(_meow_obsidian_appearance)" "$MEOW_OBSIDIAN_TEMA" "$_OBS_OUTROS"
  case $? in
    0) ;;
    1) meow_muda "obsidian: appearance.json divergente"; divergente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_DIVERGENTE" ;;
  esac
  # O cofre em git (P74 item 8): sem o filtro, o tema volta no próximo checkout.
  _meow_obsidian_git conferir "$MEOW_OBSIDIAN_TEMA" || divergente=1

  if [ "$divergente" = "0" ]; then
    meow_ok "obsidian: $_OBS_EXIBE já aplicado"
    return "$MEOW_OK"
  fi
  # Aviso útil: divergente + app aberto = o aplicar vai recusar.
  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: está ABERTO — feche-o para o MeowSystem poder aplicar"
  fi
  return "$MEOW_DIVERGENTE"
}

# --- 3. aplicar -------------------------------------------------------------
# 0 = nada a fazer · 1 = aplicou · 2 = erro · 3 = app ausente (ou aberto).
meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente obsidian; return; }

  local tema_dir appearance mudou=0 rc
  tema_dir="$(_meow_obsidian_tema_dir)"
  appearance="$(_meow_obsidian_appearance)"

  # --- 3.0a — o tema de fora desce ANTES de levantar (P55): sem ele não há com
  # que comparar o cofre. A descida só escreve na nossa pasta
  # ($MEOW_OBSIDIAN_BAIXADOS), e por isso vem antes do guarda do app aberto, que
  # protege o appearance.json dela. Refazer a cópia guardada não é "aplicar":
  # se o cofre já estava certo, a saída continua sendo 0. O seco não desce — diz
  # que desceria, e os dois arquivos contam como pendentes logo abaixo.
  if ! _meow_obsidian_fonte_pronta; then
    if meow_seco; then
      meow_muda "obsidian: baixaria o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME ($_OBS_URL)"
    else
      _meow_obsidian_baixar; rc=$?
      # A DESCIDA QUE NÃO ENTROU NÃO DEIXA A PASTA — 25/09/2026, P61. O palco
      # mora dentro dela (o `mv` final é no mesmo disco), então o `mkdir` vem
      # antes da rede; sem rede, a pasta ficava vazia e o desfazer, sem nada
      # nosso para tirar, a deixava. Vazia, ela sai; com o que já desceu de
      # outra vez, o `rmdir` a deixa.
      #   [25/09/2026, P65: e as mães dela, que o `mkdir -p` cria numa casa
      #   nova — `meowsystem/temas-de-apps/` e `meowsystem/`. Medido numa casa
      #   de brinquedo sem rede: a pasta do Obsidian saía e as duas ficavam
      #   vazias. O `rmdir` vai de baixo para cima e para na primeira que tem
      #   alguma coisa (o tema do Telegram, os packs dela); acima de
      #   `meowsystem/` não sobe, porque dali para cima a pasta não é nossa.]
      [ "$rc" = 1 ] || rmdir -- "$MEOW_OBSIDIAN_BAIXADOS" "${MEOW_OBSIDIAN_BAIXADOS%/*}" \
                                "${MEOW_OBSIDIAN_BAIXADOS%/*/*}" 2>/dev/null
      case $rc in
        1) ;;
        3) meow_app_pendente obsidian; return ;;
        *) return "$MEOW_ERRO" ;;
      esac
    fi
  fi

  # --- 3.0 — LEVANTAR o que falta, ANTES de qualquer guarda ou escrita.
  # Duas coisas dependem desta ordem (ver armadilha 3):
  #   · "nada a fazer" é 0, mesmo com o Obsidian aberto. Recusar antes de olhar
  #     devolvia 3 ("pulado") a cada ciclo com o tema já aplicado;
  #   · o backup e a pasta de backup só nascem quando existe escrita para
  #     desfazer — medido: três rodadas no-op deixavam três pastas em backups/,
  #     e o self-heal roda de hora em hora.
  local -a pendentes=()
  local arquivo
  for arquivo in theme.css manifest.json; do
    _meow_obsidian_igual "$MEOW_OBSIDIAN_FONTE/$arquivo" "$tema_dir/$arquivo" \
      || pendentes+=("$arquivo")
  done

  local json_pendente=0
  _meow_obsidian_json conferir "$appearance" "$MEOW_OBSIDIAN_TEMA" "$_OBS_OUTROS" 2>/dev/null
  rc=$?
  case $rc in
    0) ;;                   # já está como queremos: nem backup, nem escrita
    1) json_pendente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_ERRO" ;;
  esac

  # O cofre em git (P74 item 8): o filtro que faz o tema desta máquina sobreviver
  # ao git dele. Levantado aqui com os outros, pelo mesmo motivo do 3.0.
  local git_pendente=0
  _meow_obsidian_git conferir "$MEOW_OBSIDIAN_TEMA" >/dev/null 2>&1 || git_pendente=1

  if [ "${#pendentes[@]}" -eq 0 ] && [ "$json_pendente" = "0" ] && [ "$git_pendente" = "0" ]; then
    meow_ok "obsidian: $_OBS_EXIBE já estava aplicado"
    return "$MEOW_OK"
  fi

  # --- 3.0b — só agora o guarda do app aberto. Armadilha (3): com o app vivo,
  # ele regrava o appearance.json ao sair e apagaria o que fizermos. Recusar é o
  # certo — e recusa NÃO é erro.
  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: o app está ABERTO — nada foi escrito."
    meow_aviso "obsidian: ele regrava o appearance.json ao sair e desfaria a troca."
    meow_aviso "obsidian: aberto agora; a próxima passada com ele fechado aplica."
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # --- 3.0c — TRAVA 1 no caminho que NÃO passa pela `meow_escrever`.
  # O appearance.json é gravado pelo python; sem esta linha ele escreveria em
  # território proibido se `MEOW_OBSIDIAN_VAULT` apontasse para lá (ver 3b).
  meow_destino_permitido "$appearance" || return "$MEOW_ERRO"

  # Zerado a cada execução para o backup ser um diretório só por rodada.
  unset MEOW_OBSIDIAN_BACKUP_DIR

  # --- 3.1 — os dois arquivos do tema.
  for arquivo in "${pendentes[@]}"; do
    # Só faz backup se JÁ existia algo ali (um Catppuccin antigo, por exemplo).
    if ! _meow_obsidian_backup "$tema_dir/$arquivo" "$arquivo"; then
      meow_erro "obsidian: não consegui fazer backup de $arquivo"
      return "$MEOW_ERRO"
    fi
    # A fonte só falta no seco, com o tema de fora ainda por descer (3.0a). Fora
    # dele, faltar é erro: um `$(cat)` de arquivo sumido gravaria VAZIO no cofre.
    if [ ! -f "$MEOW_OBSIDIAN_FONTE/$arquivo" ]; then
      if meow_seco; then meow_muda "mudaria $tema_dir/$arquivo"; mudou=1; continue; fi
      meow_erro "obsidian: $MEOW_OBSIDIAN_FONTE/$arquivo sumiu no meio da passada — nada escrito"
      return "$MEOW_ERRO"
    fi
    meow_escrever "$tema_dir/$arquivo" "$(cat "$MEOW_OBSIDIAN_FONTE/$arquivo")" 644
    rc=$?
    case $rc in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: falhou ao instalar $arquivo"; return "$MEOW_ERRO" ;;
    esac
  done

  # --- 3.2 — o appearance.json, por MERGE (as chaves dela ficam).
  if [ "$json_pendente" = "1" ]; then
    _meow_obsidian_backup "$appearance" "appearance.json" || {
      meow_erro "obsidian: não consegui fazer backup do appearance.json"
      return "$MEOW_ERRO"
    }
    _meow_obsidian_json aplicar "$appearance" "$MEOW_OBSIDIAN_TEMA" "$_OBS_OUTROS"
    case $? in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: falhou ao mesclar o appearance.json"; return "$MEOW_ERRO" ;;
    esac
  fi

  # --- 3.3 — o git do cofre, se ele for um repositório e o arquivo estiver nele.
  if [ "$git_pendente" = "1" ]; then
    _meow_obsidian_git aplicar "$MEOW_OBSIDIAN_TEMA"
    case $? in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: não consegui pôr o filtro do tema no git do cofre"; return "$MEOW_ERRO" ;;
    esac
  fi

  # O índice do git do cofre fica sabendo que o arquivo é o mesmo (ver `renovar`).
  [ "$json_pendente" = "1" ] || [ "$git_pendente" = "1" ] && _meow_obsidian_git renovar "$MEOW_OBSIDIAN_TEMA"

  if [ "$mudou" = "0" ]; then
    meow_ok "obsidian: $_OBS_EXIBE já estava aplicado"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "obsidian: (seco) aplicaria o $_OBS_EXIBE no vault"
    return "$MEOW_DIVERGENTE"
  fi

  if [ -n "${MEOW_OBSIDIAN_BACKUP_DIR:-}" ] && [ -d "${MEOW_OBSIDIAN_BACKUP_DIR:-}/obsidian" ]; then
    meow_info "obsidian: backup do que existia em $MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  fi
  meow_ok "obsidian: $_OBS_EXIBE aplicado — reabra o app para ver"
  meow_registrar "obsidian: cssTheme=$MEOW_OBSIDIAN_TEMA em $MEOW_OBSIDIAN_VAULT"
  return "$MEOW_DIVERGENTE"
}

# Os temas que o MeowSystem traz, um por linha: `pasta<TAB>nome`. O vendor/
# primeiro, depois o que desceu (só a pasta com a nossa `.meow-origem`). O nome
# sai do manifest de cada um — é a pasta em `themes/` e o `cssTheme`.
_meow_obsidian_nossos() {
  python3 -I - "$MEOW_OBSIDIAN_VENDOR" "$MEOW_OBSIDIAN_BAIXADOS" <<'PYFIM' 2>/dev/null
import json, os, sys

def pastas(base, marca):
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [os.path.join(base, n) for n in nomes
            if not n.startswith(".") and os.path.isdir(os.path.join(base, n))
            and (not marca or os.path.isfile(os.path.join(base, n, marca)))]

for pasta in pastas(sys.argv[1], "") + pastas(sys.argv[2], ".meow-origem"):
    try:
        with open(os.path.join(pasta, "manifest.json"), encoding="utf-8") as fh:
            nome = json.load(fh).get("name")
    except (OSError, ValueError, AttributeError):
        continue
    if isinstance(nome, str) and nome not in ("", ".", "..") and not set("\t\n/") & set(nome) \
       and os.path.isfile(os.path.join(pasta, "theme.css")):
        print(pasta + "\t" + nome)
PYFIM
}

# Os snippets que estão no disco, desmarcados, com o nome de um pack — os que o
# `aplicar` desmarca, e que a frase do fim do desfazer nomeia. Um por linha. A
# régua é a de todos os packs, montada no `_meow_obsidian_packs` (25/09/2026).
_meow_obsidian_snippets_desmarcados() {   # <régua dos packs> <cofre>...
  python3 -I - "$@" <<'PYFIM' 2>/dev/null
import json, os, re, sys

packs = sys.argv[1]
achados = []
for cofre in sys.argv[2:]:
    try:
        with open(os.path.join(cofre, ".obsidian", "appearance.json"), encoding="utf-8") as fh:
            ligados = json.load(fh).get("enabledCssSnippets") or []
        arquivos = sorted(os.listdir(os.path.join(cofre, ".obsidian", "snippets")))
    except (OSError, ValueError, AttributeError):
        continue
    for arq in arquivos:
        nome = arq[:-len(".css")] if arq.endswith(".css") else ""
        if nome and nome not in ligados and nome not in achados \
           and packs and re.search(packs, nome):
            achados.append(nome)
for nome in achados:
    print(nome)
PYFIM
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter obsidian` e o passo 2/6 do `--uninstall`.
#
# A MESMA RECUSA DO `aplicar`, PELO MESMO MOTIVO
#   Com o Obsidian aberto, ele regrava o `appearance.json` ao sair e desfaria o
#   nosso desfazer — o tema voltaria sozinho e pareceria que o comando mentiu.
#   Recusar é a resposta certa, e recusa não é erro (3, "pendente").
#
# `cssTheme=""` É O PADRÃO DO OBSIDIAN, não um valor inventado: é o que o app
# grava quando ela escolhe o tema base na interface.
#
# O QUE NÃO VOLTA: o snippet `dracula_background` que o `aplicar` desmarcou. O
# `.css` dele nunca saiu do disco (ver `_meow_obsidian_json`) — remarcar é um
# clique na interface, e adivinhar por ela seria repor uma escolha que não é
# nossa. A mensagem diz onde está.
#   [P55, 24/09/2026: a mensagem nomeava o `dracula_background` com qualquer
#   cofre e qualquer pack. Agora ela nomeia os snippets que estão no disco,
#   desmarcados, com o nome de um pack — que são os que o `aplicar` desmarca.]
#
# O DESFAZER NÃO DEPENDE DO PACK NO AR — 24/09/2026, P55
#   É a regra do kitty: quem trocou de pack continua com o tema de antes no
#   cofre, e o que diz de quem ele é são os bytes. Nosso é o tema byte a byte
#   igual a um dos que o MeowSystem traz — os de vendor/ e os que desceram para
#   $MEOW_OBSIDIAN_BAIXADOS —, e o `cssTheme` volta ao padrão se for o nome de
#   um deles. Por isso o `detectar` vem sem o pack (`sem-pack`), e um pack sem
#   tema de Obsidian não trava o `--uninstall`. O pack no ar só dá o nome da
#   frase. O que desceu sai por último, depois dos cofres: é a régua do nosso.
#
# TODOS OS COFRES, E EM CADA UM SÓ O QUE É NOSSO — 24/09/2026, revisão da P43
#   Quando o cofre deixou de ser escrito por extenso (item 5 da P43), o desfazer
#   passou a ir ao cofre que o Obsidian abriu por ÚLTIMO — e esse não é, em
#   geral, o que foi tematizado. Medido numa casa de brinquedo com dois cofres
#   (seção 7 do tests/temas-de-apps.sh): tematizado o A, aberto o B com um tema
#   que a pessoa escolheu, o desfazer zerava o `cssTheme` do B e tirava o
#   snippet dele, sem backup, dizia que o tema tinha saído e deixava o A como
#   estava. E como o doctor diário tematiza o cofre da vez, o `--uninstall`
#   deixava o tema em todos os cofres de antes.
#
#   Agora ele passa por TODOS os cofres dos dois obsidian.json, mais o de
#   `MEOW_OBSIDIAN_VAULT`, cada pasta uma vez só. Em cada um saem os arquivos do
#   tema que ainda são byte a byte os nossos, e o `cssTheme` só volta ao padrão
#   se ainda for o nosso (ver `_meow_obsidian_json`). O appearance.json vai para
#   o backup antes de ser reescrito, como no `aplicar`: um arquivo por cofre,
#   com o número e o nome da pasta no rótulo, para saber de onde cada um veio.
meow_app_reverter() {
  # A frase que estava aqui era um chute entre duas das cinco causas que o
  # `detectar` mede. Agora é a medida que fala — e sem o pack (ver acima).
  meow_app_detectar sem-pack || { meow_app_pendente obsidian; return; }
  # O pack no ar só dá o nome da frase; sem resposta, a frase diz de quem é.
  _meow_obsidian_packs || _OBS_PACK_NOME="tema do MeowSystem"

  local -a lidos=() cofres=()
  local -A vistos=()
  local c real
  mapfile -d '' -t lidos < <(_meow_obsidian_cofre todos)
  for c in "$MEOW_OBSIDIAN_VAULT" ${lidos[@]+"${lidos[@]}"}; do
    # O mesmo cofre chega por dois nomes (o link da armadilha 7, os dois
    # obsidian.json): quem decide se já foi visto é a pasta de verdade.
    real="$(readlink -m -- "$c")"
    [ -n "${vistos[$real]:-}" ] && continue
    vistos[$real]=1
    cofres+=("$c")
  done

  # Os nossos: a pasta de onde cada tema sai e o nome dele, e a lista dos nomes,
  # um por linha, que é como o `_meow_obsidian_json` os recebe.
  local -a fontes=() nomes=() baixados=()
  local fonte nome nossos_nomes
  while IFS=$'\t' read -r fonte nome; do
    fontes+=("$fonte"); nomes+=("$nome")
    [ -f "$fonte/.meow-origem" ] && baixados+=("$fonte")
  done < <(_meow_obsidian_nossos)
  nossos_nomes="$(printf '%s\n' ${nomes[@]+"${nomes[@]}"})"
  # A SOBRA DE UMA DESCIDA INTERROMPIDA — 25/09/2026, revisão da P55. O palco do
  # `_meow_obsidian_baixar` (`.meow-descendo.*`) é nosso, e o
  # `_meow_obsidian_nossos` não o vê: pula pasta com ponto, e o palco não tem
  # manifest. Uma descida cortada no meio o deixava ali para sempre — nem este
  # desfazer nem o `--uninstall` o levavam.
  local -a sobras=()
  local sobra
  for sobra in "$MEOW_OBSIDIAN_BAIXADOS"/.meow-descendo.*; do
    [ -d "$sobra" ] && sobras+=("$sobra")
  done

  # Este `local` faz sombra no global só enquanto a função roda: é o que deixa
  # os utilitários lá de cima, que leem MEOW_OBSIDIAN_VAULT, servirem cofre a cofre.
  local MEOW_OBSIDIAN_VAULT tema_dir appearance mudou=0 algum=0 arquivo i k p lista tem
  # Um PAR é um tema nosso achado num cofre: o cofre, o tema e os arquivos que
  # ainda são byte a byte os nossos. Um cofre pode ter mais de um (o de antes
  # da troca de pack e o de agora).
  local -a json_de=() tem_de=() git_de=() par_cofre=() par_tema=() par_arquivos=() com_algo=()

  # Levantar ANTES de recusar por app aberto: com nada a fazer, "já estava
  # desfeito" é 0 mesmo com o Obsidian na tela.
  for i in "${!cofres[@]}"; do
    MEOW_OBSIDIAN_VAULT="${cofres[$i]}"
    appearance="$(_meow_obsidian_appearance)"
    tem=0
    for k in "${!fontes[@]}"; do
      tema_dir="$MEOW_OBSIDIAN_VAULT/.obsidian/themes/${nomes[k]}"
      lista=""
      for arquivo in theme.css manifest.json; do
        _meow_obsidian_igual "${fontes[k]}/$arquivo" "$tema_dir/$arquivo" && lista+=" $arquivo"
      done
      [ -n "$lista" ] || continue
      par_cofre+=("$i"); par_tema+=("${nomes[k]}"); par_arquivos+=("$lista"); tem=1
    done
    json_de[i]=0
    _meow_obsidian_json conferir-desfazer "$appearance" "$nossos_nomes" >/dev/null 2>&1
    case $? in
      0) ;;
      1) json_de[i]=1 ;;
      *) meow_erro "obsidian: não consegui ler o appearance.json de '$MEOW_OBSIDIAN_VAULT'"; return "$MEOW_ERRO" ;;
    esac
    # O filtro do git do cofre (P74 item 8) é nosso, e sai junto.
    git_de[i]=0
    _meow_obsidian_git conferir-desfazer >/dev/null 2>&1 || git_de[i]=1
    [ "${git_de[i]}" = "1" ] && tem=1
    tem_de[i]="$tem"
    [ "$tem" = "1" ] || [ "${json_de[i]}" = "1" ] || continue
    algum=1
    com_algo+=("$MEOW_OBSIDIAN_VAULT")
    # A trava 1 aqui, e não no laço que escreve: cofre em território proibido
    # recusa a rodada inteira ANTES de qualquer escrita, como era com um cofre só.
    meow_destino_permitido "$appearance" || return "$MEOW_ERRO"
  done
  [ "${#baixados[@]}" -gt 0 ] && algum=1
  [ "${#sobras[@]}" -gt 0 ] && algum=1

  if [ "$algum" = "0" ]; then
    # A PASTA VAZIA DO QUE DESCE TAMBÉM SAI AQUI — 25/09/2026, P61. Até a P61 o
    # `aplicar` sem rede a deixava vazia, e este caminho, que é o de nada
    # nosso para tirar, a deixava também. Pasta vazia não é tema: a frase
    # continua dizendo que ele não estava, e a saída continua 0.
    meow_seco || rmdir -- "$MEOW_OBSIDIAN_BAIXADOS" 2>/dev/null
    meow_ok "obsidian: já estava sem o $_OBS_PACK_NOME"
    return "$MEOW_OK"
  fi

  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: o app está ABERTO — nada foi escrito."
    meow_aviso "obsidian: ele regrava o appearance.json ao sair e traria o tema de volta."
    meow_aviso "obsidian: aberto agora; a próxima passada com ele fechado aplica."
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # Zerado a cada execução para o backup ser um diretório só por rodada.
  unset MEOW_OBSIDIAN_BACKUP_DIR

  for i in "${!cofres[@]}"; do
    [ "${tem_de[i]}" = "1" ] || [ "${json_de[i]}" = "1" ] || continue
    MEOW_OBSIDIAN_VAULT="${cofres[$i]}"
    appearance="$(_meow_obsidian_appearance)"

    if meow_seco; then
      for p in "${!par_cofre[@]}"; do
        [ "${par_cofre[p]}" = "$i" ] || continue
        meow_muda "obsidian: removeria${par_arquivos[p]} de $MEOW_OBSIDIAN_VAULT/.obsidian/themes/${par_tema[p]}"
      done
      [ "${json_de[i]}" = "1" ] && meow_muda "obsidian: cssTheme de '$MEOW_OBSIDIAN_VAULT' voltaria ao padrão do app"
      [ "${git_de[i]}" = "1" ] && _meow_obsidian_git desfazer
      continue
    fi

    # 0. o filtro do git do cofre (P74 item 8), antes do appearance.json: sem
    #    ele, o desfazer abaixo é o que o git guardaria.
    if [ "${git_de[i]}" = "1" ]; then
      _meow_obsidian_git desfazer
      case $? in
        0|1) mudou=1 ;;
        *) meow_erro "obsidian: não consegui tirar o filtro do git de '$MEOW_OBSIDIAN_VAULT'"; return "$MEOW_ERRO" ;;
      esac
    fi

    # 1. os dois arquivos de cada tema nosso — só saem os que ainda são byte a
    #    byte os nossos. Um `theme.css` que ela editou deixou de ser nosso e fica.
    #    (A lista é de nomes fixos, sem espaço: pode ser partida pelo `for`.)
    for p in "${!par_cofre[@]}"; do
      [ "${par_cofre[p]}" = "$i" ] || continue
      tema_dir="$MEOW_OBSIDIAN_VAULT/.obsidian/themes/${par_tema[p]}"
      for arquivo in ${par_arquivos[p]}; do
        if rm -f "$tema_dir/$arquivo"; then mudou=1; else
          meow_erro "obsidian: não consegui remover $tema_dir/$arquivo"; return "$MEOW_ERRO"
        fi
      done
      # `rmdir` sem `-p` e sem `-f`: some se ficou vazio, fica se ela pôs algo lá.
      [ -d "$tema_dir" ] && rmdir "$tema_dir" 2>/dev/null
      meow_muda "obsidian: tema ${par_tema[p]} removido de '$MEOW_OBSIDIAN_VAULT'"
    done

    # 2. o appearance.json, pelo mesmo varredor que o aplicou. O python grava
    #    direto (não passa por `meow_escrever`), então nada disto entra no
    #    manifesto — que é o que impede o desinstalador de apagar o arquivo depois.
    if [ "${json_de[i]}" = "1" ]; then
      _meow_obsidian_backup "$appearance" "$((i + 1))-$(basename -- "$MEOW_OBSIDIAN_VAULT")-appearance.json" || {
        meow_erro "obsidian: não consegui fazer backup do appearance.json de '$MEOW_OBSIDIAN_VAULT'"
        return "$MEOW_ERRO"
      }
      _meow_obsidian_json desfazer "$appearance" "$nossos_nomes"
      case $? in
        0|1) mudou=1; meow_muda "obsidian: cssTheme de '$MEOW_OBSIDIAN_VAULT' de volta ao padrão do app" ;;
        *) meow_erro "obsidian: falhou ao devolver o appearance.json de '$MEOW_OBSIDIAN_VAULT'"; return "$MEOW_ERRO" ;;
      esac
    fi
  done

  # 3. o que desceu, por último: é a régua do "nosso" dos cofres acima, e sem
  #    ele um tema baixado que ficou num cofre deixaria de ser reconhecido.
  for fonte in ${baixados[@]+"${baixados[@]}"}; do
    if meow_seco; then meow_muda "obsidian: removeria o tema baixado em $fonte"; continue; fi
    if rm -rf -- "$fonte"; then mudou=1; meow_muda "obsidian: o tema baixado saiu de $fonte"; else
      meow_erro "obsidian: não consegui remover $fonte"; return "$MEOW_ERRO"
    fi
  done
  for sobra in ${sobras[@]+"${sobras[@]}"}; do
    if meow_seco; then meow_muda "obsidian: removeria a sobra de uma descida interrompida, $sobra"; continue; fi
    if rm -rf -- "$sobra"; then mudou=1; meow_muda "obsidian: a sobra de uma descida interrompida saiu de $sobra"; else
      meow_erro "obsidian: não consegui remover $sobra"; return "$MEOW_ERRO"
    fi
  done
  meow_seco && return "$MEOW_DIVERGENTE"
  # A pasta do que desceu também é nossa, e vazia sai, como a do Telegram
  # (25/09/2026). Com alguma coisa que não é nossa lá dentro, o `rmdir` a deixa.
  rmdir -- "$MEOW_OBSIDIAN_BAIXADOS" 2>/dev/null || true

  [ "$mudou" = "0" ] && { meow_ok "obsidian: já estava sem o $_OBS_PACK_NOME"; return "$MEOW_OK"; }
  if [ -n "${MEOW_OBSIDIAN_BACKUP_DIR:-}" ] && [ -d "${MEOW_OBSIDIAN_BACKUP_DIR:-}/obsidian" ]; then
    meow_info "obsidian: backup do que existia em $MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  fi
  meow_ok "obsidian: sem o $_OBS_PACK_NOME — reabra o app para ver"
  while IFS= read -r nome; do
    [ -n "$nome" ] && meow_info "o snippet '$nome' continua no disco, desmarcado: Aparência > Snippets CSS"
  done < <(_meow_obsidian_snippets_desmarcados "$_OBS_PACKS" ${com_algo[@]+"${com_algo[@]}"})
  meow_info "tire 'obsidian' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
