# O acabamento do painel — passagens de 07/09/2026

Registro autossuficiente das três versões publicadas neste dia: **v1.2.2**,
**v1.2.3** e **v1.2.4**. Quem for mexer no painel depois disto não precisa de
mais nada além do repositório e desta folha.

O fio que costura as três é um só: **a tela dizia menos do que sabia** — um
número sem efeito que não se anunciava, um texto emprestado que se passava por
próprio, uma caixa maior que o desenho dentro dela, e um desenho grudado que
não parava quieto.

## As regras que valeram (e continuam valendo)

1. **Não abrir janela na tela dela.** O navegador é o Playwright em
   `~/.local/share/meowsystem/venv-testes`, sem cabeça, contra
   `http://127.0.0.1:<porta>`.
2. **Não tocar no `~/.config/meow/meow.conf`.** A suíte confere byte a byte no
   fim; quando uma medição precisou de outro valor, o servidor subiu com
   `MEOW_CONF` apontando para uma cópia descartável.
3. **Medir antes de escrever, e medir de novo depois.** Quatro afirmações
   caíram assim nesta passagem — estão na seção final, com o número que as
   derrubou.
4. **Navegar como usuária no fim de cada leva**, com foto, antes de dizer
   "pronto". Foi a caminhada, e não a suíte, que pegou dois defeitos.
5. O vocabulário do repositório é `frente`, `passagem`, `medição`,
   `conferência`. Commit em `tipo: descrição`, sem rodapé de coautoria.

---

## v1.2.2 — o teclado inteiro, e o verbo que faltava

**O teclado.** O `Importar` era uma `<label>`, e `<label>` não entra na fila do
foco: percorrido o ciclo inteiro de Tab e Shift+Tab, ele aparecia zero vezes —
quem usa só teclado não tinha como trazer um `.conf` para dentro. Virou
`<button>`. O primeiro Tab pulava a metade de cima da página, porque o rolar do
menu movia o ponto de partida do foco. O `/` morria depois de ajustar uma
régua, porque a guarda tratava todo `<input>` como campo de texto — e um
deslizante não digita nada; são doze réguas só em «Painel e dock». O Esc não
fechava o balão de quem chegou de teclado: ele estava na tela por CSS
(`:focus-visible`) com o atributo `hidden` ainda posto, e o teste `hidden` dizia
"não há nada aberto". A pergunta certa é ao navegador — `getComputedStyle`.

**O pulo das grades.** 138 das 181 paradas de Tab de «Papel de parede» eram os
botões das 46 figuras. As três grades grandes ganharam um "pular", no padrão do
"Pular para o conteúdo".

**O verbo «Usar».** Fixar *esta* imagem, agora. A ficha oferecia Dia, Noite e
Tirar, e buscar "fixar" devolvia um gato. Nasceu `meow wallpaper usar <img>`, a
ação no servidor e o chip na ficha.

**Duas chaves que existiam sem existir.** `MODO_AUTO_CLARO_DE/ATE` — as horas
do tema automático, 7 e 18 de fábrica — o `bin/meow` lê desde sempre, e nenhum
arquivo as declarava. Entraram no `meow.conf.exemplo` como régua de 0 a 23.

> **A cerca lê o comentário ao pé da letra.** A primeira redação dizia "não
> HH:MM", e a sigla literal é o que o leitor procura para classificar uma chave
> como horário: as duas réguas nasceram campo de relógio. A suíte pegou, a
> frase saiu. **Não citar a sigla de relógio na prosa de um comentário, nem
> para negá-la.**

---

## v1.2.3 — o que a tela escondia

### A margem que o compositor jogava fora

Com **«Painel descolado da borda» em Não**, o deslizante de distância aceitava
o número, gravava, e a barra continuava colada. Não é defeito nosso: o
`get_effective_anchor_gap()` do cosmic-panel é

```rust
if self.anchor_gap { self.margin as u32 } else { 0 }
```

O cabeçalho do `scripts/forma.sh` descrevia isso desde 10/08/2026, inclusive a
consequência — *"a barra continua colada e ninguém diz por quê"*. A página era
justamente quem não dizia.

