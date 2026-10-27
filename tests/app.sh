#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

_TMP_DO_TESTE="$(mktemp -d)" || exit 2
trap 'rm -rf "$_TMP_DO_TESTE"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export TMPDIR="$_TMP_DO_TESTE"
EXEMPLO="$RAIZ/meow.conf.exemplo"
falhas=0

command -v python3 >/dev/null || { printf 'pulado: sem python3\n'; exit 0; }

python3 -m py_compile "$RAIZ/app/servidor.py" || {
  printf 'FALHOU: app/servidor.py não compila\n' >&2; exit 1; }

esquema_bash="$(
  MEOW_RAIZ="$RAIZ" bash -c '
    set -uo pipefail
    . "'"$RAIZ"'/lib/comum.sh"
    RAIZ="'"$RAIZ"'"
    CONF_PADRAO="'"$EXEMPLO"'"
    logos_disponiveis() { :; }   # o painel lê os mascotes do disco; aqui não importa
    # AS DECLARAÇÕES VÊM ANTES, E SEM ELAS O TESTE MORRE COM UM ERRO ENIGMÁTICO
    #   No `bin/meow` estes arrays são declarados FORA das funções, e o recorte
    #   abaixo pega só as funções. Sem o `declare -A`, `WIZ_AJUDA[$chave]="..."`
    #   trata `$chave` como ÍNDICE ARITMÉTICO de um array indexado — ou seja, o
    #   bash avalia a string `FLAVOR` como expressão, e com `set -u` isso morre
    #   com "FLAVOR: variável não associada", que não tem nada a ver com o que
    #   está sendo testado. Foi exatamente o que aconteceu na primeira execução.
    declare -a WIZ_CHAVES=()
    declare -A WIZ_AJUDA=() WIZ_SECAO=() WIZ_ESSENCIAL=()
    # As funções do wizard, recortadas do arquivo vivo.
    eval "$(sed -n "/^wiz_ler_esquema() {/,/^}/p"      "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_valor_da_linha() {/,/^}/p"   "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_linha_da_chave() {/,/^}/p"   "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_comentario_da_linha() {/,/^}/p" "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_opcoes() {/,/^}/p"           "$RAIZ/bin/meow")"
    wiz_ler_esquema || exit 2
    for k in "${WIZ_CHAVES[@]}"; do
      linha="$(wiz_linha_da_chave "$k" "$CONF_PADRAO")"
      valor="$(wiz_valor_da_linha "$linha")"
      inline="$(wiz_comentario_da_linha "$linha")"
      opc="$(wiz_opcoes "$k" "${WIZ_AJUDA[$k]:-}" "$inline" | grep -v "^vazio$" | paste -sd, -)"
      printf "%s\t%s\t%s\n" "$k" "$valor" "$opc"
    done
  '
)" || { printf 'FALHOU: não consegui rodar a leitura do bin/meow\n' >&2; exit 1; }

esquema_py="$(
  MEOW_RAIZ="$RAIZ" python3 - "$RAIZ" <<'PY'
import sys, os
raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor
for i in servidor.ler_esquema():
    if i["chave"] in ("LOGO", "LOGO_DIA", "LOGO_NOITE", "FASTFETCH_LOGO_GATO"):
        opc = ""
    else:
        bruto = servidor._opcoes(i["chave"], i["ajuda"], i["inline"])
        opc = ",".join(o for o in bruto if o != "vazio")
    print("%s\t%s\t%s" % (i["chave"], i["padrao"], opc))
PY
)" || { printf 'FALHOU: não consegui rodar a leitura do app/servidor.py\n' >&2; exit 1; }

esquema_bash="$(printf '%s\n' "$esquema_bash" | awk -F'\t' -v OFS='\t' '
  $1=="LOGO"||$1=="LOGO_DIA"||$1=="LOGO_NOITE"||$1=="FASTFETCH_LOGO_GATO" {$3=""}
  {print}')"

if [ "$esquema_bash" != "$esquema_py" ]; then
  printf 'FALHOU: o wizard (bash) e o painel (python) leem o meow.conf.exemplo diferente.\n\n' >&2
  diff <(printf '%s\n' "$esquema_bash") <(printf '%s\n' "$esquema_py") \
    | sed 's/^</  bin\/meow  /; s/^>/  servidor  /' >&2
  falhas=$((falhas+1))
else
  n="$(printf '%s\n' "$esquema_py" | grep -c .)"
  printf 'ok: as %s chaves leem igual no bin/meow e no app/servidor.py\n' "$n"
fi

python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import re, sys, os
raiz = sys.argv[1]
falhou = 0

css = open(os.path.join(raiz, "app/pagina/estilo.css"), encoding="utf-8").read()
css_sem_comentario = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
hex_achados = re.findall(r"#[0-9A-Fa-f]{3,8}\b", css_sem_comentario)
if hex_achados:
    print("FALHOU: há hex no CÓDIGO de estilo.css — a cor tem de vir da paleta: %s"
          % ", ".join(sorted(set(hex_achados))), file=sys.stderr)
    falhou = 1
else:
    print("ok: estilo.css não tem um hex fora de comentário — a cor vem de /paleta.css")

sys.path.insert(0, os.path.join(raiz, "app"))
import servidor
escorregou = [
    i["chave"] for i in servidor.ler_esquema()
    if i["opcoes"] == ["sim", "nao"]
    and not servidor._opcoes(i["chave"], i["ajuda"], i["inline"])
    and i["padrao"] not in ("sim", "nao")
]
if escorregou:
    print("FALHOU: sim/nao inferido para chave que não é binária: %s"
          % ", ".join(escorregou), file=sys.stderr)
    falhou = 1
else:
    n = sum(1 for i in servidor.ler_esquema() if i["opcoes"] == ["sim", "nao"])
    print("ok: as %d chaves com dois botões sim/nao têm padrão `sim` ou `nao`" % n)

import re as _re, subprocess as _sp

_IDIOMA = _re.compile(r'^\s*([A-Z][A-Z0-9_]{2,})="\$\{\1:[-=]', _re.M)
_NAO_E_AJUSTE = {
    "APROXIMOU",
    "FORMA_COMP_BIN",
    "FZF_ALVO",
    "GREETER_HOME",
    "PROMPT_ALVO",
    "SOM_DURACAO",
    "SOM_GANHO",
    "VIDRO_OPACIDADE",
}
_INTERNAS = _re.compile(r"^(MEOW_|FFL_|CP_|CV_|PA_|AP_|AS_|OT_|GB_|SN_|SPICE_|XDG_|ZDOTDIR|TMPDIR|NO_COLOR)")

