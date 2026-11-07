# P182 — a suíte portátil verde no GitHub (07/11/2026)

O job `testes` nunca tinha terminado: era cancelado aos 15 minutos. Com 45 minutos, ele termina e fica vermelho, nos mesmos 12 testes em f59d3c14 e em d4538c91, enquanto a suíte local dá 146 de 146.

## O que se mediu

`git-limpo`, `convergencia` (sem `convert`), `chaves-aposentadas`, `doctor-veredito`, `gerador-dracula` (`converter_icone.py` falha; `KeyError: 'svg'`), `trava-herdada`, `garantir-builds`, `contrato-cosmic` (`CosmicComp/v2/pinned_workspaces` não existe), `achados-tecnicos`, `tres-pastas`, `maquina-nova`, `deb`. Log com `gh run view <id> --log-failed`, último run do workflow `testes`.

## A causa

Medida teste a teste na Execução. A separação: dependência que falta no runner, teste que depende desta máquina e deveria ser hermético, teste que só vale em máquina COSMIC e está na lista errada, e defeito real de portabilidade. O runner tem `sudo` sem senha de verdade: o falso precisa valer ali.

## A cura

Dependências em `.github/workflows/testes.yml`; teste hermético; lista portátil de `tests/todos.sh` com o que cabe nela. Sem afrouxar asserção e sem pular para ficar verde.

## Como se prova

Run do workflow `testes` verde no `master`.

## Execução

### Como se mediu

- O runner é Ubuntu 26.04 (`ubuntu-26.04`, 20261101.186), o que o log do run 42351540332 mostra no «Set up job». Ali o `coreutils` é o uutils de um binário só, o `sudo` é real e sem senha, o Python é o 3.14 e o ImageMagick é o 7.
- Sem docker, a reprodução foi o `ubuntu-base-26.04.1` num chroot de user namespace, com os pacotes da lista da imagem e o usuário `runner` com `NOPASSWD`. Clone raso, sem as curas: os 12 vermelhos voltaram, com as mesmas mensagens do log.
- Três diferenças do chroot deram vermelho falso, e nenhuma é do repositório: faltava `/run/user/1001/systemd`, faltava `node` e o `rustc` era um falso. Corrigido o chroot, os testes passaram.

### A causa de cada teste

| teste | classe | causa medida | cura |
| --- | --- | --- | --- |
| `git-limpo` | dependência | o `construir_convertidos.sh` pula sem `rsvg-convert` e `convert` | `imagemagick` e `librsvg2-bin` no workflow |
| `convergencia` | dependência | o teste fabrica a capa com `convert` | o mesmo |
| `gerador-dracula` | dependência | o `converter_icone.py` rasteriza com `rsvg-convert` e `convert`; o `KeyError: 'svg'` é consequência | o mesmo |
| `tres-pastas` | dependência | o conferir dos convertidos pula sem as mesmas ferramentas | o mesmo |
| `chaves-aposentadas` | dependência | o checkout raso não tem o commit `18c1d88^` | `fetch-depth: 0` |
| `deb` | dependência | o checkout raso não tem tag, e o `deb.sh` tira dela a versão | `fetch-depth: 0`; `strace` para o teste medir a escrita do install, em vez de pular |
| `trava-herdada` | hermético | `cp sleep` copia o multichamada do uutils; como `spotify`, ele sai com `unknown program` e solta o cadeado | `dormente`: script bash que dorme sem filho, com o nome certo em `/proc/<pid>/comm` |
| `contrato-cosmic` | hermético | `janelas.sh`, `relogio.sh` e `areas.sh` só seguem com o binário em `/usr/bin` ou a pasta v2; o `terminal.sh` pede `cosmic-term` | o teste cria as pastas v2 e um `cosmic-term` falso |
| `garantir-builds` | hermético | o doctor olhava `/usr/bin/cosmic-comp` de verdade | `CP_BIN` aponta para a fábrica falsa em toda a seção |
| `maquina-nova` | hermético | o pré-voo só passava com o `cosmic-comp` vivo nesta máquina; e o `btop`, o `bat`, o Papirus e o `fastfetch` que faltam fazem o `pacotes` mudar em toda passada, e a árvore sem `.git` não converge | `MEOW_IGNORA_DESKTOP=1`, falsos em `$T/sistema` e `MEOW_ICONES_SISTEMA` |
| `doctor-veredito` | hermético | sem a Fira Sans, o `instalar_fontes.sh` pede `pop-fonts` depois do `curl`, e o `recebido` guarda só o último pedido | `fc-list`, `fc-cache` e `fc-match` falsos; a asserção `= curl` ficou igual |
| `achados-tecnicos` | portabilidade | o Python do runner tem `gi` e não tem Gtk 4 (o chroot deu o mesmo `rc=0` ao ganhar `python3-gi`); o `icones_absolutos.sh` tomava isso por «o ícone não resolve», saía 0 e não deixava a pendência | a sonda do `PY_SISTEMA` pede o Gtk 4; sem ele, vale o caminho de quem não tem `gi` |

Nenhum teste foi para a lista de máquina, nenhuma asserção mudou e nenhum `FALHOU` virou pulado. Código de produto: uma linha em `scripts/icones_absolutos.sh` e uma em `install.sh`, que só lê `MEOW_ICONES_SISTEMA`. Nas máquinas com Gtk 4 e sem essa variável, nada muda.

O `timeout-minutes` foi a 60. Os 12 caíam cedo e o run levou 33 minutos; `convergencia` e `deb` agora rodam inteiros, cerca de 6 minutos a mais, perto dos 45 de antes.

### Provas

- Os 12 no chroot 26.04: vermelhos sem as curas, verdes com elas.
- `tests/todos.sh --portatil` inteiro no chroot, em bd022817: 112 verdes, 3 pulados, 2 vermelhos. Os 2 (`janela-sem-app-id`, `nomes-nas-duas-telas`) vinham do `rustc` falso do chroot; com o `rustc` 1.99.1 de verdade, passaram sozinhos.
- O `sudo` real do chroot, com registro, não recebeu nenhuma chamada na suíte inteira: os falsos valem com `sudo` sem senha.
- Os seis testes que mudaram de falsos (`trava-herdada`, `contrato-cosmic`, `maquina-nova`, `doctor-veredito`, `garantir-builds`, `achados-tecnicos`) passaram nesta máquina, com HOME temporário.

### O que falta

- A prova da sprint: o run do workflow `testes` verde no `master`, depois do push. O chroot aproxima o runner, não é o runner.
- Seguem pulados no CI: `pack.sh` (sem `bat` e sem `btop`), `estilo.sh` (o acervo Arcticons não vem no clone) e `extensoes-install.sh` (sem a árvore clonada dos applets). Com as dependências novas, `app.sh` e `pack-dracula-completo.sh` saíram dos pulados.
