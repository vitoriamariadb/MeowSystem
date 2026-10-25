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

## 6. Achado de segurança no item 1 (quem coordena, 24/10)
- `scripts/pack.py`, `origem_dos_wallpapers`: o laço copia para a saída toda chave de `origens.wallpapers` que
  não é dict/list, inclusive uma `fotos` declarada pelo pack. Sem imagem própria no pack, um pack importado com
  `"fotos": "/caminho/qualquer"` faz o `wallpaper.sh` semear de fora do pack. Pack é dado (GSD §2).
- Cura: lista fechada de chaves na saída; `fotos` só a calculada de `dir_pack` (nunca a declarada); o
  `_conferir_papeis` do `validar` recusa `fotos` e chave desconhecida em `origens.wallpapers`; o `wallpaper.sh`
  confere que a origem de `fotos` resolve dentro da pasta do pack.
- Prova: `tests/pack-malicioso.sh` com `fotos` declarada apontando para fora: validar recusa, nada semeado.

## Execução

### Os dois branches (24/10)
- `sprint/p102` (fork público): `ef1cdc75` fotos do pack sem rede, `5138d3d9` `./install.sh --perfil <nome>`,
  `dc6cf094` README, `9080e28c` achado 6, `9839a370` a conferência de cada `perfis/*/meow.conf` (sem caminho de
  casa, tela, escala nem GPU) e o `frases-velhas` fora de `perfis/`, e este registro. Nenhum commit traz
  foto, fonte, perfil ou a liberação deles no `.gitignore` (`git log -p sprint/p102 ^dev --stat`).
- `sprint/p102-privado` = `sprint/p102` + quatro commits por cima, só com arquivo privado e o mínimo de regra e
  teste: as 29 fotos (17 do Dracula, 12 do meowsystem) com a liberação no `.gitignore`, as linhas no
  `docs/CREDITOS.md` e 8 linhas a menos no `BANIDOS.txt.padrao` (fotos que estão girando hoje); o perfil
  `andre` (o `meow.conf` desta casa com `ICONES_LOGO_HEFESTO` vazio, sem credencial, e o mapa dos ícones
  escolhidos); as fontes de quem usa em `assets/fontes/locais/` com o `tests/git-limpo.sh` invertido; o README
  com o clone do privado e `./install.sh --perfil andre`.
- Cada foto e cada fonte versionada é byte a byte o arquivo de origem. Maior arquivo: 17 MB.

### Conferência (agente 2)
- Correções: a conferência genérica dos perfis e a exclusão no `frases-velhas` desceram para o público
  (estavam num commit privado); três fontes `osc_*.ttf`, cópias byte a byte das Open Sans Condensed com outro
  nome, saíram do commit privado (44 faces, não 47).
- Suíte (`tests/todos.sh`), duas vezes em cada branch: `== todos os 79 · 78 verde(s), 1 pulado(s),
  0 vermelho(s) ==`. O pulado é o `pack.sh`: a contagem da biblioteca contra o `Dracula_OS-Theme`, que não
  existe mais nesta máquina. Já saía pulado no `3680c8f4`.
- `git ls-files | xargs du`: nada acima de 50 MB, e nenhum blob acima de 50 MB no histórico do privado.

### PC virgem, num container `ubuntu:24.04` descartável
Clone limpo do `sprint/p102-privado`, usuário com senha, `./install.sh --perfil andre`. As chamadas de `curl`,
`wget` e `git` foram registradas por um invólucro, e `wallhaven.cc`, `wallpapercave.com` e `api.github.com`
(só a semeadura da rede o usa) apontavam para `127.0.0.1`.
- A senha foi pedida 1 vez. Todo sudo depois dela passou pela ponte.
- `PACK="dracula"`, `FLAVOR="dracula"`, o mapa dos ícones igual ao do perfil. O install trocou só o
  `FASTFETCH_LOGO_GATO` (de `coquinha` para `morcego-noite`), porque o perfil trazia o mascote do outro pack.
- As 17 fotos do Dracula estão em `ativos/` e são a rotação: tudo ali é do pack, então não há `ativos-pack/`.
  O log diz «17 foto(s) do pack copiadas». Nenhuma chamada de rede foi para foto, e as 17 são iguais às do clone.
- `fc-list` mostra Arial, Arial Narrow, Zrnic, Selawik, Open Sans Condensed, Liberation Sans Narrow, Fira Code,
  FiraCode Nerd Font e JetBrains Mono, as 44 faces em `~/.local/share/fonts/MeowSystem/locais`, e a JetBrainsMono
  Nerd Font Mono baixada da release.
- Ocultos: «47 na lista de meow.conf, 46 não instalados». O único instalado no container ficou oculto.
- `meow pack usar meowsystem`: «12 foto(s) do pack copiadas», também sem rede. Ficaram 29 em `ativos/`, e a
  rotação do meowsystem (`ativos-pack/`) tem 21, porque as 8 `tulip-*` são do Dracula e ficam fora dela.
- O install convergiu em 3 passadas. O que falha no container é só o `cursor`, porque o gsettings não tem o
  schema `org.gnome.desktop.interface` sem sessão gráfica. Pulam por falta de sessão: `forma`, `relogio`,
  `escala`, `terminal`, `assets`, `autostart`, `autoreparo` e as vigias, que precisam de systemd --user ou do
  COSMIC.

### O que ficou
- Item 4: o pack local `projetos-pessoais` continua na máquina, porque esta conferência não escreve no HOME
  real. Nada o lê: não é o `PACK`, nenhum pack herda dele e o repositório não o cita. Basta apagar a pasta à mão.
- Sem rede, o `scripts/instalar_fontes.sh` para no download da Nerd Font antes de instalar as fontes locais.
  Num PC virgem há rede, então não pega; fica anotado para o próximo bloco.
- O `BANIDOS.txt` do estado desta máquina ainda lista as 8 fotos devolvidas. Isso é do estado de quem usa, não
  do repositório.
