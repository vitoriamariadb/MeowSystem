# `app/` — o painel de configuração visual

Uma página local que configura **tudo o que hoje só se configura editando o
`~/.config/meow/meow.conf` ou digitando comandos do `meow`**. As 102 chaves, com
o valor que você escolheu, o que vinha de fábrica e a explicação de cada uma; e
34 ações, com a saída aparecendo ao vivo enquanto rodam.

```bash
./app/run.sh
```

Ou o ícone **MeowSystem** no lançador, que é o mesmo caminho.

---

## Por que a pasta se chama `app/`, e não `painel/`

Porque neste repositório **"painel" já é a barra de cima do COSMIC**, e a palavra
tem cinco donos: `scripts/painel.sh`, `lib/painel.sh`, `meow painel`,
`meow-painel.service` e a seção inteira do README sobre a barra que sumia. Uma
pasta `painel/` faria `meow painel teto` e `painel/index.html` serem dois
assuntos sob um nome só — que é exatamente o tipo de ambiguidade que este
projeto persegue em toda parte.

`app/` estava livre, e a distinção com o plural se sustenta: **`apps` (plural) são
os aplicativos que o projeto tematiza** (`meow apps`, `APPS_ATIVOS`,
`aplicar_apps.sh`), **`app` (singular) é este** — o aplicativo do próprio
MeowSystem. Pelo mesmo motivo a etapa e a checagem não se chamam `app`: elas se
chamam **`atalho`**, porque o que elas instalam é o atalho do lançador, e
`chk_app` ao lado de `chk_apps` na tabela do `doctor` seria uma linha que ninguém
lê duas vezes sem errar.

E `app/` não quebra a regra de topo do README (`assets/` é o que o projeto
**desenha**, `src/` é o que ele **compila**): isto não é nem uma coisa nem outra
— é o que ele **serve**.

---

## O que tem dentro

```
app/
  run.sh          sobe o backend, abre o navegador, e derruba tudo ao sair
  servidor.py     o backend: lê o conf, escreve pelo meow_conf_definir, roda ações
  pagina/
    index.html    o esqueleto (nenhum nome de chave escrito nele)
    estilo.css    o visual (nenhum hex escrito nele)
    app.js        monta a tela a partir do que o servidor derivou
    standalone.js só existe dentro do HTML exportado: troca o fetch pelos
                  dados congelados e as imagens pelos data: embutidos
    standalone.css o pouco que a página exportada acrescenta
```

Fora daqui, mas parte disto:

```
scripts/atalho.sh          instala/confere/remove o .desktop e o lançador
docs/folhas/               as 19 folhas visuais que vieram da home
```

---

## A ideia que sustenta o resto: **o catálogo é derivado**

Não existe uma lista de chaves neste diretório. O `servidor.py` lê o
`meow.conf.exemplo` e tira de lá, para cada chave: a ordem, a seção, o comentário
que a explica, as opções (`a | b | c`), a faixa numérica, se é lista, se é
horário, se aceita vazio, e se é `[essencial]`.

São as **mesmas regras** que o `wiz_ler_esquema` do `bin/meow` usa para o
`meow configurar`. Uma chave nova no `meow.conf.exemplo` aparece nesta página
sozinha; uma chave que sair de lá some daqui sozinha.

Isso não é elegância — é a cicatriz da **armadilha nº 3** deste repositório
(`docs/idempotencia-armadilhas.md`): *toda lista fixa é uma lista que alguém vai
esquecer*. O `bin/meow` pagou essa conta duas vezes. Em 11/08/2026 as doze chaves
`FORMA_*` não tinham efeito nenhum porque não estavam numa lista de `export`
escrita à mão; em 25/08/2026 seis chaves novas nasceram mortas pelo mesmo motivo,
com o `doctor` dizendo "já conforme" sem ter conferido — o pior sintoma possível.

`tests/app.sh` compara as duas leituras (a do bash e a do Python) e falha se elas
divergirem, para que a divergência apareça no mesmo dia e não meses depois.

---

## Quem escreve no `meow.conf`

`meow_conf_definir`, de `lib/comum.sh`. Sempre. O backend chama literalmente:

```bash
bash -c '. "$1/lib/comum.sh"; meow_conf_definir "$2" "$3"' _ RAIZ CHAVE VALOR
```

Python tem `re.sub` e seria uma linha — e seria a **terceira** rotina de escrita
na mesma chave. O cabeçalho de `lib/comum.sh` conta o que aconteceu quando
existiram duas: uma trocava a *primeira* ocorrência enquanto o shell obedece a
*última*, e o `meow configurar` gravava `2h` mostrando o diff certo enquanto o
valor em vigor continuava `1d`, sem nada acusar.

