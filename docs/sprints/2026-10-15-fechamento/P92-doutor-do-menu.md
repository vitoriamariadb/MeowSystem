# P92 — O doutor do menu vem para o MeowSystem

**Status: REGISTRADA em 17/10 pela P91 — NÃO executar sem quem usa mandar.**
Origem: [`docs/pesquisas/2026-10-17-vizinhos.md`](../../pesquisas/2026-10-17-vizinhos.md), falhas F1 e F2.

## O que se mediu
- **F1 — a dock não casa janela com lançador quando o `StartupWMClass` do empacotador está errado.**
  O `scripts/appid_dock.sh` (pontes `meow-janela-*.desktop` a partir do `assets/icones/appid.map`)
  não é chamado por ninguém: nem `bin/meow`, nem `install.sh`, nem unidade (o `tests/orfaos.sh` já o
  acusa). O `assets/icones/wmclass.map` é lido só pelo `aurora-menu-doctor.py` do Spellbook, por um
  caminho cravado do clone (`~/Desenvolvimento/MeowSystem/assets/icones/wmclass.map`), que noutra
  casa não existe. E os dois mapas discordam para o mesmo app: `boxy-svg-boxy-svg` contra
  `boxy-svg-boxy-svg-linux`.
- **F2 — lançador de app removido continua no lançador, e o `mimeinfo.cache` fica velho.** O doctor
  só confere os lançadores que o próprio MeowSystem escreve (a sombra do applet de mídia, os jogos,
  as pontes). Quem limpa o resto é o `aurora-menu-doctor.py --fix` (quarentena em
  `~/.local/share/aurora-menu-quarentena`), pelo `aurora-self-heal` a cada terminal aberto.

## A causa
O casamento janela ↔ lançador e o conteúdo do lançador são do MeowSystem (`docs/FRONTEIRA.md`:
«`~/.local/share/applications/` — conteúdo do lançador: Meow»), mas a peça que os aplica ficou no
Spellbook, lendo um arquivo deste repositório pelo caminho desta máquina.

## A cura na origem
- um mapa só (`appid.map` ou `wmclass.map`, decidido medindo o `app_id` real de cada janela), lido
  por um passo do MeowSystem com `chk_`/`fix_` no doctor e etapa no `install.sh`;
- o órfão do lançador (alvo inexistente, com a mesma régua de wrapper e namespace do
  `aurora-menu-doctor.py`) vai para uma quarentena fora de qualquer `applications/`, com volta;
- o `mimeinfo.cache` se refaz quando um `.desktop` do home é mais novo que ele.
- `mimeapps.list` e editor padrão ficam do PC (Aurora).

## Como se prova
Teste numa casa de brinquedo (janela com `StartupWMClass` errado, lançador órfão, cache velha):
o doctor vê, o `--consertar` cura, a segunda passada não escreve. Depois do merge e do install:
`scripts/vizinhos.sh --conferir` deixa de listar o `aurora-menu-doctor.py` e o
`aurora-desktop-guards-apply.sh` quando estes forem desativados no Spellbook (item novo no
`contratos/vizinhos.tsv`, commit só de desativação lá).
