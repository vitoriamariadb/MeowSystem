# P136 — acabamento dos applets e as cores do pack em todos

Anotada em 28/10, com três capturas dela (Desempenho, Conta-gotas, Bandeja): «aparece desnecessariamente o placa:
nome setado, isso sai, assim como o persistência, e alinhar o nvidia com fonte zuada»; «tá inglês»; «tira o bandeja
e deixa o configurar na mesma linha dos apps da tray mas separados à direita, separado dos demais da tray por um |»;
«eles não têm elementos de cores que casam com os temas, seja dracula ou meowsystem. Preciso que todos eles tenham
isso». Ordem dela: três Opus, corrigir e dar push nos forks.

## O que se mediu
- `meowsystem-performance`: a linha «Placa: Equilibrado» repete o perfil marcado; «Persistência ligada» sobra; a
  linha da GPU quebra o nome («RTX 4060 Laptop / GPU») e desalinha dos números; o botão «NVIDIA» marcado tem o texto
  apagado, com a fonte diferente dos vizinhos.
- `meowsystem-eyedropper`: «No colour selected», «Select Colour», «Copy on selection» em inglês.
- `meowsystem-status-hub` (Bandeja): um cabeçalho «Bandeja» com a engrenagem, uma linha, e os ícones da bandeja
  embaixo.
- Cores do pack: o contrato é `~/.config/meowsystem/extensoes/<TEMA>/tema.conf` (`chave = #hex`), escrito por
  `scripts/extensoes_tema.sh` a partir de `TEMA`/`TEMA_CHAVES` do pino. `performance`, `leitura` e `now-playing`
  não têm `TEMA`; os outros seis têm, mas quem usa não vê elemento de cor do pack em todos.

## Cura na origem (nos forks; o MeowSystem só atualiza os pinos na integração)
- Grupo A (performance, leitura, quick-settings): tirar «Placa: …» e «Persistência …»; a linha da GPU em uma linha
  só, alinhada com os números; os três botões do modo gráfico com a mesma fonte e o marcado legível.
- Grupo B (eyedropper, clipboard, drives): toda frase em português do Brasil (a tradução pt-BR existe e é a que
  sobe nesta máquina, `LANG=pt_BR.UTF-8`).
- Grupo C (status-hub, ascii-battery, now-playing): sem o cabeçalho «Bandeja»; a engrenagem na mesma linha dos
  ícones da bandeja, à direita, separada deles por um traço vertical.
- Os nove: lê o `tema.conf` como os que já leem, e o acento e o fundo do pack aparecem em elemento visível
  (marcado, ativo, barra, realce). As chaves pedidas existem nas paletas do `meowsystem` e do `dracula`.

## Prova
- Em cada fork: `cargo build --release --locked` e os testes dele verdes; commit e push na `main`.
- No MeowSystem, na integração: pinos com `COMMIT`, `VERSAO`, `TEMA` e `TEMA_CHAVES` novos; `tests/extensoes.sh`
  verde; depois do install, captura dos três applets no painel.
