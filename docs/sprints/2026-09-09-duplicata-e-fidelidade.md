# O cartão que duplica e o traço que não é fiel — sprints de 09/09/2026

Duas sprints **abertas, nenhuma executada**. Ela pediu por escrito: *"só anota
a sprint e não resolve"*. Este arquivo é autossuficiente — quem for executar
não precisa de contexto de conversa.

**O pedido dela, literal, com três capturas:**

> *"ao instalar um jogo o icone dele duplica. e precisamos melhorar o nosso
> gerador de icones. sinto que não tá fidedigno e a ideia é termos linhas das
> bordas nas nossas cores e o fundo transparente."*

As capturas: o lançador com **Future Knight aparecendo duas vezes**, o GIMP
como está na tela dela (*"gimp feito a mão"*) e o GIMP na folha do conversor
(*"gimp do nosso gerador"*).

---

## Sprint S — Um jogo instalado, um cartão  ← **ABERTA**

**Tamanho:** ~2 h, e a maior parte é conferir que a regra nova não tira nada
que seja dela.

### O defeito, medido em 09/09/2026

Dois arquivos para o mesmo jogo, em `~/.local/share/applications`:

```
Future Knight.desktop           Exec=steam steam://rungameid/4235410
                                Icon=steam_icon_4235410
meow-steam-4235410.desktop      Exec=/usr/games/steam steam://rungameid/4235410
                                Icon=steam_icon_4235410
                                X-MeowSystem=jogo-steam
```

O rival se chama **pelo nome legível do jogo**, com espaço e maiúsculas. É o
atalho que a Steam escreve quando o jogo é instalado com "criar atalho no menu
de aplicativos" — e, como o nome do arquivo é o `Name=`, ele é **imprevisível
por construção**: um jogo chamado `A Casa` vira `A Casa.desktop`.

Hoje é o único caso na máquina dela; é o jogo que ela acabou de instalar.

### Por que a limpeza não pegou, e é a quarta vez

`scripts/jogos_steam.sh` reconhece rival **pelo nome do arquivo**, e conhece
três moldes:

| molde | de onde veio |
|---|---|
| `steam-jogo-<appid>.desktop` | o gerador antigo |
| `steam-<appid>*.desktop` | idem |
| `steam_app_<appid>.desktop` | o molde da Steam, achado em 15/08/2026 |

O quarto molde é `<Nome do Jogo>.desktop`, e **nenhum padrão de nome o
descreve**. Isto já é a repetição de um defeito conhecido: em 15/08/2026 a
limpeza conhecia dois moldes e não conhecia o terceiro; quinze jogos
apareciam em duplicata, e ela viu. `tests/um-cartao-por-jogo.sh` nasceu
daquele dia e continua passando — porque ele afirma a regra **pelos moldes que
a limpeza conhece**, e não pela pergunta que interessa.

**A lição, e é o coração desta sprint:** enquanto o reconhecimento for por
NOME DE ARQUIVO, sempre haverá um quinto molde. A pergunta certa é sobre o
**conteúdo**.

### O que fazer

**1. A regra passa a ser por conteúdo.** Um `.desktop` em
`~/.local/share/applications` é rival quando, ao mesmo tempo:

- o `Exec=` contém `steam://rungameid/<appid>` (ou `-applaunch <appid>`) —
  o `<appid>` é extraído dali, não do nome;
- **não** traz `X-MeowSystem=jogo-steam` — é a nossa assinatura, e ela já
  existe em todo cartão que escrevemos;
- nós temos cartão para aquele mesmo `<appid>`, isto é,
  `meow-steam-<appid>.desktop` existe e vai continuar existindo nesta
  passagem.

As três condições juntas. A terceira é a que já está escrita no cabeçalho de
hoje e não se toca: **nunca remover um rival sem deixar um substituto no
lugar** — senão um jogo somiria do lançador dela.

**2. Os três moldes por nome continuam**, e não viram código morto: eles
pegam o caso em que o rival aponta para um `<appid>` que a biblioteca já não
tem (jogo desinstalado, cartão órfão), onde a regra por conteúdo não acha
substituto e por isso se cala.

