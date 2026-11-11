# P191 — a interface sem registro (10/11/2026)

Texto de quem usa: «vamos deixar sem logs a interface». Sim de 10/11: tudo que é registro.

## O que se mediu

1. Manter › bloco «Registro» (`lugares.js:275-279`): `LOG_NIVEL` («Quanto fala»), `BACKUPS_MANTIDOS` («Cópias
   guardadas») e a ação `log` («Ver»). Foto `fotos/4-registro.png`.
2. Extensões › Builds: `<details>` «Registro de <applet>» aberto quando um build falha (`extensoes.js:240-241`).
3. «Guardar» na janela de resultado (`index.html:85`), que sai pela P189.

## A cura na origem

- Saem da tela: o bloco Registro, `LOG_NIVEL`, a ação `log` e o «Registro de <applet>». O build que falhou mostra
  só o estado e o botão de tentar de novo.
- `BACKUPS_MANTIDOS` não é registro: muda para o bloco «Sozinho», com o nome do glossário.
- As chaves seguem no `meow.conf` e o log no disco; o `meow doctor` continua lendo.

## Como se prova

- Gate do navegador: nenhum `pre`/`details` de log em tela alguma, com um applet falho plantado.
- `BACKUPS_MANTIDOS` grava pelo bloco novo.

Tamanho: 1 h.
