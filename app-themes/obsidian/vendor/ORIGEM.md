# Origem do tema Catppuccin para Obsidian

- Repositorio: https://github.com/catppuccin/obsidian
- Licenca: MIT
- Commit PINADO: a498ec094a8e619e78bbaad93fb89cecd938f6c4
- Data do commit: 2026-08-03T20:38:16Z
- Assunto: "fix: update --callout-color usage for Obsidian 1.13+ (#159)"
- Versao do manifest: 0.4.47 (minAppVersion 1.13.0)

Arquivos baixados de:
  https://raw.githubusercontent.com/catppuccin/obsidian/a498ec094a8e619e78bbaad93fb89cecd938f6c4/theme.css
  https://raw.githubusercontent.com/catppuccin/obsidian/a498ec094a8e619e78bbaad93fb89cecd938f6c4/manifest.json

Para atualizar: troque o SHA acima, rebaixe os dois arquivos e confira que
a linha ".theme-dark, .theme-dark.ctp-mocha" continua existindo (e ela que
faz o Mocha valer sem depender do plugin Style Settings).

## Por que VENDORAR e nao baixar na hora

O .gitignore do repo tem a convencao oposta para `src/icons/upstream/` e
`src/wallpapers/baixados/`: "o repo guarda o script que baixa, com commit
pinado, nao o conteudo". Aqui a decisao foi diferente, de proposito:

- o `meow_app_aplicar` roda no ciclo do self-heal, que precisa funcionar
  SEM REDE — baixar na hora transformaria "sem internet" em erro;
- sao 2,3 MB, duas ordens de grandeza abaixo do Papirus (que e o caso que
  motivou aquela regra) e bem longe do limite de 100 MB que ja emudeceu o
  auto-sync do Andromeda por 18h;
- o que entra no vault e sempre o mesmo byte que foi revisado.

Se um dia isso incomodar, o caminho e trocar `vendor/` por um
`scripts/baixar_tema_obsidian.sh` com o mesmo SHA pinado e chamar antes do
aplicar — mas ai o modulo passa a depender de rede.
