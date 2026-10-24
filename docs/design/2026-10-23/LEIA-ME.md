# Painel do MeowSystem: o mockup final (P97, 23/10/2026)

Abra `final/index.html` no navegador. Não precisa de servidor nem de internet. Todas as telas se ligam pela
barra de cima. Se você escolher outro tema na tela Tema, o painel inteiro troca de roupa e mantém a escolha
ao passar de uma tela para outra.

| pasta | o que tem |
|---|---|
| `hoje/` | prints do painel atual, de 00 a 14, em 1829x1029 |
| `mockup-a/` | 1º Opus: cinco portas, prévia viva e régua do dia |
| `mockup-b/` | 2º Opus: trilho lateral, Estúdio em 5 passos, tabela Painel e Dock e Saúde |
| `final/` | o que fica: o melhor dos dois, com correções |
| `final/prints/` | as 16 telas em 1829x1029, e as telas com mais de uma versão (Dracula, Latte, Alucard e a ação rodando) |
| `final/prints/inteiras/` | as mesmas telas com a página inteira |

## As telas do final

O topo tem **quatro portas: Tema · Criar tema · Ajustes · Cuidar**. Ao lado ficam a busca (tecla `/`) e um
botão **Aplicar**, que mostra quantas mudanças faltam aplicar e traz o Desfazer.

- **Tema** (`index.html`): os dois packs, MeowSystem e Dracula, aparecem lado a lado, cada um com a prévia no estilo dele, as variantes e o sino para ouvir. Depois vêm o destaque, o claro ou escuro, Criar o meu, Seus temas (vazio) e Mande para alguém.
- **Criar tema**: tem 5 passos.
  - `criar-cores`: seis cores, com o contraste medido de verdade.
  - `criar-icones`: as pastas Apps, Sistema e Biblioteca.
  - `criar-papel`
  - `criar-sons`
  - `criar-publicar`: o passo "Mandar".
- **Ajustes**: um trilho de 7 itens. Cada página mostra a prévia de um lado e as linhas de ajuste do outro.
  - `ajustes-painel`
  - `ajustes-janelas`
  - `ajustes-papel`
  - `ajustes-gato`
  - `ajustes-dia-e-noite`
  - `ajustes-terminal`
  - `ajustes-programas`
- **Cuidar** (`cuidar.html`): mostra o estado e o que foi conferido, e tem as ações Outro computador, Atualizar e Instalar de novo. Embaixo ficam o que roda sozinho, o registro e a zona de perigo.
- **Estados da tela** (`estados.html`, com link no rodapé): erro, ação que falhou, pedido de senha, arquivo que não é tema, sem internet, vazio, contraste ruim, os estados do botão e a busca aberta.

## O que veio do A

- **A primeira tela explica o que é o MeowSystem:** "Um tema veste o computador inteiro." Escolher o tema é a primeira coisa a fazer.
- **Um clique troca o tema** e o painel inteiro se veste do pack escolhido. Aplicar é o gesto que grava. Por isso o "Ver sem mudar" saiu.
- **Dia e noite numa régua de 24 h**, com um horário só e o interruptor "Tudo segue este horário". Isso substitui os 4 pares de relógio de hoje.
- **Cuidar** tem o cartão **Outro computador**, que é o que serve para o PC recém-formatado. Desinstalar fica separado, num contorno tracejado.
- **Mande para alguém** com as linhas reais do README e um botão Copiar.
- **Tracejado na prévia** marca o que mudou e ainda não foi aplicado.
- A família de letras Fira Sans, que já vem no Pop!_OS, com JetBrains Mono só para os valores.

## O que veio do B

- **Tabela Painel | Dock**: uma propriedade por linha e as duas colunas lado a lado. Isso acaba com a parede de 60 cartões.
- **Ajuste vira linha, objeto vira cartão.** O rótulo fica à esquerda e o controle à direita, separados por uma linha fina. Acabou o cartão vazio.
- **Criar tema em passos** (o Estúdio do B), com a prévia grande ao vivo e o checklist, mais a árvore do arquivo em "Mandar".
- **Seis cores** fazem o tema, e as 26 saem delas. O contraste é medido no navegador: Dracula dá 13,4:1 no texto e 5,9:1 no destaque.
- **A faixa de estado no Cuidar** mostra Tema, Ícones, Painel e dock, Mascote, Som e Atalho. Cada item leva à tela dele.
- **Um só Aplicar** no topo, com contador e Desfazer.
- Ação perigosa vira botão vermelho vazado. O que pede senha leva o selo "pede senha" escrito por extenso.
- O sino toca com os números do `pack.json`: 784 + 932,3 Hz no Dracula e 880 + 1320 Hz no MeowSystem.

## O que eu mudei, e por quê

