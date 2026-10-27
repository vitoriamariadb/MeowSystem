# Conferência do bloco painel: P115, P116 e P117

Branch `bloco/painel`, os 11 commits de `aa02c0f8` a `ed56086c`, contra `dev` (`58b531be`).

## O que conferi
- As provas das três `## Execução`, rodadas de novo com os falsos do `todos.sh`: `conversor.sh`, `pack.sh`,
  `pack-dracula-completo.sh`, `app-completo.py --aba criar/icones`, `app-completo.py --aba tema` e `restaurar.sh`.
- P115, o gerador:
  - o ícone do Cherry Studio, que encosta na borda, sai com um contorno externo fechado;
  - o trilho das réguas acompanha o valor (`r-detalhe` em 3 dá `--p` de 30%, e assim por diante);
  - o Refazer e o histórico que sobrevive à troca de traço passam no `app-completo.py --aba criar/icones`;
  - a cura está na origem: a margem transparente entra no `converter_icone.py`, antes do traçado.
- P116, a prévia e a biblioteca:
  - `previa_do_pack` monta o dock e a pasta só com a cadeia do próprio pack, e o Dracula não herda do `meowsystem`;
  - a biblioteca vem pintada na cor do texto;
  - a porta Tema e o Personalizar › Ícones, em Playwright headless com HOME temporário, comparados com as fotos
    da leva e a maquete.
- P117, a paridade Dracula: `icones_sistema.sh`, `icones_bandeja.sh`, `icones_tray_steam.sh`,
  `icones_tray_zapzap.sh`, `meow_icones_de_status` e os campos novos do `pack.json`.

## Achados e correções
| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | P116: o dock da prévia de um pack que não traz todos os apps encolhia. O `dockDaPrevia` só desenhava os apps feitos, e a fileira de seis virava uma de um. | os seis lugares ficam, e o app que o pack não traz sai em traço neutro | a6fba9b9 | `app-completo.py --aba tema`: o dock parcial dá 6 apps, 1 `arte-pack` e 5 `neutro`. Com o `mesa.js` antigo dá [1, 1, 0]. |
| 2 | P116: a prévia do Personalizar não usava as cores do rascunho. Ela mostrava a prévia do cartão do pack no ar, e o ramo `previa=1` do `/api/criar` não tinha quem o chamasse. | `previaDoRascunho()` pede o `/api/criar?previa=1` com id, base, flavor e cores do rascunho, com espera de 250 ms e cache por chave, e cai na prévia do cartão enquanto a resposta não chega | 5e965d88 | `app-completo.py --aba criar/icones` (`h_previa_do_rascunho`): com peach e lavender em `#fe0102`, o dock do palco traz `img.arte-pack` com a cor marcada e nenhum `svg.neutro`. Com o `paginas.js` antigo: «XX a prévia do Personalizar pinta o dock com as cores do rascunho». |
| 3 | P116: a prova dizia «todos os ícones diferem entre os packs» e não conferia a forma da pasta | o teste exige 5 de 6 diferentes (o neutro é igual de propósito), a pasta do Dracula cheia e a do MeowSystem em contorno | 536aac7a | o mesmo `app-completo.py --aba tema`, verde |
| 4 | P117: o `validar` não olhava os dois blocos novos. Um `icones.sistema.pintar` com papel que não existe ou um `icones.bandeja.mapa` que falta passavam com rc 0, e só quebravam na instalação. | `icones.sistema` e `icones.bandeja` entram na conferência de `desenhos`/`mapa`, e o `pintar` tem de ser um papel da paleta | 7228f028, e0477da5 | `pack.sh`: «o validar recusa icones.sistema torto e diz qual campo» e o mesmo para `icones.bandeja`. Com o `pack.py` antigo os dois casos falham com rc=0. |
| 5 | P117: o ramo da Steam sem `icones.bandeja` (devolver o ícone de fábrica) não tinha teste. Era pendência do implementador. | caso novo: o ícone que não é nosso fica, e o nosso, registrado no manifesto, volta ao `.meow-original`, sai do manifesto, e a segunda passada dá 3 | cf0a729a | `pack-dracula-completo.sh`, verde. Sem o `_nosso` no `_sem_glifo`, os dois casos falham. |

## O que ficou como estava, de propósito
- A pasta da prévia do MeowSystem é `folder_docs`, porque o `pastas.map` não tem uma `folder` pura. É a arte do
  próprio pack.
- A limpeza de órfãos do `icones_sistema.sh` tira todo `.svg` de status que não é do pack no ar. Já era assim antes
  do bloco.
- O desfazer do ZapZap com o app instalado continua sem teste automático. Só uma máquina com o Flatpak dele prova
  esse caso, e ele vai para a lista de conferir com a mão.

## Placar
Último `./tests/todos.sh`, em `cf0a729a`: 102 testes, 100 verdes, 0 pulados, 2 vermelhos. Nenhum é deste bloco:
- `decisoes.sh`: aceito (GPU fora da RTX e shim do compositor; é o estado da máquina).
- `restaurar.sh`: aceito para `pack_usar` e `desinstalar` (arquivos do VS Code). O `sistema_limpar` (o `.deb` do
  `cosmic-comp` em `~/.local/share/meowsystem/debs`) também fica vermelho em `dev` (`58b531be`), medido na mesma
  máquina: não é deste bloco.
