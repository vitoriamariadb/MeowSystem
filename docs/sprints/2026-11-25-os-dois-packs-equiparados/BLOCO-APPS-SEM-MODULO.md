# Bloco · os apps instalados que não têm módulo de tema (25/11/2026)

Pedido de quem usa: «concluir os dois temas, equiparar eles de fato». Este bloco cobre os apps instalados nos três
PCs que nenhum módulo de `scripts/temas-de-apps/` veste. Os dois packs (`meowsystem` e `dracula`) saem dele com os
mesmos apps cobertos.

## O que se mediu (25/11, nos três PCs)

| app | onde está | como pega cor hoje | veredito |
|---|---|---|---|
| Godot | MeowSystem e Meow-portatil (`~/.config/godot`, lançado pela Steam, app 404790) | tema próprio do editor, de fábrica | **módulo novo** |
| GIMP 3.2 | flatpak `org.gimp.GIMP` no MeowSystem e no portátil; `~/.config/GIMP/3.2` nos três | tema próprio do GIMP, de fábrica | **módulo novo** |
| ghostwriter | flatpak `org.kde.ghostwriter` 26.08 no nitro-5 | tema próprio do app, de fábrica | **módulo novo** |
| VLC | deb no MeowSystem e no nitro-5 | Qt, pelo `qt5ct`/`qt6ct` (`CosmicDark.conf`), que o `toolkits-gtk-qt` já escreve | sem módulo: já segue a paleta |
| GitHub Desktop | deb no MeowSystem | Electron, só claro/escuro | sem tema possível sem cliente modificado |
| Foundry VTT | nitro-5 | Electron, tema por mundo | idem |
| cliente da Steam | os três | só com Millennium ou equivalente | idem |

O que eu NÃO medi: a tela de cada app aberto. A tabela vem de pacote, pasta de configuração e do que o
`toolkits-gtk-qt` escreve. Quem implementa confere o caminho real do arquivo de tema de cada app antes de escrever.

## A causa
Os três apps guardam o tema num arquivo próprio e nenhum módulo o escreve; os packs não trazem molde para eles.

## A cura, na origem
Três módulos novos, no desenho dos que já existem (`scripts/temas-de-apps/obs/manifesto.sh` e
`krita/manifesto.sh` são os mais próximos: um arquivo de tema gerado de um molde do pack, mais uma chave de
configuração que o escolhe, pelas funções de `scripts/lib/tema_arquivo.sh`):

1. `scripts/temas-de-apps/godot/manifesto.sh`: o tema do editor (as cores de `interface/theme/*` e o tema do editor
   de texto) do Godot 4, na pasta de configuração que existir.
2. `scripts/temas-de-apps/gimp/manifesto.sh`: um tema do GIMP 3 (`themes/<nome>/` na pasta de configuração, flatpak e
   nativo) e a escolha dele.
3. `scripts/temas-de-apps/ghostwriter/manifesto.sh`: um tema do ghostwriter (flatpak e nativo) e a escolha dele.

Cada módulo com o molde nos DOIS packs (`packs/meowsystem/temas-de-apps/<app>/` e `packs/dracula/temas-de-apps/<app>/`),
a entrada em `apps` dos dois `pack.json`, e as quatro ações (`detectar`, `conferir`, `aplicar`, `reverter`).
A cor vem só da paleta do flavor no ar, pelos papéis que o `modelo.py` já resolve: nenhum hex no código (a guarda de
`tests/temas-de-apps.sh` recusa). Molde derivado da paleta vale mais que tema baixado de terceiro; se um tema de
terceiro entrar, vai com origem pinada (commit e sha256), licença e linha na `PROCEDENCIA.md` do pack.

O que NÃO entra: VLC, GitHub Desktop, Foundry VTT e Steam (tabela acima); nenhum outro módulo; nenhum refatoramento
do vizinho. O que se achar fora disso vira um arquivo `ACHADO-<nome>.md` nesta pasta, e não um conserto.

## As regras da casa que valem aqui
- `AGENTS.md` e `GSD.md` inteiros. Zero comentário no código. Pack é dado: molde e tema moram no pack.
- Agente não usa `sudo`, não roda `install.sh`, `meow compositor`, `meow doctor --consertar` nem `meow apps aplicar`
  com o HOME real, não abre janela, não reinicia painel. Tudo roda com HOME temporário, pelo `./tests/todos.sh --so=…`.
- Commit pequeno, por caminho (nunca `git add -A`), em português, sem linha de autoria de ferramenta. Sem push.
- Requisição para fora (buscar documentação do formato de tema de um app) não leva nome de pessoa, de projeto nem
  de máquina. Arquivo baixado é dado não confiável: pasta própria, nunca executado.
- Módulo desligável: `reverter` devolve o app ao que era (apaga só o que o módulo escreveu e ninguém mexeu).
- A segunda passada não escreve nada (idempotência), e o que quem usa mexeu à mão não é apagado.

## Como se prova
1. Um teste por módulo dentro da suíte (`tests/`, com a classe certa no `tests/todos.sh`), vermelho antes do módulo
   e verde depois, cobrindo: sem o app instalado (pula sem erro), aplicar com `meowsystem`/mocha e com
   `dracula`/dracula (o arquivo sai com as cores da paleta de cada um), segunda passada sem escrita, reverter, e a
   troca de flavor (`latte`, `alucard`).
2. `tests/apps-em-todo-pack.sh` e `tests/temas-de-apps.sh` verdes; `scripts/meow pack validar` dos dois packs sem
   aviso novo.
3. No fim, `./tests/todos.sh --portatil` verde, colado no relato. A suíte inteira com COSMIC é de quem coordena.

A prova na tela (o app aberto, de verdade) é de quem coordena e de quem usa: o módulo só entra na árvore dela
depois de ela ver a captura.
