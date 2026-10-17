
## Entram também (pendências da integração final da leva I, 17/10)
8. **Projetos pessoais fora do pack**: Beholder, Elden Ring Tracker, Protocolo Ouroboros, Nyx e Caldeirão
   saem do repositório (regra de 23/09, decisão 13), inclusive do exportar; os arquivos vão para o pack do
   usuário em `~/.local/share/meowsystem/packs/` (formato de três pastas), para continuarem na máquina.
9. **O porquê de volta**: a P89 (`9ba8171`) cortou o porquê em cerca de um terço dos comentários. Reler o
   diff do `9ba8171` e devolver, em 1–3 linhas, o porquê onde ele protege alguém: segurança de pack,
   sudo/HOME real, armadilhas do COSMIC, decisões de quem usa. Sem história nem data (a regra da P89 vale).
10. **Nada manda digitar, também no terminal**: as ~45 mensagens «rode: …» de `bin/meow`, `install.sh` e
    `scripts/` viram a ação feita ou o estado; o `tests/nada-manda-digitar.sh` passa a cobrir o terminal.
11. **A versão de 15/10 do `folder-download`**: o arquivo `.versao-folder-download.svg` na raiz desta
    worktree (edição solta que estava no dev) entra como versão em `packs/dracula/icones/biblioteca/`
    com linha no PROCEDENCIA (decisão 16, item 5: a ligada continua a atual). Apague o arquivo da raiz.
