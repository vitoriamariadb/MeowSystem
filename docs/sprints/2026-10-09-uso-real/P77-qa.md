# P77 — QA de uso real, como quem nunca viu o painel (10/10/2026)

Branch `sprint/p77`. O painel subiu da worktree (`app/run.sh --sem-abrir`) com um HOME
temporário: cópia de `~/.config/meow`, `~/.config/cosmic`, `~/.local/share/{icons,applications}`,
dos papéis de parede ativos e do estado leve (sem `leitura/`, `midia/`, `backups/`); os 7 links
que apontavam para o HOME real viraram cópia. Falsos no PATH para `sudo`, `pkexec`, `apt`,
`systemctl`, `pkill`, `kill`, `curl`, `wget`, `cargo`, `busctl`, `gdbus`, `dbus-send`,
`cosmic-randr`, `gsettings`, `gtk-update-icon-cache`, `flatpak` e afins, cada um registrando e
recusando. Sem `DBUS_SESSION_BUS_ADDRESS`, `WAYLAND_DISPLAY` e `DISPLAY`. Conferido no fim: o
`CosmicBackground/v1/all` real continua com o mtime de 09/10 18:13, e o registro dos falsos só
tem leituras (`sudo -n … estado`, `systemctl --user show`) e o `gtk-update-icon-cache` do tema
de brinquedo.

Navegador: Playwright, 1440×900 e 1920×1080. Prints em
`.playwright-mcp/ux-p77/qa-*.png` (raiz do checkout principal, fora do git).

## A medida: caracteres visíveis por página, na MESMA casa

Mesma régua do `tests/app-texto-visivel.py` (texto visível em `#conteudo`, fora de dica e balão;
«frases» = bloco corrido com 60+ caracteres; «comando» = texto em `<code>`). «Antes» é o
`af3159f` (a integração da onda 1, de onde a P77 partiu), servido da exportação dele com o MESMO
HOME temporário; «depois» é o `HEAD` da branch no fim deste QA. 1440×900, página no topo.

| página | antes: caracteres / frases / comando | depois: caracteres / frases / comando | print antes (dev, 09/10) | print antes (af3159f) | print depois |
|---|---|---|---|---|---|
| Início | 2822 / 9 / 0 | 1372 / 0 / 0 | `ux/01-home.png` | `qa-antes-pg-01-inicio-1440.png` | `qa-pg-01-inicio-1440.png` |
| Cor e tela | 2173 / 10 / 48 | 555 / 0 / 0 | `ux/10-cor-e-tela.png` | `qa-antes-pg-02-cor-e-tela-1440.png` | `qa-pg-02-cor-e-tela-1440.png` |
| Áreas de trabalho | 1391 / 9 / 110 | 296 / 0 / 0 | `ux/23-areas.png` | `qa-antes-pg-03-areas-de-trabalho-1440.png` | `qa-pg-03-areas-de-trabalho-1440.png` |
| Logo do sistema | 4103 / 18 / 49 | 743 / 0 / 0 | `ux/13-logo.png` | `qa-antes-pg-04-logo-do-sistema-1440.png` | `qa-pg-04-logo-do-sistema-1440.png` |
| Ícones | 3393 / 16 / 68 | 1552 / 0 / 0 | `ux/03-icones.png` | `qa-antes-pg-05-icones-1440.png` | `qa-pg-05-icones-1440.png` |
| Painel e dock | 4348 / 14 / 54 | 1112 / 0 / 0 | `ux/11-painel-dock.png` | `qa-antes-pg-06-painel-e-dock-1440.png` | `qa-pg-06-painel-e-dock-1440.png` |
| Papel de parede | 2449 / 8 / 162 | 589 / 0 / 0 | `ux/12-papel.png` | `qa-antes-pg-07-papel-de-parede-1440.png` | `qa-pg-07-papel-de-parede-1440.png` |
| Dia e noite | 1300 / 6 / 0 | 249 / 0 / 0 | `ux/21-dia-noite.png` | `qa-antes-pg-08-dia-e-noite-1440.png` | `qa-pg-08-dia-e-noite-1440.png` |
| Modo de leitura | 2111 / 14 / 52 | 220 / 0 / 0 | `ux/22-leitura.png` | `qa-antes-pg-09-modo-de-leitura-1440.png` | `qa-pg-09-modo-de-leitura-1440.png` |
| Terminal | 679 / 3 / 0 | 160 / 0 / 0 | `ux/20-terminal.png` | `qa-antes-pg-10-terminal-1440.png` | `qa-pg-10-terminal-1440.png` |
| Lançadores e jogos | 3148 / 11 / 122 | 1144 / 0 / 0 | `ux/14-lancadores.png` | `qa-antes-pg-11-lancadores-e-jogos-1440.png` | `qa-pg-11-lancadores-e-jogos-1440.png` |
| Manutenção | 2734 / 15 / 83 | 557 / 0 / 0 | `ux/17-manutencao.png` | `qa-antes-pg-12-manutencao-1440.png` | `qa-pg-12-manutencao-1440.png` |
| Instalação | 1414 / 6 / 102 | 233 / 0 / 0 | `ux/18-instalacao.png`, `ux/19-conferir.png` | `qa-antes-pg-13-instalacao-1440.png` | `qa-pg-13-instalacao-1440.png`, `qa-72-conferir-com-consertar.png` |
| Atualização | 1318 / 5 / 109 | 146 / 0 / 0 | `ux/24-atualizacao.png` | `qa-antes-pg-14-atualizacao-1440.png` | `qa-pg-14-atualizacao-1440.png` |
| **total** | **33383 / 144 / 959** | **8928 / 0 / 0** | | | |

