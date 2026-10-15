#!/usr/bin/env python3
"""app-acessibilidade.py — os numeros da P6 e da P7, medidos na pagina em pe.

    tests/app-acessibilidade.py             roda a conferencia
    tests/app-acessibilidade.py --detalhe   lista quem reprovou, um por linha

POR QUE ESTE ARQUIVO EXISTE, NAS PALAVRAS DELA (21/09/2026)
  "aqui outra falha: botao impossivel de clicar devido a largura da imagem."

  O que cobre o botao nao e' a imagem: e' o balao do botao vizinho. Medido com
  o painel no ar, as 14 abas percorridas uma a uma, ANTES da P6 — e sao estes
  os numeros que este arquivo devolveu rodando contra o codigo de 20/09:

      alvos abaixo de 24 px ................... 200 de 1105
                                                (176 botoes, 119 numa aba so';
                                                 o resto e' deslizante e ficha)
      baloes acima de 80 caracteres ........... 243 de 1005
                                                (301 passavam de 60; o maior
                                                 tinha 154 caracteres)
      baloes com um comando `meow` cru dentro . 159
                                                (119 deles entre parenteses, na
                                                 ficha de imagem; os outros 40
                                                 eram o comando inteiro)

  A sprint P6 trocou o `title` nativo por um balao proprio, poe um piso de
  24 px em todo alvo de clique e manda o comando para um botao "ver comando".
  Este arquivo e' o que impede os tres numeros de voltarem.

O QUE ELE MEDE, E POR QUE ASSIM
  1. ALVO DE CLIQUE ABAIXO DE 24 PX (WCAG 2.2, criterio 2.5.8). Conta todo
     elemento que recebe clique ou foco e tem caixa na tela. O botao escondido
     por `display:none` nao conta — ele nao e' alvo de nada; o botao da ficha
     de imagem, que so' aparece no hover, CONTA: ele e' alcancavel pelo teclado
     e pelo rato, e era ele a queixa.
  2. BALAO ACIMA DE 80 CARACTERES. Balao e' legenda de botao, nao documentacao
     dele. O censo olha o `data-balao` (o balao nosso) E o `title` (o nativo)
     pelo mesmo nome de propósito: se alguem reintroduzir um `title`, ele cai
     nesta mesma conta em vez de escapar por baixo dela.
  3. BALAO COM COMANDO `meow` DENTRO. O comando tem lugar — o "ver comando" do
     cartao, com um Copiar — e nao e' o balao.

  E UM QUARTO, QUE NAO E' NUMERO E IMPORTA TANTO QUANTO: o balao tem de
  aparecer no FOCO. O `title` nativo, por pior que seja, aparecia; um
  substituto que so' responda ao rato piora a acessibilidade em vez de
  melhorar. O passo 3 exercita o Tab e confere que o balao nasce, que ele fica
  FORA da fileira de botoes, e que o Escape o fecha.

  E O TETO DE 80 E' MEDIDO DUAS VEZES — 21/09/2026
    Porque medi-lo uma so' vez, na tela, nao o media. O `partirAjuda` apara
    antes de escrever o atributo, entao o `data-balao` devolve 80 mesmo para
    uma frase de 200 na fonte; e o elemento de um botao que so' nasce em certo
    estado nunca e' pintado para ser medido. As duas metades estao fechadas: o
    passo 1 le' a FONTE (e nao depende de pintar nada) e o passo 4 conta a
    PEGADA da apara (`data-balao-aparado`), que cobre a frase montada com dado
    de fora. O porque' de cada um esta' junto do codigo de cada um.

E OS QUATRO TETOS DA P7 — 22/09/2026
  A sprint seguinte e' sobre a mesma tela, e por isso mora no mesmo arquivo em
  vez de num irmao ao lado: o passeio pelas 14 abas ja' custa alguns segundos,
  e medir duas vezes a mesma pagina para responder a duas sprints seria
  cobra-lo duas vezes. O que ela cobra, e o numero de antes de cada um, medido
  com o painel no ar em 21 e 22/09:

      caminhos absolutos na tela .............. 43 -> 0
                                                (42 na linha de comando do
                                                 cartao de acao, 1 no
                                                 «vale como» do papel de parede)
      nomes acessiveis com caminho dentro ..... 34 -> 0
                                                (32 botoes de gato e 2 de
                                                 ponteiro; o maior anunciava 67
                                                 caracteres de caminho no lugar
                                                 do nome)
      ajudas do servidor acima de 220 ......... 1 -> 0   (de 50 medidas)
      ajudas com trecho repetido colado ....... 1 -> 0
                                                ("Nao escreve, nao escreve e
                                                 nao pede senha")
      paragrafos de ajuda em minuscula ........ 21 -> 0
                                                (12 legendas de desenho, 8
                                                 «vale como» e 1 ajuda de acao)

  A CONTA DO CAMINHO NAO PODE SER SOBRE `/home/`, e isto e' o achado que fez
  este bloco ser escrito. A conferencia que a P7 propos era
  `innerText.match(/\\/home\\/[a-z]+\\//g)`, e rodada num worktree em `/tmp` ela
  devolvia 1 onde havia 43: os caminhos estavam todos la', escritos com o
  prefixo do lugar de onde o painel subiu. Uma rede presa a `/home/` fica verde
  por estar olhando para o lugar errado, que e' o pior jeito de ficar verde.
  Aqui a raiz vem do processo que subiu o painel, e o `/home/<nome>/` entra ao
  lado dela porque e' a CASA, que tambem nao tem o que fazer na tela.

  E DOIS TETOS QUE A P7 PEDIU E ESTE ARQUIVO NAO COBRA, com a medida na mao:
    · «zero botao com nome acessivel acima de 40 caracteres». Os 56 que a
      sprint contou foram medidos por `textContent`, que nao e' nome acessivel:
      54 deles sao o par Sim/Nao, cujo desenho e' `aria-hidden` desde
      07/09/2026 — o Chrome ja' anuncia "Sim". Medido o nome COMPUTADO, sobram
      19, e todos sao o botao `?`, que anuncia "O que e' <titulo do cartao>"
      entre 41 e 60 caracteres. Encurta-lo deixaria trinta `?` indistinguiveis
      na mesma aba, que e' pior que o teto estourado. O teto de 40 e' regua
      certa para um botao de escolha e errada para um `?`; cobrar os dois com
      a mesma nao mediria nenhum.
    · «teto de 220 por paragrafo de ajuda» na TELA. Medido com o painel no ar
      e as 14 abas percorridas, e nao copiado da sprint: 124 paragrafos acima
      de 220 ANTES deste commit, dos quais 110 sao o `.motivo` dentro do balao
      do `?` — que e' a rede para onde o texto que nao cabe deve ir, e a
      propria P7 diz que sem ela a sprint troca "longo demais" por "curto e
      incompreensivel". (A sprint contou 122 no total; a diferenca e' de
      medida, nao de tela, e a conta daqui esta' aberta linha a linha.)
      Dos 14 que sobravam, 13 sobram agora, e eles NAO sao todos legenda:
        · 12 sao legenda de desenho vinda dos `previas-*.js` (231 a 545
          caracteres), e sao a enumeracao dos numeros que o desenho mostra;
        · 1 era a ajuda de acao do `servidor.py` — 230 caracteres, e e' a que
          este commit encurtou. E' o unico dos 14 que o teto COBRADO alcanca,
          e por isso ele e' cobrado na FONTE do `servidor.py`;
        · 1 nao e' nem uma coisa nem outra e continua la': a `.nota-secao` de
          299 caracteres da aba «Logo do sistema» (o `fecho` do
          `NOTA_DO_ASSUNTO`, em `app.js`). Ela e' PRE-EXISTENTE e esta sprint
          nao a tocou; fica escrita aqui para nao voltar a ser contada como
          legenda de desenho, que era o que esta linha dizia antes — 22/09/2026.
      O teto vale onde ha o que apertar, e e' por isso que ele e' cobrado na
      FONTE do `servidor.py`, e nao na tela.

O QUE ELE NAO FAZ
  Nao clica em nada que escreva: nenhuma acao e' executada, nenhuma chave e'
  gravada, nem o Salvar e' apertado. A conferencia e' de medida, e medir a
  pagina nao muda a maquina de quem mede.

DEPENDENCIA, E A DEGRADACAO QUANDO ELA FALTA
  A mesma disciplina do `tests/app-navegador.py`: sem Playwright no
  interpretador, SAI 3 (pulado) com a receita na tela, em vez de falhar.

      python3 -m venv ~/.local/share/meowsystem/venv-testes
      ~/.local/share/meowsystem/venv-testes/bin/pip install playwright
      ~/.local/share/meowsystem/venv-testes/bin/playwright install chromium
"""
import ast
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DETALHE = "--detalhe" in sys.argv
PISO_PX = 24
TETO_BALAO = 80

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    print("  " + sys.executable)
    print("  receita no cabecalho de tests/app-acessibilidade.py")
    sys.exit(3)


