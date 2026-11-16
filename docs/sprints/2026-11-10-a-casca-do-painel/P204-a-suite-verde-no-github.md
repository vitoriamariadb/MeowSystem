# P204 — a suíte verde no GitHub

## O que se mediu

O `testes` do GitHub está vermelho no master desde 11/11. O run 43117793662 falhou em `chaves-aposentadas`,
`doctor-veredito`, `trava-herdada`, `garantir-builds` e `maquina-nova`; o 43125694085 foi cancelado aos 45 min.

Em 07/11 a branch `bloco/ci` já tinha medido os 12 vermelhos do runner (`ubuntu-26.04`, coreutils uutils de um binário só,
`sudo` real sem senha, Python 3.14, ImageMagick 7): `git-limpo`, `convergencia`, `chaves-aposentadas`, `doctor-veredito`,
`gerador-dracula`, `trava-herdada`, `garantir-builds`, `contrato-cosmic`, `achados-tecnicos`, `tres-pastas`,
`maquina-nova` e `deb`. Log com `gh run view <id> --log-failed`, último run do workflow `testes`.

## A causa

A `bloco/ci` (12 commits, 07/11) curava isso e nunca chegou ao master. A base dela estava 103 commits atrás, e a sprint
dela colidia em número com a P182 do master (os builds que caíam calados). Os vermelhos se separam em dependência que
falta no runner, teste que depende desta máquina e deveria ser hermético, teste que só vale em máquina COSMIC e defeito
real de portabilidade.

| teste | classe | causa medida | cura |
| --- | --- | --- | --- |
| `git-limpo`, `convergencia`, `gerador-dracula`, `tres-pastas` | dependência | o `construir_convertidos.sh` e o `converter_icone.py` pulam ou falham sem `rsvg-convert` e `convert` | `imagemagick` e `librsvg2-bin` no workflow |
| `chaves-aposentadas` | dependência | o checkout raso não tem o commit `18c1d88^` | `fetch-depth: 0` |
| `deb` | dependência | o checkout raso não tem tag, e o `deb.sh` tira dela a versão | `fetch-depth: 0`; `strace` para o teste medir a escrita do install |
| `trava-herdada` | hermético | `cp sleep` copia o multichamada do uutils, que sai com `unknown program` e solta o cadeado | `dormente`: script bash que dorme sem filho, com o nome certo em `/proc/<pid>/comm` |
| `contrato-cosmic` | hermético | as pastas v2 e o `cosmic-term` só existiam com o COSMIC instalado | o master já cura, a versão dele fica |
| `garantir-builds` | hermético | o doctor olhava `/usr/bin/cosmic-comp` de verdade | `CP_BIN` aponta para a fábrica falsa em toda a seção, e a seção 3b do master fica |
| `maquina-nova` | hermético | o pré-voo só passava com o `cosmic-comp` vivo; `btop`, `bat`, `fastfetch` e o Papirus faltantes fazem o `pacotes` mudar em toda passada, e a árvore sem `.git` não converge | `MEOW_IGNORA_DESKTOP=1`, falsos em `$T/sistema` e `MEOW_ICONES_SISTEMA` |
| `doctor-veredito` | hermético | sem a Fira Sans, o `instalar_fontes.sh` pede `pop-fonts` depois do `curl`, e o `recebido` guarda só o último pedido | `fc-list`, `fc-cache` e `fc-match` falsos; a asserção `= curl` ficou igual |
| `achados-tecnicos` | portabilidade | o Python do runner tem `gi` e não tem Gtk 4 | o master já cura em `scripts/icones_absolutos.sh`, a versão dele fica |

Nenhum teste foi para a lista de máquina, nenhuma asserção mudou e nenhum `FALHOU` virou pulado. Código de produto: uma
linha em `install.sh`, que só lê `MEOW_ICONES_SISTEMA`; sem essa variável nada muda.

## A cura na origem

Reaplicada em `bloco/ci2` (worktree `.meow-wt-ci2`, a partir do master), commit a commit, do que faltava de `bloco/ci`:

- `.github/workflows/testes.yml`: `fetch-depth: 0`, `timeout-minutes: 60` (a convergência e o `deb` agora rodam inteiros) e
  os pacotes da branch (`imagemagick`, `librsvg2-bin`, `strace`) somados aos do master;
- `tests/trava-herdada.sh` (dorminhoco próprio), `tests/maquina-nova.sh` (os dois commits), `tests/doctor-veredito.sh`
  (fontconfig falso) e `tests/garantir-builds.sh` (binário de fábrica falso), respeitando a seção 3b do master;
- `install.sh`: a base de ícones do sistema aceita outra raiz (`MEOW_ICONES_SISTEMA`), sobre o `sistema.tsv` do master;
- `scripts/icones_absolutos.sh` e `tests/contrato-cosmic.sh` ficam com a versão do master, que já cobre;
- `tests/acervo-da-ficha.sh`: vermelho do próprio master desde a P203, que passou a oferecer a pasta `sistema/` na ficha de
  propósito; as duas asserções agora esperam `sistema/` em vez de proibi-la;
- o «abre P182» e o arquivo da sprint antiga não voltam: o conteúdo útil está aqui.

## Como se prova

- os seis testes tocados, um a um, e `./tests/todos.sh --portatil` verdes na worktree;
- a suíte inteira verde no conferente;
- depois do push, o run `testes` do master verde no GitHub. O chroot de 07/11 aproximou o runner, mas não é o runner.

## O que segue pulado no CI

`pack.sh` (sem `bat` e sem `btop`), `estilo.sh` (o acervo Arcticons não vem no clone) e `extensoes-install.sh` (sem a
árvore clonada dos applets).
