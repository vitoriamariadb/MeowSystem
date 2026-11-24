# P282 — testes, etapa 3: o máximo possível (23/11/2026)

## O que se mediu (catálogo de 23/11)
- 173 testes, cerca de 80 minutos na máquina e de 56 a 67 no CI portátil, em sequência.
- O que não pode sair sem trocar outra coisa junto:
  1. `numeros.sh`, `frases-velhas.sh` e `portabilidade.sh` rodam no pre-commit (`scripts/higiene.sh:28-37`); o
     `numeros.sh` também dentro do `etapa-compositor.sh:204-210`.
  2. `app-completo.py` é importado por 23 testes de navegador.
  3. `tests/decisoes.sh` cobra as 66 decisões e exige 32 testes pelo nome.
  4. A decisão 47 pede três testes extraindo a mesma função.
- 35 testes recortam função do fonte com `sed` e 15 carregam o `bin/meow` inteiro: qualquer mudança de lugar os
  quebra.

## A regra desta etapa
Fica o teste que é a única prova de uma destas três coisas: uma decisão de `docs/DECISOES.md`, uma etapa do install
ou uma conferência do doctor, uma regra do `GSD.md`. O resto sai.

## A cura
1. Montar a tabela de cobertura: decisão, etapa, conferência e regra, cada uma com o teste que a prova. Ela mora
   neste arquivo.
2. O teste que não aparece em nenhuma linha da tabela sai. O que aparece em linha que tem outro teste sai também, e
   fica o mais curto.
3. Os scripts que só teste chamava saem com o teste: `afinar_conversor.py`, `estilo_icone.py`,
   `creditos_dos_papeis.py`, `derivar_claro.py`, `inventario_do_sistema.py`.
4. O que ficar sem prova entra na lista «sem prova» da P281.

## Como se prova
- A tabela de cobertura sem linha vazia para decisão, e com a lista «sem prova» dizendo o que perdeu teste.
- `tests/decisoes.sh` e o pre-commit verdes.
- A suíte inteira, com o número de testes e o tempo anotados no `ESTADO.md`.

## O sim de quem usa
Sim de quem usa, 24/11/2026 (AskUserQuestion): «Sim, pode juntar». As duas linhas passam a dizer o que é vigiado, sem
nome de arquivo de teste; o que elas decidem não muda.

O pedido era:
A decisão 47 («três testes extraem a função verbatim») e a 46 («o `tests/variante.sh` vigia») citam teste pelo
nome. Fundir esses testes troca o texto das duas linhas.

## Primeira passada por script (23/11, integração `11ad5d43`)
O roteiro `~/.cache/meow-leva/cobertura/cobertura.py <raiz> <serie.log>` liga cada decisão, cada `etapa_*` do
`install.sh` e cada `chk_*` do `bin/meow` aos testes que a citam, e grava `itens.tsv` e `testes.tsv` ao lado dele.
Citar não é provar: a saída é a lista de candidatos, e o veredito de cada teste é de leitura. Ele roda de novo
sobre a árvore final.

| medida | valor |
| --- | --- |
| testes na lista do `todos.sh` | 175 |
| itens (66 decisões, 78 etapas, 89 conferências) | 233 |
| decisões provadas por um teste só | 52 (quase todas dentro do próprio `decisoes.sh`) |
| decisões provadas por dois | 9 |
| decisões sem prova de código | 5: duas ditas «só texto» e a 10, a 16 e a 18 |
| etapas sem teste que as cite | 7 |
| conferências sem teste que as cite | 9 |
| testes com item único, ou citados pelo `decisoes.sh` | 46 |
| testes só em item que outro teste também cita | 76 (1915 s em série) |
| testes que não citam item nenhum | 53 (1968 s em série) |

O que a passada já mostra:
- A regra desta etapa, lida ao pé da letra, tiraria `deb.sh`, `restaurar.sh`, `higiene.sh`, `portabilidade.sh` e os
  testes de página do painel: eles provam verbo do `meow`, regra do `GSD.md` ou tela, que o roteiro não lê. A regra
  do `GSD.md` e o verbo entram na tabela à mão antes de qualquer corte.
- Sete etapas e nove conferências não têm teste nenhum que as cite (`etapa_cli`, `etapa_atalho`, `etapa_svg`,
  `etapa_vigia_qt`, `chk_modo`, `chk_fundo`, `chk_forma`, `chk_pacotes` e outras): vão para a lista «sem prova».

## Segunda passada, sobre a árvore de cinco pastas (24/11, integração `1cf0d430`)
Os números do roteiro, com os tempos da suíte inteira em paralelo (`suite-arvore-final.log`, 1469 s de parede):

