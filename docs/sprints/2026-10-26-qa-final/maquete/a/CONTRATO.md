# Maquete A: contrato

## A moldura (copie exatamente)

Toda página da maquete é esta moldura. Muda só:

- o `<title>`;
- o `data-porta` do `body` (`tema`, `criar`, `ajustes`, `cuidar`, `extensoes`);
- o `aria-current="page"` da porta;
- o `nav.abas-ajustes`, que vai entre `</header>` e `<main>` quando a porta tem seções;
- o conteúdo de `main#principal`.

Os caminhos são relativos a `maquete/a/`. A maquete B usa `../a/estilo.css`, `../a/demo.js` e `../a/svg/`, ou copia esses arquivos.

A barra de abas da seção, quando existe, fica entre o `</header>` e o `<main>`:

```html
<nav class="abas-ajustes" id="abas" aria-label="Definir">
  <ul>
    <li><a href="#painel" data-controle="ajuste:painel" aria-current="page"><svg class="i" viewBox="0 0 24 24" aria-hidden="true">…</svg><span>Painel e dock</span></a></li>
    <li><a href="#janelas" data-controle="ajuste:janelas"><svg …></svg><span>Janelas e tela</span></a></li>
  </ul>
  <div class="fila"><button type="button" class="bt pequeno" data-acao>Recarregar o painel</button></div>
</nav>
```

A prévia fixa: `main > .oficina` com `[.palco > .previa, .pilha]`. Sem prévia: `.oficina.sem-previa`.

```html
<div class="oficina">
  <div class="palco"><figure class="previa" id="previa" …>…</figure></div>
  <div class="pilha">…blocos…</div>
</div>
```

### Página inteira (`extensoes.html`)