_catalogo = {i["chave"] for i in servidor.ler_esquema()}
_lidas = {}
for _f in _sp.run(["git", "ls-files"], cwd=raiz, capture_output=True,
                  text=True).stdout.split():
    if not _f.endswith(".sh") or _f.startswith("tests/"):
        continue
    try:
        _txt = open(os.path.join(raiz, _f), encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for _m in _IDIOMA.finditer(_txt):
        _k = _m.group(1)
        if not _INTERNAS.match(_k) and _k not in _NAO_E_AJUSTE:
            _lidas.setdefault(_k, set()).add(_f)

import importlib.util as _ilu
_spec = _ilu.spec_from_file_location("meow_migrar_conf", os.path.join(raiz, "scripts", "migrar_conf.py"))
_migrar = _ilu.module_from_spec(_spec); _spec.loader.exec_module(_migrar)
_aposentadas = set(getattr(_migrar, "APOSENTADAS", {}))
_com_cartao = sorted(_aposentadas & _catalogo)
if _com_cartao:
    print("FALHOU: chave aposentada ainda tem cartão no painel: %s" % ", ".join(_com_cartao),
          file=sys.stderr)
    falhou = 1
_sem_cartao = sorted(k for k in _lidas if k not in _catalogo and k not in _aposentadas)
if _sem_cartao:
    print("FALHOU: script lê do meow.conf e o painel não oferece: %s"
          % ", ".join("%s (%s)" % (k, ", ".join(sorted(_lidas[k]))) for k in _sem_cartao),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: as %d chaves que os scripts leem do conf têm cartão no painel"
          % len(_lidas))

_sh_codigo = {}
for _f in _sp.run(["git", "ls-files", "scripts"], cwd=raiz, capture_output=True,
                  text=True).stdout.split():
    if _f.endswith(".sh"):
        _txt = open(os.path.join(raiz, _f), encoding="utf-8", errors="replace").read()
        _sh_codigo[_f] = "\n".join(l for l in _txt.splitlines() if not l.lstrip().startswith("#"))
_sem_escritor = []
for _k, (_arq, _traduz) in sorted(servidor.NA_MAQUINA.items()):
    _programa = _arq.split("/")[0].split(".")[2]
    _nome = os.path.basename(_arq)
    if not any(_programa in _t and _nome in _t for _t in _sh_codigo.values()):
        _sem_escritor.append("%s (%s)" % (_k, _arq))
_fora = sorted(k for k in servidor.NA_MAQUINA if k not in _catalogo)
if _sem_escritor or _fora:
    print("FALHOU: o painel lê da máquina o que nenhum script grava: %s; fora do catálogo: %s"
          % (", ".join(_sem_escritor) or "—", ", ".join(_fora) or "—"), file=sys.stderr)
    falhou = 1
else:
    print("ok: as %d chaves que o painel lê da máquina saem de arquivos que os scripts gravam"
          % len(servidor.NA_MAQUINA))

_js = re.sub(r"/\*.*?\*/", "", open(os.path.join(raiz, "app/pagina/app.js"),
                                    encoding="utf-8").read(), flags=re.S)
_js = "\n".join(l for l in _js.splitlines() if not l.lstrip().startswith("//"))
_guardado = re.findall(r"meow-seco", _js)
_guardado += [l.strip() for l in _js.splitlines()
              if re.search(r"(session|local)Storage", l) and re.search(r"\bseco\b", l)]
_py = "\n".join(l for l in open(os.path.join(raiz, "app/servidor.py"), encoding="utf-8")
                .read().splitlines() if not l.lstrip().startswith("#"))
_ligam = re.findall(r"""\[["']MEOW_DRY_RUN["']\]\s*=""", _py)
if _guardado or len(_ligam) != 1 or "_ambiente_do_painel(seco=False)" not in _py:
    print("FALHOU: o interruptor de ensaio voltou ao painel: guardado=%s, "
          "ligações de MEOW_DRY_RUN=%d (espera 1), assinatura do ambiente=%s"
          % (sorted(set(_guardado)) or "—", len(_ligam),
             "ok" if "_ambiente_do_painel(seco=False)" in _py else "mudou"),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: o ensaio é pedido por gesto, e não guardado num interruptor")

_pecas = [("o botão do diálogo", "confirmar-ensaio", _js),
          ("o botão da barra do alto", "botao-ensaiar", _js),
          ("a faixa da gaveta", "faixa-ensaio", _js),
          ("o «Rodar de verdade» pós-ensaio", "ensaio-rodar", _js),
          ("a cópia descartável do ensaio", "_conf_de_ensaio", _py),
          ("o MEOW_CONF do ensaio", 'ambiente["MEOW_CONF"]', _py),
          ("o seco no /api/rodar", 'corpo.get("seco")', _py),
          ("o seco no /api/salvar", 'corpo.get("seco")', _py)]
_faltam = ["%s (%s)" % (nome, marca) for nome, marca, onde in _pecas if marca not in onde]
if _faltam:
    print("FALHOU: o ensaio da sprint P8 sumiu da tela: %s" % ", ".join(_faltam),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: o «Ver sem mudar» está no diálogo, na barra e na janela de resultado")

import hashlib as _hl
import shutil as _sh
import tempfile as _tf9
_d9 = _tf9.mkdtemp()
_dela = os.path.join(_d9, "meow.conf")
_sh.copyfile(os.path.join(raiz, "meow.conf.exemplo"), _dela)
_antes9 = _hl.sha256(open(_dela, "rb").read()).hexdigest()
_conf_dela9 = servidor.CONF
_erros9 = []
_faz_ensaio = getattr(servidor, "_conf_de_ensaio", None)
if _faz_ensaio is None:
    _pasta9, _queixa9 = None, "o _conf_de_ensaio não existe (ver a trava acima)"
else:
    try:
        servidor.CONF = _dela
        _pasta9, _queixa9 = _faz_ensaio([("FLAVOR", "frappe")])
    finally:
        servidor.CONF = _conf_dela9
if _queixa9:
    _erros9.append("o ensaio não conseguiu preparar a cópia: %s" % _queixa9)
else:
    _copia9 = os.path.join(_pasta9, "meow.conf")
    if 'FLAVOR="frappe"' not in open(_copia9, encoding="utf-8").read():
        _erros9.append("a escolha não entrou na cópia que o install.sh vai ler")
    if (servidor.conf_exportada(_copia9) or {}).get("FLAVOR") != "frappe":
        _erros9.append("a conf exportada da cópia ainda diz o FLAVOR do disco")
    _sh.rmtree(_pasta9, ignore_errors=True)
if _hl.sha256(open(_dela, "rb").read()).hexdigest() != _antes9:
    _erros9.append("o ensaio mexeu no meow.conf dela — é a promessa inteira da palavra")
_sh.rmtree(_d9, ignore_errors=True)
if _erros9:
    print("FALHOU: o ensaio do «Salvar e aplicar»: " + "; ".join(_erros9), file=sys.stderr)
    falhou = 1
else:
    print("ok: o ensaio lê as escolhas numa cópia e não toca no meow.conf dela")

import inspect as _inspect9
_ini9 = _inspect9.getsource(servidor.iniciar)
_falta9 = [v for v in ("MEOW_ICONES_ESCOLHAS", "MEOW_ICONES_TRACO") if v not in _ini9]
if _falta9:
    print("FALHOU: o ensaio do «Salvar e aplicar» não leva os mapas de ícone dela: "
          + ", ".join(_falta9), file=sys.stderr)
    falhou = 1
else:
    print("ok: o ensaio lê os mapas de ícone de quem usa, e não os da pasta da cópia")

_erros9f = []
for _id9f, _a9f in servidor.ACOES.items():
    _alvo9f = _a9f.get("conserta_com")
    if _alvo9f and (_alvo9f not in servidor.ACOES or not servidor.escreve(servidor.ACOES[_alvo9f])):
        _erros9f.append("%s conserta com %r, que não é ação que escreve" % (_id9f, _alvo9f))
if servidor.ACOES.get("doctor", {}).get("conserta_com") != "doctor_consertar":
    _erros9f.append("o «Conferir a máquina» não declara o «Consertar o que estiver fora»")
_js9f = open(os.path.join(raiz, "app/pagina/app.js"), encoding="utf-8").read()
if ('"conserta_com"' not in _inspect9.getsource(servidor)
        or "conserta: trabalho.conserta_com" not in _js9f or '"resultado:consertar"' not in _js9f):
    _erros9f.append("o trabalho não leva a `conserta_com` à gaveta, ou a gaveta não a oferece")
if _erros9f:
    print("FALHOU: " + "; ".join(_erros9f), file=sys.stderr)
    falhou = 1
else:
    print("ok: o «há divergências» do conferir oferece o botão do conserto na gaveta")

import inspect as _inspect
import tempfile as _tf
_d = _tf.mkdtemp()
_bom, _quebrado = os.path.join(_d, "bom.conf"), os.path.join(_d, "quebrado.conf")
with open(_bom, "w", encoding="utf-8") as _fh:
    _fh.write('FLAVOR="latte"\nICONES_COR_MARCA="sim"   # sim | nao\n'
              'ICONES_PASTAS="cat-${FLAVOR}"\n')
with open(_quebrado, "w", encoding="utf-8") as _fh:
    _fh.write('FLAVOR="latte\n')
_conf_dela = servidor.CONF
try:
    servidor.CONF = _bom
    _exp = servidor.conf_exportada() or {}
    servidor.CONF = _quebrado
    _exp_quebrado = servidor.conf_exportada()
finally:
    servidor.CONF = _conf_dela
_erros10 = []
for _k, _v in (("ICONES_COR_MARCA", "sim"), ("FLAVOR", "latte"), ("ICONES_PASTAS", "cat-latte"),
               ("MODO", "escuro")):
    if _exp.get(_k) != _v:
        _erros10.append("%s saiu %r, e não %r" % (_k, _exp.get(_k), _v))
if _exp_quebrado is not None:
    _erros10.append("um conf com erro de sintaxe virou ambiente em vez de recusa")
_ini = _inspect.getsource(servidor.iniciar)
if "conf_exportada(" not in _ini or "ambiente.update(conf)" not in _ini:
    _erros10.append("o iniciar não põe a conf no ambiente do trabalho")
_m = servidor.Manipulador.__new__(servidor.Manipulador)
_tr = _m._travas_do_arcticons()
if not _tr[0]:
    _erros10.append("a lista INTOCAVEIS do script não foi lida")
if not _m._motivo_da_trava(_tr, ["hefesto-dualsense4unix"], "Hefesto"):
    _erros10.append("o Hefesto, intocável, não trava")
if _tr[3] and not _m._motivo_da_trava(_tr, [sorted(_tr[3])[0]], "x"):
    _erros10.append("um app do acervo convertido não trava")
if _m._motivo_da_trava(_tr, ["org.exemplo.NaoExiste"], "x") is not None:
    _erros10.append("um app sem nenhuma das três travas travou")
if _erros10:
    print("FALHOU: " + "; ".join(_erros10), file=sys.stderr)
    falhou = 1
else:
    print("ok: o trabalho leva a conf do set -a, e as travas do traço chegam ao servidor")

py = open(os.path.join(raiz, "app/servidor.py"), encoding="utf-8").read().splitlines()
codigo = [l for l in py if not l.lstrip().startswith("#")]
if any("shell=True" in l for l in codigo):
    print("FALHOU: app/servidor.py usa shell=True no código", file=sys.stderr)
    falhou = 1
else:
    print("ok: o servidor não tem shell=True em lugar nenhum do código")
sys.exit(falhou)
PY

_tmp11="$(mktemp -d)"
HOME="$_tmp11/casa" MEOW_CONF="$_tmp11/casa/.config/meow/meow.conf" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import os, subprocess, sys
raiz = sys.argv[1]
casa = os.environ["HOME"]
conf = os.environ["MEOW_CONF"]
os.makedirs(os.path.dirname(conf))
with open(os.path.join(raiz, "meow.conf.exemplo"), encoding="utf-8") as fh:
    exemplo = fh.read()
vazia = 'WALLPAPER_FONTES_PERMITIDAS=""'
if vazia not in exemplo:
    print("FALHOU: o meow.conf.exemplo não tem mais a linha %s" % vazia, file=sys.stderr)
    sys.exit(1)
sentinela = "meow-teste-sentinela"
base_velha = 'WALLPAPER_BASE="$HOME/.local/share/backgrounds/meowsystem"'
if base_velha not in exemplo:
    print("FALHOU: o meow.conf.exemplo não tem mais a linha %s" % base_velha, file=sys.stderr)
    sys.exit(1)
fora = os.path.join(os.path.dirname(casa), "disco", sentinela, "wallpapers")
os.makedirs(os.path.join(fora, "ativos"))
with open(os.path.join(fora, "ativos", "gato.png"), "wb") as fh:
    fh.write(bytes.fromhex("89504e470d0a1a0a0000000d4948445200000001000000010806000000"
                           "1f15c4890000000d4944415478da63f8ffff3f0005fe02fea7d6a4"
                           "8f0000000049454e44ae426082"))
with open(conf, "w", encoding="utf-8") as fh:
    fh.write(exemplo.replace(vazia, 'WALLPAPER_FONTES_PERMITIDAS="$HOME/Imagens:/run/media/%s/HD"'
                             % sentinela)
             .replace(base_velha, 'WALLPAPER_BASE="%s"' % fora))
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor

erros = []
imagem = os.path.join(casa, "Imagens", "Parede_papel", "Cyberpunk Neon Cat.jpeg")
cache = os.path.join(casa, ".local", "share", "icons", "Meow", "icon-theme.cache")
for impresso, corte, alvo in (
        ('  meow wallpaper permitir "%s"' % imagem, " permitir ", imagem),
        ("  apague o arquivo: rm '%s'" % cache, " rm ", cache),
        ('  meow wallpaper permitir "%s"' % casa, " permitir ", casa)):
    tela = servidor.texto_na_tela(impresso)
    if casa in tela:
        erros.append("a casa ficou na tela: %r" % tela)
        continue
    colado = subprocess.run(["bash", "-c", 'printf "%s\\n" ' + tela.split(corte, 1)[1]],
                            capture_output=True, text=True, cwd="/").stdout
    if colado != alvo + "\n":
        erros.append("%r colado vira %r, e não o caminho da casa" % (tela.strip(), colado))
for vizinho in (casa + "zinho/x", "'%szinho/x'" % casa):
    if servidor.texto_na_tela(vizinho) != vizinho:
        erros.append("a casa comeu o vizinho: %r virou %r"
                     % (vizinho, servidor.texto_na_tela(vizinho)))

html, _ = servidor.Manipulador.__new__(servidor.Manipulador)._exportar_pagina()
if sentinela in html:
    erros.append("a página exportada leva o nome de usuário de uma fonte fora da casa "
                 "%d vez(es)" % html.count(sentinela))
if casa in html:
    erros.append("a página exportada leva a casa %d vez(es)" % html.count(casa))
if "$WALLPAPER_BASE/ativos/gato.png" not in html:
    erros.append("a foto do acervo de fora sumiu da página, em vez de sair sem a pasta")

if erros:
    print("FALHOU: " + "; ".join(erros), file=sys.stderr)
    sys.exit(1)
print("ok: o comando da gaveta cola com a casa entre aspas, e a página exportada não "
      "leva caminho de fora da casa")
PY
rm -rf "$_tmp11"

_tmp12="$(mktemp -d)"
HOME="$_tmp12/casa" MEOW_CONF="$_tmp12/casa/.config/meow/meow.conf" \
MEOW_ESTADO="$_tmp12/casa/.local/state/meowsystem" \
MEOW_COSMIC_DIR="$_tmp12/casa/.config/cosmic" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import os, re, subprocess, sys, time
raiz = sys.argv[1]
casa = os.environ["HOME"]
conf = os.environ["MEOW_CONF"]
cosmic = os.environ["MEOW_COSMIC_DIR"]
os.makedirs(os.path.dirname(conf))
with open(os.path.join(raiz, "meow.conf.exemplo"), encoding="utf-8") as fh:
    exemplo = fh.read()
if not re.search(r'^LOGO_MODO="hora"', exemplo, re.M):
    print('FALHOU: o meow.conf.exemplo não tem mais LOGO_MODO="hora"', file=sys.stderr)
    sys.exit(1)


def conf_com(**chaves):
    texto = exemplo
    for k, v in chaves.items():
        texto, n = re.subn(r'^%s="[^"]*"' % k, '%s="%s"' % (k, v), texto, count=1, flags=re.M)
        if not n:
            texto += '\n%s="%s"\n' % (k, v)
    with open(conf, "w", encoding="utf-8") as fh:
        fh.write(texto)


conf_com()
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor

erros = []

classes = {"ok", "correndo", "pula", "erro"}
for ident, acao in servidor.ACOES.items():
    nat = acao.get("natureza")
    if nat not in servidor.NATUREZAS:
        erros.append("a ação %s não declara uma natureza conhecida (%r)" % (ident, nat))
for nat, tabela in servidor.NATUREZAS.items():
    for cod, (classe, frase) in tabela.items():
        if classe not in classes or not frase or cod not in ("0", "0~", "1"):
            erros.append("a natureza %s tem a linha %s mal formada: %r" % (nat, cod, (classe, frase)))
fim = servidor.fim_da_acao
if not erros:
    if fim("painel_reciclar")["0"][1] == "já estava certo" or "0~" not in fim("painel_reciclar"):
        erros.append("«Recarregar o painel» ainda pode dizer «já estava certo» depois de reciclar")
    if "consert" in fim("wallpaper_proximo")["1"][1]:
        erros.append("«Próxima imagem» ainda termina dizendo que consertou")
    if fim("som_ouvir")["0"][1] != "tocou":
        erros.append("«Ouvir o som» não termina dizendo que tocou: %r" % (fim("som_ouvir")["0"],))
    if fim("instalar")["1"][0] == "ok":
        erros.append("o 1 do instalador (o tema que não chegou, P48) ainda é verde")
    if re.search(r"aplicou|consertou", fim("doctor_consertar")["0~"][1]):
        erros.append("o conserto que não consertou nada ainda diz que aplicou")
    for ident in servidor.ACOES:
        for cod, (_c, frase) in fim(ident, seco=True).items():
            if re.search(r"aplicou|consertou|trocou|gravou|tirou|devolveu|baixou|tocou|recarregou",
                         frase):
                erros.append("o ensaio de %s diz %r — num ensaio nada foi feito" % (ident, frase))
                break

esperado = "«Conferir e consertar», em Cuidar › Estado"
if servidor.onde_na_tela("doctor_consertar") != esperado:
    erros.append("--onde doctor_consertar diz %r, e não %r"
                 % (servidor.onde_na_tela("doctor_consertar"), esperado))
if servidor.onde_na_tela("areas-sem-alfinete") != "«Resolver», em %s" % servidor.porta_das_pendencias():
    erros.append("--onde de uma pendência não diz o «Resolver» da lista dela")
oculta = next(k for k, a in servidor.ACOES.items() if a.get("oculta"))
if servidor.onde_na_tela(oculta) or servidor.onde_na_tela("nao-existe"):
    erros.append("--onde cita um botão que não tem cartão (%s) ou que não existe" % oculta)
modulos = os.path.join(raiz, "scripts", "temas-de-apps")
com_modulo = next(n for n in sorted(os.listdir(modulos))
                  if os.path.isfile(os.path.join(modulos, n, "manifesto.sh")))
onde = servidor.onde_na_tela(com_modulo + servidor.SUFIXO_TEMA_DE_TERCEIRO)
if not all("«%s»" % r in onde for _a, r in servidor.ESCOLHA_TEMA_DE_TERCEIRO) \
        or not onde.endswith("em %s" % servidor.porta_das_pendencias()):
    erros.append("--onde da pendência de tema de terceiro de %s não cita os botões da lista: %r"
                 % (com_modulo, onde))
def curto(t):
    return bool(t) and len(t.split()) <= 3 and t[0].isupper()
longos = ["%s: %r" % (k, a["rotulo"]) for k, a in servidor.ACOES.items() if not curto(a["rotulo"])]
assert servidor.PENDENCIAS.startswith(casa), servidor.PENDENCIAS
os.makedirs(os.path.dirname(servidor.PENDENCIAS), exist_ok=True)
with open(servidor.PENDENCIAS, "w", encoding="utf-8") as fh:
    fh.write("%s\twallpaper.sh\tA saída voltou\t%s/x/y.png\t2026-10-23T00:00:00-03:00\n"
             % (servidor.PENDENCIA_PAREDE, servidor.PREFIXO_PERMITIR.strip()))
    fh.write("%s\tvscode\tExtensão\tmeow apps aplicar vscode\t2026-10-23T00:00:00-03:00\n"
             % servidor.PENDENCIA_EXTENSAO)
    fh.write("files-menu-build\tfiles_menu.sh\tO menu compila\t\t2026-10-23T00:00:00-03:00\n")
    fh.write("%s%s\tlib\tTema de fora\tmeow apps aplicar %s\t2026-10-23T00:00:00-03:00\n"
             % (com_modulo, servidor.SUFIXO_TEMA_DE_TERCEIRO, com_modulo))
for p in servidor.pendencias():
    if p["nome"] and not curto(p["nome"]):
        longos.append("pendência %s: %r" % (p["id"], p["nome"]))
    longos += ["botão de %s: %r" % (p["id"], e["rotulo"]) for e in p["escolha"]
               if not curto(e["rotulo"]) and not e["rotulo"].startswith("Instalar ")]
os.remove(servidor.PENDENCIAS)
if longos:
    erros.append("12c: nome ou botão com mais de três palavras, ou sem maiúscula: %s" % "; ".join(longos[:6]))
if servidor.onde_na_tela("sem-modulo-nenhum" + servidor.SUFIXO_TEMA_DE_TERCEIRO):
    erros.append("--onde cita os botões do tema de terceiro para um app sem módulo")
porta = subprocess.run(["bash", "-c", '. "$1/lib/comum.sh"; meow_onde_no_painel doctor_consertar',
                        "_", raiz], capture_output=True, text=True, env=dict(os.environ))
if porta.stdout.strip() != esperado:
    erros.append("o meow_onde_no_painel do lib/comum.sh diz %r" % porta.stdout.strip())
for extra in ([], ["doctor", "instalar"]):
    try:
        r = subprocess.run([sys.executable, os.path.join(raiz, "app", "servidor.py"), "--onde"]
                           + extra, capture_output=True, text=True, timeout=20)
        if r.returncode != 2 or "http" in r.stdout:
            erros.append("--onde com %d argumento(s) não recusou: rc=%s %r"
                         % (len(extra), r.returncode, r.stdout[:80]))
    except subprocess.TimeoutExpired:
        erros.append("--onde com %d argumento(s) subiu o servidor" % len(extra))
for rel in ("scripts", "bin", "lib", "install.sh"):
    base = os.path.join(raiz, rel)
    arquivos = ([base] if os.path.isfile(base) else
                [os.path.join(d, n) for d, _s, ns in os.walk(base) for n in ns])
    for arq in arquivos:
        try:
            linhas = open(arq, encoding="utf-8").read().splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        for n, l in enumerate(linhas, 1):
            if l.lstrip().startswith("#"):
                continue
            if "Instalar e conferir" in l or "«Resolver» no painel" in l:
                erros.append("nome de tela escrito à mão em %s:%d" % (os.path.relpath(arq, raiz), n))

conf_com(LOGO_MODO="hora")
trocar, girar = servidor.indisponivel("logo_trocar"), servidor.indisponivel("logo_girar")
if trocar != {"chave": "LOGO_MODO", "vale": "hora", "pede": "fixo"}:
    erros.append("com o mascote por horário, «Pôr um mascote no dock» não se apaga: %r" % (trocar,))
if not girar or girar.get("pede") != "rotacao":
    erros.append("com o mascote por horário, «Passar ao próximo mascote» não se apaga: %r" % (girar,))
trabalho, erro = servidor.iniciar("logo_trocar", "coquinha")
if trabalho is not None or not erro:
    if trabalho is not None:
        trabalho.parar()
    erros.append("o servidor rodou «Pôr um mascote no dock» apagado")
conf_com(LOGO_MODO="fixo")
if servidor.indisponivel("logo_trocar") or not servidor.indisponivel("logo_girar"):
    erros.append("com o mascote fixo, o «Pôr» tem de acender e o «Passar ao próximo» não")
conf_com(LOGO_MODO="", LOGO_ROTACAO="sim")
trocar, girar = servidor.indisponivel("logo_trocar"), servidor.indisponivel("logo_girar")
if trocar != {"chave": "LOGO_MODO", "vale": "rotacao", "pede": "fixo"} or girar:
    erros.append("LOGO_ROTACAO=sim sem LOGO_MODO é o modo que gira (a regra do logo.sh): "
                 "o «Pôr» se apaga pedindo fixo, e o «Passar ao próximo» acende — "
                 "deu %r e %r" % (trocar, girar))
applet = os.path.join(cosmic, "dev.cappsy.CosmicExtAppletLogoMenu", "v1")
os.makedirs(applet)
aplicativos = os.path.join(casa, ".local", "share", "applications")
os.makedirs(aplicativos, exist_ok=True)
with open(os.path.join(aplicativos, "dev.cappsy.CosmicExtAppletLogoMenu.desktop"), "w",
          encoding="utf-8") as fh:
    fh.write("[Desktop Entry]\nType=Application\nName=Logo Menu\nNoDisplay=true\n"
             "X-CosmicApplet=true\n")
falso = os.path.join(os.path.dirname(casa), "falso")
os.makedirs(falso)
with open(os.path.join(falso, "notify-send"), "w", encoding="utf-8") as fh:
    fh.write("#!/bin/sh\nexit 1\n")
os.chmod(os.path.join(falso, "notify-send"), 0o755)
ambiente = dict(os.environ, PATH=falso + os.pathsep + os.environ.get("PATH", ""),
                XDG_DATA_HOME=os.path.join(casa, ".local", "share"),
                XDG_DATA_DIRS=os.path.join(casa, "sem-pastas-do-sistema"))
logo_sh = os.path.join(raiz, "scripts", "logo.sh")
conf_com(LOGO_MODO="hora", LOGO_DIA="mimir", LOGO_NOITE="mimir", LOGO="mimir", LOGO_RECICLAR="nao")
subprocess.run(["bash", "-c", 'set -a; . "$1"; set +a; exec "$2" aplicar', "_", conf, logo_sh],
               capture_output=True, env=ambiente, timeout=60)
conf_com(LOGO_MODO="fixo", LOGO="mimir", LOGO_RECICLAR="nao")
botao = os.path.join(casa, ".local", "share", "icons", "MeowSystem-Icons", "scalable", "apps",
                     "com.system76.CosmicPanelAppButton.svg")
coquinha = os.path.join(cosmic, "logos", "meow-coquinha.svg")


def no_dock(caminho):
    try:
        with open(botao, "rb") as a, open(caminho, "rb") as b:
            return a.read() == b.read()
    except OSError:
        return False


if no_dock(coquinha) or not no_dock(os.path.join(cosmic, "logos", "meow-mimir.svg")):
    erros.append("a casa de brinquedo não começou com o mimir no dock")
elif servidor.indisponivel("logo_trocar"):
    erros.append("com o mascote fixo, «Pôr um mascote no dock» não acendeu")
else:
    argv = [a.replace("@ARG@", "coquinha") for a in servidor.ACOES["logo_trocar"]["argv"]]
    r = subprocess.run(argv, capture_output=True, text=True, env=ambiente, timeout=120)
    if r.returncode != 1 or not no_dock(coquinha):
        erros.append("no modo fixo, «Pôr um mascote no dock» com a Coquinha não a pôs no dock "
                     "(rc=%s): %s" % (r.returncode, (r.stdout + r.stderr).strip()[-160:]))
    elif servidor.fim_da_acao("logo_trocar")["1"][1] != "trocou":
        erros.append("o fim do «Pôr» que trocou não diz «trocou»")
conf_com()
if (servidor.indisponivel("areas_aplicar") or {}).get("antes") != "areas_alfinetar_primeira":
    erros.append("sem área fixada, «Gravar as áreas» não manda antes a «Criar a primeira área»")
import time as _t
svg_png = open(os.path.join(raiz, "packs", "dracula", "logo.svg"), "rb").read()
casos = ((svg_png, True), (b"\x89PNG\r\n\x1a\n", False),
         (b'\xef\xbb\xbf<?xml version="1.0"?>\n<!-- a -->\n<!DOCTYPE svg>\n<svg xmlns="x"/>', True),
         (b"<svgx/>", False), (b"<!--" * 1000, False), (b"<!--a-->" * 500 + b"<x", False))
for dados, quer in casos:
    t0 = _t.monotonic()
    deu = servidor.comeca_como_svg(dados)
    if deu != quer or _t.monotonic() - t0 > 0.05:
        erros.append("comeca_como_svg(%r…) deu %s em %.0f ms" % (dados[:24], deu, (_t.monotonic() - t0) * 1000))
if servidor.indisponivel("areas_alfinetar_primeira"):
    erros.append("sem área fixada, «Criar a primeira área» nasceu apagada")
pinos = os.path.join(cosmic, "com.system76.CosmicComp", "v1")
os.makedirs(pinos)
with open(os.path.join(pinos, "pinned_workspaces"), "w", encoding="utf-8") as fh:
    fh.write('[\n    (\n        output: (\n            name: "DP-1",\n            edid: None,\n'
             '        ),\n        tiling_enabled: false,\n        id: Some("c0ffee"),\n'
             '        name: Some("Brinquedo"),\n    ),\n]\n')
if servidor.indisponivel("areas_aplicar"):
    erros.append("com uma área fixada, «Gravar as áreas» continua apagado")
if (servidor.indisponivel("areas_alfinetar_primeira") or {}).get("feito") != "areas_aplicar":
    erros.append("com uma área fixada, «Criar a primeira área» segue acesa, e só podia não fazer nada")
os.makedirs(os.path.dirname(servidor.PENDENCIAS), exist_ok=True)
with open(servidor.PENDENCIAS, "w", encoding="utf-8") as fh:
    fh.write("areas-sem-alfinete\tareas\tSem área fixada\tmeow areas alfinetar-primeira\t2026-10-10T00:00:00-03:00\n"
             "starship-ausente\tprompt\tSem starship\tmeow prompt starship\t2026-10-10T00:00:00-03:00\n")
vistas = [p["id"] for p in servidor.pendencias()]
if "areas-sem-alfinete" in vistas:
    erros.append("com área fixada, a pendência «areas-sem-alfinete» continua na lista: %r" % vistas)
if "starship-ausente" not in vistas:
    erros.append("a pendência que ainda vale sumiu junto: %r" % vistas)
os.remove(servidor.PENDENCIAS)

dock = os.path.join(cosmic, "com.system76.CosmicPanel.Dock", "v1")
os.makedirs(dock)
for nome, valor in (("size", "L"), ("padding", "4")):
    with open(os.path.join(dock, nome), "w", encoding="utf-8") as fh:
        fh.write(valor)
medida = servidor.teto_do_raio()
if "Dock" not in medida or medida.get("compositor") not in ("clampa", "pendente", "sem"):
    erros.append("o teto do raio não saiu do lib/painel.sh: %r" % (medida,))
if "Panel" in medida or servidor.teto_da_chave("FORMA_RAIO_PAINEL"):
    erros.append("a barra sem pasta no COSMIC ganhou teto: %r" % (medida,))
item = next(i for i in servidor.ler_esquema() if i["chave"] == "FORMA_RAIO_DOCK")
for estado, recusa in ((dict(Dock=0, compositor="sem", experimental=False), True),
                       (dict(Dock=0, compositor="pendente", experimental=False), True),
                       (dict(Dock=36, compositor="clampa", experimental=False), False),
                       (dict(Dock=0, compositor="sem", experimental=True), False)):
    servidor._TETO_CACHE.update(quando=time.time(), valor=estado)
    queixa = servidor.validar_valor(item, "16")
    if bool(queixa) != recusa:
        erros.append("com %r, 16 no raio da dock %s" % (estado, "passou" if recusa else
                                                       "foi recusado: %s" % queixa))
    if servidor.validar_valor(item, "0") or servidor.validar_valor(item, ""):
        erros.append("com %r, o 0 ou o vazio foram recusados" % (estado,))
    teto = servidor.teto_da_chave("FORMA_RAIO_DOCK")
    if not teto or not teto["motivo"] or teto["trava"] != recusa:
        erros.append("com %r, o cartão não diz o teto e o porquê: %r" % (estado, teto))

if erros:
    print("FALHOU: " + "; ".join(erros), file=sys.stderr)
    sys.exit(1)
print("ok: cada ação declara a natureza e o fim diz o que ela fez; o nome de tela sai "
      "da tabela; o botão sem efeito se apaga; o raio não passa do teto de agora")
PY
rm -rf "$_tmp12"

_tmp13="$(mktemp -d)"
HOME="$_tmp13/casa" MEOW_CONF="$_tmp13/casa/.config/meow/meow.conf" \
MEOW_ESTADO="$_tmp13/casa/.local/state/meowsystem" \
MEOW_COSMIC_DIR="$_tmp13/casa/.config/cosmic" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import collections, glob, os, re, shutil, subprocess, sys
raiz = sys.argv[1]
casa = os.environ["HOME"]
conf = os.environ["MEOW_CONF"]
cosmic = os.environ["MEOW_COSMIC_DIR"]
os.makedirs(os.path.dirname(conf))
with open(os.path.join(raiz, "meow.conf.exemplo"), encoding="utf-8") as fh:
    exemplo = fh.read()
IDIOMA = ("LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG")


def conf_com(**chaves):
    texto = exemplo
    for k, v in chaves.items():
        texto, n = re.subn(r'^%s="[^"]*"' % k, '%s="%s"' % (k, v), texto, count=1, flags=re.M)
        if not n:
            texto += '\n%s="%s"\n' % (k, v)
    with open(conf, "w", encoding="utf-8") as fh:
        fh.write(texto)


def idioma(**amb):
    """Troca a cadeia de idioma deste processo por `amb`; devolve a de antes."""
    antes = {k: os.environ.pop(k, None) for k in IDIOMA}
    os.environ.update(amb)
    return antes


conf_com()
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor

erros = []
aplicativos = os.path.join(casa, ".local", "share", "applications")
os.makedirs(aplicativos)


def desktop(ident, corpo):
    with open(os.path.join(aplicativos, ident + ".desktop"), "w", encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\nType=Application\nExec=true\n" + corpo)


desktop("com.exemplo.Ajustes", "Name=Settings\nName[pt]=Definições\nName[pt_BR]=Configurações\n"
        "\n[Desktop Action nova]\nName=New window\nName[pt_BR]=Outra janela\n")
desktop("com.exemplo.Camara", "Name=Camera\nName[pt]=Câmara\n")
desktop("com.exemplo.Fontes", "Name=Fonts\n")
m = servidor.Manipulador.__new__(servidor.Manipulador)
for amb, quer in ((dict(LANG="pt_BR.UTF-8"), ["Configurações", "Câmara", "Fonts"]),
                  (dict(LANG="pt_PT.UTF-8"), ["Definições", "Câmara", "Fonts"]),
                  (dict(LANG="C.UTF-8"), ["Settings", "Camera", "Fonts"]),
                  (dict(LANG="en_US.UTF-8", LANGUAGE="pt_BR:en"),
                   ["Configurações", "Câmara", "Fonts"]),
                  (dict(LANG="pt_BR.UTF-8", LC_MESSAGES="en_US.UTF-8"),
                   ["Settings", "Camera", "Fonts"]),
                  (dict(LANG="en_US.UTF-8", LC_ALL="pt_BR.UTF-8"),
                   ["Configurações", "Câmara", "Fonts"])):
    antes = idioma(**amb)
    try:
        por_id = {d["id"]: d["nome"] for d in m._desktops()}
    finally:
        idioma(**{k: v for k, v in antes.items() if v is not None})
    tem = [por_id.get(i) for i in ("com.exemplo.Ajustes", "com.exemplo.Camara",
                                   "com.exemplo.Fontes")]
    if tem != quer:
        erros.append("13a: com %s as fichas dizem %s, e o lançador diria %s" % (amb, tem, quer))
desktop("nm-connection-editor", "Name=Advanced Network Configuration\n"
        "Name[pt_BR]=Configuração avançada de rede\n")
bin_editor = os.path.join(os.path.dirname(casa), "bin-editor")
os.makedirs(bin_editor)
for prog, corpo in (("xdg-mime", "echo com.exemplo.Editor.desktop"), ("xdg-open", "exit 0")):
    with open(os.path.join(bin_editor, prog), "w", encoding="utf-8") as fh:
        fh.write("#!/bin/sh\n%s\n" % corpo)
    os.chmod(os.path.join(bin_editor, prog), 0o755)
desktop("com.exemplo.Editor", "Name=Vector Editor\nName[pt_BR]=Editor de vetores\n"
        "MimeType=image/svg+xml;\n")
caminho_antes = os.environ["PATH"]
antes = idioma(LANG="pt_BR.UTF-8")
os.environ["PATH"] = bin_editor + os.pathsep + caminho_antes
servidor._EDITOR_SVG = None
try:
    editor = m._editor_de_svg()
finally:
    os.environ["PATH"] = caminho_antes
    servidor._EDITOR_SVG = None
    idioma(**{k: v for k, v in antes.items() if v is not None})
if editor != {"tem": True, "nome": "Editor de vetores"}:
    erros.append("13a: o botão do editor de SVG diz %r, e a grade diria «Editor de vetores»"
                 % (editor,))

quer = "«Arrumar o lançador», em Ajustes › Programas › Lançador"
if servidor.onde_na_tela("LANCADOR_SISTEMA") != quer:
    erros.append("13b: --onde LANCADOR_SISTEMA diz %r, e a linha é %s"
                 % (servidor.onde_na_tela("LANCADOR_SISTEMA"), quer))
porta = subprocess.run(["bash", "-c", '. "$1/lib/comum.sh"; meow_onde_no_painel LANCADOR_SISTEMA',
                        "_", raiz], capture_output=True, text=True, env=dict(os.environ))
if porta.stdout.strip() != quer:
    erros.append("13b: o meow_onde_no_painel de um cartão diz %r" % porta.stdout.strip())
if servidor.onde_na_tela("WALLPAPER_DRACULA_REPO") != "«Acervo do Dracula», em Ajustes › Papel de parede › Mais ajustes":
    erros.append("13b: --onde de uma chave do «Mais ajustes» diz %r" % servidor.onde_na_tela("WALLPAPER_DRACULA_REPO"))
if servidor.onde_na_tela("inicio") != "em Cuidar":
    erros.append("13b: --onde inicio não diz onde as pendências moram: %r" % servidor.onde_na_tela("inicio"))
velhas = [f for f in (servidor.onde_na_tela(k) for k in list(servidor.ACOES) + ["inicio", "PACK", "CURSOR"])
          if "na aba" in f]
if velhas:
    erros.append("13b: o --onde ainda fala de aba: %r" % velhas[:3])
esquema = servidor.ler_esquema()
nomes = ({i["titulo"] for i in esquema if i.get("titulo")}
         | {a["rotulo"] for a in servidor.ACOES.values() if not a.get("oculta")})
abas = ({i["secao"] for i in esquema if i.get("secao")}
        | {a["grupo"] for a in servidor.ACOES.values() if not a.get("oculta")}
        | {"Início", servidor.porta_das_pendencias()})
with open(os.path.join(raiz, "install.sh"), encoding="utf-8") as fh:
    instalador = fh.read()
for n, linha in enumerate(instalador.splitlines(), 1):
    if linha.lstrip().startswith("#"):
        continue
    citados = [x for x in nomes
               if "painel" in linha and ("«%s»" % x in linha or '"%s"' % x in linha)]
    citados += ["aba " + x for x in abas
                if re.search(r"\baba\s+[«\"]?%s(?!\w)" % re.escape(x), linha)]
    if citados:
        erros.append("13b: install.sh:%d escreve à mão %s" % (n, ", ".join(sorted(citados))))
for ident in ("LANCADOR_SISTEMA", "inicio", "desfazer"):
    if "meow_onde_no_painel %s" % ident not in instalador:
        erros.append("13b: o install.sh não pergunta ao --onde onde fica %s" % ident)

logo_sh = os.path.join(raiz, "scripts", "logo.sh")
falso = os.path.join(os.path.dirname(casa), "falso")
os.makedirs(falso)
with open(os.path.join(falso, "notify-send"), "w", encoding="utf-8") as fh:
    fh.write("#!/bin/sh\nexit 1\n")
os.chmod(os.path.join(falso, "notify-send"), 0o755)
ambiente = dict(os.environ, PATH=falso + os.pathsep + os.environ.get("PATH", ""), NO_COLOR="1",
                XDG_DATA_HOME=os.path.join(casa, ".local", "share"),
                XDG_DATA_DIRS=os.path.join(casa, "sem-pastas-do-sistema"))
logos = os.path.join(cosmic, "logos")
botao = os.path.join(casa, ".local", "share", "icons", "MeowSystem-Icons", "scalable", "apps",
                     "com.system76.CosmicPanelAppButton.svg")


def logo(**chaves):
    conf_com(LOGO_RECICLAR="nao", **chaves)
    r = subprocess.run(["bash", "-c", 'set -a; . "$1"; set +a; exec "$2" aplicar', "_", conf,
                        logo_sh], capture_output=True, text=True, env=ambiente, timeout=180)
    return r.stdout + r.stderr


def no_dock():
    for caminho in sorted(glob.glob(os.path.join(logos, "meow-*.svg"))):
        with open(caminho, "rb") as a:
            try:
                with open(botao, "rb") as b:
                    if a.read() == b.read():
                        return os.path.basename(caminho)[len("meow-"):-len(".svg")]
            except OSError:
                return None
    return None


def ler(caminho):
    try:
        with open(caminho, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return None


sobra = os.path.join(cosmic, "co.uk.cappsy.CosmicAppletLogoMenu", "v1", "custom_logo_path")
os.makedirs(os.path.dirname(sobra))
de_outro = '"%s"' % os.path.join(logos, "de-outro.png")
with open(sobra, "w", encoding="utf-8") as fh:
    fh.write(de_outro)
logo(LOGO_MODO="hora", LOGO_DIA="mimir", LOGO_NOITE="mimir", LOGO="mimir")
saida = logo(LOGO_MODO="fixo", LOGO="gato-de-fora")
if no_dock() != "mimir":
    erros.append("13c: no modo fixo, um LOGO fora do acervo trocou o mascote do dock por %s — "
                 "o aviso promete que fica o que está no ar" % no_dock())
aviso = next((l for l in saida.splitlines() if 'LOGO="gato-de-fora"' in l), "")
if "mimir" not in aviso:
    erros.append("13c: o aviso do LOGO fora do acervo não diz o mascote que ficou: %r" % aviso)
if ler(sobra) != de_outro:
    erros.append("13c: o logo.sh escreveu na configuração de um applet que não está instalado")
desktop("co.uk.cappsy.CosmicAppletLogoMenu", "Name=Logo Menu\nNoDisplay=true\nX-CosmicApplet=true\n")
dev = os.path.join(cosmic, "dev.cappsy.CosmicExtAppletLogoMenu", "v1")
os.makedirs(dev)
logo(LOGO_MODO="fixo", LOGO="coquinha")
if ler(sobra) != '"%s"' % os.path.join(logos, "meow-coquinha.svg"):
    erros.append("13c: com o co.uk.cappsy instalado, o mascote não foi para a chave dele: %r"
                 % ler(sobra))
if os.path.exists(os.path.join(dev, "custom_logo_path")):
    erros.append("13c: o logo.sh escreveu na pasta do dev.cappsy, que não está instalado")
with open(os.path.join(dev, "custom_logo_path"), "w", encoding="utf-8") as fh:
    fh.write('"%s"' % os.path.join(logos, "de-outro.svg"))
r = subprocess.run([os.path.join(raiz, "bin", "meow"), "logo"], capture_output=True, text=True,
                   env=ambiente, timeout=60)
linha = next((l for l in r.stdout.splitlines() if "arquivo" in l), "")
if "meow-coquinha.svg" not in linha:
    erros.append("13c: o «arquivo» do `meow logo` não é a chave do applet instalado: %r" % linha)
if all(shutil.which(p) for p in ("rsvg-convert", "convert")):
    def _mascotes_de(pack):
        return [n[:-len(".svg")] for n in sorted(
            os.path.basename(p) for p in glob.glob(os.path.join(raiz, "packs", pack, "mascote", "*.svg"))
            if not p.endswith("-symbolic.svg"))]
    nomes_gatos = _mascotes_de("meowsystem")
    morcegos = _mascotes_de("dracula")
    espelho = nomes_gatos[(nomes_gatos.index("coquinha") + 1) % len(nomes_gatos)]
    carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch", ".gato-atual"))
               or "").split(" ")[0]
    if no_dock() != "coquinha" or carimbo != espelho:
        erros.append("13c: no modo fixo, o dock foi para %s e o terminal ficou com %r — o "
                     "espelho pede %s" % (no_dock(), carimbo, espelho))
    com_quebra = []
    for n in morcegos:
        with open(os.path.join(raiz, "packs", "dracula", "mascote", n + ".svg"), "rb") as fh:
            if fh.read().endswith(b"\n"):
                com_quebra.append(n)
    if com_quebra:
        gato = com_quebra[0]
        logo(LOGO_MODO="fixo", LOGO=gato, LOGO_DIA=gato, LOGO_NOITE=gato, PACK="dracula", FLAVOR="dracula")
        espelho = morcegos[(morcegos.index(gato) + 1) % len(morcegos)]
        carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                    ".gato-atual")) or "").split(" ")[0]
        if no_dock() != gato or carimbo != espelho:
            erros.append("13c: com %s (o SVG termina em quebra de linha) no dock, o terminal "
                         "ficou com %r — o espelho pede %s" % (no_dock(), carimbo, espelho))
    else:
        print("pulado: 13c, o mascote cujo SVG termina em quebra de linha — nenhum no acervo")
    if len(morcegos) >= 3:
        import datetime
        dia, noite = morcegos[0], morcegos[1]
        agora = datetime.datetime.now()
        longe = [(agora + datetime.timedelta(hours=h)).strftime("%H:%M") for h in (2, 3)]
        for fase, janela, no_dock_esperado, no_terminal in (
                ("noite", ("00:00", "00:00"), noite, dia),
                ("dia", tuple(longe), dia, noite)):
            logo(LOGO_MODO="hora", LOGO_DIA=dia, LOGO_NOITE=noite,
                 NOITE_INICIO=janela[0], NOITE_FIM=janela[1], PACK="dracula", FLAVOR="dracula")
            carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                        ".gato-atual")) or "").split(" ")[0]
            if no_dock() != no_dock_esperado or carimbo != no_terminal:
                erros.append("13c: no modo hora, de %s, o dock ficou com %s e o terminal com %r "
                             "— o outro do par é %s" % (fase, no_dock(), carimbo, no_terminal))
            r = subprocess.run([sys.executable, "-c",
                                "import sys; sys.path.insert(0, sys.argv[1]); import servidor; "
                                "print(servidor._gato_no_dock())",
                                os.path.join(raiz, "app")],
                               capture_output=True, text=True, env=ambiente, timeout=60)
            if r.stdout.strip() != no_dock_esperado:
                erros.append("13c: de %s, o esquema diz o mascote do dock %r — o dock tem %s"
                             % (fase, r.stdout.strip() or r.stderr.strip()[-160:], no_dock_esperado))
        with open(os.path.join(raiz, "app", "pagina", "paginas.js"), encoding="utf-8") as fh:
            if "ESQUEMA.gato_no_dock ||" not in fh.read():
                erros.append("13c: o retrato da Início não lê o mascote do dock (ESQUEMA.gato_no_dock)")
    else:
        print("pulado: 13c, o outro do par no modo hora — o acervo tem menos de três gatos")
