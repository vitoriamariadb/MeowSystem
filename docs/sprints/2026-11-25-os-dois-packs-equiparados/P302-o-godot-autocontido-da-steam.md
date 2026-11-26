# P302 — o Godot autocontido fica sem o tema (25/11/2026)

Achado na passada de tela do bloco dos módulos, antes de integrar.

## O que se mediu
- O módulo do Godot aplicado numa cópia de `~/.config/godot` escreveu o `.tet` e as chaves do tema, e o editor da
  Steam (4.7.2) abriu com as cores de fábrica: captura de antes e de depois idênticas, byte a byte.
- Ao lado do binário da Steam (`steamapps/common/Godot Engine/`) há um arquivo `._sc_`. Com ele (ou `_sc_`) o Godot
  roda em modo autocontido: as preferências do editor moram em `editor_data/`, ao lado do binário, e
  `~/.config/godot` nem é lido. A `editor_data/cache` mudou de data quando o editor abriu; `~/.config/godot` não.
- `_godot_pastas` só conhecia `$XDG_CONFIG_HOME/godot` e a pasta do flatpak. Os testes escreviam e liam arquivo, e
  nenhum abria o editor.

## A causa
O módulo procurava as preferências do editor em dois lugares fixos, e o Godot decide o lugar pelo modo em que roda:
autocontido, a pasta é a `editor_data` ao lado do binário.

## A cura na origem
`_godot_pastas` passa a somar a `editor_data` de toda pasta `steamapps/common/*/` que tenha `._sc_` ou `_sc_`, em
toda biblioteca da Steam (`libraryfolders.vdf` das três raízes conhecidas). A lista sai sem repetição pelo caminho
real, porque `~/.steam/steam` costuma ser atalho para a mesma instalação. Pasta sem a marca fica de fora. O resto do
módulo (aplicar, conferir, reverter) já trabalha por pasta e não mudou.

Limite conhecido: um Godot autocontido baixado à mão, fora da Steam, não tem como ser achado sem alguém dizer onde
está.

## Como se prova
`tests/temas-por-app.sh`: duas bibliotecas, uma com `._sc_` e outra com `_sc_`, mais uma pasta de jogo sem a marca.
Vermelho antes (rc=3, «sem configuração do editor»), verde depois: as duas `editor_data` vestidas, uma vez cada, a
pasta sem marca intocada, e o reverter limpa as duas.

Na tela: o editor da Steam aberto num servidor gráfico escondido, com cópia da instalação, antes e depois.
