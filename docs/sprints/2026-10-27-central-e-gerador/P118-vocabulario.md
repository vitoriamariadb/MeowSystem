# P118: palavras do dia a dia no painel e no que ele mostra

Itens 4 e 6 do `ANDAMENTO.md`. A lista completa (termo → troca → arquivo:linha) está em
`relatorios/levantamento-painel.md` §5. Trocas decididas: «Mandar» → «Disponibilizar», «Vestir
agora» → «Aplicar tema».

## O que se mediu
- `git grep` das formas de *vestir* (vestir, veste, vestem, vestido/a/s, vestindo, vestiria, revestido) e de «Mandar», sem contar *vestígio*:
  - 110 linhas que chegam à tela em `app/`, `scripts/`, `bin/` e `lib/`, mais 2 no `install.sh` (`:952` «Flatpak veste o tema» e `:2044`, a mensagem do greeter);
  - 30 arquivos.
- No painel, os rótulos visíveis são:
  - `app/pagina/lugares.js:15,66,69,235`;
  - `app/pagina/paginas.js:107,639,641`;
  - `app/servidor.py:747,749,753,3395,3403,7299`.
- Telas com o termo velho, capturadas nesta leva:
  - `capturas/painel/biblioteca-1920.png`: a aba «5 Mandar»;
  - fotos 1 e 3: «Vestir», «Vestir agora».
- O que sai dos scripts aparece no diálogo de resultado do painel: 54 chamadas `meow_ok`, `meow_muda`, `meow_pula`, `meow_aviso`, `meow_erro`, `meow_info` e `meow_app_sem`, mais 7 `printf`/`print`, com «vestido de», «nada a vestir», «vestem».
- Testes que conferem esses textos:
  - `tests/pastas-do-pack.sh:119` («pasta(s) especiais já vestidas com os desenhos»);
  - `tests/temas-de-apps.sh:1287` («o pack no ar (…) veste o '…'»);
  - `tests/instalacao.sh:211` («a tela de login veste o tema do COSMIC», que vem de `install.sh:2044`);
  - `tests/p113-navegador.py:116-119` («Mandar», «Vestir agora»).
- `docs/readme.toml:15` gera o «Vestir troca o pack.» do `README.md:49`.

## Causa
O verbo da casa (*vestir* o sistema) virou rótulo de botão e mensagem de resultado. Não há guarda
que barre a palavra no que a tela mostra.

## Cura na origem
1. Trocas no painel:

   | lugar | hoje | depois |
   |---|---|---|
   | cartão do Tema | «Vestir» | «Aplicar tema» |
   | Personalizar, botão | «Vestir agora» | «Aplicar tema» |
   | Personalizar, passo | «Mandar» | «Disponibilizar» |
   | `apps_aplicar` em Definir → Programas | «Vestir agora» / «Vestir» | «Aplicar agora» / «Aplicar» |
   | rótulo de `apps_aplicar` | «Vestir os programas» | «Aplicar nos programas» |
   | rótulo de `apps` | «Programas vestidos» | «Programas com o tema» |
   | dica | «Um .meowpack para mandar» | «Um .meowpack para outra máquina» |
   | frases do `ICONES_DRACULA` | «vestindo o lançador» | «no lançador» |
   | frases do `ICONES_DRACULA` | «não tem o que vestir» | «não tem o que aplicar» |
   | `servidor.py:7299` | «%s veste %s» | «%s usa %s» |

2. Trocas nas mensagens dos scripts, por forma:

   | hoje | depois |
   |---|---|
   | «nada a vestir» | «nada a aplicar» |
   | «já vestidos de X» | «já com o X» |
   | «vestido de X» | «com o tema X» |
   | «vestem» / «veste» | «usam» / «usa» |
   | «vestiria» / «vestida» | «aplicaria» / «aplicada» |
   | «revestido de» | «refeito com» |
   | «isto veste o COSMIC» | «isto arruma o COSMIC» |
   | «para mandar a alguém» (`bin/meow:3173`) | «para passar a alguém» |

3. `tests/frases-velhas.sh` ganha uma classe nova: as formas de *vestir* e o rótulo «Mandar».
   - Ela vale só no que a tela mostra: strings de `app/pagina/*.js`, os `rotulo`/`ajuda`/`frase` de `app/servidor.py` e as chamadas `meow_ok`/`meow_muda`/`meow_pula`/`meow_aviso`/`meow_erro`/`meow_info`/`meow_app_sem`.
   - *vestígio* fica de fora.
4. Os quatro testes acima passam a conferir o texto novo.
5. Trocar «Vestir» em `docs/readme.toml:15`. O `README.md` sai do `readme.py`, e as capturas do README são refeitas pelo gancho de sempre.

