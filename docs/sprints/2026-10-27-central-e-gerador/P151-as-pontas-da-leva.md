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

## Execução
