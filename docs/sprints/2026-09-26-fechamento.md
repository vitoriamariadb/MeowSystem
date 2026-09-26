# Leva F — o fechamento (26/09/2026)

O segundo roteiro de usuário (25/09, 23:47–23:58, dev em f54405b com P48–P68)
deu 16 de 16 ações que fazem o que prometem e deixou duas observações; a
pergunta do dono («tudo do tema foi aplicado?») deixou mais três fatos
medidos; e a documentação parou em 21/09. Decisões de 26/09: materializar tudo
em sprint, atualizar a documentação como um todo, e instalar o Vesktop para o
Discord também vestir o Dracula.

Ordem: P69 e P70 primeiro; P71 e P72 (documentação) depois do merge delas, para
descreverem o estado final.

---

# P69 — As cores seguem o lado que a tela veste

### O que medi

- Com `MODO=claro` e o Dracula no ar, o COSMIC veste o Alucard (P63), e os
  traços dos ícones do dock continuam os do Dracula escuro — lilás, com pouco
  contraste sobre o vidro claro (foto de 25/09, 23:52).
- A página decide o lado pelo `_flavor_no_modo` (`app/servidor.py`); o shell
  gera ícones, pastas e o resto pelo `FLAVOR` (a regra do flavor padrão da P61,
  `meow_flavor` no `lib/comum.sh`), sem olhar o `MODO`.

### O que fazer

1. Uma regra só, no shell, diz o flavor do lado que a tela veste (o mesmo par
   que a página usa), e quem tira cor do flavor para desenhar o que aparece na
   tela — ícones de aplicativo, pastas, e o que mais a medição achar — passa por
   ela.
2. Meça o `MODO=automático` (o lado muda com a hora): diga se os dois lados já
   ficam prontos no disco ou se a troca pede reconstrução, e escolha o caminho
   que não deixa a tela com o lado errado.
3. Com `MODO=escuro`, os bytes são os de hoje.

### Como conferir

Numa casa de brinquedo com o Dracula e `MODO=claro`, os traços dos ícones saem
da paleta do Alucard; com `MODO=escuro`, iguais aos de hoje.

---

# P70 — A tela de login pela ponte, o status que diz a verdade, e o Vesktop

1. **A ponte recusa a tela de login.** Toda instalação diz «a ponte recusou
   vestir a tela de login — tentando pelo caminho antigo», e o caminho antigo
   resolve (44 arquivos). Meça por que a ponte recusa (a lista de arquivos, o
   caminho novo da Light do Alucard, a versão da ponte instalada) e conserte para
   a ponte aceitar — ou para a recusa dizer o motivo.
2. **O status nomeia o tema errado.** O `meow status` diz «ativo alucard-mauve
   (o alvo é dracula-mauve)»: depois da P63, `dracula-mauve` e a derivada
   `alucard-mauve` vestem as mesmas árvores, e o status escolhe a primeira que
   casa. Quando mais de uma casa, o alvo vence.
3. **O status chama de divergência o que foi pulado.** A seção «Divergências»
   lista linhas `--` (puladas: o Heroic não instalado, o acervo do Catppuccin que
   o Dracula não usa) e termina com «detalhes e conserto: meow doctor
   --consertar» quando o `doctor` diz «nada a consertar». A linha do
   `iconesapps` cita «o acervo Catppuccin de aplicativos» com o Dracula no ar.
4. **O Vesktop.** Instalado em 26/09 (`dev.vencord.Vesktop`, flatpak do
   usuário) por decisão do dono. Antes da primeira abertura não há
   `config/vesktop/themes/`, e o módulo do Discord diz «falta um cliente
   modificado» — com o cliente instalado. Depois de criada a pasta, o módulo
   grava o tema e manda «ligue 'Dracula (MeowSystem)' em Configurações > Temas
   do cliente»: passo manual. O módulo prepara a pasta sozinho e liga o tema nas
   configurações do cliente (meça onde o Vesktop guarda os temas ligados), sem a
   pessoa abrir menu nenhum.

---

# P71 — A documentação do produto

O `README.md`, o `README.en.md`, o `app/LEIA-ME.md`, o `docs/PACKS.md`, o
`docs/COSMIC-THEMING.md`, o `docs/FRONTEIRA.md`, os `LEIA-ME.md` dos packs e os
`docs/jogos-*.md` passam a descrever o produto de hoje (P1 a P70): os packs
(Catppuccin, o padrão; Dracula), as variantes e o lado claro e escuro (Alucard),
a cor de destaque que se deriva, o vidro do COSMIC instalado, o seletor de ícone
com os desenhos do pack, os temas de aplicativo por pack (e o que não se veste,
com o porquê), importar, exportar e remover pack, o painel (a natureza das
ações, o ensaio), o `doctor` e a ponte, os testes e a regra de merge. Os
números conferem com o `tests/numeros.sh`; o português e o inglês ficam
paralelos; nenhum nome pessoal nem caminho de casa (o `tests/portabilidade.sh`).

---

# P72 — O índice das sprints

O `docs/SPRINTS.md` diz «última atualização: 21/09/2026» e «vinte e quatro
sprints, nenhuma executada» — nenhuma de P30 a P68 aparece nele. Ele passa a
ser o índice de estado verdadeiro: cada sprint de P1 a P72 com o estado, o
arquivo da spec e o merge; as levas (21/09 a 26/09) com o que cada uma fechou;
a regra de merge; e «o que está no ar». Cada arquivo de `docs/sprints/` ganha no
topo o estado dele.