| medida | valor |
| --- | --- |
| testes na lista do `todos.sh` | 182 |
| itens (67 decisões, etapas e conferências) | 234 |
| itens sem teste que os cite | 17: as decisões 10, 16 e 18; `etapa_conf_ler`, `etapa_backup_tema`, `etapa_cli`, `etapa_svg`, `etapa_icones_tray_zapzap`, `etapa_vigia_qt`; `chk_modo`, `chk_fundo`, `chk_qtvigia`, `chk_forma`, `chk_trayzapzap`, `chk_svg`, `chk_cli`, `chk_pacotes` |
| testes com item único, ou citados pelo `decisoes.sh` | 47 |
| testes só em item que outro teste também cita | 78 (2605 s somados) |
| testes que não citam item nenhum | 57 (2719 s somados) |

O roteiro liga por citação, e citação erra para os dois lados: `etapa_cli` aparece sem teste, e o `instalacao.sh`
prova a CLI instalada sem citar o nome da etapa. A lista «sem teste» é lista de onde olhar, não veredito.

### O que a leitura mostrou
- Afirmação repetida entre testes: cruzei os rótulos (`ok`, `falha`, `passou` e os parentes) dos 182 arquivos, em
  `~/.cache/meow-leva/cobertura/rotulos/`. O par que mais repete é `apps-em-todo-pack.sh` com `temas-por-app.sh`: 7
  afirmações iguais em 30. Depois vêm `claro-do-pack.sh` com `variante.sh` (4) e pares com 2 ou menos. As etapas 1 e
  2 já tiraram o repetido; o que sobra é caso de juntar arquivo, que é a P283.
- Os 57 que não citam item são prova de tela do painel (`app-layout.py`, `modificacoes-pagina.py`,
  `personalizar-pagina.py` e os parentes), de verbo do `meow` (`restaurar.sh`, `deb.sh`, `perfil.sh`,
  `levantamento.sh`) e de regra do `GSD.md` (`higiene.sh`, `portabilidade.sh`, `frases-velhas.sh`,
  `dado-sem-comentario.sh`, `caminhos-do-manual.sh`, `orfaos.sh`). Li os rótulos de doze dos menores (`afinador.sh`,
  `conversor.sh`, `gerador-dracula.sh`, `levantamento.sh`, `previa-cerca.sh`, `mesmo-horario.sh`,
  `retirados-do-pack.sh`, `vagas-novas.sh` e outros): cada um prova um comportamento que nenhum outro prova.
- Os cinco scripts do item 3 da cura não saíram. Medido em 24/11:

| script | quem usa além do teste | o que o teste perde se ele sai |
| --- | --- | --- |
| `inventario_do_sistema.py` | ninguém | `icones-do-sistema.sh` deixa de provar que o contrato `nomes-de-sistema.tsv` cobre o que o COSMIC pede |
| `derivar_claro.py` | ninguém (o `pack.py` tem a função dele) | `pack.sh` deixa de provar que as duas portas dão o mesmo claro, 26 de 26 |
| `creditos_dos_papeis.py` | o `docs/PACKS.md:580` diz que é ele que escreve a seção dos créditos; dois conferentes desta leva rodaram o `--conferir` | a seção dos créditos volta a ser escrita à mão |
| `estilo_icone.py` | o `afinar_conversor.py` e o manual da oficina | a medida da caneta dos ícones |
| `afinar_conversor.py` | ninguém | só o `afinador.sh` (2 s) |

  São instrumentos de quem mantém, e o teste os usa como árbitro. Tirar o script apaga a prova junto. Ficam até quem
  usa dizer que algum pode sair.

### Veredito desta etapa
Nenhum teste saiu nesta passada. A regra da etapa, ao pé da letra, tiraria prova única de tela, de verbo e de regra.
Dos 135 candidatos, só doze tiveram os rótulos lidos um a um, e nenhum deles era sobra; os outros 123 foram
olhados só pelo cruzamento de rótulos, que não achou repetição. Corte entre esses 123 pede a leitura que falta. O ganho de tempo já veio da suíte em paralelo (de
cerca de 80 minutos para 24). O que ainda encurta a suíte, por ordem de tempo, é reescrita e não corte, e é da P283:
`app-completo.py` (1269 s), `restaurar.sh` (809 s), `deb.sh` (428 s) e os testes de página do painel que sobem um
navegador cada.

As linhas das decisões 46 e 47 foram reescritas para dizer o que é vigiado sem nome de arquivo de teste (sim de
24/11), o que deixa a P283 livre para juntar.