A página devolve os três códigos do projeto com as palavras do projeto:

| código | o que a página diz |
|---|---|
| `0` | "já estava assim" — não é silêncio, é a resposta que a idempotência permite dar |
| `1` | "gravado" |
| `2` | o erro, com o texto que o bash imprimiu |

**Conferido em 01/09/2026:** gravar `LOG_NIVEL` com o valor que ele já tinha
devolve `0` e o md5 do `meow.conf` não muda; gravar outro valor e voltar deixa o
arquivo **idêntico byte a byte** — o comentário da linha e os espaços que o
alinham sobrevivem.

### Gravar não é aplicar, e a página não finge que é

Escrever a chave e o tema mudar na tela são coisas diferentes neste projeto desde
sempre — é o que a primeira linha do `meow.conf` diz: *"Editou uma linha? Rode:
`meow aplicar`"*. Um clique em `FLAVOR` não repinta o COSMIC: a etapa de tema
copia árvore de arquivo, e o painel precisa reciclar.

Então a página **conta**: acende um aviso com quantas chaves foram gravadas e
ainda não valeram na tela, com o botão que as aplica ao lado.

---

## O modo seco

O interruptor **Modo seco** no topo põe `MEOW_DRY_RUN=1` em tudo que aceita — as
escritas de chave e as ações. É a promessa do projeto, e ela vale aqui:
**medido em 01/09/2026**, gravar uma chave em seco devolve `1` com
`~~ mudaria /home/…/meow.conf` e o md5 do arquivo não muda.

Ele fica amarelo quando ligado, de propósito. Um seco esquecido ligado é ela
clicando em "instalar" e nada acontecendo.

---

## As ações

Trinta e quatro, agrupadas por assunto: ciclo de vida (instalar, doctor, consertar,
desinstalar, log), tema e cor, ícones e gato, papel de parede, barra e janelas,
aplicativos.

Cada uma mostra o comando exato que vai rodar, e as que merecem aviso o trazem
antes do clique: **pode usar sudo**, **desfaz coisas**, **usa rede**, **aceita
seco**. As três primeiras exigem confirmação num diálogo que repete o comando.

**Um trabalho por vez.** `./install.sh` e `meow doctor --consertar` pegam o
`flock` de `~/.local/state/meowsystem/lock` (regra 10 do contrato); dois cliques
rápidos dariam *"outro meow está rodando"* com o culpado sendo a própria página.
O servidor recusa o segundo e diz qual está correndo.

**A saída é acumulada, não transmitida.** Um `text/event-stream` seria menos
código e cairia junto com a aba — um F5 no meio de um `./install.sh` mataria o
processo. Guardando as linhas no servidor, a página pode fechar, recarregar e
voltar a acompanhar o mesmo trabalho de onde parou. É o que uma instalação de 49
etapas pede.

### O sudo, e o que foi medido

O plano inicial era confortável e **errado**: *"o backend não tem tty, então todo
sudo falha sozinho"*. Medido nesta máquina em 01/09/2026:

```
$ sudo -n -v ; echo $?
0
$ sudo -n -l | grep timestamp
... timestamp_type=global, timestamp_timeout=60
```

`timestamp_type=global` quer dizer que o cache do sudo **não é por terminal**: um
`sudo` digitado em qualquer janela na última hora faz `sudo -n` devolver `0` aqui
dentro, sem tty e sem perguntar. Ou seja, `./install.sh` disparado por um clique
**pode** atravessar as etapas de `/usr/share` — se a hora for aquela.

Nenhuma senha é pedida, lida, guardada ou passada adiante em ponto nenhum deste
código. O que existe é o cache que já era dela. O que mudou é que agora **está
dito**, no diálogo, antes do clique. Se o cache estiver frio, aquelas etapas se
pulam sozinhas e aparecem em `pulado:`.

---

## Como ele é servido

`python3` da biblioteca padrão (`http.server`), **sem uma dependência nova**.

- escuta em `127.0.0.1` e em **porta efêmera** — o kernel escolhe, não há porta
  fixa para adivinhar, e não há bind em `0.0.0.0` em lugar nenhum;
- **token de sessão** sorteado a cada execução (`secrets.token_urlsafe(32)`),
  comparado com `hmac.compare_digest`. Ele entra na página uma vez e o `app.js`
  o tira da barra de endereço no primeiro instante — nada de `localStorage`, nada
  em disco: o token vale enquanto o processo viver;
- o cabeçalho **`Host`** é conferido contra `(127.0.0.1|localhost):<porta>`, o
  que fecha o DNS rebinding; **`Origin`**, quando vem, tem de bater;