else:
    print("pulado: 13c, o mascote do terminal — falta rsvg-convert ou o convert do ImageMagick")

mod = servidor.modulo_pack()
feitas = collections.Counter()
adocao, rodar = mod.adocao, servidor.subprocess.run


def contar_adocao(*a, **k):
    feitas[("adocao",) + tuple(a)] += 1
    return adocao(*a, **k)


def contar_rodar(argv, *a, **k):
    feitas[tuple(argv)] += 1
    return rodar(argv, *a, **k)


antes = idioma(LANG="pt_BR.UTF-8")
mod.adocao, servidor.subprocess.run = contar_adocao, contar_rodar
try:
    dados = servidor.Manipulador.__new__(servidor.Manipulador)._dados_esquema()
finally:
    mod.adocao, servidor.subprocess.run = adocao, rodar
    idioma(**{k: v for k, v in antes.items() if v is not None})
repetidas = sorted((n, " ".join(str(x) for x in k).replace("\n", " ")[:90])
                   for k, n in feitas.items() if n > 1)
if repetidas:
    erros.append("13d: uma leitura do esquema repetiu %d pergunta(s) — a pior %d vezes: %s"
                 % (len(repetidas), repetidas[-1][0], repetidas[-1][1]))
if {"descricoes", "blocos", "aba_inicio"} & set(dados):
    erros.append("13b: o esquema ainda manda à página o texto das abas de antes")