**3. As guardas de hoje continuam todas:** a biblioteca tem de estar montada
(senão um `.desktop` órfão viraria remoção em massa), backup em
`$MEOW_ESTADO/backups/<carimbo>-duplicatas/` antes de remover, e a remoção é
sempre arquivo a arquivo, pelo caminho exato.

**4. `tests/um-cartao-por-jogo.sh` ganha o quarto caso**, e é ele que impede a
quinta vez: um rival chamado `Jogo Qualquer.desktop`, com espaço e acento no
nome, apontando por `rungameid` para um appid que tem manifesto. Tem de sair.
E um quinto caso que é o contrário: um `.desktop` escrito à mão por ela, com
`rungameid` de um jogo **sem** manifesto, **fica** — não temos substituto.

### Como conferir que ficou certo

- `meow jogos` (ou a ação do painel) relata `1 cartão duplicado a tirar` e,
  depois de rodar, `nada a fazer` na segunda passagem;
- o lançador mostra **um** Future Knight;
- `tests/um-cartao-por-jogo.sh` passa, com os dois casos novos;
- nenhum `.desktop` que não seja de jogo da Steam é tocado — conferir com
  `ls` antes e depois, arquivo a arquivo.

### O que pode dar errado

- **Casar `Exec=` com regex frouxa** e pegar um lançador genérico dela (um
  script que abre a Steam, por exemplo). O `rungameid/<digitos>` tem de ser
  ancorado, e o `<appid>` tem de bater com um manifesto.
- **O rival ser o preferido dela.** Se ela mesma editou aquele arquivo, a
  remoção apaga o trabalho dela. O backup cobre, mas vale registrar no relato
  qual arquivo saiu e o que ele dizia.
- **A Steam reescrever o atalho depois.** É esperado: a passagem seguinte o
  tira de novo, como já acontece com o molde de 15/08. É por isso que a
  afirmação 3 daquele teste existe.

---

## Sprint T — O traço fiel ao desenho, não só à fronteira  ← **ABERTA**

**Tamanho:** um dia para medir e gerar a folha; a decisão é dela e não tem
prazo.

### O que ela disse, e o que a medição diz

> *"sinto que não tá fidedigno e a ideia é termos linhas das bordas nas nossas
> cores e o fundo transparente."*

**A segunda metade da frase já é verdade hoje** — o acervo sai `fill="none"`,
`stroke="currentColor"` e a cor entra da paleta na instalação; não há fundo
para ser transparente porque não há fundo. Então o alvo que ela descreve é o
que o conversor persegue, e **a queixa é de FIDELIDADE**: o desenho que sai
não é o desenho que entrou.

**O GIMP das duas capturas dela difere em UMA curva.** Medido: o retoque à mão
tem 7 subcaminhos, a conversão tem 6, e os seis são byte a byte iguais. O que
falta é **a boca**. O `retoques/LEIA-ME.txt` já explica por que ela não sai por
parâmetro, com a aritmética: no Wilber do Papirus a boca não é uma cor, é uma
sombra da mesma cor, a 45,0 de distância em RGB do focinho — e o `--funde`
padrão é 46. Baixar para separá-las mata o focinho.

Ou seja: **no GIMP a queixa dela tem nome, e o nome é "a boca"**. Mas ela
falou do gerador em geral, e o resto desta sprint é o resto.

### Os modos de falha, medidos em seis ícones do lançador dela

Convertidos com o padrão de hoje e olhados a 150 px, ao lado do original:

| ícone | veredito | o que acontece |
|---|---|---|
| Calculadora | **fiel** | grade de teclas, corpo, visor: tudo legível |
| Telegram | **fiel** | o avião de papel sai inteiro |
| VLC | **fiel** | o cone e as listras |
| Discord | **aceitável** | o Clyde perde o recorte do capacete, mas se reconhece |
| **Chrome** | **falha** | as três pás viram linhas soltas que não fecham; o desenho perde a estrutura |
| **Brave** | **falha** | o leão vira um emaranhado ilegível |

O padrão que isso desenha, e ele **contradiz o que o cabeçalho do conversor
afirma hoje**. Lá está escrito que o que decide é "geométrico sai, orgânico
não". A medição diz que a variável é outra: **quantas fronteiras de cor
existem dentro da silhueta**. A Calculadora é cheia de detalhe e sai; o Brave
tem poucas formas e não sai, porque as formas dele se sobrepõem em camadas de
tom parecido e cada encontro vira um traço.