## Prova
- `tests/frases-velhas.sh` verde com a classe nova, e vermelho num commit de ensaio que devolva «Vestir agora» a `paginas.js`.
- `tests/app-completo.py --aba tema` e `--aba criar/mandar` (a rota fica com o nome velho): os botões mostram «Aplicar tema», e a aba mostra «Disponibilizar».
- `tests/pastas-do-pack.sh`, `tests/temas-de-apps.sh`, `tests/instalacao.sh` e `tests/p113-navegador.py` verdes com o texto novo.

## Arquivos
- Painel e docs: `app/pagina/lugares.js`, `app/pagina/paginas.js`, `app/servidor.py`, `app/LEIA-ME.md`, `docs/readme.toml`.
- Scripts (os da §5 do relatório): `install.sh`, `scripts/*.sh`, `scripts/temas-de-apps/*/manifesto.sh`, `scripts/pack.py`, `bin/meow`, `lib/preflight.sh`.
- Testes: `tests/frases-velhas.sh` e os quatro testes citados.

## Item do coordenador (27/10)
- `docs/PACKS.md` descreve os campos novos da P117, `icones.sistema` e `icones.bandeja` (herda, pintar, desenhos, mapa), e a linha do doctor «sistema: … já vestidos de Arcticons» diz o pack no ar.

## Fora desta sprint
- Fica como está:
  - identificadores internos: `vestir()`, `_quem_veste`, `_o_que_veste`, `meow_flavor_vestido`, `_vestido`, o `filtro_git.py vestir` (protocolo do filtro git do Obsidian);
  - os valores de `data-controle` (`pack:<id>:vestir`, `criar:vestir`);
  - a rota `#criar/mandar`;
  - as frases de `ok`/`falha` dos testes, que não chegam à tela.
- Os manuais (`docs/PACKS.md:1315,1358,2407` e `docs/ESTADO-FINAL.md:77`) citam o rótulo «Vestir» e entram só se o `tests/decisoes.sh` cobrar.

## Execução
- **Painel** (`2f11fdf5`, `8e15cb80`). «Vestir» do cartão do Tema e «Vestir agora» do Personalizar viram «Aplicar tema»; o passo «Mandar» vira «Disponibilizar»; `apps_aplicar` diz «Aplicar nos programas», `apps` diz «Programas com o tema», e as frases do `ICONES_DRACULA` e do `servidor.py` perdem *vestir*. Os `data-controle` (`pack:<id>:vestir`, `criar:vestir`) e a rota `#criar/mandar` ficam. `--aba tema` e `--aba criar/mandar` verdes, com os rótulos novos (a primeira falhou uma vez só pelo teto de 240 s com a máquina em carga 29, e passou sozinha, 244 s).
- **Scripts, instalador e CLI** (`9933afd4`). 54 chamadas `meow_*` e os `printf` trocam «vestido de», «nada a vestir», «veste», «vestem» pelas formas da tabela; `install.sh:952` e `:2044`, `bin/meow` e `lib/preflight.sh` entram. Os quatro testes da sprint conferem o texto novo: `pastas-do-pack.sh`, `temas-de-apps.sh`, `instalacao.sh` e `p113-navegador.py`, todos verdes. A coluna «não aplica» da tabela do `meow apps` cabe nos 10 caracteres de `pad`.
- **Guarda** (`b4f7e7d3`). Classe 8 do `tests/frases-velhas.sh`: as formas de *vestir* (sem *vestígio*) e «Mandar» só no que a tela mostra, ou seja, strings de `app/pagina/*.js`, `rotulo`/`ajuda`/`frase` do `servidor.py` e chamadas `meow_*`. Verde; com `botao("Vestir agora", {})` plantado em `paginas.js` o teste sai 1, e sai 0 sem a planta.
- **Docs** (`309ee614`, `eb5340c8`). `docs/readme.toml` (o `readme.py texto` regerou os dois README e o `--conferir` fecha), `app/LEIA-ME.md`, `docs/ESTADO-FINAL.md` e `docs/PACKS.md` (:1315, :1358, :2407) trocam o rótulo. Item do coordenador: o `PACKS.md` descreve `icones.sistema` e `icones.bandeja` (desenhos, mapa, herda, pintar), e a linha do doctor passou a dizer «já com o Arcticons do pack X» (`scripts/icones_sistema.sh`).
- **Não feito:** refazer as capturas do README (`tema.png`): o gancho de sempre as refaz no commit da leva, e a imagem do README ainda mostra «Vestir» até lá.