# O PAINEL SOBE NUM HOME DE BRINQUEDO, E NUNCA CONTRA A CASA DELA —
# 23/09/2026, sprint P33
#   Ate' hoje este arquivo subia o `app/run.sh` com o ambiente de quem o
#   chamava: o `meow.conf` de verdade, o estado de verdade e o `sudo` da
#   maquina. Ele nao clica em nada que escreva, mas o painel que ele sobe e' o
#   de verdade, e a regra do projeto e' que nada da interface e' aplicado em
#   sandbox — tudo e' aplicado na maquina da pessoa. Por isso quem vai para a
#   sandbox e' o TESTE. E a P33 tornou isto urgente: o `tests/todos.sh`
#   passou a achar o python com Playwright, e este arquivo, que saia "pulado"
#   nos terminais sem o pyenv, agora roda de fato a cada `./tests/todos.sh`.
#
#   O servidor recebe um ambiente limpo, o `env -i` do `tests/convergencia.sh`:
#   HOME e `MEOW_CONF` num diretorio temporario, `MEOW_PONTE` para o vazio e um
#   `sudo` falso na frente do PATH — numa maquina com `NOPASSWD: ALL` o
#   `sudo -n` de verdade PASSA, e um teste cujo alcance depende disso e' roleta.
#
#   E A CASA NAO FICA VAZIA, porque vazia ela mediria menos e seguiria verde —
#   o jeito errado de ficar verde que o cabecalho inteiro combate. Duas coisas
#   que a casa dela tinha e o brinquedo nao teria sao plantadas, e cada uma
#   por uma conferencia que sem ela nao mediria nada:
#     · UMA PENDENCIA POR CONSERTO QUE O SERVIDOR CONHECE (`ACAO_DA_PENDENCIA`,
#       lido da fonte, e nao uma lista escrita aqui). Sem elas a Home nao
#       desenha nenhum «Resolver», e o balao dele — o que a P33 conserta —
#       sairia da conta calado. O comando plantado tem a forma crua do que o
#       `meow_pendencia_acionavel` grava, `./scripts/<x>.sh <verbo>`: se o
#       balao voltar a ser o comando, o passo 4 reprova.
#     · UMA IMAGEM NA GALERIA. O passo 3 mede o balao no foco do teclado sobre
#       os botoes da ficha de imagem; sem ficha, ele reprova por "nao achei".
BRINQUEDO = tempfile.mkdtemp(prefix="meow-acessibilidade-")


def pendencias_com_conserto():
    """Os ids de pendencia que ganham «Resolver», lidos do `servidor.py`."""
    caminho = os.path.join(RAIZ, "app", "servidor.py")
    with open(caminho, encoding="utf-8") as f:
        arvore = ast.parse(f.read())
    for no in arvore.body:
        if (isinstance(no, ast.Assign)
                and any(isinstance(a, ast.Name) and a.id == "ACAO_DA_PENDENCIA"
                        for a in no.targets)):
            return sorted(ast.literal_eval(no.value))
    return []


