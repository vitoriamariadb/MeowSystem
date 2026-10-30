# P151 — as pontas da leva P140 a P149

Anotada em 30/10, no fecho da leva: cinco pontas que sobraram das sprints, cada uma curada na origem e com teste
que falha antes e passa depois.

## 1. O `meow.conf.exemplo` diz o que o código faz

### O que se mediu
- `EXTENSOES` falava em cinco extensões (now-playing, status-hub, quick-settings, leitura, performance). Os pinos
  são 12, e os de TIPO="applet" são 10 (ascii-battery, clipboard, drives, eyedropper, leitura, now-playing,
  performance, quick-settings, soneca, status-hub). Compositor e menu do Arquivos têm pino, mas quem manda neles é
  `COMPOSITOR` e `FILES_MENU`.
- `LEITURA_APPLET` dizia que só o `./install.sh` compila, que o `plugins_wings` é escrito à mão e que nenhum script
  o escreve, que o build gasta ~1,5 GB de target e que sem cargo a etapa se pula. Hoje o doctor também compila
  (decisão 50), o «Pôr no painel» escreve o `plugins_wings` por gesto, o target é um só (P147) e o
  `meow_garantir_cargo` instala o rust pelo rustup.
- `MIDIA` dizia que o `midia.sh` reverte e que compilar não é do doctor. Quem reverte é a passada do
  `extensoes_build --todas`, e o doctor compila.
- `PROMPT_STARSHIP` dizia que o MeowSystem não escreve arquivo de shell e mandava rodar `./scripts/prompt.sh
  mostrar`. O bloco marcado do `terminal_bloco.sh` (decisão 20) inicia o starship, e o install o baixa
  (decisão 26).
- Quatro citações `scripts/x.sh:NNN` apontavam para linhas que mudaram (areas, midia, fastfetch_logo, autostart).

### Cura na origem
- Os quatro textos foram reescritos pelo código. As citações perderam o número de linha.

### Prova
- `tests/numeros.sh` ganha uma conferência: o texto de `EXTENSOES` cita todo id de pino TIPO="applet", e todo
  número que ele escreve é a contagem desses pinos.

## 2. Nenhuma saída manda rodar um script

### O que se mediu
- `completar_icones.sh` imprimia «auditoria completa da máquina: ./scripts/auditar_icones.sh».
- A varredura de `scripts/`, `lib/`, `bin/meow`, `install.sh` e dos manifestos achou 11 saídas `meow_*` que citam
  `./scripts/` ou `scripts/x.sh` como comando: areas (5), autostart, completar_icones (2), spicetify_setup,
  icones_apps_arcticons e fastfetch_logo.

### Cura na origem
- Cada saída diz o fato ou o lugar do painel (`meow_onde_no_painel`), ou sai.
- O `auditar_icones.sh` ficou sem chamador e entra nos isentos do `tests/orfaos.sh` como ferramenta de bancada.

### Prova
- `tests/nada-manda-digitar.sh` ganha uma seção 10: nenhuma saída `meow_info|aviso|pula|ok|erro|muda` cita
  `./scripts/` nem `scripts/x.sh` como comando. Os textos de uso ficam de fora.
- O padrão tem uma autoprova, com quatro comandos que ele pega e quatro fatos que ele deixa passar.

## 3. VS Code: a extensão no `.obsolete` não está instalada

### O que se mediu
- Depois do `--uninstall-extension`, o VS Code deixa a pasta e lista a extensão em `~/.vscode/extensions/.obsolete`.
- O `_meow_vscode_pkg` achava a pasta e dava a extensão por instalada. O segundo desfazer então avisava «não
  consegui remover».

### Cura na origem
- `_meow_vscode_obsoleta` lê o `.obsolete`, e o `_meow_vscode_pkg` pula as pastas que ele lista.

### Prova
- O `code` falso de `tests/temas-de-apps.sh` faz o que o real faz (a variável `CODE_OBSOLETO`).
- O cenário: aplicar, desfazer, desfazer de novo e conferir. O segundo desfazer diz «já estava sem» e não tenta
  remover nada; aplicar de novo reinstala.