ficha = next((i for i in dados["chaves"] if i["chave"] == "LANCADOR_OCULTAR"), {})
nome = ((ficha.get("programas") or {}).get("nm-connection-editor") or {}).get("nome")
if nome != "Configuração avançada de rede":
    erros.append("13a: a ficha de «Quais programas o lançador esconde» diz %r" % nome)

class Rodado:
    returncode = 1
    stdout = ("  ~~   'brinquedo.ttf' instalada\n  >> copiada de %s/Downloads/brinquedo.ttf\n"
              "  >> 1 face(s) instalada(s) — o acervo é %s/assets/fontes/locais\n" % (casa, raiz))
    stderr = ""


respostas = []
m._json = lambda dados, status=200: respostas.append(dados)
servidor.subprocess.run = lambda *a, **k: Rodado()
try:
    m._acervo_por_comando(servidor.Manipulador.ACERVOS["fonte"], "brinquedo.ttf",
                          {"conteudo": "Zm9udGU="})
finally:
    servidor.subprocess.run = rodar
    del m._json
log = (respostas or [{}])[0].get("log", "")
if raiz in log or casa in log or "o acervo é ./assets/fontes/locais" not in log \
        or "~/Downloads/brinquedo.ttf" not in log:
    erros.append("13e: a torrada do «Adicionar fonte» leva %r" % log)