def png_liso(caminho, larg=64, alt=40, rgb=(0x28, 0x2A, 0x36)):
    """Um PNG de uma cor so', escrito a mao para nao depender de biblioteca."""
    def pedaco(tipo, corpo):
        return (struct.pack(">I", len(corpo)) + tipo + corpo
                + struct.pack(">I", zlib.crc32(tipo + corpo) & 0xFFFFFFFF))
    linhas = (b"\x00" + bytes(rgb) * larg) * alt
    with open(caminho, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n"
                 + pedaco(b"IHDR", struct.pack(">IIBBBBB", larg, alt, 8, 2, 0, 0, 0))
                 + pedaco(b"IDAT", zlib.compress(linhas))
                 + pedaco(b"IEND", b""))


def montar_casa():
    """Semeia o HOME de brinquedo e devolve o ambiente do servidor."""
    casa = os.path.join(BRINQUEDO, "casa")
    conf = os.path.join(casa, ".config", "meow", "meow.conf")
    estado = os.path.join(casa, ".local", "state", "meowsystem")
    os.makedirs(os.path.dirname(conf))
    os.makedirs(estado)
    exemplo = os.path.join(RAIZ, "meow.conf.exemplo")
    shutil.copyfile(exemplo, conf)

    with open(os.path.join(estado, "pendencias.tsv"), "w", encoding="utf-8") as fh:
        for ident in pendencias_com_conserto():
            fh.write(f"{ident}\tteste\tPendência plantada pelo teste ({ident})"
                     f"\t./scripts/teste.sh {ident}\t2026-09-23T00:00:00-03:00\n")

    # A pasta da galeria sai do proprio `meow.conf` do brinquedo, e `ativos/`
    # e' a canonica — a unica cuja ficha ganha a fileira inteira de botoes.
    with open(exemplo, encoding="utf-8") as fh:
        base = re.search(r'^WALLPAPER_BASE="([^"]*)"', fh.read(), re.M).group(1)
    ativos = os.path.join(base.replace("$HOME", casa), "ativos")
    os.makedirs(ativos)
    png_liso(os.path.join(ativos, "brinquedo.png"))

    falso = os.path.join(BRINQUEDO, "falso")
    os.makedirs(falso)
    with open(os.path.join(falso, "sudo"), "w", encoding="utf-8") as fh:
        fh.write("#!/bin/sh\n"
                 "printf 'sudo: recusado pelo tests/app-acessibilidade.py\\n' >&2\n"
                 "exit 1\n")
    os.chmod(os.path.join(falso, "sudo"), 0o755)
    return {"PATH": falso + os.pathsep + os.environ.get("PATH", ""),
            "HOME": casa, "USER": os.environ.get("USER", "meow"),
            "LANG": os.environ.get("LANG", "C.UTF-8"),
            "MEOW_CONF": conf, "MEOW_ESTADO": estado,
            "MEOW_PONTE": "/nao/existe"}