**Onde mora o conserto:** `DOMINIOS`, no `app/servidor.py`. Duas entradas novas
(`FORMA_MARGEM_PAINEL` e `FORMA_MARGEM_DOCK`), condição `v == "nao"`. A máquina
que desenha o aviso amarelo (`.frase.dominada`) já existia e não mudou. O
`tests/app.sh` confere sozinho que as chaves citadas existem.

**O aviso é do DISCO, não da escolha pendente**, e isso é de propósito: dizer
"quem manda é X" com base num valor ainda não salvo seria a página afirmando um
efeito que ainda não existe.

### O texto emprestado

Trinta chaves herdam o comentário da irmã de cima — o arquivo escreve os pares
e as famílias sob um bloco só, porque é uma decisão só. Até aqui, apenas a
**frase** do cartão sinalizava isso, por um traço à esquerda; o balão do `?`
abria o bloco alheio cru. Em «Dia e noite» são quatro assim.

O esquema passa a carregar **`ajuda_de`**: a chave DONA do bloco, seguindo a
cadeia. `WALLPAPER_NOITE_FIM` herda de `WALLPAPER_NOITE`, **não** da vizinha
`_INICIO` — é por isso que o campo se propaga (`itens[-1]["ajuda_de"] or
itens[-1]["chave"]`) em vez de olhar só o vizinho.

Quem titula o cartão continua sendo a página (`tituloDaDona` → `tituloDoCartao`):
o servidor manda a chave, não o título.

### A caixa era maior que o desenho

A nota anterior dizia *"faixa vazia ao lado de desenho único"* e culpava a
largura da coluna. **Era falso.** `max-height` com `width: 100%` não encolhe a
caixa: ela fica com a largura da coluna e o desenho se centraliza dentro dela.

| | antes | depois |
|---|---|---|
| caixa do SVG | 459 px | 250 px |
| desenho pintado | 249 px | 249 px |
| recuo até a margem do texto | 115 px | 11 px (o recheio) |

Alargar a coluna nunca ia funcionar — **o teto era de altura**. O conserto é
`height` fixa com `width: auto`, e a caixa passa a medir o que o desenho mede.

**E isso cortou o que dois desenhos pintam FORA do `viewBox`:** o relógio da
faixa de «Dia e noite» virou "8:00", com o 1 comido. Medidos os 16 desenhos da
faixa, 13 cabem inteiros; o de «Painel e dock» tem um `<rect>` de fundo em
`x=-12 w=124` — a tela que continua além do quadro, de propósito — e o de «Dia
e noite» começa o `18:00` em `x=-1.8`. O recorte do SVG é o **viewport**, não o
`viewBox`; enquanto a caixa era mais larga, sobrava viewport e os dois
apareciam inteiros **por acidente**. `overflow: visible` os devolve de
propósito.

> Quem pegou isto foi a **caminhada com foto**, não a suíte: 83/83 passavam com
> o rótulo comido.

### E o nome que tinha ficado pela metade

Seis lugares de tela ainda diziam "barra" onde é o painel de cima: o título
«Controle na barra», o rótulo da ação «Barra e dock: diagnóstico» e quatro
frases. **Não é troca cega** — das 26 ocorrências no `meow.conf.exemplo`, a
maioria é o termo genérico certo para "painel **ou** dock" (o próprio
`forma.sh` diz "as duas barras, painel e dock"), e essas ficaram.

---

## v1.2.4 — o desenho parou de sambar

Queixa dela, literal: *"os ícones que ficam congelados ficam sambando na tela
tipo travando, em todas as páginas"*.

**Medido, quadro a quadro, rolando:** o `presa` da faixa trocava de estado de
**32 a 62 vezes numa rolagem só**, e o navegador mexia no `scrollTop` sozinho,
subtraindo **exatamente** o que a faixa encolhe — 103 px em «Ícones», 104 em
«Cor e tela», 60 em «Painel e dock» —, de 17 a 31 vezes por rolagem.

**O laço, e não há um culpado:**

1. a faixa gruda e encolhe, para devolver a fileira de títulos que ficava atrás dela;
2. o conteúdo abaixo sobe 103 px;
3. a **ancoragem de rolagem** do Chrome compensa mexendo no `scrollTop`, para o leitor não perder o lugar;
4. isso devolve a sentinela para dentro da tela;
5. a faixa desgruda e cresce — e o navegador compensa de novo.

