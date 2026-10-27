# Conferência do bloco «central» (P120 e P121)

Branch `bloco/central`, worktree `MeowSystem-central`, base `58b531be`. Conferidos os 16 commits do
implementador (`ed564fee` a `98de7f8a`), item a item da «Cura na origem» das duas sprints: a cura está
na origem, a prova existe e passa, o que ficou de fora, e se as funções tocadas regrediram. A tela
Extensões foi aberta headless (HOME de brinquedo da suíte, Panel e Dock montados) e comparada com a
maquete `2026-10-26-qa-final/maquete/b/` e com as capturas do levantamento.

## Achados corrigidos

| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | A pílula «Atualização» do cartão de build nunca aparecia: o `_b_estado` só põe `atualizacao=sim` com `instalada=nao` (versão nova do pacote, build velho guardado), e o `pilulaDoBuildDaCasa` testava `!instalada` antes. Depois de um `apt upgrade` do cosmic-comp o cartão dizia «Não instalada», oferecia «Instalar» e deixava «Remover» parado com o shim de pé. | `extensoes.js`: «Atualização» antes de «Não instalada»; «Instalar» fica parado quando há atualização; «Remover» segue o shim (`ativa`), não o build da versão do dia. | `0e83b9c8` | `tests/extensoes-pagina.py` seção 7: build velho guardado + shim de pé → «Atualização», botões `Instalar (parado), Atualizar, Refazer, Remover Compositor`; volta a «Pronto, desligado». |
| 2 | «Refazer» do compositor ou do menu ligava o shim ou o menu mesmo com `COMPOSITOR=nao` ou `FILES_MENU=nao`: o `cmd_refazer` chama `--aplicar`, que sempre fazia `_b_ligar`. O meow.conf dizia «não» e o shim ficava de pé; o menu ia e voltava com o doctor. | `extensoes_build.sh`: `_b_conf_quer` lê a `CHAVE_DO_CONF` do pino no meow.conf; com «nao», `_b_aplicar` compila e deixa desligado. O `--fundo` do instalar leva a chave como sim. | `cfcdc93f` | `tests/garantir-builds.sh`: depois do «remover», `refazer compositor` compila, não liga o shim, meow.conf segue `nao`; «instalar» de novo liga. Sem a cura: `FALHA refazer com COMPOSITOR=nao ligou o shim`. |
| 3 | O `garantir_builds.sh` compilava o cosmic-comp no pós-apt e no login com `COMPOSITOR=nao` (o «compila para nada» do levantamento). O menu já respeitava `FILES_MENU`. | `_gb_comp_quer`, no molde do `_gb_files_quer`, no `_gb_pendentes`. | `cfcdc93f` | `tests/garantir-builds.sh`: `COMPOSITOR=nao` + versão nova do pacote → zero `compositor compilar`. Sem a cura: `esperado '0', veio '1'`. |
| 4 | Regressão: a pendência `files-menu-build` passou de «Refazer» (`files_menu_build`) para «Resolver» = `doctor_consertar`. O `files_menu.sh` só emite essa pendência depois de três falhas («parei de tentar sozinha»), e aí o `fix_files_menu` → `disparar_autobuild` não tenta mais: o botão não fazia nada. | `servidor.py`: pendência de pino de build (`TIPO` compositor ou menu) mostra só «Refazer», `extensao_refazer` com o id do pino, que compila em primeiro plano; `onde_na_tela` diz «Refazer»; `lugares.js` ganha o botão nas Pendências. `ACAO_DA_PENDENCIA` e `NOME_DA_PENDENCIA` seguem com as mesmas chaves. | `a022a4ad` | `tests/app.sh`: `files-menu-build` → `acao=""`, escolha `[extensao_refazer, menu-arquivos, «Refazer»]`; `--onde` cita «Refazer». `tests/migracao-do-painel.py` verde com o botão no `lugares.js`. |
| 5 | Os cartões Compositor e Menu do Arquivos caíam no ícone genérico de grade; a maquete desenha o compositor com camadas. | `assets/extensoes/icones/compositor.svg` (camadas) e `menu-arquivos.svg` (janela com imagem e setas), no traço dos outros cinco. | `83bcf33c` | `tests/extensoes-pagina.py`: os dois cartões têm `img`; foto `extensoes-builds-1500x900`. |
| 4b | O `app-completo.py` esperava `acao:extensao_refazer` na página Manter, mas a pendência passa o id do pino, como as outras escolhas com dado. | `extensao_refazer` entra no `ACAO_COM_DADO` do teste; a linha é `pendencia:extensao_refazer`. | `5c3f7c3b` | `tests/app-completo.py` verde (820 s). |
| 6 | Três linhas em branco antes de `_pendencias_das_extensoes` no `servidor.py`. | Saiu com a correção 4. | `a022a4ad` | `ast.parse` e `tests/app.sh`. |

