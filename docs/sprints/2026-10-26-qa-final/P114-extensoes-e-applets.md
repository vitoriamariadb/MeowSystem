# P114 — a porta Extensões: os applets da casa, os builds e o repo de quem usa

Leia `00-leva.md`. Itens: `relatorios/qa-3.md` Q3-09, Q3-10; `relatorios/qa-2.md` Q2-18, Q2-22,
Q2-23; `relatorios/qa-1.md` Q1-20.

## Maquete
`maquete/b/extensoes.html`: abas Applets e Builds, a faixa que copia a barra de cima, «Pôr no painel», a troca pendente (Trocar/Manter) e o diálogo «Adicionar repositório»; os Créditos do «…» em `maquete/b/personalizar.html?creditos=1`. O «Construídos» do Manter (maquete A) mostra o mesmo estado que a aba Builds.

## O que quem usa pediu
Uma porta «Extensões» no topo (Tema · Personalizar · Definir · Manter · Extensões) que mostra os
applets, instala, atualiza e remove, deixa adicionar o repositório de um applet (uma central de
applets) e mostra o estado dos builds (compositor, menu do Arquivos, applets) com «refazer». Nunca
briga com o sistema: escolhe junto com o COSMIC, nunca sobrescreve o que ele gerencia.

## Os applets da casa (já publicados; leia o INTEGRACAO.md de cada um)
| repo | pasta local | app id |
|---|---|---|
| vitoriamariadb/meowsystem-now-playing | ~/Desenvolvimento/meowsystem-now-playing | io.github.meowsystem.NowPlaying |
| vitoriamariadb/meowsystem-status-hub | ~/Desenvolvimento/meowsystem-status-hub | io.github.meowsystem.Bandeja |
| vitoriamariadb/meowsystem-quick-settings | ~/Desenvolvimento/meowsystem-quick-settings | io.github.meowsystem.AjustesRapidos |
| vitoriamariadb/meowsystem-leitura | ~/Desenvolvimento/meowsystem-leitura | io.github.meowsystem.Leitura |
| vitoriamariadb/meowsystem-performance | ~/Desenvolvimento/meowsystem-performance | io.github.meowsystem.Performance |

## Decisões que valem (ANDAMENTO.md)
- Porta própria. Adicionar repo de qualquer URL, por gesto, com SHA pinado, compilado sem sudo, em
  `~/.local`. Os da casa instalam pelo doctor com selo de rede (decisão 7 de `docs/DECISOES.md`); os
  adicionados por ela, só por gesto: escreva essa exceção no `docs/DECISOES.md`.
- Repositório da casa: `vitoriamariadb/MeowSystem` (a decisão 22 cai: troque a linha 22 do
  `docs/DECISOES.md`, a prova 22 do `tests/decisoes.sh` e o `repositorio` do `docs/readme.toml`).
- A ordem dos applets no painel é de quem usa: a página instala e oferece «pôr no painel», nunca
  reordena sozinha.

## Ordem
1. Q1-20 / Q2-22: a casa de teste (`tests/app-completo.py`) ignora repositório aninhado na cópia.
2. Q2-23: `app/pagina/previas-*.js` — se o B0 já resolveu, só confirme.
3. Pino e receita por applet no molde de `scripts/midia_build.sh` + `src/applets/now-playing/PINO`:
   um arquivo de dado por applet (URL, commit), uma etapa genérica de build que serve os cinco.
   `src/applets/now-playing/` (patch) e `src/applets/leitura/` saem do repo; o now-playing passa a
   ser o fork. Siga o INTEGRACAO.md de cada repo (cache, chaves de config, contrato de tema).
4. Tema: o doctor gera o arquivo de tema de cada applet a partir do pack (contrato comum dos
   INTEGRACAO.md).
5. Página Extensões (Q3-10): cartão por applet (ícone, nome, estado, versão, Instalar/Atualizar/
   Remover, Pôr no painel), bloco «Builds» (Q2-18: compositor, menu do Arquivos, applets; estado e
   refazer), «Adicionar repositório». API no servidor; estado em `~/.local/state/meowsystem/`.
6. Q3-09: «Créditos» do «…» com os dois autores (Vitória Maria e André Farias) e os upstreams dos
   applets; `LICENSE` e `CREDITOS.md` com os dois nomes; links para `vitoriamariadb/MeowSystem`.

## Prova
Testes de shell da etapa de build com um repositório git falso local (sem rede); Playwright da
página Extensões com HOME temporário; segunda passada do doctor não escreve nada.

## Fora desta sprint
README (refeito pelo gancho do B0), renomes das outras portas (P111).

## Execução

Branch `sprint/p114`, 20 commits em português, por caminho.

| item | prova |
|---|---|
| Q1-20 / Q2-22: o repo aninhado fica fora do `tests/app-completo.py` | `app-completo.py` verde |
| Q2-23: `previas-*.js` | nada a fazer |
| pino por applet e etapa de build genérica; `now-playing` e `leitura` saem do repo | `tests/extensoes.sh`, `extensoes-gesto.sh`, `garantir-builds.sh`, `midia.sh`, `leitura-fonte-unica.sh` verdes, com repositório git falso local e `cargo` falso |
| tema de cada applet gerado pelo doctor a partir do pack | `tests/extensoes.sh`; a segunda passada do `--aplicar` não muda arquivo nenhum e não roda build |
| Q3-10 / Q2-18: página Extensões (cartões, Builds, Adicionar repositório) | `tests/extensoes-pagina.py`, 58 conferências em Playwright com HOME temporário |
| Q3-09: Créditos (diálogo, os dois autores, upstreams) | `extensoes-pagina.py` passo 10; `app-completo.py` abre o diálogo e o link; `LICENSE` e `docs/CREDITOS.md` com os dois nomes |
| decisão 22 para `vitoriamariadb/MeowSystem` | `tests/decisoes.sh` (22 verde); `docs/readme.toml` e README regerados |
| exceção do doctor com selo de rede para applet da casa | linha 50 de `docs/DECISOES.md` |

Achados e correções no caminho: a troca só é oferecida com a extensão nova instalada; os gestos usam
as naturezas que dizem ok no rc 1; os rótulos das ações cabem em três palavras; o interruptor «Refazer
ao entrar na sessão» ignora a resposta velha de um `GET` em voo; `migracao-do-painel.py` ganhou os
destinos das chaves e ações novas; `app-acessibilidade.py` conta cinco portas; `app-navegador.py` rola o
alvo da dica antes do hover (a Cuidar ficou mais alta com as pendências dos applets).

Capturas: `capturas/p114/` (1920x1080, 1550x860, 1500x900, 1280x800, ao lado da maquete). O
`.gitignore` ignora PNG: ficam só na árvore.

`./tests/todos.sh`: 90 testes; vermelhos que não são desta sprint: `readme.sh` (selo v2.1.0 contra a tag
alcançável), `decisoes.sh` (GPU e shim do compositor da máquina) e `restaurar.sh` (`pack_usar` e
`desinstalar`: arquivos do VS Code). Os que eram da sprint foram corrigidos e rodados de novo
isoladamente (`app.sh`, `migracao-do-painel.py`, `app-acessibilidade.py`, `app-navegador.py`,
`app-completo.py`).

Fora: capturas do README (o gancho do merge refaz); a linha 50 do registro pode colidir de número com
outra sprint na integração.