# O CENSO DE UMA ABA, COLHIDO DE UMA VEZ.
#   Abrir as 14 abas ja' custa alguns segundos; medir cada alvo e cada balao
#   enquanto a aba esta' na tela custa um `evaluate` por aba, e nao uma segunda
#   volta pela pagina inteira.
CENSO_JS = """
([raiz, tetoParagrafo]) => {
  const SELETOR_ALVO = 'button, a[href], input:not([type=hidden]), select,'
                     + ' textarea, summary, [role=button],'
                     + ' [tabindex]:not([tabindex="-1"])';
  const visivel = (el, r) => {
    if (r.width === 0 && r.height === 0) return false;   // sem caixa na tela
    const cs = getComputedStyle(el);
    return cs.display !== 'none' && cs.visibility !== 'hidden';
  };
  const alvos = [];
  let medidos = 0;
  for (const el of document.querySelectorAll(SELETOR_ALVO)) {
    const r = el.getBoundingClientRect();
    if (!visivel(el, r)) continue;
    medidos++;
    if (r.width >= 24 && r.height >= 24) continue;
    alvos.push({
      tag: el.tagName.toLowerCase(),
      classe: (el.className || '').toString().slice(0, 40),
      rotulo: (el.textContent || el.getAttribute('aria-label') || '').trim().slice(0, 28),
      w: Math.round(r.width), h: Math.round(r.height),
    });
  }
  /* O `title` entra no MESMO censo do `data-balao`, e nao num censo ao lado:
     um `title` que volte e' um balao nativo de volta, e tem de reprovar aqui
     em vez de sumir da conta. */
  const baloes = [...document.querySelectorAll(
    '[data-balao], [title], [data-balao-aparado]')].map((el) => ({
    texto: el.getAttribute('data-balao') || el.getAttribute('title') || '',
    nativo: el.hasAttribute('title'),
    /* O COMPRIMENTO QUE A FRASE TINHA NA FONTE, quando a rede do `partirAjuda`
       teve de apara-la. Medir so' o `data-balao` mede DEPOIS da apara, e ai'
       uma frase de 200 caracteres devolve 80 e passa — a rede apagando a
       propria pegada. Aqui ele vem junto, e o passo 4 exige zero. */
    aparado: Number(el.getAttribute('data-balao-aparado') || 0),
    tag: el.tagName.toLowerCase(),
    classe: (el.className || '').toString().slice(0, 40),
  }));

  /* ------------------------------------------------------------------
     OS TETOS DA P7, colhidos no mesmo passeio pelas abas — 22/09/2026.
     ------------------------------------------------------------------ */
  const pr = document.getElementById('principal');

  /* 1. CAMINHO ABSOLUTO NA TELA. A raiz vem de FORA (é a do processo que subiu
     o painel), e não de uma expressão sobre `/home/`: o painel roda de onde o
     repositório estiver, e uma rede presa ao `/home/` devolve zero numa cópia
     em `/tmp` — verde por estar olhando para o lugar errado. O `/home/<nome>/`
     entra ao lado dela porque é o caminho da CASA, que não é a raiz e também
     não tem o que fazer na tela. */
  const texto = pr.innerText;
  const daRaiz = raiz ? texto.split(raiz).length - 1 : 0;
  const daCasa = (texto.match(/\\/home\\/[^/\\s]+\\//g) || []).length;
  const amostraCaminho = [];
  for (const el of pr.querySelectorAll('*')) {
    if (el.children.length || el.offsetParent === null) continue;
    const t = (el.textContent || '');
    if ((raiz && t.includes(raiz)) || /\\/home\\/[^/\\s]+\\//.test(t)) {
      amostraCaminho.push({ tag: el.tagName.toLowerCase(),
                            classe: (el.className || '').toString().slice(0, 30),
                            texto: t.trim().slice(0, 80) });
    }
  }

  /* 2. O CAMINHO NO NOME ACESSÍVEL. Um `aria-label` É o nome do botão para
     quem usa leitor de tela, e o `porBalao` o escreve sozinho quando o botão
     não tem texto. Eram 34 botões anunciando um caminho de arquivo no lugar
     do nome do gato ou do ponteiro. O `data-balao` NÃO entra nesta conta: ele é legenda,
     e uma legenda que diga de onde a imagem veio é legítima.

     O `…/` CONTA COMO COMEÇO DE CAMINHO, e não contar era um buraco medido:
     o `encurtarCaminho` da P6 corta o caminho pela esquerda e põe reticências
     na frente, então o que o leitor de tela anunciava era
     `…/scratchpad/wt/p7/assets/gatos/coquinha.svg` — um caminho que não começa
     com `/`. A primeira versão desta rede pedia `/` ou `~` no início e devolvia
     3 onde havia 32: ela passava por cima justamente dos botões pelos quais a
     P7 existe. Caminho encurtado continua sendo caminho. */
  const nomeComCaminho = [];
  for (const el of pr.querySelectorAll('[aria-label]')) {
    const nome = el.getAttribute('aria-label') || '';
    if (/(?:^|[\\s(«])(?:…|\\.\\.\\.|~)?\\/(?:[^\\s/]+\\/)+[^\\s/]/.test(nome))
      nomeComCaminho.push({ tag: el.tagName.toLowerCase(), nome: nome.slice(0, 80) });
  }

  /* 3. PARÁGRAFO DE AJUDA ABRINDO EM MINÚSCULA. Só o que está PINTADO: o texto
     do balão do `?` (a `.dica`) fica de fora porque ele é o comentário do
     `meow.conf.exemplo` copiado cru, e reescrever a pontuação do autor dentro
     do balão é outra sprint — ver o bloco da P7 no cabeçalho.

     E A `.sem-previa` TAMBÉM FICA DE FORA, por um motivo diferente e medido em
     22/09/2026: ela não é ajuda, é ESTADO DE CARREGAMENTO — `<p
     class="sem-previa">lendo o tema instalado…</p>` (app.js:2450), que existe
     desde antes desta sprint. Contra os 700 ms fixos que este teste espera por
     aba, contá-la fazia a conferência sair VERMELHA sem defeito nenhum na
     tela: medido, 1 vermelho em 8 corridas, e reproduzido de forma
     determinística com 1,5 s de latência via CDP.

     Um teste que falha por latência ensina a ignorar vermelho — que é
     exatamente o defeito que a P23 veio consertar. Antes desta rede, uma aba
     sub-renderizada só media menos coisa e seguia verde; o falso-vermelho
     seria criação desta sprint, e por isso morre aqui.

     E A HISTÓRIA DO PACK TAMBÉM FICA DE FORA — 24/09/2026, P53. Ela deixou
     de ser um `<pre>` e virou parágrafos montados do `LEIA-ME.md` de quem
     publicou o pack (o `historiaDoPack` do app.js). É texto do autor do
     pack, e não ajuda deste painel: o do Dracula abre um parágrafo com
     `meow pack info dracula`, em código, e a primeira letra é a dele. */
  const minusculas = [];
  for (const p of pr.querySelectorAll('p')) {
    if (p.offsetParent === null || p.closest('.dica')) continue;
    if (p.classList.contains('sem-previa')) continue;
    if (p.closest('.pack-historia')) continue;
    const t = (p.textContent || '').trim().replace(/\\s+/g, ' ');
    if (!t) continue;
    const c = t[0];
    if (c.toLocaleLowerCase('pt-BR') === c && c.toLocaleUpperCase('pt-BR') !== c)
      minusculas.push({ classe: (p.className || '').toString().slice(0, 30),
                        texto: t.slice(0, 80) });
  }

  /* 4. O TETO DE 220 NO PARÁGRAFO PINTADO — 15/10/2026, P82 (item 39). Ele
     ficava só na fonte do `servidor.py`, porque na tela as 12 legendas de
     desenho dos `previas-*.js` passavam dele e eram isentas. A P77 levou a
     legenda para o balão do `?` (o `dicaDoDesenho`), e a isenção ficou sem
     objeto: agora o teto vale para todo parágrafo pintado. Fora só o que
     já estava fora pela mesma razão do passo 3: o balão (`.dica`), o estado
     de carregamento e a história do pack, que é texto do autor dele. Uma
     legenda que volte à tela reprova aqui. */
  const longos = [];
  for (const p of pr.querySelectorAll('p')) {
    if (p.offsetParent === null || p.closest('.dica')) continue;
    if (p.classList.contains('sem-previa')) continue;
    if (p.closest('.pack-historia')) continue;
    const t = (p.textContent || '').trim().replace(/\s+/g, ' ');
    if (t.length > tetoParagrafo)
      longos.push({ classe: (p.className || '').toString().slice(0, 30),
                    tam: t.length, texto: t.slice(0, 80) });
  }

  return { alvos, medidos, baloes,
           daRaiz, daCasa, amostraCaminho, nomeComCaminho, minusculas, longos };
}
"""

