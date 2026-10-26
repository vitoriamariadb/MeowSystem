# Maquete B: contrato

Personalizar (`personalizar.html`) e Extensões (`extensoes.html`). Abre por `file://`, sem rede.

## A moldura é a da maquete A

- `estilo.css` e `demo.js` são cópia fiel de `maquete/a/` (commit `1c967337`). Não edite aqui: copie de novo.
- O cabeçalho, os dois diálogos (`#resultado`, `#pergunta`), `#torradas` e `#dica` são o markup de
  `maquete/a/extensoes.html`. Muda só o que o contrato de A permite: `data-porta`, `aria-current`,
  o `nav.abas-ajustes` e o miolo.
- As portas Tema, Definir e Manter apontam para `../a/`.
- A prévia segue a estrutura de A (`.p-barra > .ws/.meio/.bandeja`, `.p-dock > .ala-ini/.centro/.ala-fim`).
- A barra de mudanças é a de A: `anotar()` e `MUDANCAS` do `demo.js`. O `maquete.js` só chama essas funções.
- `estilo-b.css` traz só as classes que A e o app não têm. `paleta.css` traz as cores dos sabores e do Dracula.

## Só da maquete

- `.maquete-ctl` (canto de baixo à esquerda) troca o estado: normal, vazio, carregando, erro,
  sem ponte e, em Extensões, atualização.
- Parâmetros de URL: `?estado=`, `?sabor=` (mocha, macchiato, frappe, latte, alucard, dracula),
  `?sub=` (apps, sistema, biblioteca), `?app=spotify`, `?fonte=acervo`, `?passo=` (url, ficha, erro)
  e `?creditos=1`. A aba vem do `#`.
- As classes `.so-<estado>`, `.fora-<estado>`, `.so-meowsystem` e `.so-dracula` escondem por estado
  e por pack. No app, quem decide é o servidor.
- `svg/*/variantes/spotify-*.svg` ilustram a saída de cada predefinição do gerador. Foram desenhadas
  para a maquete; o gerador real sai de `scripts/`.
- O registro de compilação em «Adicionar repositório» é ilustrativo. A URL e o commit são reais:
  `cosmic-utils/cosmic-ext-applet-now-playing` @ `66df229`.
- `papel/*.jpg` são miniaturas locais (640 px) dos papéis do pack MeowSystem. O `.gitignore` as
  barra: gere de novo com `convert "packs/meowsystem/wallpapers/<nome>[0]" -resize 640x papel/<nome>.jpg`.
  Sem elas, a galeria e a prévia do MeowSystem ficam sem imagem.

## SVG copiados

São todos dos packs, sem desenho novo. Os de traço (`currentColor`) foram pintados com a Mocha.

| pasta | origem |
|---|---|
| `svg/meowsystem/apps/`, `pastas/`, `tipos/`, `biblioteca/` | `packs/meowsystem/icones/` |
| `svg/dracula/apps/`, `pastas/`, `biblioteca/` | `packs/dracula/icones/` |
| `svg/*/logo.svg`, `svg/*/mascote.svg` | `packs/*/mascote/` e o logo do pack |
| `svg/dracula/papel/` | `packs/dracula/wallpapers/` |
| `svg/original/spotify.svg` | o ícone hicolor do flatpak do Spotify |
| `svg/applets/` | o ícone de cada repo `meowsystem-<id>` |

## Sons

- MeowSystem toca o que está em `/usr/share/sounds/Pop/stereo/{action,alert,notification}/`.
- `dialog-warning` existe só em `/usr/share/sounds/freedesktop/stereo/`.
- Dracula toca `packs/dracula/sons/stereo/{action,alert,notification}/*.oga`, pelo caminho relativo
  `../../../../../packs/…`.
- O sino é sintetizado no navegador com a conta de `scripts/som.sh`: 0,085 s, ganho 0,18, rampas de 2 ms,
  `exp(-t·decaimento)`, duas senoides com peso. Os valores iniciais são os do pack:
  MeowSystem 880 / 1320 / 0,62 / 0,28 / 46; Dracula 784 / 932,3 / 0,58 / 0,32 / 38.

## Elemento → onde → item → sprint

### Personalizar

