# Catálogo do repositório (23/11/2026, `master` `9110e7d7`)

Levantado por quatro agentes de leitura e conferido pelo coordenador. Nada foi escrito no repositório. Os quatro
relatórios inteiros, com cada prova, e as saídas do install e do doctor estão fora do repositório, em
`~/.cache/meow-leva/catalogo-2026-11-23/`. O que está marcado «inferência» não foi medido.

## 1. O tamanho de hoje
| pasta | arquivos | KB | o que é |
| --- | --- | --- | --- |
| `packs/` | 2992 | 5208 | os dois packs: arte e dado de tema |
| `docs/` | 443 | 4792 | manual, capturas do README e sete levas de sprints |
| `tests/` | 179 | 2580 | 173 testes, o `todos.sh` e 5 arquivos de apoio |
| `scripts/` | 159 | 2268 | uma etapa por arquivo, o `pack.py` e `temas-de-apps/` |
| `assets/` | 181 | 1548 | dado do motor, com arte que sobrou |
| `app/` | 20 | 744 | o painel |
| `patches/` | 22 | 228 | as três séries |
| `systemd/` | 39 | 156 | unidades de usuário |
| `bin/` | 1 | 152 | a CLI `meow` |
| `lib/` | 9 | 100 | funções comuns |
| `packaging/` | 2 | 8 | o modelo do `.deb` |
| `src/` | 2 | 8 | o molde do oráculo, em Rust |

Texto versionado: 12 322 KB. O `.git` pesa 162 MB, com 2411 commits e 12 tags; os maiores objetos do histórico são
papéis de parede e PNG feitos à mão que já saíram da árvore (o maior, 16,2 MB).

## 2. Arte fora dos packs
| onde | quantos | o que é | destino |
| --- | --- | --- | --- |
| `docs/sprints/2026-10-26-qa-final/maquete/` | 210 | maquete de sprint, sem leitor | sai (decisão 24) |
| `assets/icones/resgatados-antes-e-depois.png` | 1 (740 KB) | saída do `resgatados_folha.sh`; nenhum leitor de produção | sai |
| `assets/extensoes/icones/` | 13 SVG | ícone de cada applet na Central; 10 com a cor do Catppuccin cravada | pack |
| `assets/prompt/starship.toml` | 1 | prompt com a paleta `catppuccin_mocha`, 26 cores | pack, com campo e leitor |
| `assets/fastfetch/` | 3 | config de exemplo, sugestão e gato em ASCII; sem leitor | sai |
| `assets/fontes/locais/` | 1 | só o LEIA-ME da pasta de fontes soltas | pack |
| `app/pagina/mesa.js` | 8 desenhos | ícones de app embutidos no código do painel | ler do pack |
| `docs/pack-minimo/` | 10 | um pack de exemplo fora de `packs/`, lido por 2 testes | a decidir |
| `docs/capturas/`, `docs/logo.svg`, `app/pagina/*.css` | 15 | do programa (README e painel) | ficam |

Nenhum som, fonte ou papel de parede está versionado fora de `packs/`. O teste que guarda a fronteira
(`tests/arvore.sh`) só olha o nome do arquivo; por isso a cor cravada passou.

O código ainda escreve arte em `assets/`: `meow icones importar` (`scripts/importar_icones.sh`) cria
`assets/icones/curadoria/`. Três caminhos de reserva apontam para o que já não existe:
`assets/icones/apps-dracula.map`, `assets/icones/overrides` e `assets/paleta/<PALETA_ARQUIVO>`.

## 3. O que é dado do motor em `assets/` (fica, em algum lugar)
`contratos/` (10), `extensoes/*.pino` (13), `apps/*.map` (3) e o original da bandeja da Steam, `assinantes`,
`pacotes/` (2), `paleta/cosmic-map.json`, `ponte/` (2), `rust/rustup.pino`, `sons/eventos.json`,
`flatpak/runtimes-gnome.tsv`, `zsh/_meow`. São 36 arquivos.

A decidir: `assets/temas/capturados/original/` (123 arquivos), a captura que serve de molde do tema v1 e de alvo do
`meow desfazer`. O `docs/PACKS.md` a registra como exceção.

## 4. Temas de apps
- O tema de terceiro (com sha) já mora em `packs/<id>/temas-de-apps/`.
- `scripts/temas-de-apps/` tem 18 apps: o código de cada um e 11 arquivos `*.modelo.*` (cerca de 1147 linhas), moldes
  sem cor que a paleta preenche. O `scripts/pack.py:1207` os procura nessa pasta quando o pack não traz arquivo.
- `scripts/temas-de-apps/btop-bat/SHA256SUMS` é cópia idêntica e sem leitor da que está no pack.
- Dois módulos leem o pack `meowsystem` por caminho fixo: `heroic/manifesto.sh:5` e `btop-bat/manifesto.sh:17`.
- `packs/meowsystem/temas-de-apps/spotify/catppuccin/theme.js` é o único código dentro de um pack, e roda dentro do
  Spotify (`inject_theme_js 1`); o `docs/PACKS.md:2103` diz que isso não existe.