# O COMANDO CRU DENTRO DO BALAO.
#   `meow` seguido de um verbo, com ou sem parenteses a' volta — que era a
#   forma dos 119 —, e tambem o caminho absoluto do `bin/meow` ou de um script
#   do projeto, que e' a mesma coisa escrita por extenso. `meow.conf` NAO casa:
#   e' o nome de um arquivo, e falar dele em portugues e' legitimo.
#
#   O `.sh` NO FIM DO BALAO TAMBEM CONTA — corrigido em 21/09/2026
#     A primeira versao pedia `\S+\.sh\s`, com espaco OBRIGATORIO depois, e com
#     isso um balao que TERMINASSE no nome do script escapava da conta inteira:
#     "roda o ~/bin/meow-pack.sh" passava. Buraco numa rede e' pior que rede
#     nenhuma, porque ela declara cobrir o que nao cobre. Agora o fim da frase
#     fecha o casamento como um espaco fecharia.
#
#   E O LADO FALSO-POSITIVO FICA COMO ESTA, de proposito: `meow\s+[a-z]` pega
#   tambem uma frase legitima que comece com "meow " mais minuscula ("o meow le
#   o arquivo"). Distinguir exigiria a lista dos verbos do `meow`, que e' a
#   armadilha nº 3 do projeto — lista fixa que alguem vai esquecer de crescer. E
#   o erro cai para o lado seguro: um falso positivo REPROVA e alguem le a
#   frase; um falso negativo passa calado, que e' o que esta rede veio matar.
COMANDO_NO_BALAO = re.compile(r"(?:^|[(\s/])meow\s+[a-z]|\S+\.sh(?:\s|$)")