```html
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeowSystem · Extensões</title>
<link rel="icon" type="image/svg+xml" href="svg/logo-meowsystem.svg">
<link rel="stylesheet" href="estilo.css">
</head>
<body data-porta="extensoes" data-estado="normal">
<a class="pular" href="#principal">Pular para o conteúdo</a>
<header class="topo" id="topo">
  <a class="marca" href="tema.html" data-controle="marca"><img src="svg/logo-meowsystem.svg" alt="" width="30" height="30"><span>MeowSystem</span></a>
  <nav aria-label="Portas">
    <ul class="portas" id="portas">
      <li><a href="tema.html" data-controle="porta:tema"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="13.5" cy="6.5" r="1.5"/><circle cx="17.5" cy="10.5" r="1.5"/><circle cx="8.5" cy="7.5" r="1.5"/><circle cx="6.5" cy="12.5" r="1.5"/><path d="M12 2a10 10 0 0 0 0 20c1.1 0 2-.9 2-2 0-.5-.2-1-.5-1.3-.3-.4-.5-.8-.5-1.3 0-1.1.9-2 2-2h2.3A5.7 5.7 0 0 0 22 9.7C22 5.4 17.5 2 12 2Z"/></svg><span>Tema</span></a></li>
      <li><a href="personalizar.html" data-controle="porta:criar"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg><span>Personalizar</span></a></li>
      <li><a href="definir.html" data-controle="porta:ajustes"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/></svg><span>Definir</span></a></li>
      <li><a href="manter.html" data-controle="porta:cuidar"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/></svg><span>Manter</span></a></li>
      <li><a href="extensoes.html" data-controle="porta:extensoes" aria-current="page"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 3h6v4a2 2 0 1 0 4 0V3h2v6h-4a2 2 0 1 0 0 4h4v8h-8v-4a2 2 0 1 0-4 0v4H3v-8h4a2 2 0 1 0 0-4H3V3Z"/></svg><span>Extensões</span></a></li>
    </ul>
  </nav>
  <div class="busca" id="caixa-busca" role="search">
    <button type="button" class="bt leve so-icone abrir-busca" id="abrir-busca" aria-label="Procurar um ajuste" data-controle="busca"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg></button>
    <svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
    <input id="busca" type="search" placeholder="Procurar um ajuste" aria-label="Procurar um ajuste" autocomplete="off" aria-controls="achados">
    <kbd>/</kbd>
    <div class="achados" id="achados" role="listbox" aria-label="Achados"></div>
  </div>
  <div class="aplicar" id="aplicar" data-n="3">
    <span class="gravando" id="gravando" role="status" data-estado="ok" aria-label="Gravado"><svg class="i so-ok" viewBox="0 0 24 24" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg><svg class="i so-erro" viewBox="0 0 24 24" aria-hidden="true"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/></svg></span>
    <button type="button" class="conta" id="conta" aria-expanded="false" aria-controls="ultimas" data-controle="mudancas">3 mudanças</button>
    <button type="button" class="bt leve pequeno desfazer" id="desfazer" data-controle="descartar"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg>Desfazer</button>
    <div class="menu-corpo ultimas" id="ultimas" role="list" aria-label="Últimas mudanças" hidden>
      <div class="ultima" role="listitem" data-indice="0">
        <span><b>Solta da borda (dock)</b><small>Sim → Não</small></span>
        <button type="button" class="bt leve pequeno" data-controle="desfazer-uma"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg>Desfazer</button>
      </div>
      <div class="ultima" role="listitem" data-indice="1">
        <span><b>Cantos (barra de cima)</b><small>12 px → 16 px</small></span>
        <button type="button" class="bt leve pequeno" data-controle="desfazer-uma"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg>Desfazer</button>
      </div>
      <div class="ultima" role="listitem" data-indice="2">
        <span><b>Segundos no relógio</b><small>Não → Sim</small></span>
        <button type="button" class="bt leve pequeno" data-controle="desfazer-uma"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg>Desfazer</button>
      </div>
    </div>
  </div>
  <details class="menu" id="menu">
    <summary class="bt leve pequeno so-icone" aria-label="Mais" data-controle="menu"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/></svg></summary>
    <div class="menu-corpo" id="menu-corpo">
      <button type="button" data-controle="creditos"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9Z"/></svg>Créditos</button>
      <button type="button" data-controle="exportar-pagina"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></svg>Esta tela num arquivo</button>
    </div>
  </details>
</header>
<main id="principal" class="pagina">
  <h1 class="sr">Extensões</h1>
</main>
<div id="torradas" class="torradas" aria-live="polite"></div>
<div id="dica" class="dica" hidden></div>
<dialog id="resultado" class="resultado" aria-labelledby="resultado-titulo">
  <div class="dentro">
    <header class="resultado-topo">
      <h2 id="resultado-titulo">Instalar tudo</h2>
      <div class="fila"><span class="estado-pilula" id="resultado-estado" data-estado="correndo">Rodando</span></div>
    </header>
    <details class="registro" id="registro">
      <summary>Registro</summary>
      <pre id="saida"></pre>
    </details>
    <div class="acoes">
      <button type="button" class="bt perigo" id="parar" data-controle="parar">Parar</button>
      <button type="button" class="bt" id="resultado-restaurar" data-controle="restaurar" hidden><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg>Restaurar</button>
      <button type="button" class="bt" id="resultado-guardar" data-controle="guardar-log"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></svg>Guardar</button>
      <button type="button" class="bt principal" id="resultado-ok" data-controle="resultado:ok">OK</button>
    </div>
  </div>
</dialog>
<dialog id="pergunta" aria-labelledby="pergunta-titulo">
  <form class="dentro" method="dialog">
    <h2 id="pergunta-titulo">Falta a ponte</h2>
    <div id="pergunta-corpo" hidden></div>
    <div class="acoes">
      <button class="bt" value="nao" id="pergunta-nao">Cancelar</button>
      <button class="bt principal" value="sim" id="pergunta-sim"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 18h20M4 18V9M20 18V9M4 9c4 4 12 4 16 0M9 13v5M15 13v5"/></svg>Consertar a ponte</button>
    </div>
  </form>
</dialog>
<script src="demo.js"></script>
</body>
</html>
```

## Páginas

| arquivo | porta (`data-porta`) | o que tem |
|---|---|---|
| `tema.html` + `tema.js` | `tema` | os packs MeowSystem e Dracula com variantes, Cor de destaque, Claro ou escuro, «Criar o meu tema» |
| `definir.html` + `definir.js` | `ajustes` | sete seções por `#hash`: `painel`, `janelas`, `papel`, `mascote`, `noite`, `terminal`, `programas` |
| `manter.html` + `manter.js` | `cuidar` | estado, pendências, três cartões, Sozinho, Ícones da máquina, Construídos, Registro, perigo |
| `extensoes.html` | `extensoes` | só a moldura (da maquete B) |
| `demo.js` | todas | moldura: gravando, mudanças, desfazer, busca, diálogos, estados |
| `prova.py` | — | a prova headless (abaixo) |