| elemento | id / classe | item | sprint |
|---|---|---|---|
| abas da seção, presas sob o cabeçalho | `nav.abas-ajustes#abas` | Q2-08, Q2-09 | P110 |
| pack em edição | `.abas-ajustes .fila .editando` | Q1-02, Q1-05 | P112 |
| prévia fixa, ≥ 900 px em 1920 | `.oficina > .palco > .previa#previa` | Q2-09 | P110 |
| ícone mexido marcado na dock da prévia | `.previa .alvo-spotify.mudou-aqui` | Q1-01, Q1-02 | P112 |
| barra «N mudanças · Desfazer» e a lista | `#aplicar`, `#conta`, `#ultimas`, `#desfazer` | Q1-14 | P109 |
| Cores: nome, «Começa de», seis cores com contraste, as 26 | `[data-aba-corpo="cores"]`, `.comeca`, `.poco` | Q1-14 | P109, P111 |
| Papel: galeria do pack, encaixe | `[data-aba-corpo="papel"] .galeria`, `[data-encaixe]` | Q1-05 | P112 |
| Ícones: Apps, Sistema, Biblioteca, só do pack | `.sub-abas [data-sub]`, `.grade-apps.so-<pack>` | Q1-05, Q1-06, Q1-07 | P112 |
| marca de origem do ícone | `.grade-apps .app .marca-origem[data-origem]` | Q1-02 | P112 |
| oficina sem caixa dentro de caixa | `.desenho#desenho` (`.desenho-olho`, `.desenho-mao`, `.desenho-pe`) | Q1-10 | P112 |
| um «Usar» só, que grava no pack | `#d-usar`, `#d-salvo`, `#d-desfazer` | Q1-02, Q1-10 | P112 |
| Partida: Original, Do pack, Salvo | `.oficina-cartao[data-src]`, `[data-salvo]` | Q1-01, Q1-02 | P112 |
| gerador MeowSystem, traço Arcticons | `.desenho .so-meowsystem` (Fiel, Limpo, Silhueta, Detalhe, Área cheia, Da capa), `#r-detalhe`, `#r-suave`, `#r-fracas`, `#r-minimo` | Q1-08 | P112 |
| gerador Dracula, disco com glifo | `.desenho .so-dracula` (Disco, Disco e aro, Lua, Glifo solto, Da capa), `#r-glifo` | Q1-08 | P112 |
| Do acervo | `[data-fonte="acervo"]`, `.grade-glifos.acervo` | Q1-07 | P112 |
| sino do volume: tocar, envelope, cinco números | `.sino[data-sino]`, `#<pack>-f/-h/-pf/-ph/-d`, `[data-envelope]` | Q1-03 | P113 |
| sons: nome legível, quando toca, ouvir, trocar, origem | `ul.sons.com-origem li`, `.som-nome`, `button.p[data-som]`, `[data-trocar]`, `[data-origem]` | Q1-04 | P113 |
| carregador e bateria pela ponte | `.so-sem-ponte`, `.aviso-linha` | Q1-04 | P113 |
| Mandar: resumo desde o primeiro passo | `[data-aba-corpo="mandar"] .resumo`, `.amostras`, `.icones-mini` | Q1-13, Q1-18 | P113 |
| Mandar: erro com registro | `.registro.so-erro` | Q3-01 | P111 |
| Créditos: os dois autores e os upstreams | `dialog#creditos`, `.creditos.upstreams` | Q3-09 | P114 |

### Extensões

| elemento | id / classe | item | sprint |
|---|---|---|---|
| porta própria, abas Applets e Builds | `body[data-porta="extensoes"]`, `#abas a[data-aba]` | Q3-10 | P114 |
| barra da prévia com as asas reais | `.barra-perto`, `#asa-direita`, `.applet-na-barra(.nosso)` | Q3-10 | P114 |
| cartão por applet: ícone, nome, estado, versão | `.grade-extensoes article.cartao-acao[data-applet]`, `.cartao-cabeca`, `[data-pilula]`, `.versao` | Q3-10 | P114 |
| repo e commit na dica da versão | `.versao .dica-repo` | Q3-09, Q3-10 | P114 |
| Instalar, Atualizar, Remover, Pôr no painel | `[data-instalar]`, `.so-atualizacao`, `[data-por]`, `.bt.so-icone` (lixeira) | Q3-10 | P114 |
| troca de Quick Settings por Ajustes rápidos | `#pendencia`, `[data-trocar-qs]`, `#na-barra-qs` | Q3-10 | P114 |
| applet que falhou, com registro | `.so-erro .registro` | Q3-01, Q3-10 | P114 |
| Builds: compositor, menu do Arquivos, applets | `[data-aba-corpo="builds"] .linha`, `.estado-pilula`, botão «Refazer» | Q2-18 | P114 |
| refazer ao entrar na sessão | `.chave` na seção Builds | Q2-18 | P114 |
| Adicionar repositório: URL, commit, compilando, erro | `dialog#adicionar[data-passo]`, `#repo-url`, `.ficha-repo`, `.p-url/.p-ficha/.p-compilando/.p-erro/.p-pronto` | Q3-10 | P114 |
| URL inválida | `#adicionar[data-passo="erro-url"]` | Q3-10 | P114 |

## Prova

`prova.py` (Playwright, headless, `file://`) abre 26 telas em 1920×1080, 1550×860, 1500×900 e
1280×800. Em cada uma, nenhum elemento passa da largura do pai, a página não rola de lado, e, rolada
até o fim, o cabeçalho fica em 0, as abas em 64 e a prévia inteira na tela. As capturas ficam em
`capturas/`, fora do git.
