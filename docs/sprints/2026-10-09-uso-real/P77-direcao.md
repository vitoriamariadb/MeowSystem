# P77 — Direção visual: a interface mostra em vez de explicar

**Base:** `00-achados-como-usuario.md` (28, 30, 6, 15, 17, 18, 21, 24), `01-regressoes.md`
(U1, U2, U3), os prints de antes em `.playwright-mcp/ux/` e a medida de texto em
`.playwright-mcp/ux-p77/antes-*.png`. Direção feita com a skill `hallmark` (auditoria e
redesenho de um app de várias páginas). Este arquivo é o sistema que vale para TODAS as
páginas: quem reescrever uma página lê isto antes e não inventa outro padrão.

> Hallmark · genre: modern-minimal (ferramenta) · macro: painel de ajustes em grade ·
> tema: a paleta do pack no ar (`paleta.css`, travada: o painel veste o tema que configura) ·
> fonte: Inter/Cantarell (preservada) · movimento: cortado · design-system: este arquivo ·
> pre-emit critique: P4 H4 E4 S4 R5 V3

## O diagnóstico, em uma linha por print

| Print | O que o olho encontra | O defeito de sistema |
|---|---|---|
| 13 Logo | 18 parágrafos; «Quem manda é…» em três cartões; legenda de 4 linhas sob o desenho | explicação como conteúdo, estado como frase |
| 11 Painel e dock | legenda de 4 linhas sob cada barra; «Restaurar ao padrão (0)»; frase sob cada controle | a legenda compete com o desenho que ela legenda |
| 17 Manutenção | 12 desenhos iguais e uma frase sob cada um; comando cru sobre cada botão | o desenho deixou de distinguir; o comando aparece duas vezes |
| 12 Papel de parede | 11 ações técnicas antes da coleção | hierarquia invertida: o que importa vai para o fim |
| 18 Instalação | parágrafo-legenda de 3 linhas; selos em CAIXA ALTA disputando com o título | o risco é dito em palavras, não visto |
| 01 Início | bloco monoespaçado «Próprio/herdado/do motor» de 6 linhas | dado técnico tratado como leitura |

A causa comum: **cada componente nasceu com uma frase embaixo**, e a frase virou o jeito de
resolver toda dúvida. Somadas, são 31 416 caracteres visíveis e 135 parágrafos nas 14
páginas (tabela no fim).

## 1. A explicação vira dica

**Regra.** Na tela, só fica texto que **nomeia** ou **mede**: título de página, título de
cartão, rótulo de opção, valor, número, unidade. Tudo que **explica** (o porquê, a
consequência, a legenda do desenho, «vale quando…», «sem isto…») mora atrás de um `?`.

Dois degraus, e só dois:

| Degrau | Onde | Teto | Para quê |
|---|---|---|---|
| balão | `data-balao`, sobre um controle ou selo | 80 caracteres | o NOME do que o controle faz |
| dica | `?` ao lado de um título, abre `.dica` | 22 rem de altura, rola | o parágrafo inteiro |

Um `?` por dono: um por cartão de ajuste, um por cartão de ação, um no cabeçalho da página,
um por desenho. Nunca `?` dentro de `?`. O `?` é sempre o mesmo glifo, o mesmo alvo de 24 px,
o mesmo comportamento (espia no hover, fixa no clique, Esc fecha, abre no foco do teclado).

```
ANTES                                      DEPOIS
Dock em pastilha  (?)                      Dock em pastilha  (?)
[desenho Sim] [desenho Não]                [desenho Sim] [desenho Não]
│ A dock encolhe até o tamanho dos ícones.
```

## 2. O padrão de prévia real

**Regra.** A prévia é a explicação. Ela responde «o que isto faz com a minha tela» sem
legenda, e para isso cumpre quatro coisas:

1. **Reflete o valor em vigor**, e a escolha pendente ao lado («Como está» / «Como fica»,
   as duas únicas palavras que a prévia pode ter).
2. **Usa o real quando o real existe**: o papel de parede da coleção, o SVG do gato, o ícone
   do tema instalado, a captura. Desenho só onde não há o que capturar.
3. **Desenho se reconhece pelo traço**, não por aviso: linha sobre fundo liso, sem textura
   de foto. A frase «Desenho, não é a sua tela» **sai de todas as páginas** (seção 6).