# O TETO DE 80 MEDIDO NA FONTE, E NAO SO' NA TELA — 21/09/2026
#   A sprint pede "limite duro de 80 caracteres — o teste falha acima disso", e
#   a primeira versao deste arquivo nao cumpria isso por dois motivos somados:
#   o `partirAjuda` APARA antes de escrever o `data-balao`, e a varredura das 14
#   abas so' ve' o que a pagina pinta. O caso que escapou tinha as duas coisas:
#   a frase de 83 caracteres do «Desfazer N escolhas» saia mutilada na tela
#   ("O meow.conf nao e'…", que diz o oposto do que a frase existe para dizer) e
#   o botao so' nasce quando ha escolha pendente no bloco — estado que a
#   varredura nunca alcanca. Verde por duas ausencias.
#
#   A apara agora deixa marca (`data-balao-aparado`, contada no passo 4). Esta
#   leitura da FONTE cobre a outra metade: a frase escrita a mao acima do teto
#   aparece mesmo que o elemento dela nunca seja pintado. Rodada contra o
#   commit que a introduziu, ela devolve exatamente aquela linha.
#
# POR QUE SO' `app.js` E `index.html`
#   E' onde o balao e' AUTORADO. As ajudas do `servidor.py` sao, na quase
#   totalidade, prosa VISIVEL do cartao de acao — medi-las por este teto
#   reprovaria vinte frases que nunca viram balao. As quatro que viram (os
#   botoes do cabecalho da Inicio) passam pelo `porBalao` na aba Inicio, que a
#   varredura percorre, e caem na marca da apara se estourarem.
#
# O QUE FICA DE FORA, DITO EM VOZ ALTA
#   Frase MONTADA (`${…}`) nao entra: o comprimento dela depende do dado, e e'
#   exatamente para ela que a rede do `partirAjuda` existe — quem cuida desse
#   caso e' a marca da apara. E o denominador ("N frases fixas medidas") sai na
#   tela de proposito: um "0 reprovado" tambem e' o que uma expressao quebrada
#   devolve, e sem o denominador os dois se parecem.
LITERAL = r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|`(?:[^`\\]|\\.)*`'
_VALOR = r'((?:' + LITERAL + r')(?:\s*\+\s*(?:' + LITERAL + r'))*)'
# A ANCORA DE POSICAO NAO E' ZELO: sem exigir inicio de linha, `{` ou `,` antes
# da chave, o `title` CITADO num comentario casa, e o literal de crase que vem
# depois dele engole o comentario inteiro — um achado de 1195 caracteres que
# nao existe na tela. A chave tem de estar em posicao de propriedade.
AJUDA_NA_FONTE = {
    "app/pagina/app.js": re.compile(
        r'(?:^[ \t]*|[{,][ \t]*)(?:title|titulo):\s*' + _VALOR, re.M),
    "app/pagina/index.html": re.compile(r'\stitle=\s*' + _VALOR),
}


def frases_fixas():
    """Devolve (quantas foram medidas, as que passam do teto na FONTE)."""
    medidas, compridas = 0, []
    for rel, padrao in AJUDA_NA_FONTE.items():
        with open(os.path.join(RAIZ, rel), encoding="utf-8") as f:
            src = f.read()
        for m in padrao.finditer(src):
            pecas = re.findall(LITERAL, m.group(1))
            txt = "".join(p[1:-1] for p in pecas)
            if "${" in txt:
                continue
            txt = txt.replace('\\"', '"').replace("\\'", "'")
            medidas += 1
            if len(txt) > TETO_BALAO:
                compridas.append((rel, src.count("\n", 0, m.start()) + 1,
                                  len(txt), txt))
    return medidas, compridas


# O TETO DE 220 E A PALAVRA REPETIDA, LIDOS NA FONTE DO `servidor.py`
# ---------------------------------------------------------------------------
# Os dois medem a mesma coisa que a tela mostraria, e medem ANTES: uma ajuda
# comprida ou com uma palavra duplicada já está errada no arquivo, e esperar a
# varredura pintá-la é esperar que a aba dela seja aberta. O `ast` é quem lê, e
# não uma expressão regular: as ajudas são literais concatenados em várias
# linhas, e juntar as partes é exatamente o que o `literal_eval` faz sem errar.
#
# POR QUE SÓ O `servidor.py`, DITO EM VOZ ALTA
#   É onde mora a ajuda de ação — a prosa que o cartão imprime embaixo do
#   título. As outras duas fontes de parágrafo da página NÃO entram, e cada uma
#   por uma razão diferente, medida em 22/09/2026:
#     · o `.motivo` do balão do `?` (110 dos 122 parágrafos acima de 220) é o
#       comentário do `meow.conf.exemplo` copiado cru, e é ele a REDE que
#       justifica encurtar o resto. Aplicar o teto nele seria cortar justamente
#       o texto para onde o que não cabe deve ir;
#     · a legenda de desenho (12) vinha dos `previas-*.js`. [P82, 15/10/2026:
#       a P77 a levou para o balão do `?`, e a isenção saiu. O teto de 220
#       vale agora para todo parágrafo PINTADO, medido na tela pelo passo 4
#       do `CENSO_JS`, e uma legenda que volte à tela reprova lá.]
#   O que esta leitura cobra é o que esta sprint pode manter honestamente.
TETO_AJUDA = 220
CHAVES_DE_AJUDA = ("ajuda", "frase", "nota", "texto")

# TRECHO REPETIDO COLADO. A P7 achou um em produção: *"Não escreve, não
# escreve e não pede senha"* — duas vezes a mesma metade, e a outra metade
# perdida. O separador entre as duas é vírgula ou só espaço; com ponto no meio
# são duas frases, e repetir palavras em frases vizinhas é legítimo.
#
# E O QUE SE REPETE NÃO É UMA PALAVRA, É UM TRECHO — medido em 22/09/2026
#   A primeira versão desta rede pedia uma palavra colada nela mesma
#   (`\b(\w+)\b\s*,?\s+\1\b`) e devolvia ZERO contra a frase que a motivou:
#   em "Não escreve, não escreve", nenhuma palavra encosta na sua igual —
#   "escreve," é seguido de "não". O que se duplicou foi o par. O grupo agora
#   vai de uma a quatro palavras, que é o tamanho de uma oração curta; medido
#   contra as 50 ajudas deste arquivo, ele pega exatamente aquela e mais
#   nenhuma.
#   O lado falso-positivo fica como está, de propósito: um trecho legitimamente
#   repetido REPROVA e alguém lê a frase; um duplicado que passe calado é o que
#   esta rede veio matar. É a mesma escolha que o `COMANDO_NO_BALAO` já fez.
TRECHO_REPETIDO = re.compile(r"\b(\w{2,}(?:\s+\w+){0,3})\b\s*,?\s+\1\b",
                             re.IGNORECASE)


def frases_do_servidor():
    """(quantas medidas, as acima do teto, as com trecho repetido)."""
    import ast
    caminho = os.path.join(RAIZ, "app", "servidor.py")
    with open(caminho, encoding="utf-8") as f:
        arvore = ast.parse(f.read())
    medidas, compridas, repetidas = 0, [], []
    for no in ast.walk(arvore):
        if not isinstance(no, ast.Dict):
            continue
        for chave, valor in zip(no.keys, no.values):
            if not (isinstance(chave, ast.Constant)
                    and chave.value in CHAVES_DE_AJUDA):
                continue
            try:
                txt = ast.literal_eval(valor)
            except Exception:
                continue
            if not isinstance(txt, str) or not txt:
                continue
            medidas += 1
            if len(txt) > TETO_AJUDA:
                compridas.append((valor.lineno, len(txt), txt))
            m = TRECHO_REPETIDO.search(txt)
            if m:
                repetidas.append((valor.lineno, m.group(0), txt))
    return medidas, compridas, repetidas


def sobe_servidor(ambiente):
    """Sobe o painel e devolve (processo, url). A URL sai na PRIMEIRA linha do
    `--sem-abrir` — e e' a unica forma de saber a porta, que o kernel escolhe.
    `ambiente` e' o do HOME de brinquedo (`montar_casa`), e SO' ele: nada do
    ambiente de quem chamou chega ao servidor."""
    proc = subprocess.Popen(
        [os.path.join(RAIZ, "app", "run.sh"), "--sem-abrir"],
        cwd=RAIZ, env=ambiente,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    url = None
    inicio = time.time()
    while time.time() - inicio < 40:
        linha = proc.stdout.readline()
        if not linha:
            break
        m = re.search(r"http://127\.0\.0\.1:\d+/\?t=[A-Za-z0-9_-]+", linha)
        if m:
            url = m.group(0)
            break
    return proc, url


def percorrer(pag):
    """Abre as abas uma a uma e devolve (pequenos, medidos, baloes, p7) da
    pagina.

    `pequenos` sao os alvos que reprovaram; `medidos` e' quantos foram olhados,
    e ele e' o denominador — sem ele um "0 reprovado" tambem e' o que um
    seletor quebrado devolve. `p7` traz os tres tetos que a P7 mede na tela."""
    pequenos, medidos, baloes = [], 0, []
    # A RAIZ VAI DAQUI PARA DENTRO DA PAGINA, e nao e' lida la': quem sabe de
    # onde o painel subiu e' este processo, que o subiu. Ver o censo.
    p7 = {"caminhos": 0, "onde": [], "nomes": [], "minusculas": [], "longos": []}
    nomes = pag.locator("#trilho button").all_text_contents()
    for i in range(len(nomes)):
        pag.locator("#trilho button").nth(i).click()
        pag.wait_for_timeout(700)
        # O nome do botao do trilho traz a contagem colada no fim ("Painel e
        # dock12"); no relatorio isso vira um numero sem dono, entao ele sai.
        aba = re.sub(r"\s*\d+$", "", nomes[i].strip())
        d = pag.evaluate(CENSO_JS, [RAIZ, TETO_AJUDA])
        for chave in ("alvos", "baloes", "amostraCaminho",
                      "nomeComCaminho", "minusculas", "longos"):
            for x in d[chave]:
                x["aba"] = aba
        pequenos += d["alvos"]
        medidos += d["medidos"]
        baloes += d["baloes"]
        p7["caminhos"] += d["daRaiz"] + d["daCasa"]
        p7["onde"] += d["amostraCaminho"]
        p7["nomes"] += d["nomeComCaminho"]
        p7["minusculas"] += d["minusculas"]
        p7["longos"] += d["longos"]
        print(f"  {aba[:34]:36s} alvos={d['medidos']:4d}"
              f"  abaixo de {PISO_PX} px={len(d['alvos']):4d}"
              f"  baloes={len(d['baloes']):4d}"
              f"  caminhos={d['daRaiz'] + d['daCasa']:3d}")
    return pequenos, medidos, baloes, p7


# O BALAO NO TECLADO — o risco declarado da sprint.
#   `:focus-visible` so' casa quando o foco veio do teclado. Um `Tab` de
#   verdade antes do `focus()` e' o que poe o navegador nessa modalidade; sem
#   ele o teste mediria o clique, que e' justamente onde o balao NAO deve
#   nascer.
FOCO_JS = """
(sel) => {
  const alvo = document.querySelector(sel);
  if (!alvo) return { erro: 'nao achei ' + sel };
  alvo.focus();
  const b = document.getElementById('balao');
  const visto = !!b && !b.hidden;
  const rb = visto ? b.getBoundingClientRect() : null;
  /* O balao nao pode cobrir os IRMAOS do botao — era exatamente isso que o
     nativo fazia, e e' a queixa inteira desta sprint. */
  let cobre = [];
  if (rb) {
    for (const irmao of alvo.parentElement.children) {
      if (irmao === alvo) continue;
      const r = irmao.getBoundingClientRect();
      if (r.width === 0 && r.height === 0) continue;
      const cruza = rb.left < r.right && rb.right > r.left
                 && rb.top < r.bottom && rb.bottom > r.top;
      if (cruza) cobre.push((irmao.textContent || '').trim().slice(0, 20));
    }
  }
  return {
    visto,
    texto: visto ? b.textContent : '',
    descrito: alvo.getAttribute('aria-describedby') || '',
    cobre,
  };
}
"""


def main():
    falhas = []

    # Este passo nao precisa de navegador nem de painel no ar, e vem primeiro
    # por isso: se a frase esta comprida na fonte, nao ha o que medir na tela.
    print("1. O TETO DE 80 NA FONTE (antes da apara, e mesmo sem pintar)")
    medidas, compridas = frases_fixas()
    for rel, linha, tam, txt in compridas:
        print(f"  XX {rel}:{linha}  {tam} caracteres  {txt[:70]!r}")
    print(f"  {len(compridas)} acima de {TETO_BALAO}, "
          f"de {medidas} frases fixas medidas")
    if compridas:
        falhas.append(f"{len(compridas)} frases fixas acima de "
                      f"{TETO_BALAO} caracteres na fonte")
    if not medidas:
        falhas.append("nenhuma frase fixa foi encontrada na fonte — "
                      "a leitura quebrou, e um zero assim nao e' verde")

    # Tambem sem navegador, e pela mesma razao: uma ajuda comprida ou com uma
    # palavra duplicada ja' esta' errada no arquivo.
    print(f"\n1b. AS AJUDAS DO `servidor.py` (teto de {TETO_AJUDA}, "
          f"e o trecho repetido)")
    quantas, compridas_ajuda, repetidas = frases_do_servidor()
    for linha, tam, txt in compridas_ajuda:
        print(f"  XX app/servidor.py:{linha}  {tam} caracteres  {txt[:64]!r}")
    for linha, trecho, txt in repetidas:
        print(f"  XX app/servidor.py:{linha}  repete {trecho!r}  em {txt[:56]!r}")
    print(f"  {len(compridas_ajuda)} acima de {TETO_AJUDA} e "
          f"{len(repetidas)} com trecho repetido, de {quantas} ajudas medidas")
    if compridas_ajuda:
        falhas.append(f"{len(compridas_ajuda)} ajudas do servidor acima de "
                      f"{TETO_AJUDA} caracteres")
    if repetidas:
        falhas.append(f"{len(repetidas)} ajudas do servidor com trecho "
                      f"repetido colado")
    if not quantas:
        falhas.append("nenhuma ajuda foi encontrada no `servidor.py` — "
                      "a leitura quebrou, e um zero assim nao e' verde")
    # Sem pendencia plantada a Home nao desenha «Resolver», e o balao dele sai
    # da conta calado — o mesmo zero que nao e' verde, pelo lado da casa.
    if not pendencias_com_conserto():
        falhas.append("nenhuma pendencia com conserto foi lida do `servidor.py` "
                      "— o balao do «Resolver» ficaria fora da conta")

    proc, url = sobe_servidor(montar_casa())
    if not url:
        print("XX o app/run.sh nao imprimiu a URL — nada a medir")
        proc.terminate()
        return 2

    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1600, "height": 900})
            # `networkidle` nunca chega: o painel mantem o `EventSource` do
            # pulso aberto de proposito, e ele conta como rede viva.
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_timeout(3000)

            print("\n2. AS ABAS, UMA A UMA")
            pequenos, medidos, baloes, p7 = percorrer(pag)

            print("\n3. O BALAO NO TECLADO (o risco declarado da sprint)")
            # A ficha de imagem e' onde a queixa nasceu: quatro botoes lado a
            # lado, e o balao de um cobria os outros tres.
            pag.locator('#trilho button:has-text("Papel de parede")').first.click()
            pag.wait_for_timeout(1200)
            pag.keyboard.press("Tab")
            pag.wait_for_timeout(120)
            r = pag.evaluate(FOCO_JS, ".galeria .acoes .btn[data-balao]")
            if r.get("erro"):
                falhas.append(f"o foco nao pode ser medido: {r['erro']}")
                print("  XX " + r["erro"])
            else:
                for cond, frase in [
                    (r["visto"], "o balao aparece no foco do teclado"),
                    (r["descrito"] == "balao",
                     "o botao focado aponta para o balao por aria-describedby"),
                    (not r["cobre"],
                     "o balao nao cobre nenhum botao irmao"
                     + (f" (cobre {r['cobre']})" if r["cobre"] else "")),
                    (len(r["texto"]) <= TETO_BALAO,
                     f"o balao do foco tem {len(r['texto'])} caracteres"),
                ]:
                    print(("  ok " if cond else "  XX ") + frase)
                    if not cond:
                        falhas.append(frase)
                pag.keyboard.press("Escape")
                pag.wait_for_timeout(150)
                fechou = pag.evaluate(
                    "() => { const b = document.getElementById('balao');"
                    " return !b || b.hidden; }")
                print(("  ok " if fechou else "  XX ") + "o Escape fecha o balao")
                if not fechou:
                    falhas.append("o Escape fecha o balao")
            nav.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()

    compridos = [b for b in baloes if len(b["texto"]) > TETO_BALAO]
    com_comando = [b for b in baloes if COMANDO_NO_BALAO.search(b["texto"])]
    nativos = [b for b in baloes if b["nativo"]]
    aparados = [b for b in baloes if b["aparado"]]

    print("\n4. OS TRES NUMEROS, E A PEGADA DA REDE")
    print(f"alvos com menos de {PISO_PX} px ................. "
          f"{len(pequenos)}   (antes da P6: 200)")
    print(f"baloes com mais de {TETO_BALAO} caracteres ......... "
          f"{len(compridos)}   (antes da P6: 243)")
    print(f"baloes com comando meow dentro ........... "
          f"{len(com_comando)}   (antes da P6: 159)")
    # A REDE EXISTE PARA NAO PEGAR NINGUEM, e por isso ela aparece no placar:
    # um balao aparado e' uma frase que estourou o teto na fonte e chegou a' tela
    # mutilada. Zero e' o unico numero aceito aqui.
    print(f"baloes que a rede teve de aparar ......... "
          f"{len(aparados)}   (o teto nao e' para chegar aqui)")
    print(f"\n({medidos} alvos e {len(baloes)} baloes medidos nas 14 abas; "
          f"{len(nativos)} baloes ainda sao `title` nativo)")

    print("\n5. OS TETOS DA P7, NA TELA")
    print(f"caminhos absolutos na tela .............. "
          f"{p7['caminhos']}   (antes da P7: 43)")
    print(f"nomes acessiveis com caminho dentro ..... "
          f"{len(p7['nomes'])}   (antes da P7: 34)")
    print(f"paragrafos de ajuda em minuscula ........ "
          f"{len(p7['minusculas'])}   (antes da P7: 21)")
    if p7["caminhos"]:
        falhas.append(f"{p7['caminhos']} caminhos absolutos visiveis na tela")
    if p7["nomes"]:
        falhas.append(f"{len(p7['nomes'])} nomes acessiveis com caminho dentro")
    if p7["minusculas"]:
        falhas.append(f"{len(p7['minusculas'])} paragrafos de ajuda comecando "
                      f"em minuscula")
    print(f"paragrafos pintados acima de {TETO_AJUDA} ......... "
          f"{len(p7['longos'])}   (antes da P82: as 12 legendas eram isentas)")
    if p7["longos"]:
        falhas.append(f"{len(p7['longos'])} paragrafos pintados acima de {TETO_AJUDA} caracteres")

    if DETALHE:
        print("\n--- quem reprovou -------------------------------------------")
        for a in pequenos:
            print(f"  alvo  {a['w']:4d}x{a['h']:<4d} [{a['aba'][:16]:16s}]"
                  f" {a['tag']}.{a['classe'][:26]} {a['rotulo']!r}")
        for b in compridos:
            print(f"  balao {len(b['texto']):4d} car [{b['aba'][:16]:16s}]"
                  f" {b['texto'][:90]!r}")
        for b in com_comando:
            print(f"  cmd        [{b['aba'][:16]:16s}] {b['texto'][:90]!r}")
        for b in aparados:
            print(f"  aparado {b['aparado']:4d} car na fonte "
                  f"[{b['aba'][:16]:16s}] {b['texto'][:70]!r}")
        for x in p7["onde"]:
            print(f"  caminho    [{x['aba'][:16]:16s}] {x['tag']}.{x['classe'][:20]}"
                  f" {x['texto']!r}")
        for x in p7["nomes"]:
            print(f"  nome       [{x['aba'][:16]:16s}] {x['tag']} {x['nome']!r}")
        for x in p7["minusculas"]:
            print(f"  minuscula  [{x['aba'][:16]:16s}] {x['classe'][:20]:22s}"
                  f" {x['texto']!r}")
        for x in p7["longos"]:
            print(f"  longo {x['tam']:4d} [{x['aba'][:16]:16s}] {x['classe'][:20]:22s}"
                  f" {x['texto']!r}")

    if pequenos:
        falhas.append(f"{len(pequenos)} alvos abaixo de {PISO_PX} px")
    if compridos:
        falhas.append(f"{len(compridos)} baloes acima de {TETO_BALAO} caracteres")
    if com_comando:
        falhas.append(f"{len(com_comando)} baloes com comando meow dentro")
    if aparados:
        falhas.append(f"{len(aparados)} baloes que a rede teve de aparar "
                      f"(o maior tinha {max(b['aparado'] for b in aparados)} "
                      f"caracteres na fonte)")
    if nativos:
        falhas.append(f"{len(nativos)} baloes ainda sao `title` nativo")

    print()
    if falhas:
        for f in falhas:
            print("XX " + f)
        print(f"\n{len(falhas)} reprovacoes.")
        return 1
    print("ok  os tres numeros da P6 estao em zero, o teto de 80 se sustenta na")
    print("    fonte e na tela, e o balao responde ao teclado.")
    print("ok  os quatro tetos da P7 estao em zero: nenhum caminho absoluto na")
    print("    tela nem em nome acessivel, nenhuma ajuda acima de "
          f"{TETO_AJUDA} na fonte")
    print("    do servidor, nenhuma com trecho repetido, e nenhum paragrafo")
    print("    de ajuda abrindo em minuscula.")
    return 0


if __name__ == "__main__":
    # O brinquedo sai sempre, inclusive quando o teste morre no meio: ele e'
    # uma casa inteira em /tmp, com um `sudo` falso dentro.
    try:
        sys.exit(main())
    finally:
        shutil.rmtree(BRINQUEDO, ignore_errors=True)