Em 1920×1080 os números são os mesmos, menos Cor e tela (555), Logo do sistema (743) e Painel e
dock (1112), que já eram os do fim (`qa-pg-*-1920.png`). As páginas rolando inteiras, a 1440:
`qa-rolo-<página>-1440-<n>.png`.

## As tarefas, uma a uma

| tarefa | conseguiu sem ler texto? | dúvida ou defeito | estado | prints |
|---|---|---|---|---|
| Trocar o pack | sim: o cartão do pack é o gesto, «Usar este» pergunta com «Ver o que faria» | a caixa de pergunta tem um parágrafo de 4 linhas sobre o sudo; o ensaio mostra que CURSOR e ICONES_PASTAS ficam no Dracula ao ir para o Catppuccin | anotado (próxima leva) | `qa-90-pack-usar-clique.png`, `qa-91-pack-ensaio.png`, `qa-92-pack-card-aberto.png` |
| Trocar o ícone do agente | sim, pela grade e pela busca | a linha «Gerar ícone — MeowSystem» não dizia que abre (o triângulo do `details` não nasce com o summary em flex) | **corrigido** (item 3) | `qa-10` a `qa-17` |
| Trocar o ícone do Discord | sim: a busca devolve 6 sugestões, as apagadas têm balão | — | ok | `qa-18-discord-busca.png` |
| «Ver o que faria» depois de trocar o ícone | não: o ensaio dizia «apagaria …/claude-desktop.svg (desenho que saiu do mapa do pack no ar)» logo depois do «Usar este ícone» | o ensaio lia os mapas de ícone da pasta da cópia do conf | **corrigido** (item 4) | `qa-21-ver-o-que-faria.png` (antes), `qa-22-ver-o-que-faria-depois.png` |
| Mudar o horário da noite | não: com as duas pontas vazias, mudar «A noite começa às» acendia o ⊘ e o relógio não andava | a meia escolha não vale no `lib/noite.sh` | **corrigido** (item 5): a irmã vazia entra com a hora herdada | `qa-40`, `qa-41-noite-20h.png` (antes), `qa-42-noite-20h-par.png` |
| Ligar o modo de leitura | sim: «Sim» no par, «como está / como fica», régua de horas | «Restaurar ao padrão (Não)» com o padrão de fábrica Sim | o caso «já no padrão» **corrigido** (item 1); o nome do botão fora do padrão segue anotado | `qa-50-leitura.png`, `qa-51-leitura-ligada.png` |
| Mudar a forma da dock | sim: «como está / como fica» lado a lado, barra «1 escolha» | — | ok | `qa-20-dock-pastilha-sim.png` |
| Escolher um papel de parede | sim: clique na imagem abre Usar / Dia / Noite / Tirar | não há gesto de favoritar, e a aba «Favoritos» existe | anotado | `qa-30-papel-clique.png`, `qa-31-papel-usado.png` |
| Trocar o gato | sim, mas o desenho da dock não mudava: «como está» e «como fica» iguais trocando morcego-dia por Mimir (o gato de traço dá o mesmo rosto aos dois nomes) | **corrigido** (item 7): a miniatura do gato do acervo na ponta da dock | `qa-80-gato-mimir-1920.png` (antes), `qa-81`, `qa-82-dock-gato-real-mimir.png` |
| Conferir a máquina | sim; veredito «HÁ DIVERGÊNCIAS» coerente com as linhas | terminava em «rode: meow doctor --consertar» | **corrigido** (item 6): o botão «Consertar o que estiver fora» nasce na gaveta | `qa-71-conferir.png` (antes), `qa-72-conferir-com-consertar.png` |