### Três caminhos, e nenhum é exclusivo

**1. Peso de fronteira.** Hoje toda fronteira entre duas classes vale um
traço, com o mesmo peso. Uma fronteira entre dois tons vizinhos (o vermelho e
o vermelho escuro do Brave) carrega quase nenhuma informação e custa uma
linha; uma fronteira entre o desenho e o fundo carrega tudo. Medir o
**contraste** de cada fronteira e descartar as fracas é a mudança mais
promissora, e ela cabe onde o dedupe de aresta já roda.

**2. Teto de legibilidade.** A 48 px com traço de 2,25 há um número de traços
acima do qual o ícone vira mancha, independentemente de estarem certos. A
régua se **mede** (contar traços dos 39 Arcticons desenhados à mão dá o teto
honesto), e o conversor sobe a fusão até caber. Hoje ele não tem noção de
quanto cabe.

**3. Curadoria honesta, que é a mais barata e já tem material.** O que não
converte vai para o acervo de traço desenhado à mão. **E os três que falham já
estão baixados no repositório e fora do mapa:**
`assets/icones/arcticons-apps/brave.svg`, `google-chrome.svg`,
`discord.svg`. Trocar é uma linha de mapa em cada um, e a folha de 11/08 já
estabeleceu o precedente: cinco ícones ficaram de fora do conversor por não
terem conserto, e nenhum ficou sem desenho.
> Medido junto: o acervo remoto **não tem** `gimp` nem `chrome` (404 no
> índice; `google-chrome` sim). Para o GIMP não existe saída pelo acervo — ou
> o retoque à mão fica, ou o caminho 1 tem de resolver a boca.

### O que fazer, na ordem

1. **Medir o teto** nos 39 Arcticons desenhados à mão: traços por ícone,
   mínimo, mediana, máximo. É o número que o caminho 2 precisa e ninguém tem.
2. **Implementar o peso de fronteira** (caminho 1) atrás de uma chave, com o
   padrão em desligado, para a folha comparar.
3. **Gerar a folha** com quatro colunas: original · hoje · com peso de
   fronteira · o glifo Arcticons quando existir. Os 24 com origem, mais o
   Brave, o Chrome e o Discord em destaque.
4. **Parar e mostrar a ela.** Nada instalado. A decisão de qual coluna vence,
   ícone a ícone, é dela — é a mesma folha que ela já usou em 10/08 e 11/08.

### As perguntas que são dela, e que a folha existe para responder

- O Brave, o Chrome e o Discord passam para o acervo desenhado à mão, ou vale
  esperar o peso de fronteira?
- A boca do Wilber: o retoque à mão continua (e aí o GIMP nunca muda), ou ela
  quer o desenho reconvertido em curvas com a boca redesenhada por cima?
- Os outros oito com retoque à mão foram desenhados quando o conversor só
  fazia escada. Vale reconverter e retocar de novo, ou está bom?

### O que pode dar errado

- **Descartar fronteira fraca demais** e transformar tudo em silhueta — é o
  modo de falha que a primeira folha do conversor já sofreu, e o cabeçalho do
  `colapsar_fitas` conta a história: o Terminal virou um quadrado e o Editor
  uma folha em branco. O limiar é medido nos que HOJE saem bem (Calculadora,
  Telegram, VLC), que não podem piorar.
- **Mexer no que ela já aprovou.** Os 9 com retoque à mão não entram nesta
  sprint sem ela pedir; retoque é decisão registrada.
- **Confundir a queixa.** A frase dela sobre "bordas nas nossas cores e fundo
  transparente" descreve o que já existe. Se, ao ver a folha, ela apontar
  outra coisa, é a folha que manda — e esta seção envelhece.

---

## O que NÃO entra nestas duas sprints

A folha do conversor de 09/09 (`~/Documentos/meow-conversor-folha.html`)
continua esperando o olhar dela, e os **15** ícones que mudariam continuam sem
ser instalados. A Sprint T pode mudar o que aqueles 15 seriam — então **a
ordem natural é T antes da regeneração**, para ela decidir uma vez só em vez
de duas.