## 5. Código sem chamador
| situação | arquivos |
| --- | --- |
| ninguém chama | `scripts/auditar_icones.sh` (495 linhas), `scripts/icones_orfaos.py` (123) |
| verbo vivo, efeito morto | `scripts/importar_icones.sh` (grava em pasta que não existe e espera um arquivo que o painel não gera) |
| só teste chama | `afinar_conversor.py`, `estilo_icone.py`, `creditos_dos_papeis.py`, `derivar_claro.py`, `inventario_do_sistema.py` |
| ferramenta, sem etapa | `deb.sh` (README), `palco.sh` (regra do GSD), `resgatados_folha.sh` |
| parece legado e não é | `gerar_tema_v1.py` e `migrar_conf.py`: install, doctor e painel os usam |

`patches/` e `systemd/` não têm órfão: os 15 patches têm leitor e as 39 unidades têm quem as instale.

## 6. O que prende cada pasta ao lugar
| mudança | referências | o nó |
| --- | --- | --- |
| `lib/` para dentro de `scripts/` | 422 linhas em 186 arquivos | `lib/comum.sh:4` acha a raiz subindo um nível; três validadores só aceitam a raiz com `lib/comum.sh` (`bin/meow:5`, `app/servidor.py:28`, `assets/zsh/_meow:7`) |
| `bin/meow` para outro lugar | 250 linhas em 98 arquivos (177 em teste) | o install copia para `~/.local/bin/meow` e o doctor compara byte a byte |
| `src/` para outro lugar | 1 de código, 1 de contrato, 2 de teste | nenhum |
| `assets/` com outro nome | 470 em 163 arquivos | mais 13 caminhos montados em Python |
| `systemd/` para outro lugar | 80 em 22 arquivos | o código monta `$RAIZ/systemd/$u` em 16 pontos |
| `patches/` para outro lugar | 118 em 41 arquivos | — |
| qualquer script de lugar | 38 scripts citados como `scripts/x.sh:função` em `cosmic.tsv` e `vizinhos.tsv` | o `vizinhos.sh` confere essas linhas |

Mais de 100 arquivos calculam a raiz subindo um nível a partir de si mesmos.

A pegada instalada: tudo o que guarda caminho do repositório fora dele é regravado por um `./install.sh` novo
(inferência, pela leitura do código). Até esse install, as 18 unidades que chamam `$R/scripts/…` falham caladas, e o
`meow` antigo recusa a raiz se `lib/comum.sh` mudar de lugar.

## 7. Peso de leitura
| arquivo | KB | causa |
| --- | --- | --- |
| `packs/meowsystem/temas-de-apps/obsidian/vendor/Catppuccin/theme.css` | 2252 | upstream; 18% de todo o texto versionado |
| `docs/sprints/` (seis levas antigas) | cerca de 2280 | decisão 24 manda sair; a leva de 10/11 é lida por `tests/glossario.sh:5` |
| `packs/CAMINHOS-DE-ANTES.tsv` | 473 | tabela de migração de caminhos, lida por `scripts/pack.py:534` e 3 testes |
| `packs/dracula/PROCEDENCIA.md` | 302 | tabela de procedência |
| `meow.conf.exemplo` | 125 | 134 chaves e 1936 linhas de comentário; o `migrar_conf.py` leva o comentário junto para o conf de quem usa |
| `docs/PACKS.md` | 124 | 2499 linhas, atrasado em quatro pontos |
| `docs/COSMIC-THEMING.md` | 42 | cita três caminhos que não existem |
| comentário em arquivo de dado | 4133 linhas em 16 arquivos | o `scripts/comentarios.py` não corta `.map`, `.tsv`, `.conf` nem `.exemplo` |
| notas `_*` nos dois `pack.json` | 29 | 77% do `pack.json` do Dracula |

Três mapas do pack `meowsystem` não têm linha de dado e seguem lidos: `apps.map`, `apps-hicolor.map` e `bandeja.map`.
`packs/meowsystem/icones/RETOQUES.txt` (266 linhas) não tem leitor.

## 8. A suíte
- 173 testes, todos no `todos.sh`: 134 no modo portátil e 39 só na máquina. Roda em sequência, sem paralelismo.
- Tempo registrado: `app-completo.py` 13 a 20 minutos; `convergencia.sh` 12 minutos (roda o install três vezes).
- Nenhum teste é órfão inteiro. Há cinco pedaços mortos dentro de testes vivos e nove grupos de repetidos.
- 14 testes estão parados com o alvo mudando (de 5 a 70 commits depois) e 8 só vigiam migração já concluída.
- O peso vem de Python e JavaScript embutidos nos testes, não de imagem.

O que trava apagar:
1. O pre-commit (`scripts/higiene.sh`) roda `numeros.sh`, `frases-velhas.sh` e `portabilidade.sh`.
2. O `app-completo.py` é importado por 23 outros testes.
3. O `tests/decisoes.sh` cobra as 66 decisões, crava 60 caminhos e exige 32 testes pelo nome, no formato do `todos.sh`.
4. A decisão 47 exige três testes extraindo a mesma função; hoje são exatamente três.
5. 35 testes recortam função do fonte com `sed`, e 15 carregam o `bin/meow` inteiro.

## 9. No disco, fora do git
`.trabalho-icones/` (24 MB), `docs/sprints/*/fotos/` (3,1 MB), os `__pycache__` (1,6 MB), `assets/temas-de-apps/`
(um `.pyc`). As duas capturas ignoradas em `packs/dracula/temas/capturados/` são estado em uso e ficam.