## Defeitos achados e corrigidos (um commit cada)

1. **«Restaurar ao padrão» sobre o valor de fábrica preenchido** (`c25ca5e`, `1141764`): Janelas
   lado a lado em Sim mostrava «Restaurar ao padrão (Sim)»; o mesmo no relógio, no modo de
   leitura e no ladrilho do ponteiro. `temOQueRestaurar` em todos os controles; o gate de uso
   real passa a cobrar o caso (reprova o `c057457` com 4 defeitos, passa na branch).
2. **Variante dos ícones de arquivo crua** (`1725ba3`): «Dracula · Alucard · macchiato» →
   «Macchiato».
3. **O teto do raio como frase e a oficina sem sinal de que abre** (`1725ba3`): as duas frases
   de Painel e dock viraram selo com o porquê no balão; a oficina ganhou o triângulo.
4. **O ensaio apagava o ícone escolhido** (`949a3f5`): `MEOW_ICONES_ESCOLHAS` e
   `MEOW_ICONES_TRACO` vão com a cópia do conf; teste em `tests/app.sh` (9e), vermelho sem a cura.
5. **Meia noite** (`ad9886b`): a ponta vazia entra com a hora herdada; teste em
   `tests/app-navegador.py` (i3), vermelho sem a cura.
6. **O doctor mandava digitar** (`095dcf1`): `conserta_com` na ação, botão na gaveta; teste em
   `tests/app.sh` (9f).
7. **A dock desenhada não mostrava o gato escolhido** (`7ecd63d`).

## Provas rodadas no fim

- `tests/app-uso-real.py`: passa na branch (14 páginas, 0 defeitos); com `--raiz` no `c057457`
  reprova com os 4 «Restaurar ao padrão» acima.
- `tests/app-navegador.py`: 156/156.
- `tests/app.sh`, `tests/estilo.sh`, `tests/frases-velhas.sh`, `tests/previa-cerca.sh`: verdes
  (o `previa-cerca.sh` com o `curl` de verdade: ele fala com o próprio servidor de brinquedo).
- `tests/app-completo.py`: ver o fim deste arquivo.

## O que se confere com a mão

- O «Consertar o que estiver fora» da gaveta não foi apertado neste QA (baixaria o
  papirus-folders para dentro da árvore); ele roda pelo mesmo `rodar()` do cartão.
- Na casa real, o «Ver o que faria» depois de um «Usar este ícone» não lista mais o
  `claude-desktop.svg` nem o `org.kde.ghostwriter.svg`.