if erros:
    print("FALHOU: " + "\n  ".join(erros), file=sys.stderr)
    sys.exit(1)
print("ok: a ficha diz o nome do lançador, o --onde cobre cartão e aba, o logo.sh diz o que "
      "faz e o terminal segue o dock, o esquema mede cada fato uma vez, e a torrada do "
      "«Adicionar» não leva o clone")
PY
rm -rf "$_tmp13"

_trava="$(env -i PATH="$PATH" HOME="$(mktemp -d)" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
m = servidor.Manipulador.__new__(servidor.Manipulador)
nome = "Visualizador de documentos do GNOME"
d = {"id": "x", "icone": "x"}
nada = (set(), (), set(), set())
frases = [
    m._trava_do_pack({"id": "x", "icone": "/opt/x/icone.png"}, nome, donos=set(), travas=nada),
    m._trava_do_pack(d, nome, donos={"x"}, travas=nada),
    m._trava_do_pack(d, nome, donos=set(), travas=({"x"}, (), set(), set())),
    m._trava_do_pack(d, nome, donos=set(), travas=(set(), (), {"x"}, set())),
]
for f in frases:
    print("%d\t%s" % (len(f or ""), f))
PY
)"
_compridas="$(awk -F'\t' '$1 > 80 || $1 == 0' <<< "$_trava")"
if [ -z "$_compridas" ] && [ "$(grep -c . <<< "$_trava")" = 4 ]; then
  echo "ok: as quatro frases da trava do pack cabem no balão (até 80), com um nome de app comprido"
