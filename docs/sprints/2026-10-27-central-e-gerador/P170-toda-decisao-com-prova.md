# P170 — toda decisão com prova (06/11/2026)

O GSD promete prova em `tests/decisoes.sh`; 27 das 53 decisões não têm linha lá: 19, 20, 21, 23 a 36, 38 a 45, 50 e 53.

## A cura

Para cada uma, achar o teste que já a cobre e citá-lo em `tests/decisoes.sh`; sem teste, escrever a prova mais curta contra o código.
Decisão só de texto, sem nada no código que a leia, fica dita como tal no registro, sem falsa prova.

## Como se prova

`tests/decisoes.sh` verde, e um script conta 0 decisão sem linha.

## Execução

Commit `81ad5637`. O levantamento da sprint estava velho: 31 das 53 já tinham linha com o número. Sem linha de verdade eram 22: 2, 4, 7, 8, 9, 12, 27, 28, 31 a 35, 38 a 42, 44, 45, 50 e 53.

- Convenção: toda prova leva o número da decisão na frente (`ok "N: …"`), ou chama `cobre N arquivo 'trecho' [código 'trecho']` ou `so_texto N`. Nas 2, 4, 7, 8, 9 e 12 a prova já existia sem o número; só ganhou o prefixo (nas 1, 3, 5 e 6 também, para o contador).
- `cobre` só diz ok se o registro tem a decisão, o teste citado existe, está no `tests/todos.sh`, contém o trecho que prova a coisa, e, quando se dá, o código que ele lê ainda tem o seu trecho. Não confere linha de registro isolada.
- Citadas: 27 (`manter-sem-pendencias.py`), 28 (`seletor-do-pack.sh`), 31 (`pack-dracula-completo.sh`: Vesktop e peach), 32 (Hidden e `Cosmic,Adwaita` em `pack-dracula-completo.sh`), 33 (`pack-dracula-completo.sh`, o Catppuccin não herda a lista), 34 (`app.sh`, noite com uma ponta só: 409), 35 (`fonte-unica.sh` mais a prova nova de que o `migrar_conf.py` não toca na chave), 39 (`par-do-pack.sh` e uma prova nova: cada pack guarda as pastas na biblioteca dele, nomes disjuntos), 41 (`pack-malicioso.sh`), 42 (`sem-dracula-os-theme.sh` mais a guarda de mesma extensão no `pack.py`), 44 (`oraculo-tema.sh`), 45 (`ganchos.sh`), 50 (`extensoes-gesto.sh` e o `EXTENSOES_COMPILAR=1` do doctor), 53 (`areas-em-cada-tela.sh`).
- Só texto, dito no registro (base «só texto, nada no código a lê»): 38 (arte e upstream que não se mexem) e 40 (nome em inglês do `.desktop`). Nenhuma falsa prova.
- O fim do `tests/decisoes.sh` conta as decisões do registro sem linha e falha se achar uma: `ok    todas as 53 decisões do registro têm linha aqui: decisões sem linha, 0`.
- Corrigido junto, porque dava vermelho de vez em quando: a prova da 25 fazia `printf | grep -q` com `pipefail` e morria de SIGPIPE (rc 141 em 1 de 6 rodadas); agora guarda a saída antes.

Prova: `tests/decisoes.sh` com HOME temporário dá `ok    todas as 53 decisões do registro têm linha aqui: decisões sem linha, 0` e uma só falha, `FALHA voltou comentário: comentario  .gitignore`, que já estava no HEAD antes do bloco (ver abaixo); nenhuma falha de decisão.

Falta: o `.gitignore` do tronco tem linha de comentário e o `scripts/comentarios.py conferir` o recusa; o vermelho é anterior a este bloco e é de quem mexeu no `.gitignore`.
