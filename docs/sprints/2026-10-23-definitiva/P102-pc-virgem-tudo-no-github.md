# P102 — PC virgem: tudo no GitHub

**Status: REGISTRADA em 24/10; roda depois da P101 (as duas mexem no `install.sh`).**

Quem usa (24/10): «Mandemos tudo. Incluindo fotos, sons, ícones e tudo mais. Preciso GitHub. Tudo de verdade
pra eu pegar um PC virgem e usar tudo lá.» Respostas no mesmo dia:
- as fotos de terceiros (wallhaven) **entram no repositório**;
- o `meow.conf` dela/dele **vira um perfil no repositório**, que o install usa;
- as fontes proprietárias (Arial local, Zrnic) **entram no repositório**.

Quem usa, logo depois: «Se tiver questão legal, deixa tudo privado na minha main. Só eu vou usar mesmo.»
O GitHub não deixa um fork de repositório público virar privado, e a PR #2 da Vitória sai do `master` do fork.
Então:
- **`AndreBFarias/MeowSystem-privado`** (repositório novo, PRIVADO, não é fork): o `master` dele tem tudo, fotos,
  fontes e perfil. É o que o PC virgem clona.
- O fork público e a PR recebem só o `dev` limpo: nenhum commit desta P102 que traga foto de terceiros, fonte
  proprietária ou perfil vai para lá.
- Na máquina, dois branches: `dev` (público) e `master` = `dev` + os commits privados desta P102, por cima.
  Daqui em diante: trabalho no `dev`, e o `master` recebe o `dev` por merge.
- O código que sabe ler fotos do pack, perfil e fontes locais é genérico e pode ir no `dev`; os ARQUIVOS (as
  fotos, as fontes, `perfis/andre/`) e a liberação no `.gitignore` vão só no `master`.

## O que se mediu (24/10)
- Ícones, sons, mascotes, temas capturados e as 13 artes SVG do Dracula já estão no git.
- **Fotos do Dracula**: 17 em `~/.local/share/backgrounds/meowsystem/ativos-pack/` (9,3 MB), do repositório
  `tulip-orchid-wallpapers` (MIT, de quem usa) no commit `98770f8a`. O endereço só existe no `meow.conf` da
  máquina (`WALLPAPER_DRACULA_REPO`; o `meow.conf.exemplo` deixa vazio): PC virgem fica sem nenhuma foto.
- **Fotos do meowsystem**: receita em `packs/meowsystem/wallpapers/FONTES.tsv` (46 linhas, wallhaven); as
  imagens em `ativos/` (29 arquivos, 42 MB). `.gitignore` barra `*.png/*.jpg/*.jpeg/*.webp` e as pastas
  `ativos*`, `banidos`, `favoritos`, `originais`, `baixados`. `banidos/` (62, 172 MB) NÃO entra: foi tirado por
  quem usa.
- **Escolhas**: `~/.config/meow/meow.conf` (≈1.800 linhas: `PACK="dracula"`, `FLAVOR="dracula"`, mascote, os 43 do
  `LANCADOR_OCULTAR`, ...), `~/.config/meow/icones-escolhidos.map`. O `bin/meow` já tem `importar` e o painel
  exporta o `meow.conf` (`exportar_conf` em `app/servidor.py`).
- **Fontes** em `~/.local/share/fonts` (53 MB): `arial-local`, `arial-narrow-local`, `Zrnic`, `selawik`,
  `OpenSansCondensed`, `LiberationNarrow`, `Roboto-*`, `FiraCode*`, `JetBrainsMono`, `MeowSystem`, `icons.ttf`,
  `CustomTkinter_shapes_font.otf`, `hefesto-dualsense4unix`. `assets/fontes/locais/*.{otf,ttf,ttc}` está no
  `.gitignore`. Uma pasta que outro programa instala (ex.: `hefesto-dualsense4unix`, do Hefesto) é dele, não entra.
- Um pack local `~/.local/share/meowsystem/packs/projetos-pessoais` (3 ícones) duplica o que a P96 já pôs no
  Dracula (`elden-ring-tracker`, `com.beholder.app`, `protocolo-ouroboros`).

## A cura
1. **Fotos no pack**: cada pack guarda as fotos dele em `packs/<pack>/wallpapers/` (pasta e nomes que o
   `wallpaper.sh` já entende, sem subpasta nova se der). O `.gitignore` deixa de barrar essas fotos (só elas;
   `banidos/` e o estado do usuário continuam fora). O install num PC virgem põe a coleção do pack no ar **sem
   rede**; a receita `FONTES.tsv` e o `WALLPAPER_*_REPO` continuam como procedência, não como fonte.
   Sem arquivo acima de 50 MB (o GitHub recusa acima de 100 MB).
2. **Perfil**: `perfis/<nome>/meow.conf` (+ o `icones-escolhidos.map`) com as escolhas de quem usa, sem nada que
   seja da máquina (caminho `/home/...`, nome de tela como `eDP-1`, escala, GPU). `./install.sh --perfil <nome>`
   copia o perfil para `~/.config/meow/` antes da fila (guardando o de antes) e segue. Num PC que já tem
   `meow.conf`, só com a flag. Nome do perfil: `andre`.
3. **Fontes**: as fontes de quem usa entram em `assets/fontes/locais/` (tirar a regra do `.gitignore`), e a etapa
   de fontes do install as instala. Uma linha de procedência por família no `docs/CREDITOS.md`.
4. O pack local `projetos-pessoais` sai da máquina (o Dracula já tem os três), se nada mais o lê.
5. README: a seção de instalar num PC virgem diz `git clone` + `./install.sh --perfil andre`, nada mais.

## Cuidados
- O gancho de commit troca palavras e o sanitizer de identidade redige o `user.name` do git no que entra em
  commit (`packs/dracula/pack.json`, `_nota_autor`): confira o diff de cada commit; binário não pode passar pelo
  gancho.
- Teste e QA só com HOME temporário.

## Como se prova
- Clone limpo do fork num container `ubuntu:24.04` (ou Pop!_OS 24.04 se houver imagem), **sem rede depois do
  clone para as fotos**: `./install.sh --perfil andre` → `PACK=dracula`, as 17 fotos do Dracula na rotação, as
  fontes em `fc-list`, os ocultos do perfil aplicados; `meow pack usar meowsystem` → as 29 fotos do meowsystem.
- `git ls-files | xargs du` sem arquivo acima de 50 MB; `tests/todos.sh` verde.