else
  echo "FALHOU: frase da trava do pack acima do teto do balão (80): $_compridas" >&2
  falhas=$((falhas+1))
fi

_lo="$(sed -n 's/^LANCADOR_OCULTAR="\(.*\)"$/\1/p' "$RAIZ/meow.conf.exemplo" | tr ',' '\n')"
_errados="$(grep -xE 'google-chrome|steam|github-desktop' <<< "$_lo")"
if [ -z "$_errados" ] && [ -n "$_lo" ]; then
  echo "ok: o LANCADOR_OCULTAR de fábrica não esconde o Chrome, a Steam nem o GitHub Desktop"
else
  echo "FALHOU: o LANCADOR_OCULTAR de fábrica esconde app de quem usa: $(echo $_errados)" >&2
  falhas=$((falhas+1))
fi

_tmp15="$(mktemp -d)"
_noite="$(env -i PATH="$PATH" HOME="$_tmp15" MEOW_CONF="$_tmp15/meow.conf" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import json, sys
sys.path.insert(0, sys.argv[1])
import servidor
open(servidor.CONF, "w").write('NOITE_INICIO=""\nNOITE_FIM=""\n')
m = servidor.Manipulador.__new__(servidor.Manipulador)
respostas = []
m._json = lambda dados, status=200: respostas.append((status, dados))
def _gravou(*a, **k):
    raise AssertionError("gravou")
