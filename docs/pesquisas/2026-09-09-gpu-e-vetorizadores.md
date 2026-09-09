# A placa de vídeo, o vetorizador e a arte de linha — 09/09/2026

**A pergunta dela, literal:** *"olha minha placa de vídeo. Não tem nenhum llm
ollama ou algo assim pra converter isso com qualidade não? tipo remove
background. aumenta saturação e só faz a nossa borda?"*

**A resposta, em três linhas:**

1. **Não vale a pena** — nem o vetorizador de verdade (`potrace`, `vtracer`),
   nem a rede de arte de linha na GPU. Medido nos seis ícones do corpus: a
   camada 1 empata e engrossa o traço; a camada 2 **quebra dois dos três
   ícones-trava** (Calculadora e VLC).
2. **A intuição dela estava certa sobre a família de ferramentas e errada sobre
   o nome:** LLM não é isso, e não há ollama nesta máquina. O que existe para
   "extrair traço" são redes de arte de linha — e elas **rodam em 0,4 s na CPU**.
   A RTX 4060 não é o gargalo de nada aqui, porque não há gargalo.
3. **O que valeu a pena saiu de graça e não instala nada:** `--k 4` conserta o
   Chrome, que a Sprint T tinha dado como sem conserto. Fidelidade 77/75 → 94/95,
   8 traços → 4, e Calculadora, Telegram e VLC não se mexem.

Nada foi instalado permanentemente nesta máquina como resultado deste estudo.
O `potrace` foi instalado para medir e **removido depois** (seção 7).

---

## 1. O que estava escrito e a medição derrubou

O cabeçalho do `scripts/converter_icone.py` lista, com data de 11/08/2026, "o
que esta máquina **não** tem". A lista envelheceu em duas frentes.

| Afirmação de 11/08 | Estado em 09/09/2026 |
|---|---|
| não tem `potrace` | continua não tendo, mas é **`apt install potrace`, 94,9 kB de download e 227 kB em disco**. Não é uma ausência estrutural, é um pacote |
| não tem vetorizador | `vtracer` compila do `cargo` que esta máquina já usa para os applets: **15,3 s de build em release, binário de 2,6 MB** |
| não tem `scipy`/`skimage` | continua não tendo no python do sistema, e **é assim que tem de ficar** — o painel roda nesse python |

Mas a conclusão que a lista sustentava **não caiu**: os dois vetorizadores
maduros **não** resolvem o problema deste projeto, por um motivo estrutural que a
seção 3 mede.

E há uma afirmação do cabeçalho que a medição **derrubou de verdade**:

> *"a boca do Wilber não sai: ela é uma sombra da mesma cor, a 45,0 de distância
> RGB do focinho, e o `--funde` padrão é 46. Baixar para separá-las mata o
> focinho."*

A primeira metade está certa e a segunda está certa **pelo motivo errado**.
Medido:

```
top-6 do histograma do org.gimp.GIMP.svg a 256px
  (100, 91, 68)  11428 px   focinho/pelo
  ( 63, 63, 63)   4399 px   a boca
  (255,255,255)   3489 px   olhos
  ( 70, 64, 48)    518 px   a sombra que faz a ponte
  (255,154, 12)    439 px   pincel
  (138,138,138)    384 px   cabo
```

O `_funde(46)` não junta boca e focinho diretamente — eles estão a 46,7. Junta
**em cadeia**, pela sombra: focinho→sombra 45,0 e sombra→boca 16,6. Até aqui o
cabeçalho está certo.

O que ele erra é dizer que baixar o `--funde` mata o focinho. **Quem mata o
focinho é o filtro de cor de mistura**, aquele que descarta o antialias. Com
`--funde 44` a cadeia se parte como esperado, e aí:

```
DESCARTADA (100, 91, 68): fica a 23,2 da reta (66,63,55)->(255,154,12) em t=0,18
```

O marrom do focinho — **11 428 pixels, a classe mais pesada do ícone inteiro** —
é classificado como mistura entre o escuro e o **laranja do pincel** e some. Isso
é um falso positivo, e ele tem conserto de uma linha: **cor de antialias é uma
faixa fina ao longo de um contorno; ela nunca é a cor mais pesada da arte.**

Uma **guarda de massa** (só tratar como mistura quando a classe pesa menos que a
menor das duas pontas) foi medida numa cópia do conversor em `/tmp`:

| ícone | hoje (`f46`) | `f44` sem guarda | `f44` com guarda |
|---|---|---|---|
| google-chrome | 8 traços | 9 | **8** |
| com.brave.Browser | 10 | 10 | **10** |
| org.gimp.GIMP | 6 | 9 | **8** |
| org.gnome.Calculator | 10 | **9 — quebra** | **10** |
| org.telegram.desktop | 4 | **5 — quebra** | **4** |
| org.videolan.VLC | 5 | **8 — quebra** | **5** |

Sem a guarda, `--funde 44` destrói os três da trava (as teclas da Calculadora
viram uma malha, o VLC ganha linha na base). **Com** a guarda a trava fica de pé
e o `--funde` volta a ser um botão utilizável em vez de uma armadilha. No padrão
(`f46`) a guarda **não dispara em nenhum dos seis** — ela é inerte até alguém
mexer no `--funde`.

Isso **não** conserta a boca do Wilber: o que aparece no GIMP com `f44`+guarda é
a paleta escura da esquerda, e o focinho fica mais carregado, não mais legível.
O retoque à mão continua ganhando.

---

## 2. O corpus, e a régua que mente

Seis ícones, os mesmos que a Sprint T mediu. A régua objetiva usada aqui é
**neutra de propósito**: a "borda real" não sai do nosso quantizador (sairia
enviesada), sai do gradiente de cor do PNG original a 256 px.

* **revocação** = quanto da borda real do desenho está coberta pelo traço
* **precisão** = quanto do traço cai em cima de borda real

| ícone | nosso (hoje) | nosso `res 512` | potrace/classe | vtracer+nosso | HED (rede) | retoque à mão | Arcticons à mão |
|---|---|---|---|---|---|---|---|
| google-chrome | 77/75 | 83/80 | 82/79 | 85/73 | **96/92** | **7/6** | 56/42 |
| com.brave.Browser | 99/94 | 99/97 | 100/96 | 100/88 | 93/93 | — | 26/22 |
| org.gimp.GIMP | 93/95 | 93/98 | 93/98 | 100/90 | 92/90 | 95/94 | 17/19 |
| org.gnome.Calculator | 98/95 | **41/31** | 100/98 | 100/91 | 90/91 | — | 25/22 |
| org.telegram.desktop | 100/94 | 100/98 | 100/97 | 100/87 | 97/96 | 73/51 | 19/21 |
| org.videolan.VLC | 100/96 | 100/100 | 100/99 | 99/92 | 93/84 | — | 9/7 |

**Leia a coluna do desenho à mão antes de acreditar em qualquer número desta
tabela.** O Arcticons, que é o padrão de qualidade que ela aprovou, tira de 9 a
56 de revocação. O retoque do Chrome que está no repositório — o desenho que
funciona — tira **7 de 100**. Ele é o menos fiel de tudo que foi medido, e é o
único Chrome que lê como Chrome.

E o campeão da régua, o HED com 96/92 no Chrome, é o Chrome **sem as costuras**:
a métrica é dominada pelo perímetro do círculo grande e é cega justamente para o
detalhe pequeno que carrega a identidade.

> **Fidelidade não é o que ela pediu.** Ela pediu que o ícone *fique bom*. São
> perguntas diferentes, e melhorar a primeira não melhora a segunda. Por isso
> toda conclusão daqui foi olhada, e as folhas estão em
> `/tmp/claude-1000/.../scratchpad/folha/`.

Nota de passagem: `res 512` **não** é um upgrade grátis. A Calculadora desaba
para 41/31 (a grade de teclas vira uma malha de losangos) e o custo triplica.
O `RES = 256` do conversor está certo.

---

## 3. Camada 1 — o vetorizador de verdade

Instalados e medidos: **`potrace` 1.16** (apt) e **`vtracer` 0.6.5** (cargo).

### O achado estrutural, que vale mais que a tabela

**Os dois são vetorizadores de REGIÃO: bitmap → contorno FECHADO e PREENCHIDO.**
Nenhum dos dois produz linha. Para chegar ao dialeto do acervo é preciso pegar
o contorno de cada região e desenhá-lo como traço — e aí aparece o problema:

> A fronteira entre a região A e a região B **pertence às duas**. O potrace
> traça A inteira e depois B inteira, e a mesma linha sai duas vezes. Com
> preenchimento isso não se vê; com traço, as duas cópias são ajustadas
> independentemente, divergem por uma fração de pixel e a linha **engorda**.

Medido — comprimento total de traço no viewBox 48:

| ícone | nosso | potrace por classe | razão |
|---|---|---|---|
| google-chrome | 278 | 484 | 1,74× |
| com.brave.Browser | 367 | 659 | 1,80× |
| org.gimp.GIMP | 255 | 350 | 1,37× |
| org.gnome.Calculator | 360 | 580 | 1,61× |
| org.telegram.desktop | 260 | 391 | 1,50× |
| org.videolan.VLC | 232 | 323 | 1,39× |

O número de traços é praticamente o mesmo; o que cresce é o comprimento, e o
excedente é linha desenhada duas vezes. Isto é exatamente o que o passo 6 do
nosso pipeline já resolve — o *"DEDUPE global de aresta"* — e é uma coisa que
o potrace, por construção, não tem como fazer: a API dele recebe um bitmap, não
uma cadeia de pontos. **Não dá para encaixar o potrace no lugar certo do nosso
pipeline.** Ou ele substitui os passos 6-8 inteiros e perde o dedupe, ou não
entra.

### E a qualidade da curva do potrace é melhor que a nossa?

**Não.** Ampliadas a 500 px e recortadas (`folha/zoom.png`), a curva do potrace e
o ajuste de Bézier da Sprint Q (que entrou hoje de manhã) são indistinguíveis.
O que se vê de diferente é o traço do potrace **mais pesado**, que é a linha
dupla acima. Essa era a hipótese mais provável antes de medir, e ela caiu.

### `potrace` na silhueta (o "só faz a nossa borda" literal)

Alfa > 128 → potrace → traço. Um caminho por ícone, e o resultado confirma
palavra por palavra o que o cabeçalho do conversor já dizia: **o Chrome vira um
círculo, o Telegram vira um círculo, a Calculadora vira um retângulo
arredondado.** A identidade está nas fronteiras internas, não no perímetro.
Beco sem saída, agora medido em vez de argumentado.

### `vtracer` — o único lugar onde a camada 1 mostrou algo

O vtracer segmenta **espacialmente** (agrupa manchas de cor conectadas), e o
nosso quantizador segmenta **globalmente** (histograma/k-means no espaço de
cor). Essa diferença é real e aparece no caso mais difícil: **o vtracer acha a
paleta escura do GIMP e alguma coisa parecida com a boca**, que o nosso perde.

Foi montado o híbrido honesto — segmentação do vtracer convertida em mapa de
rótulos, e daí para dentro do **nosso** traçador, com o nosso dedupe de aresta.
Ele roda e não tem linha dupla. E mesmo assim:

* o GIMP fica **mais informativo e menos legível**: o focinho vira uma lasca
  preta grossa e os olhos perdem a pupila;
* a Calculadora ganha peso (o visor vira um bloco);
* o VLC ganha uma linha de base que o desenho à mão não tem;
* o vtracer devolve **10 a 18 classes** onde o nosso devolve 3 a 6, e cada
  classe a mais é um traço a mais para a tela de 48 px sustentar.

Conclusão da camada 1: **empate técnico com traço mais pesado, mais dependência
e mais classe.** Não entra.

---

## 4. Camada 2 — a GPU e as redes de arte de linha

Quatro modelos, todos via `controlnet_aux` num venv isolado: **Informative
Drawings / lineart** (17 MB), **PiDiNet** (2,9 MB), **HED** (29 MB) e
**lineart_anime** (218 MB). Nenhum pesa gigabytes; o que pesa é o runtime.

### O primeiro resultado é que a placa não é necessária

Tempo por ícone de 512×512, **na CPU**, com `torch 2.14.0+cpu`:

```
lineart  498-675 ms      pidinet  703-785 ms
hed      374-549 ms      anime    152-191 ms
```

O acervo inteiro tem 34 ícones e é regenerado **à mão**, quando o Papirus muda.
Custo total: ~15 segundos de CPU, uma vez. Uma RTX 4060 economizaria talvez 10
desses 15 segundos, em troca de um wheel CUDA de 2,5-3,5 GB. **Não há gargalo
para a placa resolver.** Este é o ponto mais importante da resposta a ela: a
placa de vídeo dela é ótima e este problema simplesmente não é do tamanho dela.

### O segundo resultado é que o mapa de bordas é bonito e o vetor não é

Olhado o raster puro (`folha/c2.png`), o **HED é impressionante**: o Wilber sai
com boca e pupilas, a Calculadora sai limpa, o leão do Brave sai inteiro. Foi
o momento em que este estudo quase virou um "sim".

Só que o mapa de bordas é raster, com linha de espessura variável e força
variável. Para virar o nosso dialeto ele precisa de limiar → esqueleto
(centerline) → polilinha → Bézier. Isso foi construído (`skimage.skeletonize`
+ o `dp`/`fatiar`/`ajustar` do nosso próprio conversor) e varrido em cinco
combinações de limiar e fechamento morfológico. O melhor ponto:

| ícone | traços | **pontas soltas** (fragmentos abertos) |
|---|---|---|
| google-chrome | 10 | 30 |
| com.brave.Browser | 10 | 49 |
| org.gimp.GIMP | 20 | **124** |
| org.gnome.Calculator | 13 | 15 |
| org.telegram.desktop | 2 | 15 |
| org.videolan.VLC | 7 | 20 |

O nosso conversor tem **zero** pontas soltas, e não por talento: **fronteira de
região é fechada por construção.** O mapa de borda de uma rede não é — onde o
contraste cai, a linha afina, o limiar corta e o esqueleto abre um buraco. Na
tela:

* **Calculadora: a moldura abre nos quatro cantos** e vira quatro colchetes;
* **VLC: as duas faixas do cone somem**;
* GIMP: os anéis dos olhos quebram;
* Chrome: as costuras somem — o mesmo fracasso do nosso, por outro caminho.

**Dois dos três ícones da trava quebram.** Pela regra da casa isso encerra a
camada 2: *quem piorar Calculadora, Telegram ou VLC está errado, não eles.*

Justiça seja feita ao HED em dois pontos: o **Brave** dele é mais limpo que o
nosso (o leão perde a poeira da juba), e o **Telegram** também. Se um dia
existir um ícone que só o HED resolva, o caminho está medido e o script está em
`/tmp/claude-1000/.../scratchpad/l2vec.py`. Para o acervo de hoje, não paga.

---

## 5. Camada 3 — LLM e modelo generativo

**Para desenhar: não serve, e não é questão de tamanho de modelo.** A queixa
dela é de **fidelidade** — o desenho que sai não é o que entrou — e um modelo
generativo inventa. É a ferramenta com o defeito exato do problema. Não há
ollama instalado nesta máquina (só um `~/.ollama` vazio de 8 kB, de 12/05,
sem binário, sem modelo, sem unidade), e instalar um não mudaria isso.

**Para escolher parâmetro: não há o que escolher.** Medido: **36 combinações de
`--k`, `--funde` e `--peso-fronteira` no Chrome produzem apenas 6 desenhos
distintos.** O espaço de parâmetros é quase todo redundante; um modelo
otimizando dentro dele estaria otimizando sobre seis opções que dá para olhar
de uma vez, numa folha, em cinco segundos. (E foi exatamente assim que o achado
da seção 6 apareceu.)

**Para julgar qual candidato ficou melhor: aí sim há um papel real, e ele é de
VISÃO, não de linguagem — e este estudo é a prova.** A régua de fidelidade
elegeu o HED no Chrome (96/92) e reprovou o retoque à mão (7/6); o olho diz o
contrário nos dois casos. Nenhuma métrica escrita aqui ordenou os seis ícones
como o olho ordena. Quem separou "melhorou" de "piorou" nas seis folhas deste
estudo foi um modelo que **olha** — e a decisão final continua sendo dela,
olhando, que é a regra do projeto e continua certa.

---

## 6. O que valeu a pena, e não custa dependência nenhuma

Varrendo as 36 combinações do Chrome apareceu o desenho `d0`, que sai com
**`--k 4`**:

| | traços | fidelidade |
|---|---|---|
| Chrome hoje (`--k 6`) | 8 | 77/75 |
| Chrome com `--k 4` | **4** | **94/95** |

O anel interno tracejado — a "sujeira" que fazia o ícone não ler — some, e sobra
círculo, bola, uma costura e o rabo. **É o desenho do Arcticons, feito pelo
conversor.** A Sprint T tinha registrado o Chrome como *"18 combinações de
parâmetro desenham a mesma coisa; nenhuma lê como Chrome"* e `docs/SPRINTS.md:77`
o mandou para o desenho à mão. As 18 não incluíram `--k 4`.

E a trava não se move:

| ícone com `--k 4` | resultado |
|---|---|
| com.brave.Browser | **idêntico byte a byte** |
| org.videolan.VLC | **idêntico byte a byte** |
| org.gnome.Calculator | 0,7 % de pixel diferente (só antialias) |
| org.telegram.desktop | dobra interna do avião sai mais limpa |
| org.gimp.GIMP | **perde o pincel** — por isso `--k 4` é por ícone, não global |

O `apps-convertidos.map` já tem campo de parâmetros para isso. A mudança seria
uma linha:

```
google-chrome:/usr/share/icons/Papirus/64x64/apps/google-chrome.svg:yellow:--k 4
```