- **nenhum comando vem da página como texto.** A página manda um `id` de ação, e
  o `id` é chave de um dicionário fechado. O argumento, quando existe, é conferido
  contra uma lista montada **do disco** (as capturas que existem, os gatos que
  existem). Não há `shell=True` neste código.

**Conferido em 01/09/2026**, com `curl`: sem token → 403; token errado → 403;
`Host: evil.com` → 403; `Origin: http://evil.com` → 403; `/../../etc/passwd` →
404; chave fora do `meow.conf.exemplo` → recusada; argumento `"; rm -rf /"` numa
ação → *"argumento fora da lista do disco"*.

---

## A cor não mora no CSS

`estilo.css` não tem **um hex**. Ele consome `var(--base)`, `var(--accent)` e
companhia; quem as define é `/paleta.css`, que o `servidor.py` gera a partir de
`assets/paleta/catppuccin.json` no **flavor que o seu `meow.conf` manda**.

É a regra do README (*"nenhum hex vive dentro de script"*) aplicada ao lugar mais
provável do mundo para alguém digitar um `#1e1e2e` de memória. E tem efeito
prático: trocar `FLAVOR="latte"` e recarregar veste a página inteira de claro,
sem uma linha de CSS a mais. `MODO="claro"` também — o que você vê na tela é o
tema claro, e um painel escuro no meio disso seria a única janela fora do lugar.

O `mauve` (ou o seu `ACCENT`) aparece **só onde algo está ligado, selecionado ou
é a ação principal** — a regra da Sprint T, *"mauve significa aceso"*. Espalhá-lo
por decoração apagaria o sinal.

---

## Levar embora, e trazer de volta

O **Exportar**, ao lado do Modo seco, tem duas saídas — e elas são coisas
diferentes de propósito:

**Configurações** baixa o seu `meow.conf` inteiro, com um cabeçalho de comentário
dizendo quando saiu e de onde. É o arquivo de verdade, byte a byte: os seus
comentários, o alinhamento das colunas e a ordem das linhas sobrevivem. Continua
sendo um `meow.conf` válido — dá para copiá-lo por cima do original e rodar
`meow aplicar`.

**Página para redesenho** baixa esta tela inteira num arquivo `.html` só: as 24
abas, o menu lateral, os cartões com os valores de agora, e uma amostra das
imagens do acervo embutidas. Ele abre com dois cliques em qualquer máquina, sem
Python e sem o projeto instalado, e traz um botão **"Ver todas as abas"** que
empilha as vinte e quatro de uma vez — que é como se julga um layout inteiro sem
clicar vinte e quatro vezes.

O arquivo exportado é o `app.js` DE VERDADE rodando contra dados congelados: o
mesmo arquivo, sem uma linha diferente. Quem mente para ele é o `standalone.js`,
trinta linhas que trocam o `fetch` por uma leitura do JSON embutido e o `src` das
imagens pelos `data:` da amostra. Escrever uma segunda versão da página só para
exportar seria a terceira cópia da mesma tela neste projeto, e ela envelheceria
na primeira semana.

Nada na página exportada grava, roda ou apaga: sem servidor não há para onde
mandar, e as rotas que escrevem respondem com o aviso em vez de fingir que
funcionaram.

### O Importar não grava

Ele lê o arquivo, confere chave a chave e transforma o que passou em **escolha
pendente** — igual a um clique, com o cartão marcado e o banner contando. Quem
escreve continua sendo o `Salvar e aplicar`.

Medido: cada gravação leva 0,45 s (sobe um bash, carrega o `lib/comum.sh` e
reescreve os 55 KB do conf). Importar as cem chaves gravando seriam **43 segundos
de página parada**, sem barra de progresso e sem como cancelar — para uma
operação que se dispara ao escolher o arquivo errado por engano. Encenando, dá
para ver o que veio antes de aceitar, o modo seco continua valendo no `Salvar`, e
o `Descartar` desfaz tudo com um clique.

As duas peneiras são as mesmas do clique: `ler_esquema()` diz se a chave existe,
`validar_valor()` diz se o valor cabe. O que não passa é recusado com a frase na
tela, e o resto entra — um arquivo com uma linha estragada traz as outras.

**Conferido em 06/09/2026:** exportar e reimportar o mesmo arquivo devolve
"96 já estavam assim", **zero mudanças e zero recusas** — e ainda diz que 6
chaves do catálogo não estavam no arquivo (as do fastfetch, novas de hoje), que
não é erro: é o aviso de que elas ficaram como estão em vez de voltar ao padrão.
Um arquivo com uma chave inventada e um número fora da faixa traz as boas e
mostra as duas recusas com o motivo de cada uma.