## 4. A Biblioteca: marcas com a grafia certa

### O que se mediu
- `slidesk`: o projeto se escreve «SliDesk» (README de `slidesk/slidesk`); o catppuccin-vsc-icons usa o id
  `slidesk`.
- `network`, `player` e `star` são glifos do Arcticons. No `appfilter.xml` dele:
  - `network` é o app «Network» (`pl.lebihan.network`, um atalho para o modo de rede do celular);
  - `player` é o «Player» da TVN (`pl.tvn.player`);
  - `star` é o «Star+» da Disney (`com.disney.starplus`).
- Os três estavam como «rede», «reprodutor» e «estrela», com a tag `sistema`.

### Cura na origem
- No `catalog.json`: «SliDesk», «Network, atalho da rede do celular», «Player, da TVN» e «Star+, da Disney», os
  três com a tag `aplicativos`.
- A grafia começa em maiúscula, então não precisa de `caixa_da_marca`.

### Prova
- A tabela de grafia de `tests/biblioteca-em-portugues.sh` ganha os quatro.
- O nome de marca que ela fixa não conta como palavra comum em inglês.

## 5. Decididas, sem mudança

- A Bandeja volta a 360 de largura enquanto o menu de um item está aberto: o menu precisa da largura para os
  rótulos. Não é vão.
- No Latte, 50 itens do Sistema e 142 da Biblioteca ficam abaixo de 3:1. As cores são a arte do pack e não mudam.

## 6. As pontas que a primeira passada deixou (pedido de 30/10: «conclua todas as pontas soltas»)

### O que se mediu
- A pendência `spicetify-ausente`:
  - não tinha ação no painel;
  - guardava «scripts/spicetify_setup.sh instalar» como comando;
  - e nada baixava o spicetify.
- Três saídas ainda mandavam fazer algo:
  - `prompt.sh`: «a alternativa, pelo cargo: cargo install starship --locked»;
  - o desfazer do VS Code: «tire pela interface do editor»;
  - `afinar_conversor.py`: «Para regerar o acervo: ./scripts/construir_convertidos.sh».
- Os dois testes não pegavam essas saídas:
  - a seção 1b do `nada-manda-digitar.sh` não lia os manifestos;
  - a seção 10 não lia Python.
- O autostart só avisava quando um nome saía de `AUTOSTART_BLOQUEADOS`, e a máscara ficava. Com a lista vazia, nem
  avisava. Não havia teste do autostart.

### Cura na origem
- O painel ganha a ação `spicetify_instalar` («Baixar o spicetify», no «⋮» do cartão do Spotify). Ela:
  - roda o `spicetify_setup.sh instalar`, com rede e confirmação;
  - fica indisponível quando o spicetify já existe.
- A pendência aponta para essa ação, pelo `ACAO_DA_PENDENCIA`, como as outras pendências acionáveis. O manifesto
  não cita mais o script.
- As três saídas dizem o fato, ou saem.
- O `autostart.sh aplicar` desmascara, pelo `cmd_remover`, o que o MeowSystem mascarou e saiu da lista, também
  com a lista vazia. O que já vinha mascarado de fora fica.
- O `conferir` diverge enquanto um nome que saiu da lista segue mascarado.
- O texto de `AUTOSTART_BLOQUEADOS` no exemplo diz isso.

### Prova
- `tests/app.sh`:
  - a pendência tem a ação que baixa o spicetify, e o `--onde` leva à Modificações;
  - a pendência some com o spicetify em `~/.spicetify`;
  - o manifesto não cita o script.
- `tests/modificacoes-pagina.py`: o «⋮» do Spotify mostra o botão quando o spicetify falta.
- `tests/nada-manda-digitar.sh`:
  - a seção 1b lê os manifestos e conhece as duas formas;
  - a seção 10 lê `scripts/*.py` e `app/*.py`, e tem autoprova.
