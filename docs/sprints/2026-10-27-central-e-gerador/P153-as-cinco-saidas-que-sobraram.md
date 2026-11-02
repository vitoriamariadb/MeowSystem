# P153 — as cinco saídas que sobraram (02/11/2026)

Ela, 02/11: corrigir antes do v2.3.1 as cinco pontas anotadas no fecho de 30/10.

## O que se mediu

1. `install.sh` `_pacotes_fastfetch` imprime `sudo add-apt-repository ...` e `sudo apt-get install ...`, e roda
   `sudo` comum: sem a ponte e sem terminal, fica à espera de senha ou falha calado.
2. O rodapé de `--uma-passagem` termina mandando digitar `./install.sh`.
3. `lib/preflight.sh`, sem `apt-get`: «instale à mão, pelo gerenciador desta distribuição».
4. `scripts/prompt.sh` grava a pendência `starship-ausente` com `./scripts/prompt.sh instalar-starship`, caminho
   relativo que não existe no `.deb` (`/usr/share/meowsystem`).
5. `scripts/pack.py` `_validar_logo` manda o autor rodar `python3 scripts/pack.py logo-gerado`.

## A cura na origem

1. Verbo `fastfetch` na ponte root (sem argumento: o PPA do autor e o pacote, cravados). O install tenta a ponte,
   depois `sudo -n`, depois `sudo` com terminal; sem nenhum, pendência para o doctor. Nenhum comando impresso.
2. O rodapé diz que o doctor termina o resto, sem comando.
3. O preflight diz o que falta, sem mandar instalar.
4. A pendência guarda `meow doctor --consertar`, como as outras.
5. O validador aponta o logo gerado pelo nome do verbo do painel/CLI (`meow pack`), sem `python3 scripts/`.

## Como se prova

`tests/nada-manda-digitar.sh` ganha os cinco casos; `tests/ponte-*` confere o verbo na regra; suíte inteira verde.