**Isso não foi feito.** Trocar a arte do acervo é decisão dela, olhando a folha,
e o `retoques/google-chrome.svg` que está lá hoje já vence a conversão de
qualquer jeito. O que a medição diz é que **o Chrome tem conserto dentro do
conversor**, e que a linha do SPRINTS que o declarou sem conserto está vencida.

---

## 7. O custo honesto, e como se desfaz

| coisa | onde | tamanho | estado |
|---|---|---|---|
| `potrace` + `libpotrace0` | apt, sistema | 94,9 kB baixados / 227 kB em disco | **instalado para medir e removido** (`apt purge potrace libpotrace0`) |
| `vtracer` 0.6.5 | `$SCRATCH/cargo-root/bin` | 2,6 MB | fica no scratchpad, morre com a sessão |
| fontes de crate (`vtracer`, `visioncortex`) | `~/.cargo/registry` | 568 kB | cache do cargo que ela já usa; some com `cargo cache -a` ou ficando |
| `torch 2.14+cpu` + `controlnet_aux` | `$SCRATCH/venv-gpu` | **1,4 GB** | venv isolado, morre com a sessão. **Nada tocou o python do sistema** |
| pesos dos modelos | `$SCRATCH/hf` (`HF_HOME` redirecionado) | 272 MB | idem. `~/.cache/huggingface` **não existe** e não foi criado |

**Nada foi integrado ao `install.sh`, ao `bin/meow`, aos testes ou ao acervo.**
Como nenhuma camada bateu o conversor nos seis ícones, a regra combinada era
não instalar nada permanente, e ela foi seguida. O `converter_icone.py` não foi
tocado: a guarda de massa da seção 1 foi medida numa **cópia** em `/tmp`.

Se um dia alguma dessas camadas entrar, o que ela custaria é conhecido:
`potrace` é um pacote apt que um `apt upgrade` mantém e nunca some sozinho
(risco baixo, ganho zero medido); o `vtracer` obriga o `install.sh` a compilar
Rust ou a versionar um binário; a camada 2 põe **1,4 GB de venv + 272 MB de
pesos** numa etapa de instalação que roda em timer — o que, sozinho, já
desqualificaria a proposta mesmo se ela tivesse ganhado.

---

## 8. Por que o desenho à mão ganha, e é a resposta de fundo

O Arcticons da Calculadora **não é uma calculadora**: são quatro teclas. O do
VLC tem uma base chata que o ícone original não tem. O do Chrome tem três
costuras retas e um miolo maior que o real.

Nenhum deles é um traçado do original. Eles **redesenham a ideia** — e é por isso
que tiram 9 a 56 de fidelidade e ainda assim são o padrão que ela aprovou.

Traçar é medir; abstrair é decidir. `potrace`, `vtracer`, HED, PiDiNet e o nosso
conversor fazem a primeira coisa, com qualidade parecida entre si. Nenhum
modelo, nem na GPU dela nem em nenhuma outra, faz a segunda — porque a segunda
não é um cálculo sobre a imagem de entrada. É gosto, e o gosto neste projeto é
dela.

---

## Onde estão as folhas

Em `/tmp/claude-1000/-mnt-Apate-.../scratchpad/folha/` (sessão de 09/09/2026),
com um `LEIA-ME.txt` do lado. **Elas morrem com a sessão** — se alguma valer a
pena guardar, é copiar para `docs/folhas/` com `mogrify -strip` antes, que é a
regra desta casa para imagem que entra no `git`:

| arquivo | o que mostra |
|---|---|
| `MESTRE.png` | os seis ícones × original, hoje, potrace, vtracer+nosso, HED, à mão |
| `k4.png` | o achado do `--k 4`, e a trava intacta |
| `varredura_chrome.png` | os 6 desenhos distintos que 36 combinações produzem |
| `c1.png` | potrace: silhueta pura e por classe |
| `c1v.png` | vtracer bruto |
| `hibrido.png` | vtracer + nosso traçador |
| `c2.png` | os quatro mapas de borda das redes, sem vetorizar |
| `c2tune.png` | HED vetorizado no melhor limiar — a Calculadora aberta nos cantos |
| `zoom.png` | curva do potrace × Bézier da Sprint Q, a 500 px |
| `gimp_zoom2.png` | o Wilber em cinco versões, com o retoque à mão do lado |
| `guarda.png` | `--funde 44` com e sem a guarda de massa |
| `anomalias.png` | o retoque do Chrome (7/6 de fidelidade) e a Calculadora a 512 |