- `tests/autostart.sh` (novo), com `systemctl` falso:
  - tirar um nome desmascara;
  - esvaziar a lista desmascara;
  - o mascarado de fora fica;
  - o `conferir` diverge e depois fecha;
  - a segunda passada não mexe em nada.

## 7. O `auditar_icones.sh` fica

Decisão do coordenador (30/10): ele fica como ferramenta de quem desenvolve. Nenhuma saída o chama, e a isenção no
`tests/orfaos.sh` fica.

## Execução
- Item 1: `d937d732` (exemplo) e `e360a04e` (`tests/numeros.sh`).
  - O teste novo falha no exemplo velho: faltavam ascii-battery, clipboard, drives, eyedropper e soneca.
  - Também falha se o texto disser «nove» com 10 pinos.
- Item 2: `a35f74be` (as seis saídas), `2bde4904` (seção 10 do `nada-manda-digitar.sh`) e `b6c69322` (`orfaos.sh`).
  - Antes da cura, a seção 10 achava 11 saídas; depois, nenhuma.
- Item 3: `c9b84f56` (manifesto) e `5c074c09` (`temas-de-apps.sh`).
  - No código velho, o segundo desfazer avisava «não consegui remover»; no novo, diz «já estava sem».
- Item 4: `a0d031a7` (catálogo) e `0a6faa55` (`biblioteca-em-portugues.sh`).
  - No catálogo velho, a grafia das quatro marcas não batia; no novo, bate.
- Verdes: `numeros`, `frases-velhas`, `nada-manda-digitar`, `biblioteca-em-portugues`, `orfaos` e `temas-de-apps`.
  - Também `decisoes`, `chaves-aposentadas`, `leitura-fonte-unica`, `painel-fantasma`, `garantir-builds` e
    `chave-etapa`, que leem o exemplo.
- Não tem teste novo para o `todos.sh`: só os existentes foram estendidos.
- Anotado para o próximo bloco, fora do escopo:
  - O `spicetify-ausente` não tem ação no painel; a pendência ainda cita `scripts/spicetify_setup.sh instalar`.
  - O `prompt.sh` diz «a alternativa, pelo cargo: ...».
  - O desfazer do VS Code manda «tire pela interface do editor».
  - O `afinar_conversor.py` imprime «./scripts/construir_convertidos.sh».
  - O autostart não desmascara o nome que sai da lista.
  - Aposentar o `auditar_icones.sh` (decisão 24) é da coordenação.
- Item 6, o spicetify:
  - commits `61308c7d` (painel), `4e892dc4` (manifesto), `02d351fc` (`app.sh`) e `e1a27ecb`
    (`modificacoes-pagina.py`);
  - no código velho, o `app.sh` falhava em 4 asserções, e a página falhava em 2 de 54;
  - no novo, os dois passam.
- Item 6, as saídas:
  - commits `9982fc3d` e `9d182170`;
  - no código velho, o `nada-manda-digitar.sh` achava `prompt.sh:168`, `vscode/manifesto.sh:868` e
    `afinar_conversor.py:259`; no novo, passa.
- Item 6, o autostart:
  - commits `b379ccdd`, `d9ea4810` (exemplo) e `48852f4d` (`tests/autostart.sh`);
  - no código velho, o teste falhava em 4 dos 6 casos; no novo, passa nos 6.
- O `app/LEIA-ME.md` passou a 70 ações.
- Verdes depois do item 6:
  - `app`, `modificacoes-pagina.py`, `modificacoes`, `nada-manda-digitar` e `temas-de-apps`;
  - `spotify-atualizado`, `apps-frases`, `numeros` e `frases-velhas`;
  - `orfaos`, `decisoes`, `chaves-aposentadas` e `doctor-so-le`.
- Para ligar no `todos.sh`: `tests/autostart.sh`, no grupo `PORTATIL`, porque usa `systemctl` falso e não precisa
  do COSMIC.
