# Para a próxima leva (anotado em 23 e 24/11/2026)

Achados desta leva que ficaram fora dela. Cada um vira tarefa, com medida, quando a leva dele abrir.

## Já decidido por quem usa
- P283, a etapa 4 dos testes (um arquivo por área, apoio único): «Depois do push», 24/11.

## Pedem decisão de quem usa
- Quem instala os ganchos de push. Proposta: um verbo de quem desenvolve (`meow ganchos instalar`). P288.
- O comentário do `meow.conf.exemplo`, que é o esquema do painel (131 títulos, 131 frases, 17 seções). P276, item D.
- O prompt próprio de pack pessoal: hoje pack de fora do repositório só entrega a paleta. Abrir pede leitor de TOML
  e lista do que é permitido.
- `packs/dracula/PROCEDENCIA.md` (310 KB; 89% é a tabela que o `pack.py` lê): tirar pede mudar o leitor. P278.

## Defeitos medidos
- Cor de tema cravada em código: `scripts/gerador_circulo.py` (19), `bin/meow` no fzf (9),
  `btop-bat/manifesto.sh`, `spotify/acento.py`, `scripts/vidro.sh`, `scripts/afinar_conversor.py`, a reserva do
  `_tinta_do_traco` em `app/servidor.py`. A lista inteira está em
  `~/.cache/meow-leva/suite-2026-11-23/impl-arte-cores-fora-de-packs.md`.
- Spotify: `rm -rf "$_SPOT_TEMA"`, com o nome vindo do `spicetify_tema` do pack; o pack escolhe qual pasta de
  `~/.config/spicetify/Themes/` é substituída.
- Papéis: a semente e o envio de foto ainda criam o mesmo nome em duas pastas (`dracula/x.png` e `Minhas/x.png`);
  o carrossel, o `BANIDOS` e o lado usam só o nome.
- Papéis: o `semear-se-faltar` para no primeiro arquivo que não é par do pack; casa com um papel alheio nunca
  recebe a origem nova pelo install.
- `tests/convergencia.sh`, `tests/casa-real.sh` e `tests/pack-dracula-completo.sh` vão à rede de verdade (clones do
  GitHub e a árvore do acervo do Catppuccin).
- `tests/app-completo.py` tem teto de 240 s numa gravação e estoura com a máquina em carga.
- `scripts/migrar_conf.py` reescreve o conf sem cópia de antes e perde o CRLF.
- `assets/apps/jogos-fora.map` só guarda os 77 comentários porque não tem dado; a primeira linha que o painel
  escrever deixa `tests/dado-sem-comentario.sh` vermelho.
- A completion não tem os subverbos; o desinstalar não chama `cursor.sh remover`; o `settings.ini` do GTK que o
  `botoes_lado` escreve sai inteiro pelo manifesto.
- Valores de antes: máquina nova em que os botões já estão do lado pedido guarda cópia vazia, e o desinstalar troca
  um valor que o MeowSystem não tocou.
- O gesto de um applet só (`extensoes_build.sh <id> --aplicar`) deixa o `mimeinfo.cache` velho até o doctor.
- Hefesto: a bandeja sobe por `python3 -m hefesto_dualsense4unix.cli.app tray`, que não passa pelo `app/main.py`;
  candidata à origem do `__main__.py` do mapa de janelas. P269.
- `docs/PACKS.md`, no exemplo do `meow pack info`, diz 13 desenhos para o Dracula; são 19.

## Achados dos conferentes do passo 6 (24/11)
A porta de entrada de pack de fora é o `importar`, que recusa id de pack do repositório. Os três primeiros pedem
alguém pondo pasta à mão na casa de quem usa, então não são furo aberto; são robustez.
- Sombra: o `achar` do `pack.py` põe a raiz pessoal antes da do repositório. Uma pasta pessoal com o id de um pack
  do repositório o esconde em toda herança; pelo `vscode/manifesto.sh` a extensão escolhida pela sombra se
  instalaria sem gesto (decisão 9). O prompt e o Spotify já não confiam no id (`eee7934d`, `b68af15c`).
- «Do repositório» é `realpath` dentro de `<clone>/packs/`, inclusive pasta não versionada; o `meow pack novo` sem
  `MEOW_PACKS` grava ali e o pack criado ganha a confiança do repositório.
- `_bb_rebaixar_upstream` acha o destino por `adocao meowsystem` e pode gravar numa sombra pessoal.
- Spotify: `_spot_tema_baixar` sai cedo se `Themes/<nome>/color.ini` já existe; pasta velha com `theme.js`, deixada
  por versão antiga, seria reusada com a porta aberta ao trocar para pack do repositório de mesmo nome de tema.
- Spotify: o `user.css` de pack de fora pode trazer `@import` remoto (pedido de rede a partir do cliente; a decisão
  67 aceita o arquivo como dado).
- `heroic.esquema` não é validado contra `/` e `..` (hoje só vira valor de JSON).
- `scripts/prompt.sh`, `_prompt_dizer_falta_starship`: a frase manda a pessoa apagar um arquivo.
- O cabeçalho do `packs/CAMINHOS-DE-ANTES.tsv` não cita a P274, a P275 nem a P291.
- Comentário antigo no Python embutido do `_semear_origem` (`scripts/wallpaper.sh`), que o `dado-sem-comentario.sh`
  não pega.
- Uma cópia pessoal chamada `dracula`, sem `papeis.tsv`, numa raiz antes do repositório para a migração dos papéis
  com erro. Nenhum PC tem.
- `tests/papeis-por-pack.sh` monta a árvore do acervo por uma lista escrita no teste, sem `LICENSE`, `README` nem
  `svg/`; a prova contra a árvore real ficou em roteiro.
- Base já no desenho novo com nomes soltos (só casa de teste) fica com dois nomes da mesma arte depois do `semear`.

## Achados do conferente da árvore final (24/11)
- `packs/CAMINHOS-DE-ANTES.tsv`: 588 destinos da coluna da direita não existem no disco (nomes de
  `mimetypes/css-variables/` e de `arcticons/` que a pasta plana não tem). O mapa de quem usa que citar um deles
  migraria para caminho morto.
- `tests/caminhos-do-manual.sh` só cobra caminho que começa por uma raiz de hoje; citação com pasta velha (`lib/…`)
  nunca é cobrada.
- `packs/dracula/CREDITOS.md:97` diz que prompt e mascotes são do motor; `packs/meowsystem/mascote/LEIA-ME.md:30`
  cita `scripts/gerar_gato.py`, que não existe.
- A mensagem «aponte com: MEOW_RAIZ=/caminho/do/clone meow …» da CLI manda digitar.
- `scripts/app/run.sh` não resolve link (`dirname` sem `readlink`).
- Listas com entrada repetida ou morta em `tests/cache-do-lancador.sh:97`, `tests/flatpak-tema.sh:379` e
  `tests/app.sh:547,1119`.
- Clone que veio por `git pull` com sobra ignorada mostra `app/`, `assets/` e `src/` na raiz além das cinco.