servidor.definir = servidor.definir_varias = servidor.iniciar = _gravou
erros = []
for rota, corpo in (("/api/definir", {"chave": "NOITE_INICIO", "valor": "19:00"}),
                    ("/api/salvar", {"mudancas": {"NOITE_FIM": "06:00"}})):
    respostas.clear()
    try:
        m._api_post(rota, corpo)
    except AssertionError as e:
        erros.append("%s %s" % (rota, e))
        continue
    st = respostas[0][0] if respostas else None
    if st != 409:
        erros.append("%s com uma ponta deu %s" % (rota, st))
f = servidor.pontas_da_noite_soltas
casos = [({"NOITE_INICIO": "19:00", "NOITE_FIM": "06:00"}, {}, 0),
         ({"NOITE_INICIO": "", "NOITE_FIM": ""}, {"NOITE_INICIO": "19:00"}, 0),
         ({"NOITE_FIM": "06:00"}, {"NOITE_INICIO": "19:00"}, 0),
         ({"NOITE_FIM": ""}, {"NOITE_INICIO": "19:00", "NOITE_FIM": "06:00"}, 1),
         ({"LOG_NIVEL": "info"}, {"NOITE_INICIO": "19:00"}, 0)]
for escolhas, disco, esperado in casos:
    if len(f(escolhas, disco)) != esperado:
        erros.append("%r sobre %r deu %r" % (escolhas, disco, f(escolhas, disco)))
