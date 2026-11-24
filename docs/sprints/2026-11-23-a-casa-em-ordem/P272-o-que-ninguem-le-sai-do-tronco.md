# P272 — o que ninguém lê sai do tronco (23/11/2026)

## O que se mediu (catálogo de 23/11)
| o quê | prova de que não tem leitor |
| --- | --- |
| `assets/icones/resgatados-antes-e-depois.png` (740 KB) | é a saída de `scripts/resgatados_folha.sh:11`; só 3 testes a citam |
| `scripts/resgatados_folha.sh` e o verbo `icones resgatados folha` (`bin/meow:2143`) | fora da ajuda; só gera a folha acima |
| `assets/fastfetch/` (3 arquivos) | o `fastfetch_logo.sh` lê só o `config.jsonc` de quem usa; o bloco vivo é gerado |
| `assets/apps/tray-terceiros/zapzap-tray_icon.py.original` | só citado em mensagem (`icones_tray_zapzap.sh:189,218`) |
| `scripts/auditar_icones.sh`, `scripts/icones_orfaos.py` | nenhum chamador; isentos à mão em `tests/orfaos.sh:10` |
| `scripts/importar_icones.sh` e o verbo `icones importar` (`bin/meow:2114`) | grava em `assets/icones/curadoria/`, que não existe, e lê um arquivo que o painel não gera; `app/servidor.py:8201` e `icones_apps_arcticons.sh:46` leem o mapa que ele criaria |
| caminhos de reserva mortos | `assets/icones/apps-dracula.map` (`app/servidor.py:6348,6351`; `icones_apps_dracula.sh:18`), `assets/icones/overrides` (`install.sh:578`; `bin/meow:933,1420`), `PALETA_ARQUIVO` (`lib/comum.sh:200`; `pack.py:441`), o ramo `assets/` de `lib/comum.sh:764` |
| `scripts/temas-de-apps/btop-bat/SHA256SUMS` | cópia idêntica da do pack; o manifesto regrava a do pack (`:528`) |
| `packs/meowsystem/icones/RETOQUES.txt` (266 linhas) | nenhum leitor; descreve uma pasta que já saiu |
| `.gitignore` e `.gitattributes` | linhas para pastas que não existem (`/src/applets/`, `/assets/papeis-de-parede/`, `assets/temas/*.ron`, oito de `wallpapers/`) e duas regras de caminho antigo |

## A causa
A leva de 23/10 (três pastas por pack) moveu a arte e deixou para trás os caminhos de reserva, as ferramentas de uso
único e as folhas geradas.

## A cura na origem
Só exclusão, um commit por linha da tabela, com o leitor morto tirado no mesmo commit. O `tests/orfaos.sh` perde as
isenções dos scripts que saem. Nada muda de lugar nesta tarefa.

Fora daqui, de propósito: os scripts que só teste chama (`afinar_conversor.py`, `estilo_icone.py`,
`creditos_dos_papeis.py`, `derivar_claro.py`, `inventario_do_sistema.py`) saem junto com o teste deles, na P280 em
diante. `gerar_tema_v1.py` e `migrar_conf.py` ficam: o install, o doctor e o painel os usam.

## Como se prova
- `tests/orfaos.sh`, `tests/arvore.sh`, `tests/frases-velhas.sh`, `tests/fonte-unica.sh` e
  `tests/acervo-da-ficha.sh` verdes, com as linhas que citavam a folha acertadas.
- `./install.sh --dry-run` e `meow doctor` com a mesma saída de antes, tirando as linhas dos itens apagados.
- `git grep` de cada caminho apagado sem resultado fora de `docs/sprints/`.

## Feito (23/11, bloco `barato-de-ler`)
- As nove linhas da tabela saíram, um commit por linha. Quem conferiu tirou ainda os dois leitores do
  `curadoria.map` (o painel e o `icones_apps_arcticons.sh`), que nada mais cria: procurado no nitro-5 e no desktop,
  o mapa não existe em lugar nenhum.
- A regra `byte-exact` dos `.qbtheme` não casava nenhum arquivo desde 23/10; voltou com o caminho de hoje.
- `./install.sh --dry-run` na árvore de integração contra uma árvore sem o bloco, as duas fora do checkout: a única
  linha diferente é a do `~/.local/bin/meow`, que mudaria (a CLI perdeu dois verbos).
- O `.ignore` da raiz fica fora do `.deb`; a variável `ICONES` do `icones_apps_dracula.sh` saiu.
- Fica para a P278: `apps-resgatados.map:37` e `apps.map:12` do Dracula ainda citam `assets/icones/`.