1. **Quatro portas, não cinco (A) nem catorze (B).** "Rotina" entrou em Ajustes como Dia e noite, porque é ajuste desta máquina e não tema. Começo, Temas e Estúdio, do B, viraram uma tela só (Tema) e uma porta (Criar tema). Assim acabou o "trocar tema" em dois lugares.
2. **A faixa "painel vestido de" do B saiu.** Era um controle só do mockup, posto no meio do produto. A troca de roupa agora acontece de verdade, ao escolher o tema.
3. **As telas que os dois deixaram sem desenho foram desenhadas:**
   - Janelas e tela, Papel de parede, Mascote, Terminal e Programas;
   - a busca com resultados;
   - a caixa de senha, uma linha só e o porquê no "?";
   - a saída de ação ao vivo, com "O que ele escreveu" recolhido;
   - os estados de erro, de vazio e de contraste ruim.
4. **Tirei o texto técnico da tela.**
   - Não aparece mais nome de chave, "papirus-folders", "org.gnome.eog", "starship" nem "commit do acervo".
   - As escolhas que eram texto livre viraram objeto que se vê: o ponteiro virou três cartões com o desenho, e "Como ocupa a tela" virou três pictogramas.
   - O hex só aparece em Criar tema, onde a designer quer ver o número.
5. **Contraste:**
   - Nenhum texto usa os tons `overlay`. O mínimo é `subtext0`, que passa de 4,5:1 nas seis variantes.
   - O B esmaecia itens do trilho e o "como está · 14", e o A usava hex miúdo. Nos dois casos o texto ficava abaixo disso.
   - "Como está" virou "padrão", em cinza legível. "Voltar ao padrão" só aparece onde o valor difere, como manda a decisão 10.
6. **O cartão do tema no ar mostra a variante escolhida.** O de Latte, por exemplo, mostra Latte. O outro cartão continua com as cores do próprio pack.
7. **Mobile:** sem rolagem lateral em 375 e 768 px. A barra de cima vira duas linhas e o trilho rola de lado.
8. **Senha em ação perigosa:** o botão de confirmar repete a palavra da ação, por exemplo "Desinstalar", e não "Continuar".

## Mapa: as 15 portas de hoje → o final

| hoje | no final |
|---|---|
| Início | Tema |
| Cor e tela: pack, variante, destaque, claro/escuro | Tema |
| Cor e tela: escala, ponteiro, lado a lado | Ajustes › Janelas e tela |
| Cor e tela: faixa "Fundo" escuro/vidro/claro | sai (pergunta 2) |
| Áreas de trabalho | Ajustes › Janelas e tela |
| Logo do sistema | Ajustes › Mascote (o horário do mascote aparece também em Dia e noite) |
| Ícones: desenho de cada app, cor das pastas | Criar tema › Ícones |
| Ícones: variante dos ícones | sai (segue o tema escolhido em Tema) |
| Ícones: resgatados, cor da marca, pastas XDG | não desenhadas (pergunta 2) |
| Painel e dock | Ajustes › Painel e dock |
| Papel de parede: troca, ordem, encaixe, aviso | Ajustes › Papel de parede |
| Papel de parede: quais imagens o tema traz | Criar tema › Papel de parede |
| Papel de parede: repositório e commit do Dracula | sai da tela (é dado do pack) |
| Dia e noite | Ajustes › Dia e noite |
| Modo de leitura | Ajustes › Dia e noite › Tela quente |
| Terminal | Ajustes › Terminal (o mascote do terminal fica em Mascote) |
| Lançadores e jogos | Ajustes › Programas |
| Manutenção | Cuidar (Conferir e consertar, Sozinho, Registro) |
| Instalação | Cuidar › Instalar de novo e Desinstalar |
| Atualização | Cuidar › Atualizar a máquina |
| Créditos | rodapé e linha final de Tema |
| Exportar / Importar (topo) | Cuidar › Outro computador |
| Ver sem mudar (topo) | sai: clicar já mostra na prévia |
| Salvar e aplicar (topo) | Aplicar, com contador e Desfazer |
| (não existia) | Criar tema, Seus temas, Mande para alguém, Estados da tela |

## O que fica de fora

- A interação é de mockup: nada grava fora do navegador.
  - As abas Sistema e Biblioteca de Criar tema › Ícones não mudam a grade.
  - "Ver os 47", "Trazer ajustes" e "Abrir um tema" não abrem nada.
  - A busca leva à página certa, mas não acende a linha do ajuste.
- Criar tema parte do Dracula. Partindo do MeowSystem, os passos de ícones e de papel mostrariam os traços e o "vem da internet", mas não estão desenhados.
- O `.hallmark/log.json` não foi criado, porque mora fora da pasta permitida.
- Nada foi commitado, e nada fora de `docs/design/2026-10-23/` mudou.
