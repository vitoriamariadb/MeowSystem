# P114 — a porta Extensões: os applets da casa, os builds e o repo de quem usa

Leia `00-leva.md`. Itens: `relatorios/qa-3.md` Q3-09, Q3-10; `relatorios/qa-2.md` Q2-18, Q2-22,
Q2-23; `relatorios/qa-1.md` Q1-20.

## O que quem usa pediu
Uma porta «Extensões» no topo (Tema · Personalizar · Definir · Manter · Extensões) que mostra os
applets, instala, atualiza e remove, deixa adicionar o repositório de um applet (uma central de
applets) e mostra o estado dos builds (compositor, menu do Arquivos, applets) com «refazer». Nunca
briga com o sistema: escolhe junto com o COSMIC, nunca sobrescreve o que ele gerencia.

## Os applets da casa (já publicados; leia o INTEGRACAO.md de cada um)
| repo | pasta local | app id |
|---|---|---|
| <conta>/meowsystem-now-playing | ~/Desenvolvimento/meowsystem-now-playing | io.github.meowsystem.NowPlaying |
| <conta>/meowsystem-status-hub | ~/Desenvolvimento/meowsystem-status-hub | io.github.meowsystem.Bandeja |
| <conta>/meowsystem-quick-settings | ~/Desenvolvimento/meowsystem-quick-settings | io.github.meowsystem.AjustesRapidos |
| <conta>/meowsystem-leitura | ~/Desenvolvimento/meowsystem-leitura | io.github.meowsystem.Leitura |
| <conta>/meowsystem-performance | ~/Desenvolvimento/meowsystem-performance | io.github.meowsystem.Performance |

## Decisões que valem (ANDAMENTO.md)
- Porta própria. Adicionar repo de qualquer URL, por gesto, com SHA pinado, compilado sem sudo, em
  `~/.local`. Os da casa instalam pelo doctor com selo de rede (decisão 7 da P82); os adicionados
  por ela, só por gesto: escreva essa exceção no registro.
- Repositório da casa: `<conta>/MeowSystem` (a decisão 22 cai: troque a linha).
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
   applets; `LICENSE` e `CREDITOS.md` com os dois nomes; links para `<conta>/MeowSystem`.

## Prova
Testes de shell da etapa de build com um repositório git falso local (sem rede); Playwright da
página Extensões com HOME temporário; segunda passada do doctor não escreve nada.

## Fora desta sprint
README (refeito pelo gancho do B0), renomes das outras portas (P111).