## Estados de demonstração

Na URL: `pagina.html#estado=<e>` ou, no Definir, `definir.html#painel&estado=<e>`. O `demo.js` põe
`body[data-estado]` e liga `[data-so~=e]` e desliga `[data-nao~=e]`.

| estado | o que muda |
|---|---|
| `normal` | o padrão |
| `vazio` | Tema: «Nenhum tema pronto»; Manter: «Nada pendente»; Papel: galeria vazia; Programas: Jogos vazio |
| `carregando` | esqueletos no lugar dos blocos (`.esqueleto`, `.esqueleto-grade`) |
| `erro` | `#gravando[data-estado=erro]` e a torrada fixa «Sem servidor»; Manter: topo «Sem servidor» com «Tentar de novo»; trabalhos terminam em «Falhou» com o registro aberto |
| `sem-ponte` | toda ação `[data-root]` e a chave do lançador abrem «Falta a ponte» → «Consertar a ponte»; Manter: topo «Falta a ponte», Ponte vermelha na faixa |

## Elemento → classe → item do relatório → sprint

| elemento | id / classe | item | sprint |
|---|---|---|---|
| gravar ao soltar, sem Aplicar nem Ver sem mudar | `#gravando`, `#conta`, `#ultimas .ultima`, `#desfazer` | Q2-04, Q2-05, Q2-06, Q2-07, Q1-14 | P109 |
| rótulo com a coluna na lista de mudanças | `anotar()` em `demo.js`, `rotuloDe()` em `definir.js` | Q2-19 | P109 |
| ação abre o diálogo de resultado | `[data-acao]` → `dialog#resultado` | Q3-07 | P109 |
| modal «Instalar tudo» cabe e mostra os botões | `dialog.resultado`, `.registro pre` | Q3-01 | P110 |
| abas horizontais fixas acima da prévia | `nav.abas-ajustes` (top 64) | Q2-08, Q2-09 | P110 |
| prévia grande e fixa | `.oficina > .palco` (sticky, top 132), `.previa` | Q2-09 | P110 |
| a prévia reage a cada controle | `.previa[data-*]`, `--p-*` (tabela abaixo) | Q2-01, Q2-02, Q2-03 | P110 |
| linhas de duas colunas sem vazar | `.linha.dupla`, `@container` em `.oficina > .pilha` | Q2-10 | P110 |
| um ↶ por coluna | `.ctl[data-coluna] > .padrao` | Q2-19 | P110 |
| deslizante «Auto» vazio; margem desligada com a barra colada | `.faixa[data-vazio]`, `.ctl.desligado` | Q2-20 | P110 |
| busca vira ícone em meia tela; «/» abre | `.busca .abrir-busca`, `.busca.campo-aberto` | Q2-11 | P110 |
| Programas sem prévia, grade larga | `.oficina.sem-previa`, `.grade-cuidar` | Q2-12 | P110 |
| cartões de Manter com o desenho ao lado | `.cartao-acao` | Q3-03 | P110 |
| portas Tema · Personalizar · Definir · Manter · Extensões | `#portas` | Q1-12 | P111 |
| Tema sem Ver, sem No ar agora, sem Mais ajustes; «Criar o meu tema» | `.pack`, `.variantes`, `.criar-meu` | Q1-11, Q1-16 | P111 |
| Tema sem selects com valor falso | `.variantes button[aria-pressed]`, `.seg[data-chave=MODO]` | Q1-15 | P111 |
| sem «Mais ajustes»: raros no fim; «Ver» no bloco Conferir | último `.bloco` de cada seção | Q2-13 | P111 |
| itens de máquina dos ícones vão para Manter | bloco «Ícones da máquina» | Q1-09 | P111 |
| Modo de leitura com prévia e régua | `.quente`, `.papel`, `.regua-noite` | Q2-17 | P111 |
| Manter: só «Conferir» no topo | `.estado-maquina .fila` | Q3-04 | P111 |
| Manter botão por botão | `.cartao-acao`, Sozinho, Registro, `.bloco.tracejado` | Q3-05 | P111 |
| pendência com o nome do assunto | `.pendencias .linha` | Q3-06 | P111 |
| Escondidos sugere programas e recusa texto solto | `.nova-ficha`, `.sugestoes`, `[aria-invalid]` | Q2-14 | P113 |
| sem Baixar/Instalar que não cabem (Spotify, starship, coleção, menu) | Programas, Terminal | Q2-15, Q2-16 | P113 |
| estado dos builds | bloco «Construídos» | Q2-18 | P114 |
| porta Extensões | `extensoes.html` | Q3-10 | P114 |