4. **Nunca vazia.** Prévia que não sabe desenhar o valor não desenha contorno: some, e o
   cartão fica sem prévia. Um contorno vazio (o «No terminal» do print 13) é mentira visual.

A faixa de prévia gruda no alto da SUA seção e encolhe para tira; ela nunca paira sobre outra
seção nem cobre controle (achado 6). Os números que o desenho representa (raio 8, espaço 4…)
vão para o `?` do desenho, que é onde quem quer conferir procura.

```
ANTES                                       DEPOIS
[ desenho do painel ]                       [ desenho do painel ]                (?)
Desenho, não é a sua tela: o painel raio
0, espaço 2 e recheio 0; margem 0; em       (o ? abre: «O painel raio 0, espaço 2
pastilha: encolhe até o conteúdo…            e recheio 0; margem 0; …»)
```

## 3. Estado sem frase

**Regra.** Estado se vê em três canais, nesta ordem de força:

1. **Aresta do cartão** (já existe, fica): pêssego = diferente de fábrica; acento = esperando
   «Salvar e aplicar».
2. **Selo**: ícone de traço de 12 px na cor do estado, com no máximo um valor curto ao lado
   (`6300 K`, `«Dracula»`). Sem CAIXA ALTA, sem frase. O nome do estado vai no balão e no
   `aria-label`; a frase inteira vai para o `?` do dono.
3. **Controle apagado**: ajuste anulado por outro fica com o controle a 55 % e o selo ⊘; ação
   sem efeito agora fica com o «Executar» desligado e o selo ⊘.

| Estado | Antes (frase visível) | Depois (selo) | Balão |
|---|---|---|---|
| pede senha | PEDE SENHA | cadeado pêssego | «Pede a senha do sudo» |
| sem senha | SEM SENHA (PERFIL REGISTRADO) | cadeado aberto verde | «Sem senha: o perfil do sudo está registrado» |
| baixa da internet | BAIXA DA INTERNET | seta para baixo, céu | «Baixa da internet» |
| desfaz | DESFAZ O QUE FOI FEITO | seta de desfazer, vermelho | «Desfaz o que foi feito» |
| na máquina difere | «Na máquina agora: 6300. Quem guarda…» | monitor + `6300 K` | «Na máquina agora: 6300 K» |
| desligado agora | «Na máquina agora: desligado. O modo…» | monitor + `desligado` | «Na máquina agora: desligado» |
| anulado por outro | «Quem manda é «X», em Hora. …» | ⊘ amarelo, controle apagado | «Quem manda: «X»» |
| vestígio de pack | «Vestígio do pack «Catppuccin». …» | caixa + `«Catppuccin»` | «Vem do pack «Catppuccin»» |
| sem efeito / lista vazia | «Sem efeito com «X» em «Y»…» | ⊘ amarelo, «Executar» desligado | a frase curta |
| mudados na página | (nada) | ponto pêssego + `3` no cabeçalho | «3 ajustes diferentes de fábrica» |
| esperando na página | (nada) | anel acento + `2` no cabeçalho | «2 escolhas esperando Salvar e aplicar» |

## 4. Hierarquia de página

**Regra.** De cima para baixo, sempre nesta ordem:

1. **Cabeçalho**: título da página + `?` (a descrição da página e as notas dela) + os selos
   de resumo (mudados, esperando) + o botão de acervo da página, se houver. Nada de subtítulo
   visível.
2. **O que importa**: a coleção, a escolha principal ou a prévia da página. Na página de
   papel de parede é a coleção (achado 15); na de ícones, o seletor; nas de forma, a prévia.
3. **Os ajustes**, em grade de três colunas, agrupados pela decisão que tomam (uma decisão =
   um cartão; seis controles para «qual gato aparece» é uma decisão só — achado 17).
4. **As ações**, no fim. Ação técnica (reconstruir, regravar, baixar acervo, reaplicar) fica
   recolhida sob um único «⋯» fechado por padrão; só a ação que quem usa procura de propósito
   (ouvir o som, próxima imagem) fica aberta. Essa separação é por página, na reescrita de
   cada uma — o componente de cartão de ação já está pronto para as duas casas.