print("; ".join(erros) or "ok")
PY
)"
rm -rf "$_tmp15"
if [ "$_noite" = ok ]; then
  echo "ok: a noite com uma ponta só é recusada (409) no definir e no salvar; as duas, nenhuma, ou a que completa a do disco passam"
else
  echo "FALHOU: a noite com uma ponta só: $_noite" >&2
  falhas=$((falhas+1))
fi

_tmp16="$(mktemp -d)"
_sem_faixa="$(cd "$RAIZ" && env -i PATH="$PATH" HOME="$_tmp16" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import re, subprocess, sys
sys.path.insert(0, sys.argv[1])
import servidor
NUM = re.compile(r"-?\d+(?:[.,]\d+)?")
for i in servidor.ler_esquema():
    if i.get("faixa") or i.get("opcoes") or i.get("horario") or i.get("lista"):
        continue
    padrao = str(i.get("padrao") or "")
    if padrao and not NUM.fullmatch(padrao):
        continue
    leitores = subprocess.run(
        ["grep", "-rhoE", r"\$\{" + i["chave"] + r":-[0-9][0-9.]*\}",
         "scripts", "lib", "bin", "install.sh"],
        capture_output=True, text=True).stdout.split()
    if (padrao and NUM.fullmatch(padrao)) or leitores:
        print(i["chave"])
PY
)"
rm -rf "$_tmp16"
if [ -z "$_sem_faixa" ]; then
  echo "ok: toda chave numérica do exemplo declara a faixa (nenhuma vira campo de texto livre)"
else
  echo "FALHOU: chave numérica sem faixa no exemplo: $(echo $_sem_faixa)" >&2
  falhas=$((falhas+1))
fi

exit "$falhas"