**O conserto é no ROLADOR (`main`), não na faixa.** A âncora que o navegador
escolhe é o conteúdo **abaixo** dela: medido, com `overflow-anchor: none` na
`.previa-bloco` continuam as mesmas 34 e 62 trocas. No `main`, **uma troca só**
— a legítima — e **zero salto**, nas catorze páginas.

O preço, escrito para quem vier depois: quando algo cresce **acima** do ponto
onde a pessoa está, a página não compensa mais sozinha. Aqui isso é o
carregamento das listas, que chega antes de qualquer rolagem.

**Não nasceu na v1.2.3, e isso foi medido**: no código de 28173e2 já eram 111
trocas em «Ícones» e 106 em «Logo do sistema». A v1.2.3 redistribuiu — baixou
as piores para ~34 e subiu quatro páginas de 3 para ~35 —, e por isso o defeito
passou a aparecer em TODAS as páginas, que foi como ela viu.

---

## O que a medição derrubou

Quatro afirmações que pareciam certas e não eram. Ficam aqui para não voltarem.

| A afirmação | O que a medição disse |
|---|---|
| "A faixa vazia é a largura da coluna" | O teto é de **altura**: caixa 459 px pintando 249 px. Alargar a coluna não muda nada. |
| "A ilha anula o tamanho por segmento, então as alas também deviam avisar" | `forma.sh:229` já conferiu na fonte que **não anula** — são dois códigos diferentes do cosmic-panel. Não há nada de silencioso a avisar. |
| "O samba veio da v1.2.3" | Já eram 111 trocas em «Ícones» no código anterior. |
| "Excluir a faixa da ancoragem resolve" | Continuam 34 e 62 trocas. A âncora é o conteúdo **abaixo**. |

## As conferências que nasceram

No `tests/app-navegador.py`, seção 20c — **84/84**:

- o balão herdado nomeia o bloco dono (`WALLPAPER_NOITE`);
- a caixa do desenho cola no desenho (caixa 250 px, desenho 249 px, recuo 11 px);
- o que sangra fora do `viewBox` não é recortado (`overflow: visible`);
- rolando, a faixa gruda **uma vez só** e o navegador não mexe na rolagem.

A última **morde**: tirada a regra `overflow-anchor: none` de propósito, ela
reprova sozinha em 83/84, nomeando as três páginas e a contagem de saltos.

## Os números, medidos rodando os programas

**108 chaves · 45 ações · 13 páginas · 52 etapas de instalação · 46 conferências
no `doctor` · 46 imagens no carrossel.**

Como cada um foi obtido, porque contar errado já custou uma correção pública:

- **chaves e ações** — o esquema que a própria página monta (`ESQUEMA.chaves`,
  `ESQUEMA.acoes`), não um `grep`;
- **páginas** — o trilho tem **catorze** botões; o Início não é assunto, então
  são treze páginas de assunto;
- **etapas** — o vetor que o `install.sh` de fato roda (`local etapas=(...)`,
  `TOTAL=${#etapas[@]}`), **52**, e não os 62 `etapa_*` que o arquivo declara;
- **conferências** — a saída do `meow doctor` tem 47 linhas de veredito e uma
  delas é o resumo "nada a consertar": **46**. Não contar por prefixo: a divisão
  entre `ok` e `--` muda com o estado da máquina (medidos 45+2 e 46+1 no mesmo
  dia); o que é estável é a linha com ÁREA nomeada na segunda coluna;
- **imagens** — `assets/papeis-de-parede/ativos/`.

O README dizia "106 ajustes e 44 ações" e "os 9 ajustes e as 12 ações" do papel
de parede. Corrigido nos dois idiomas.

## Um fio solto, sem causa provada

O cabeçalho do painel passou de "14 mudados por você" para "15" no meio da
tarde. Excluído por medição: a conf dela (mtime intacto, e a suíte confere byte
a byte), o `meow.conf.exemplo` (nenhum valor de fábrica mudou), e o código — o
esquema de **28173e2**, rodado contra a mesma máquina, também diz 15 agora.
Portanto é estado da máquina que mudou durante o dia, não versão. Fica anotado
sem causa inventada.
