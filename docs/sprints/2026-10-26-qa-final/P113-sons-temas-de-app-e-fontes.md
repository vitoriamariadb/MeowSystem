# P113 — o pack traz sons, tema do Spotify e fonte; a interface não pede download

Leia `00-leva.md`. Itens: `relatorios/qa-1.md` Q1-03, Q1-04, Q1-13, Q1-18 e a pesquisa de sons do
Pop!_OS/COSMIC (seção de sons do Q1-04); `relatorios/qa-2.md` Q2-14, Q2-15, Q2-16.

## Maquete
`maquete/b/personalizar.html#sons` e `#mandar`: sino do volume com a curva, a lista de sons com a origem (Do pack, Padrão, Trocado), o aviso da ponte, e o Mandar com o resumo; `maquete/a/definir.html#programas` para o Lançador com sugestão.

## O que quem usa pediu
- Sons separados por pack; ela quer ver a lista dos sons do sistema (quando toca cada um) e trocar
  cada um pelo do pack. O gerador do sino do volume tem que funcionar.
- O tema do Spotify mora no pack meowsystem e aplica em definitivo, sem botão «Baixar».
- Fonte do terminal e tudo que a interface pede para instalar: o pack traz. No máximo, um «Trazer
  .zip», como no cursor.
- «Escondidos» do lançador sugere os apps instalados enquanto ela digita.
- A etapa Mandar do Personalizar não fica vazia.

## Decisões que valem (ANDAMENTO.md)
- Cada pack traz os seus sons; o MeowSystem ganha sons próprios (procure sons com licença livre que
  combinem com o tema, registre em PROCEDENCIA.md). `SOM_*` do meow.conf deixa de vencer o pack
  (vira ajuste por cima, só se ela mexer).
- Sons do carregador e da bateria: o COSMIC lê `/usr/share/sounds/Pop` cravado; troque pela ponte
  root (nunca sudo direto) e o vigia pós-apt repõe. A decisão 37 («sons só na notificação») cai:
  troque a linha no mesmo commit.
- Fonte do terminal vendorada no pack (JetBrainsMono Nerd Font Mono), sem seletor novo; o install
  para de baixar.
- O «Instalar» da extensão do VS Code de pack importado FICA (decisão 9).

## Ordem
1. Q1-03: um sino só. A prévia do navegador, o controle e o «Regravar» usam os mesmos números; o
   «Regravar» lê o valor que está na barra (com a P109, já gravado).
2. Q1-04: `sons/` dentro de cada pack com manifesto (evento → arquivo); página Sons do Personalizar
   lista cada som do sistema com nome legível, quando toca, ouvir e trocar.
3. Q2-15: tema do Spotify dentro de `packs/meowsystem/temas-de-apps/` (como o Dracula já faz),
   aplicado pelo doctor; some o botão.
4. Q2-16: cada ponto da lista vira dado do pack ou some; o starship sai da interface (decisão 26
   de `docs/DECISOES.md` já o põe no install; tire dela a metade do doctor).
5. Q2-14: «Escondidos» com sugestão dos apps de `/api/apps` ao digitar; só aceita app que existe.
6. Q1-13 e Q1-18: Mandar mostra o resumo do tema e as saídas desde o primeiro passo; o rascunho
   mora no servidor, não só no navegador.

## Fora desta sprint
Ícones (P112), layout (P110).

## Execução

Branch `sprint/p113`, nove commits. Prova de navegador: `tests/p113-navegador.py` (headless, casa de
brinquedo), capturas em `capturas/p113/`. A prova de cada item vem do teste que o guarda.

| item | o que foi feito | prova |
|---|---|---|
| Q1-03 | a prévia do painel é `GET /sino`, que roda `som.sh gerar`, o mesmo gerador do `aplicar`; o «Regravar» grava primeiro o que está na barra | `p113-navegador.py`: os bytes do `/sino` são os do `audio-volume-change.oga` regravado, e seguem iguais depois de recarregar; `sons-do-pack.sh` |
| Q1-04 | `packs/meowsystem/sons/` (Interface Sounds do Kenney, CC0); `assets/sons/eventos.json` dá nome, quando toca e grupo; `/api/sons` junta isso ao pack; a página Sons tem os dois blocos, ouvir, trocar, origem e o aviso de ponte; ponte root com `som` e `som-padrao`, pós-apt repondo; `SOM_*` do `meow.conf` só vale no pack em que ela o mexeu (`som-do-pack` no estado); decisão 37 reescrita | `sons-do-pack.sh` (ponte de brinquedo, nunca a real), `ponte-so-reserva.sh`, `pos-apt.sh`, `decisoes.sh` 37, `p113-navegador.py` (25 sons, 7 marcados sem ponte) |
| Q2-15 | tema catppuccin do spicetify em `packs/meowsystem/temas-de-apps/spotify/`, aplicado pelo doctor; o botão «Baixar» saiu | `pack-traz-o-que-usa.sh` |
| Q2-16 | fonte JetBrainsMono Nerd Font Mono no pack (instalador offline); saíram os botões de baixar o starship, a coleção de papéis e o menu do Arquivos; ficam «Trazer .zip/fonte» e o «Instalar» do VS Code (decisão 9) | `pack-traz-o-que-usa.sh`, `nada-manda-digitar.sh`, `p113-navegador.py` (nenhum Baixar, Instalar ou Construir fora o do tema, o do VS Code e o «Instalar tudo» da QA-3) |
| Q2-14 | «Escondidos» e «Não abrem sozinhos» ganham a lista de `/api/apps` e recusam o que não existe | `p113-navegador.py` |
| Q1-13, Q1-18 | Mandar mostra o resumo (cores, ícones, pastas, papel, sons, temas de apps, mascote) e as saídas sem guardar antes (guarda sozinho ao baixar ou vestir); o rascunho vai a `/api/rascunho` (`rascunho-do-tema.json` no estado) | `p113-navegador.py`: Mandar sem guardar, e o rascunho volta numa janela nova sem o `localStorage` |

Baixado: a Interface Sounds do Kenney (CC0, sha256 em `packs/meowsystem/sons/PROCEDENCIA.md`), o tema
catppuccin do spicetify e a JetBrainsMono Nerd Font (origem, licença e sha256 nos `PROCEDENCIA.md`
do pack).

Ficou de fora: o manifesto `evento → arquivo` é a própria árvore `sons/stereo/<contexto>/<evento>.oga`
que o `pack.py` já valida, sem um arquivo a mais; a linha «Tela de entrada» do resumo do Mandar (o
pack não tem categoria para ela); o «Registro» do Mandar (P111); «Não abrem sozinhos» sugere só o que
o `/api/apps` lista, não o que só existe em `~/.config/autostart`.