## Conferido e certo

- P120.1 a P120.5: pinos com `TIPO`, `PADRAO`, `CHAVE_DO_CONF`, `ATIVA`, `TEMA`, `TEMA_CHAVES`,
  `PENDENCIA`; `MIDIA` e `LEITURA_APPLET` seguem como «não» explícito; o `extensoes_tema.sh` lê
  `TEMA_CHAVES` do pino, sem `case` por applet. `TEMA=""` em now-playing, leitura e performance está
  certo: só status-hub e quick-settings leem `tema.conf` no repositório deles.
- P120.4: Dock no `_arquivos_do_painel`, «Trocar» na asa de onde o velho saiu, `reiniciar-painel` pela
  porta única `meow_tela_reler`.
- P120.6 e P120.7: ações `extensao_*` servem os três tipos; saem `build_compositor` e
  `files_menu_build`; cartão único com «Pronto, desligado».
- P121.1: `vizinhos.tsv` com `aurora-compositor` e `aurora-night-light`; os inícios batem com as
  linhas do self-heal real (lido, não tocado).
- P121.2, P121.3 e P121.5: `etapa_compositor` em fundo e sem sudo; `COMPOSITOR=nao` reverte;
  `chk_patches`/`fix_patches` ligam o shim com build pronto; `decisoes.sh` prova o shim no HOME de
  brinquedo.
- Rodados verdes: `extensoes.sh`, `extensoes-gesto.sh`, `garantir-builds.sh`, `vizinhos.sh`,
  `etapa-compositor.sh`, `compositor-shim.sh`, `applet-pino.sh`, `extensoes-pagina.py`,
  `migracao-do-painel.py`, `reler-uma-vez.sh`, `app.sh`, `nada-manda-digitar.sh`,
  `doctor-veredito.sh`, `chave-etapa.sh`, `readme.sh`. `decisoes.sh`: só a GPU (D6), vermelho aceito.

## Fica de fora, anotado

- P121.4 (o `/usr/bin/cosmic-comp` de volta ao de fábrica pela ponte de root) não foi feito: precisa
  da senha dela.
- O corte de verdade no self-heal do `$ZD` não foi feito (HOME real). A D11 da P124 diz que o
  `fix_vizinhos` do doctor o faz.
- O `requer` do `aurora-compositor` e do `aurora-night-light` confere que o shim existe, não que o
  build da versão do dia é válido: depois de um `apt upgrade`, se ela entra antes do build em fundo
  acabar, o shim cai no de fábrica e fica uma sessão sem o modo de leitura da Aurora.
- `garantir_builds.sh --fundo` diz «construindo» mesmo quando o `ExecCondition` da unidade pula
  (`BUILDS_AO_ENTRAR=nao` ou `AUTO_REPARO≠sim`): o instalador pode levar mais passadas para dizer em dia.
- `compositor_patches.sh cmd_reverter` ainda imprime um comando para digitar; é de antes do bloco.
- `painel.sh` diz «ou: meow painel reciclar»: é da P119.
- O vermelho do `restaurar.sh` em `sistema_limpar` vem do cache do apt da máquina.

## Para ela conferir com a mão

1. Depois do login, o processo `cosmic-comp` roda o binário de `~/.local/libexec/meow/cosmic-comp/<versão>/`.
2. Extensões › Builds: Compositor e Menu do Arquivos com ícone, pílula certa e quatro botões.
3. Um «Trocar» na Dock e depois «Reiniciar o painel».
4. Workspaces: só `Meow`, `OS` e `III`, sem vazio no fim; o modo de leitura segue certo com o
   compositor da casa.

## Suíte

`./tests/todos.sh` na worktree, depois das correções: 103 testes, 100 verdes, 0 pulados, 3 vermelhos.
`decisoes.sh` (só a GPU, D6) e `restaurar.sh` (`pack_usar`, `desinstalar`, `sistema_limpar`) são os aceitos.
O terceiro, `app-completo.py`, era o 4b: corrigido e verde rodado sozinho.