A primeira medição desse ciclo achou um defeito que não era da importação:
`MIDIA_FONTE="auto"` — o valor que está no conf dela e que a aba Automação
oferece como botão — era **recusado pelo validador**. A página propunha o que o
servidor respondia com 400. Corrigido no mesmo dia: a palavra que uma chave
numérica aceita como padrão passa a ser aceita por ela, e só por ela.

---

## Teclado

| tecla | o que faz |
|---|---|
| `/` | vai para a busca |
| `Esc` | limpa a busca |
| `↑` `↓` | percorre as seções, quando o foco está no trilho |
| `Tab` | o de sempre; o primeiro `Tab` na página oferece "pular para o conteúdo" |

A busca atravessa **todas** as seções ao mesmo tempo, e é o que faz uma página de
102 chaves não exigir que você lembre em qual aba a chave mora.

---

## Duas coisas que estavam erradas no `meow.conf.exemplo` — consertadas em 01/09

Eram achados sobre **o arquivo**, não sobre esta página, e o conserto mexe
também no que o `meow configurar` mostra. Ela autorizou, e foi feito:

1. **O marcador `# --- Wallpaper` estava órfão** — no arquivo *antes* do bloco
   `A FORMA DO PAINEL E DO DOCK`, com as chaves de papel de parede dezenas de
   linhas depois. Lido ao pé da letra, `FORMA_*`, `JANELAS_*` e `LEITURA_*` eram
   todas "Wallpaper". O marcador e o comentário que vinha com ele desceram para
   junto de `WALLPAPER_BASE`, que é o que eles nomeiam.
2. **`NOME_TEMA_ICONES` e `BACKUPS_MANTIDOS` não tinham uma linha de
   explicação**, e `WALLPAPER_BASE` tinha uma que a desordem do item 1 havia
   separado da chave. As três têm agora.

Conferido depois do conserto: as **95 chaves continuam as mesmas e na mesma
ordem** (`grep '^[A-Z_]*=' | diff`), o `tests/app.sh` passa, e
`WALLPAPER_BASE`/`WALLPAPER_INTERVALO` aparecem na seção **Wallpaper**, com
ajuda, em vez de em "Ícones".

**A armadilha que isso quase deixou passar:** o parser associa à chave o
comentário que ENCOSTA nela. Mover o bloco deixou duas linhas em branco no meio,
e `WALLPAPER_BASE` ficou sem ajuda nenhuma — sem erro, sem aviso, só um cartão
mudo na página. Pego conferindo o esquema depois de mover, não antes.

--- Wallpaper` ficou órfão.** Ele está no arquivo *antes* do
   bloco `A FORMA DO PAINEL E DO DOCK`, e as chaves de papel de parede de verdade
   só vêm dezenas de linhas depois. Lido ao pé da letra, `FORMA_*`, `JANELAS_*` e
   `LEITURA_*` são todas "Wallpaper". Por isso esta página navega pelo
   **subtítulo** do bloco (`O modo de leitura, e o relógio que o liga sozinho`),
   que descreve o assunto de verdade, e não pela seção.
2. **`WALLPAPER_BASE`, `NOME_TEMA_ICONES` e `BACKUPS_MANTIDOS` não têm uma linha
   de comentário.** As duas primeiras tinham — o comentário do `WALLPAPER_BASE`
   existe no arquivo, mas ficou separado da chave pela mesma desordem do item 1.

Nenhum dos dois quebra nada hoje. Os dois deixam o wizard e esta página com um
cabeçalho errado, e o conserto é editar o `meow.conf.exemplo` — que é decisão
dela, porque muda o que o `meow configurar` mostra.

---

## Quando ele é instalado, e como se confere

| onde | o quê |
|---|---|
| `install.sh` | a etapa **`atalho`**, junto das outras do lançador |
| `meow doctor` | a linha **`atalho`** — confere o `.desktop`, o lançador e o bit de execução |
| `meow doctor --consertar` | `fix_atalho`, que é o mesmo `scripts/atalho.sh` |
| `install.sh --uninstall` | passo 2, com `--reverter`, que também chacoalha o menu |
| `meow abrir` | sobe o painel pela CLI |

O `.desktop` aponta para `~/.local/bin/meow-painel`, **não** para o clone. O
repositório mora num NVMe separado, e o dia em que o Ápate não montar seria o dia
em que o ícone vira um clique que não faz nada. O lançador copiado resolve a raiz
pelo ponteiro `~/.local/state/meowsystem/raiz` e, quando não a acha, **diz o que
houve e espera um ENTER** — em vez de fechar a janela antes de alguém ler.

`Terminal=true` é decisão: o `run.sh` fica de pé, e a janela de terminal é o
interruptor dele. Fechar a janela derruba o servidor (o `trap ... HUP` cobre
exatamente esse caso). Um painel que pode rodar o instalador não deve esconder a
própria saída.