5. **O comando** nunca aparece por conta própria: só dentro do «ver comando» (achado 30).

```
ANTES (Papel de parede)                     DEPOIS
Título                                      Título (?)                     ● 3   1
Subtítulo                                   [ coleção: No carrossel · Noite · Dia … ]
[desenho] legenda de 2 linhas               [ grade de imagens ]
9 ajustes com frase                         9 ajustes (título, ?, controle)
11 ações com comando cru                    ações de uso         ⋯ ações técnicas
A coleção (no fim)
```

## 5. Densidade

- Cartão de ajuste = **três camadas**: linha do título (título + selos + `?`), controle,
  e nada mais. Sem a frase de baixo, a altura do cartão cai e as fileiras da grade alinham.
- Cartão de ação = **duas camadas**: título + `?`; rodapé com selos à esquerda e «ver
  comando» + «Executar» à direita.
- A grade fica em três colunas acima de 1100 px (pedido dela de 06/09, preservado).
- Nenhum bloco de texto visível passa de 60 caracteres, salvo: o texto do autor do pack (é
  dele, não deste painel) e a saída ao vivo da gaveta (é saída, não interface).

## 6. O que acontece com «Desenho, não é a sua tela»

Sai, em todas as páginas, e não volta como outra frase. O aviso existia porque o desenho
podia ser lido como captura; o que resolve isso é (a) o traço, que já é de desenho, (b) o par
«Como está / Como fica», que mostra que o desenho segue o valor, e (c) o `?` do desenho, que
abre a descrição dos números. O prefixo é tirado na origem da dica (`semAvisoDeDesenho`), então
os `previas-*.js` não precisam ser reescritos de uma vez: a próxima leva pode encurtar cada
legenda sem pressa, porque nenhuma delas fica mais na tela.

## Os componentes comuns (em `app/pagina/app.js` e `estilo.css`)

| Componente | Função | O que faz |
|---|---|---|
| dica genérica | `gatilhoDeDica(id, rotulo, filhos)` | o `?` + a `.dica`, com o comportamento do `?` do cartão; serve a qualquer dono |
| legenda → dica | `dicaDoDesenho(id, texto)` | tira «Desenho, não é a sua tela:» e põe o resto atrás do `?` do desenho |
| cabeçalho de página | `cabecalhoDePagina(assunto)` | título + `?` (descrição, nota, acervo) + selos de resumo + botão de acervo |
| cartão de ajuste | `montarCartao` | a frase e o «Vale como» vão para a dica; estado vira selo + frase na dica |
| cartão de ação | `montarAcao` | a ajuda vai para a dica; o comando só no «ver comando»; risco vira selo |
| selo de estado | `selo(tipo, {texto, balao})` | ícone de traço + valor curto opcional + balão e `aria-label` |

## A medida de antes (para a prova final)

Medido com `tests/app-texto-visivel.py` (casa de brinquedo do `app-completo.py`, HOME
temporário, falsos no PATH), na branch `sprint/p77` em `af3159f`, antes de qualquer mudança.
Conta os caracteres de texto visível em `#conteudo` fora de `.dica`, `[role=tooltip]` e
`#balao`; «frases» são blocos de texto corrido com 60 caracteres ou mais; «em `<code>`» é o
comando cru visível. Prints da mesma corrida: `.playwright-mcp/ux-p77/antes-*.png`.

| página | caracteres | frases ≥60 | em `<code>` |
|---|---:|---:|---:|
| Início | 2500 | 8 | 0 |
| Cor e tela | 1987 | 9 | 46 |
| Áreas de trabalho | 1290 | 9 | 116 |
| Logo do sistema | 4119 | 18 | 49 |
| Ícones | 2787 | 15 | 68 |
| Painel e dock | 4250 | 12 | 54 |
| Papel de parede | 2447 | 8 | 162 |
| Dia e noite | 1300 | 6 | 0 |
| Modo de leitura | 1759 | 11 | 52 |
| Terminal | 691 | 3 | 0 |
| Lançadores e jogos | 2820 | 10 | 122 |
| Manutenção | 2734 | 15 | 83 |
| Instalação | 1414 | 6 | 102 |
| Atualização | 1318 | 5 | 109 |
| **total** | **31416** | **135** | **963** |