## Controle → prévia

Cada linha é conferida pelo `prova.py` (a assinatura visual da prévia muda depois do gesto).

| controle (`data-chave`) | na prévia |
|---|---|
| `FORMA_PAINEL_SOLTO`, `FORMA_DOCK_SOLTO` | `data-solto-painel`, `data-solto-dock`: barra/dock longe da borda; desliga a Distância |
| `FORMA_PAINEL_ILHA`, `FORMA_DOCK_ILHA` | `data-ilha-*`: pastilha no meio em vez de borda a borda |
| `FORMA_MARGEM_*` | `--p-margem-painel`, `--p-margem-dock` (px × 0,12 cqi) |
| `FORMA_RAIO_*` | `--p-raio-*`: cantos |
| `FORMA_ESPACO_*` | `--p-espaco-*`: espaço entre ícones |
| `FORMA_RECHEIO_*` | `--p-recheio-*`: folga interna |
| `VIDRO_OPACIDADE_*` | `--p-vidro-painel`, `--p-vidro-dock` (%) |
| `FORMA_ALA_INICIAL_*`, `FORMA_CENTRO_*`, `FORMA_ALA_FINAL_*` | `--p-b-ini/centro/fim` e `--p-ala-ini`, `--p-centro`, `--p-ala-fim` (XS 2,6 · S 3,05 · M 3,5 · L 3,95 · XL 4,4 cqi) |
| `RELOGIO_SEGUNDOS` | `data-segundos`: «:07» no relógio |
| `MIDIA`, `MIDIA_CAPA`, `MIDIA_CONTROLES` | `data-musica`, `data-capa`, `data-tocar` |
| `MIDIA_LARGURA`, `MIDIA_FONTE` | `--p-musica-largura`, `--p-musica-letra` |
| `MIDIA_COR_TITULO`, `MIDIA_COR_ARTISTA`, `MIDIA_COR_ALBUM` | `--p-musica-titulo`, `--p-musica-artista`, `--p-musica-capa` |
| `JANELAS_TILING` | `data-tiling`: janelas lado a lado |
| `CURSOR` | `--p-ponteiro`: cor do ponteiro |
| galeria do Papel de parede | `.parede[src]` |
| `WALLPAPER_AJUSTE` | `.parede` com a classe do encaixe |
| `LOGO`, `FASTFETCH_LOGO_MODO`, `FASTFETCH_LOGO_GATO` | `.p-dock .gato[src]`, `.gato-ff img[src]` |
| `FASTFETCH_LOGO` | `data-ff`: desenho no terminal |
| `LEITURA_TEMPERATURA` | `.quente` opacidade = min((6500 − K) / 6500 × 0,6; 0,45) |
| `LEITURA_TEXTURA` | `.papel` opacidade |
| horários de Mascote, Modo de leitura, Papel da noite | `.regua-noite` (faixas por hora) |
| `TERMINAL_ESQUEMA`, `TERMINAL_CURSOR`, `PROMPT_STARSHIP` | `data-esquema`, `--p-cursor`, `data-prompt` |

## Prova

```bash
~/.local/share/meowsystem/venv-testes/bin/python3 prova.py
```

Headless, `file://`, em 1920×1080, 1550×860, 1500×900 e 1280×800, nas três portas, nas sete seções
do Definir e nos quatro estados. Confere: nenhum elemento mais largo que o pai nem com conteúdo
vazando; `scrollWidth` do documento igual a `innerWidth`; depois de rolar até o fim, topo em 0, abas
em 64 e palco em 116 ou mais e inteiro na tela; prévia com 900 px ou mais em 1920; a tabela acima; o
modal «Instalar tudo» com todos os botões à vista; «Falta a ponte» e «Sem servidor». Capturas em
`capturas/`, fora do git.
