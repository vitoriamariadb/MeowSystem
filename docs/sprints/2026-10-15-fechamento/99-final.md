# Integração final das levas H e I — 17/10/2026

Branch `integracao/leva-h`, worktree `.wt-meow/integracao-h`. O `dev` não foi tocado. Este arquivo
fecha as duas levas: o que entregaram, as duas suítes, o QA de uso real e o que se confere ao ligar
o PC. O fechamento só da leva H está em [99-fechamento.md](99-fechamento.md).

## O que as levas entregaram

| leva | sprint | o quê |
|---|---|---|
| H | [P81](P81-build-sempre.md) | o compositor e o `cosmic-files` recompilam sozinhos pela mesma função nos três gatilhos |
| H | [P84](P84-png-para-vetor.md) | os 39 PNG feitos à mão viraram vetor, medidos por RMSE |
| H | [P82](P82-abertos.md) | os abertos do uso real, com as decisões 13 a 49 |
| H | [P83](P83-documentacao.md) | a documentação do produto de hoje |
| H | [fechamento](99-fechamento.md) | 11 correções do QA final (nada manda digitar, nomes dos vetores, restos em `/tmp`) |
| I | [P86](P86-regra-da-vida.md) | a sentinela antes do apt, o `GSD.md`, uma decisão = um teste (`decisoes.sh`), o cartão «precisa de gente» |
| I | [P88](P88-tres-pastas.md) | o pack em três pastas de ícone (`apps/`, `sistema/`, `biblioteca/`), formato 2, com import do formato 1 |
| I | [P87](P87-tudo-pro-pack.md) | tudo o que foi achado e recuperado entra no pack Dracula, com a procedência |
| I | [P89](P89-repo-enxuto.md) | o repositório enxuto: comentários de registro fora, `AGENTS.md`, o gancho `scripts/higiene.sh` com teste |

Ordem dos merges nesta branch: P86, P87 (que traz a P88), a correção `af897b2` do `decisoes.sh`,
P89 (`49cc889`). A conferência da P89 repôs os avisos de segurança que o enxugamento automático
tinha cortado.

## As duas suítes

Duas rodadas seguidas do `tests/todos.sh` inteiro no `cef1495`, cada uma com a casa de brinquedo
nova que o runner cria. Por fora do runner: sem barramento da sessão, e `cargo`, `just`, `make` e
`rustup` falsos que recusam.

| rodada | resultado | gates de navegador |
|---|---|---|
| 1 | **70 testes: 69 verdes, 1 pulado, 0 vermelhos, rc=0** | `app-completo.py` 804 s, `app-uso-real.py` 93 s |
| 2 | **70 testes: 69 verdes, 1 pulado, 0 vermelhos, rc=0** | `app-completo.py` 749 s, `app-uso-real.py` 92 s |

- O pulado é o `conversor.sh` nas duas: falta o `assets/icones/catppuccin-apps/macchiato/spotify.png`,
  que nunca foi versionado.
- Em cada rodada os falsos recusaram 6 sudo (`sudo -n true` e o `estado` da ponte), 3 escritas de
  `busctl` e 10 chamadas de `cargo`.
- Nenhuma `/tmp/tmp.*` nova sobrou, e a árvore ficou limpa.

## O QA de uso real

Painel da integração numa casa temporária (cópia de `~/.config/meow`, `~/.config/cosmic`,
`~/.local/share/icons` e `~/.local/share/backgrounds`), falsos que recusam no PATH, sem barramento.
Prints em `.playwright-mcp/ux-final-i/` do checkout principal.

- **Seletor de ícone, contado contra o disco:** Dracula `apps/` 123 (76 + 29 resgatados + 18
  autorais), `biblioteca/` 670 (474 + 39 feitos à mão + 13 projetos + 144 versões, os 20 PNG com a
  trava de raster), Catppuccin 36 autorais, MeowSystem 39 traços + 50 convertidos. Tudo bate.
- **Busca:** «spotify» acha 7 desenhos, os mesmos 7 do disco.
- **Trocar um ícone:** um programa sem desenho (o de fábrica) ganhou o Spotify resgatado; a escolha entrou só no
  `icones-escolhidos.map` da casa temporária, e o tema dela ficou com o desenho.
- **«Conferir a máquina»:** 268 linhas, nenhuma manda digitar; termina em «há divergências — o
  conserto do doctor as acerta», com o botão ao lado.
- **As 14 páginas a 1440 e a 375 px:** sem rolagem lateral e sem erro no console.

**Corrigido:** na Início, a 1440 px, o selo «baixa da internet» descia sozinho para a linha de
baixo e parecia ser da «Próxima imagem». Agora o selo quebra de linha junto do «Consertar o que
estiver fora» (`cef1495`, prints `05-toda-semana-antes-1440.png` e `06-toda-semana-depois-1440.png`).

## A senha do askpass

`git grep` no HEAD: 0 arquivos com a senha, nenhum `.aurora-askpass-secret` no repositório. Ela
continua na história: entrou em `63ed2ca` (que está no `dev`) e saiu em `7f75e41` (no `dev`) e
`32561d0` (nesta branch). Nenhum remoto conhecido tem esses commits. Antes de publicar o `dev`:
reescrever a história ou trocar a senha.

## O que quem usa confere ao ligar o PC amanhã

1. **Antes do merge no `dev`:** commitar ou guardar a mudança local em
   `packs/dracula/icones/pastas/folder-download.svg`, que a P88 moveu para `sistema/pastas/`.
2. **Rodar o `install.sh` uma vez** depois do merge: monta o tema nas três pastas e instala os
   vigias novos (desenhos, sentinela).
3. **No painel:** Ícones → um programa → as pastas «resgatados», «biblioteca» e «versões» aparecem
   com desenho; a Início mostra o selo ao lado do «Consertar o que estiver fora».
4. **«Conferir a máquina»** termina sem nenhuma linha que manda digitar.
5. **A senha do askpass:** decidir entre reescrever a história do `dev` ou trocar a senha.

## Ficou aberto

- Cerca de 45 mensagens do terminal (`bin/meow`, `install.sh`, `scripts/`) ainda dizem «rode: …».
  No caminho do painel nenhuma aparece. Dono: o próximo bloco.
- O enxugamento da P89 deixou cerca de um terço dos trechos sem o porquê. O coordenador decide entre
  reverter o `9ba8171` ou revisar à mão os arquivos mais lidos.
- Os projetos pessoais (Beholder, Elden Ring Tracker, Ouroboros) seguem no pack Dracula e saem no
  exportar dele. A decisão é de quem usa.
