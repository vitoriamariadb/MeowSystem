# Sprints do MeowSystem-Theme

Este arquivo é **autossuficiente**: quem for executar uma sprint não precisa de
nenhum contexto de conversa anterior. Cada uma traz o que já foi medido, o que
fazer, em que arquivo, como conferir que ficou certo, e o que pode dar errado.

Última atualização: **05/08/2026**.

---

## Como este projeto trabalha (leia antes de qualquer sprint)

**O alvo é uma máquina só.** Em 05/08/2026 foi decidido que o repositório **não
será publicado**: ele existe para deixar o COSMIC da Vitória funcional e bonito.
Acoplar a esta máquina é permitido — caminhos absolutos, `apt`, o uid 987 do
`cosmic-greeter`, os `.desktop` dos jogos dela. O que continua obrigatório é
outra coisa: **não destruir dado dela** e **não brigar com o Ritual da Aurora**.

**Não reinventar a roda.** Regra explícita dela. Preferir pacote pronto de
terceiro a desenhar do zero. Ela rejeitou os ícones autorais que o projeto
gerava ("sinceramente são péssimos") depois de ver a folha de comparação.

**Medir, não supor.** Toda afirmação vem com o comando que a produziu. Uma
conclusão plausível e não medida é o defeito que este projeto mais combate.

**Os códigos de saída são a interface.**

| código | significado | o auto-reparo faz o quê |
|---|---|---|
| 0 | já estava certo | nada |
| 1 | divergia e foi consertado | conserta, e **notifica** |
| 2 | erro de verdade | falha alto |
| 3 | falta dependência | pula, avisa |
| 4 | divergente **por escolha dela** | mostra e **não mexe**, sem notificar |

O 4 existe por causa do timer: `meow-doctor.timer` roda todo dia às 5h e o
`ExecStopPost` notifica **só quando o código é 1**. Um estado que não tem
conserto possível, saindo 1, viraria "o auto-reparo corrigiu" toda madrugada,
sem nada ter sido corrigido. Foi ela quem apontou esse risco.

**Idempotência é conferida, não prometida.** Toda sprint termina com
`./install.sh` duas vezes: a segunda não pode escrever um byte.

**Comparar do mesmo jeito que se escreve.** `meow_escrever` grava com
`printf '%s'`, que come o `\n` final — um `cmp` byte a byte acusa divergência
eterna num arquivo que está perfeito. Já custou um `--conferir` que gritava 123
divergências num tema correto. Se o escritor é `meow_escrever`, o conferidor
compara com `$(cat ...)`; se o escritor é `cp` (binário), aí sim `cmp`.

**Um dono por arquivo.** Dois programas escrevendo o mesmo arquivo é o modo de
falha que mais custou a este projeto (`custom_logo_path`, e o tema derivado da
GUI). Quem não é dono apenas confere.

---

## O acervo de ícones que existe hoje, e o que cada um cobre

Três fontes, e confundi-las já causou erro. **Leia esta tabela antes de mexer em
ícone.**

| fonte | onde | o que é | cobre |
|---|---|---|---|
| `catppuccin/vscode-icons` | `icons/catppuccin/<flavor>/` | 656 glifos × 4 flavors, MIT, linha fina pastel. É o pack do Iconify (`catppuccin:*`) e do allsvgicons — **os três links são o mesmo acervo**. | **tipos de arquivo** e **pastas**. 123 mimetypes instalados. |
| `Daveedmee/catppuccin-icons` | `icons/catppuccin-apps/<macchiato\|latte>/` | 146 PNG 512×512 com alpha. As marcas conhecidas recoloridas em pastel. **Sem licença declarada** — uso local, nunca redistribuir. | **aplicativos**. 16 instalados. |
| desenho autoral | `src/icons/autorais/` | 10 SVG × 4 flavors, gerados por `scripts/gerar_icones_autorais.py`. | os 8 apps do COSMIC + FogStripper + Hefesto. |

### A correção que precisa ficar registrada

Foi dito nesta conversa que "o pack `catppuccin/vscode-icons` não tem nenhum
ícone de aplicativo, só `figma`". **Isso está errado.** O pack tem pelo menos 23
glifos de marca de software:

```
adobe-ae adobe-ai adobe-id adobe-ps adobe-xd angular django docker figma
gitlab godot go java kotlin laravel npm python rust svelte swift unity vue
```

O que é verdade é outra coisa, e é o que foi de fato medido: **desses 23, só o
`vscode` corresponde a um aplicativo instalado nesta máquina**. Os outros são
marcas de coisas que ela não usa, e no pack eles representam o **formato de
arquivo** (o `adobe-ps.svg` é o ícone do `.psd`, não do programa Photoshop) —
embora nada impeça usá-los como ícone de aplicativo, se um dia ela instalar
Blender, Godot, Unity ou Docker Desktop.

Comando que produz a lista:

```bash
ls icons/catppuccin/macchiato/ | sed 's/.svg$//' \
  | grep -xE 'adobe-.*|figma|docker|gitlab|python|rust|go|java|godot|unity|blender'
```

### O que NÃO se toca, por pedido expresso dela

Os jogos da Steam (`steam_icon_*`), o **Hefesto** (a logo é dela) e o
**FogStripper**. `scripts/icones_apps.sh` recusa esses nomes mesmo que entrem no
mapa — a lista está em `INTOCAVEIS` e `INTOCAVEIS_PREFIXO`.

---

## O achado que destrava as Sprints A e B: **Arcticons**

Foi ideia dela, em duas frases: *"allsvgicons.com não conseguiríamos nenhum outro
pack que pudesse complementar as lacunas do nosso?"* e *"por serem svgs se
acharmos algum que prestasse poderíamos alterar as cores sei lá."*

**Medido em 05/08/2026, pela API do Iconify:**

```
Arcticons · 14.913 ícones · CC BY-SA 4.0
```

Licença **livre e que permite modificar** — é o que autoriza recolorir. São
ícones de **linha, monocromáticos**, feitos para nomear aplicativos Android, o
que na prática significa um catálogo enorme de programas e de conceitos de
sistema. Testado contra as lacunas exatas que sobraram aqui:

| lacuna | Arcticons tem? |
|---|---|
| `wifi` `bluetooth` `settings` `volume` `battery` | **sim** — são os ícones de sistema da Sprint A |
| `calculator` `camera` `keyboard` `monitor` `mail` | **sim** — o pack `vscode-icons` não tinha nenhum |
| `thunderbird` `krita` `discord` | **sim**, pelo nome exato |
| `gimp` `flatseal` `boxy` | não |

Comando que reproduz:

```bash
curl -s "https://api.iconify.design/search?query=<termo>&prefix=arcticons&limit=5" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('icons'))"
```

**Por que isso muda o desenho das duas sprints.** Monocromático de linha é
*matéria-prima*, não produto acabado: uma cor só, trocável com um `sed` no
`stroke`/`fill`. E este projeto já tem a fonte única de cor — `palette/catppuccin.json`,
com a regra de que **nenhum hex vive dentro de script**. Recolorir Arcticons para
Catppuccin é o encaixe mais natural que apareceu até agora, e é barato.

**Cuidados antes de sair recolorindo:**

- **CC BY-SA 4.0 é _share-alike_ com atribuição.** Uso local não exige nada, mas
  registre a procedência em `icons/PROCEDENCIA.md` como o projeto já faz para
  Papirus e papirus-folders. Se um dia houver publicação, o share-alike passa a
  ter consequência.
- **Baixe pela API do Iconify, não o repositório inteiro** (são ~15 mil ícones).
  `https://api.iconify.design/arcticons/<nome>.svg` devolve um SVG por vez, e
  `?color=%23cba6f7` já devolve **recolorido** — vale medir se isso basta e
  poupa o passo de recolorir na mão.
- **Estilo:** linha fina monocromática ao lado dos ícones pastel cheios do
  lançador. Pode ficar coerente (o painel já é monocromático) ou pode brigar.
  **Folha visual antes**, pelo método da Sprint B, a 22 px e a 48 px.
- Um ícone genérico bem escolhido é aceitável aqui, ao contrário do caso das
  marcas: `settings` para Configurações **não mente** sobre o que a coisa é.

---

## Sprint A — Os ícones do próprio COSMIC  ← **a que ela mais quer**

**Por que existe.** Ela mandou a tela das Configurações (Rede, Bluetooth,
Acessibilidade, Área de trabalho, Telas, Som, Energia e Bateria, Dispositivos de
entrada, Aplicativos, Hora e Idioma, Sistema e Contas) e disse: *"até os applet e
icons do próprio sistema operacional quero mudar. Tipo tudo tudo mesmo."* E
reforçou logo depois: *"inclusive os icons do sistema."* Repetir um pedido é o
sinal mais forte que existe neste projeto — **esta sprint tem prioridade sobre a
ordem sugerida no fim do arquivo.**

O alcance é os dois: as **páginas das Configurações** e os **applets da barra**
(bateria, som, rede, bluetooth, notificações, relógio).

**O que já se sabe, e muda a abordagem.** Esses ícones são `symbolic`:
monocromáticos, com uma única cor, **recolorida pelo toolkit em tempo de
desenho**. Não adianta procurar por eles nos dois packs — nenhum os tem, e o
problema não é de mapeamento, é de geração.

**Primeiro passo obrigatório: descobrir de onde eles vêm.** Não presuma.

```bash
# 1. quais ícones a página de Configurações pede
strings -a /usr/bin/cosmic-settings | grep -E '^[a-z-]+-symbolic$' | sort -u

# 2. onde cada um resolve HOJE, no resolvedor real (não com find)
python3 - <<'EOF'
import gi; gi.require_version("Gtk","3.0")
from gi.repository import Gtk
t = Gtk.IconTheme.new(); t.set_custom_theme("MeowSystem-Icons")
for n in ["network-wireless-symbolic","bluetooth-symbolic","audio-volume-high-symbolic"]:
    i = t.lookup_icon(n, 24, 0)
    print(n, "->", i.get_filename() if i else "(nada)")
EOF

# 3. de que pacote vem
dpkg -S /usr/share/icons/Cosmic/scalable/... 2>/dev/null
```

**Decisão a tomar com ela, não sozinho.** Symbolic monocromático **já segue o
tema** — a cor vem do `CosmicTheme`. Então há duas leituras possíveis do pedido:

1. *"estão com a cor errada"* → o conserto é no tema, não nos ícones.
2. *"quero eles coloridos/pastel como os do lançador"* → é desenho novo, e é
   exatamente o caminho que ela rejeitou uma vez ("péssimos").

**Antes de escrever qualquer código, monte uma folha de comparação e mostre a
ela.** Foi assim que a decisão dos ícones autorais foi tomada, e foi assim que se
descobriu que 19 dos 27 candidatos eram logomarca. O método está na Sprint B.

**Risco declarado:** substituir symbolic por colorido no painel pode ficar
poluído — a barra tem 8 ícones em 22px. O que funciona no lançador a 64px não
funciona ali. Rasterize a 22px e olhe antes de propor.

**Como conferir:** `Gtk.IconTheme.lookup_icon` para cada nome, a 22px e 24px,
mostrando de qual tema veio. Nunca `find`: o Papirus tem link simbólico no
**nível do tamanho**, e `find` sem `-L` não desce nele — isso já fabricou uma
lista falsa de "12 ícones faltando" que na verdade era zero.

---

## Sprint B — Curadoria assistida: candidatos para os apps sem ícone

**Por que existe.** Ideia dela, textual: *"os que não encontrarem peça pros
frentes procurarem semelhantes usando regex similares e criando uma lista com os
possíveis icons e eu escolho."*

**O estado atual, medido.** Dos 51 aplicativos com ícone nesta máquina:

- 16 já usam o acervo Catppuccin de aplicativo (`icons/apps.map`)
- 10 usam desenho autoral (8 do COSMIC + FogStripper + Hefesto)
- **os demais continuam no Papirus** — e são o alvo desta sprint

Para gerar a lista dos que faltam:

```bash
./scripts/auditar_icones.sh --json > /tmp/audit.json
python3 - <<'EOF'
import json, glob, os
d = json.load(open('/tmp/audit.json'))
mapeados = {l.split(':')[0] for l in open('icons/apps.map')
            if l.strip() and not l.startswith('#')}
for a in d['aplicativos']:
    if a['icone'] not in mapeados and 'Papirus' in a['tema']:
        print(f"{a['icone']:38} {a['nome']}")
EOF
```

**O trabalho dos frentes.** Um frente por aplicativo órfão, em paralelo. Cada um
recebe: o nome do `.desktop`, o nome legível do app, e os dois acervos. Cada um
devolve **até 5 candidatos**, cada candidato com: o arquivo, por que ele foi
sugerido, e um veredito honesto de se ele **mente** sobre o que é o aplicativo.

A busca é por regex sobre os nomes dos dois acervos, mais o nome legível:

```bash
ls icons/catppuccin/macchiato/ icons/catppuccin-apps/macchiato/ \
  | sed 's/\.\(svg\|png\)$//' | grep -iE '<termo>'
```

### Exemplo já trabalhado: a busca por semelhança funciona, e falha

Ela levantou o caso e a hipótese: *"loja de aplicativos e afins, se o regex
falhar temos opções similares. aposto que deve ter um shop ou um folder
específico que se encaixe."* Testado em 05/08/2026, com o comando acima:

| termo buscado | achou |
|---|---|
| `shop\|store\|market\|cart\|bag\|package\|app` | **`folder_app`, `folder_packages`** — a aposta dela procede |
| `book\|read\|library` | `folder_storybook`, `mdbook`, `readme` |
| `camera\|photo\|snap` | só `photoshop` (é outra coisa) |
| `calc\|math` · `keyboard\|input` · `clean\|broom` · `disk\|drive` · `monitor\|cpu` · `mail\|email` | **nada** |

Ou seja: a busca por semelhança **resolve uma parte e não resolve o resto**, e o
motivo é estrutural — o pack `vscode-icons` é de **desenvolvimento**, então tem
`folder_packages` e não tem calculadora. Onde ele não alcança, os candidatos vêm
do acervo de aplicativo (`icons/catppuccin-apps/`) ou não existem, e aí o ícone
fica no Papirus e isso é dito na folha em voz alta, em vez de forçar um
casamento ruim.

**Ícone de pasta como ícone de aplicativo é decisão dela, não sua.** `folder_app`
na Loja de Aplicativos pode ficar excelente ou pode confundir pasta com programa.
Entra na folha como candidato marcado, com o veredito honesto ao lado.

**A regra que decide, e ela custa cobertura de propósito:** só entra quando é o
**mesmo aplicativo**. Já foram descartados, com correspondência tentadora e
falsa: `BoxySVG → inkscape`, `CosmicEdit → notepad`, `ProtonUp-Qt → lutris`,
`BleachBit → ccleaner`. **Um ícone errado é pior que um genérico, porque mente
sobre o que a coisa é.** Se o frente achar que vale mesmo assim, ele marca como
"parecido, não é o mesmo" e deixa a decisão para ela.

**A entrega é uma folha visual, não uma tabela de texto.** Cada órfão numa
linha: o ícone atual do Papirus e os candidatos ao lado, todos a 48px, cada um
sobre os **dois fundos** — Mocha `#1e1e2e` à esquerda, Latte `#eff1f5` à direita,
divididos na vertical, com o ícone em cima da fronteira. Isso não é enfeite: o
defeito de 04/08 foi ícone sumindo sobre papel de parede claro, e a divisão
diagonal (tentada antes) joga o ícone quase todo sobre um lado só.

Gere como **HTML standalone**, com os SVG/PNG embutidos em data URI, salvo em
`~/`. Ela pediu explicitamente "html standalone sem artifacts". Confira o
resultado antes de entregar renderizando em headless:

```bash
google-chrome --headless=new --disable-gpu --no-sandbox \
  --user-data-dir=/tmp/ch --window-size=1280,2400 --hide-scrollbars \
  --screenshot=/tmp/folha.png "file://$HOME/<arquivo>.html"
```

**Depois que ela escolher:** as linhas entram em `icons/apps.map` e
`./scripts/icones_apps.sh --aplicar` faz o resto. O script já remove órfão (o
diretório tem dono único) e já é idempotente.

---

## Sprint C — As pastas do Gestor de Arquivos

**Por que existe.** A tela que ela mandou dizendo *"esses são os ícones que eu
quero"* era a página do pack mostrando `folder-debug`, `folder-docker`,
`folder-github`, `folder-images`. São ícones de **pasta**, e é o que ela vê no
Gestor de Arquivos.

**O que está medido:**

- o pack tem **228** ícones de pasta (`folder_*.svg`, com **underscore** — o site
  e o Iconify mostram com hífen porque normalizam; no repositório é underscore)
- **14** casam com nomes de pasta que o sistema usa: `folder-android`,
  `folder-cloud`, `folder-docker`, `folder-download`, `folder-git`,
  `folder-github`, `folder-gitlab`, `folder-images`, `folder-linux`,
  `folder-private`, `folder-public`, `folder-temp`, `folder-templates`,
  `folder-video`
- hoje as pastas dela vêm do `papirus-folders` em `cat-mocha-mauve` (roxas),
  instaladas por `scripts/construir_pastas.sh`

**Decisão a tomar com ela:** as 14 pastel do pack conviveriam com as roxas do
`papirus-folders` — pastas de tipos diferentes com estilos diferentes. Pode ficar
ótimo (destaque para pastas especiais) ou pode ficar inconsistente. **Folha
visual antes**, pelo método da Sprint B.

**Cuidado com dois donos:** `construir_pastas.sh` já é dono de
`<tam>/places/folder-*`. Se estes forem para o mesmo diretório, os dois scripts
brigam a cada rodada — o laço eterno que o `construir_icones.sh` documenta no
próprio cabeçalho. Ou o novo script escreve em `scalable/places/` (diretório
próprio, dono único, e a ordem de `Directories=` decide quem ganha), ou o
`construir_pastas.sh` passa a conhecer a lista e cede.

---

## Sprint D — O `install.sh` como wizard

**Por que existe.** Pedido dela, textual: *"o install faz dele wizard pra eu ir
modificando e afins."*

**O conflito a resolver primeiro.** O cabeçalho do `install.sh` diz, hoje:

> **POR QUE NÃO TEM FLAG** — quem decide o que instalar é o `meow.conf`, não a
> linha de comando. Uma flag a menos é uma decisão a menos na hora de usar.

Um wizard **não contradiz** isso, desde que ele seja um jeito de **editar o
`meow.conf`** — e não um segundo lugar onde as decisões moram. A regra: o wizard
pergunta, grava no `meow.conf`, e depois roda o instalador de sempre. Duas fontes
de verdade seria o mesmo defeito de "dois donos".

**Desenho:**

- `./install.sh` sem argumento continua fazendo exatamente o que faz hoje. O
  wizard é `meow configurar` (ou `./install.sh --wizard`), nunca o padrão: o
  instalador roda em timer e por script, e um prompt ali travaria tudo.
- Ele só pergunta o que está no `meow.conf`: `FLAVOR`, `ACCENT`, `MODO`, `LOGO`,
  `ICONES_FLAVOR`, `VIDRO_*`, `WALLPAPER_*`, `APPS_ATIVOS`.
- Mostra o valor atual como padrão. Enter mantém.
- Grava com `meow_escrever` (atômico, e não escreve se nada mudou).
- **Nunca pergunta quando não há terminal interativo.** O teste é `[ -t 0 ]` —
  já é o padrão do projeto para as duas perguntas que existem na CLI.
- No fim, mostra o diff do que mudou e pergunta se aplica agora.

**Onde mexer:** `bin/meow` (novo `cmd_configurar`), `install.sh` (a flag),
`zsh/_meow` (completion), `meow.conf.exemplo` (é a lista de chaves e a fonte dos
comentários que o wizard mostra como ajuda).

**Como conferir:** rodar o wizard aceitando tudo com Enter não pode escrever um
byte no `meow.conf`. `MEOW_DRY_RUN=1` também não. E `echo | ./install.sh` (stdin
não-tty) tem de seguir o caminho de sempre, sem travar.

---

## Sprint E — Sincronização automática dos assets

**Por que existe.** Pedido dela em 05/08: *"o comando do meow tem que disparar em
automático, talvez no self heal algo assim"* — sobre soltar um arquivo na pasta e
ele entrar sozinho.

**O estado hoje:**

- `assets/gatos/` é a interface da logo: soltar um `.svg` ali o põe na rotação —
  mas só na próxima volta do `meow-logo.timer`, que é de **30 minutos**
- os papéis de parede entram na hora, porque o `cosmic-bg` lê a pasta
- não existe `meow-assets.path`

**Desenho:** uma unit `.path` do systemd de usuário, do **próprio MeowSystem** —
nunca pendurada no self-heal do Aurora, que é de outro projeto e que ela pode
desativar.

```ini
[Path]
PathModified=%h/... ou o diretório do repo
Unit=meow-assets.service
```

**Duas armadilhas medidas neste projeto, e as duas mordem aqui:**

1. **O caminho é `/mnt/Apate`**, que pode estar desmontado. Uma unit `.path`
   apontando para um diretório inexistente falha no boot. Precisa de
   `ConditionPathIsDirectory=` e de degradação silenciosa.
2. **`StandardOutput=append:` é montado antes de tudo**, inclusive antes de
   `StateDirectory=`. Se o diretório de log não existir, o serviço falha com
   `Failed to set up standard output` e nada mais roda. Está documentado no
   cabeçalho de `systemd/meow-doctor.service` — releia antes de escrever a unit.

**Cuidado com o laço:** o serviço disparado pela mudança **não pode escrever
dentro do diretório vigiado**, ou ele se redispara para sempre. O `logo.sh`
remove órfão do acervo — confira se o alvo dele está fora do caminho vigiado.

**Como conferir:** soltar um `.svg` em `assets/gatos/`, esperar, e ver a logo
mudar sem comando nenhum. Depois `systemctl --user status meow-assets.path` e o
journal, para provar que disparou **uma vez** e não em laço.

---

## Sprint F — Podar o que só existia para publicação

**Por que existe.** A decisão de não publicar tornou obsoleto um bloco de
trabalho que estava planejado e um bloco de texto que já está escrito.

**Sai (não fazer, e remover o que promete fazer):**

- abstração de gerenciador de pacotes além do `apt` (era para Fedora/Arch/NixOS)
- detecção de schema do COSMIC de outra versão, para capturas de tema
- camada única de detecção do Ritual da Aurora (`lib/aurora.sh`)
- a seção **"Noutra máquina"** do `README.md`, que promete portabilidade
- o `README.md` diz *"ele vai ser público"* ao justificar os 136 MB de wallpaper
  fora do git — a razão mudou, o efeito continua certo (imagem em git é dívida)

**Fica, e não é negociável:**

- **o backup antes do `rm -f`** em `scripts/aplicar_tema.sh`. Ele nunca foi sobre
  publicar: é o que protege o tema **dela** de ser apagado sem volta.
- **a não-briga com o Ritual da Aurora.** O Aurora roda nesta máquina, como root,
  a cada hora. Continua valendo integralmente.
- **a degradação elegante** (pular e avisar quando a superfície não existe). Não
  é portabilidade: é o que faz o instalador não explodir quando um app não está
  instalado.

**Como conferir:** `./install.sh` duas vezes, `meow doctor` verde, e nenhuma
promessa no README que o código não cumpra.

---

## Estado atual — o que já está no ar

| entregue em 05/08/2026 | prova |
|---|---|
| 123 tipos de arquivo em Catppuccin | 14/14 alvos resolvem no pack pelo `Gtk.IconTheme` |
| 16 aplicativos do lançador em Catppuccin | Firefox, Discord, Spotify, VLC, Steam conferidos no resolvedor |
| 242 wallpapers (eram 239) | 3 faltavam por bug de URL não escapada, calado desde a 1ª semeadura |
| o tema parou de desfazer o vidro dela | fronteira por árvore + código 4, testados em COSMIC isolado |
| o doctor enxerga receita ≠ produto | `'Low2' pede alpha 7C, está gravado D9` |

**Pendência que depende dela, e leva 2 segundos:** o vidro no disco ainda é o da
captura (`D9`) e não o que ela escolheu (`7C`), porque o estrago de 05/08 às
18:00:36 já foi consolidado. **Ela precisa abrir Aparência e mover o slider de
opacidade uma vez** — só a GUI faz a derivação completa. Escrever esse valor na
mão seria repetir o ato que causou o problema.

---

## Ordem sugerida

**A vem primeiro** — ela pediu duas vezes, e a segunda foi só para reforçar. Mas
comece pela **medição**, não pelo código: descobrir de onde os ícones vêm e
mostrar a folha antes de decidir. Se a medição travar, **B** (curadoria dos
ícones que faltam) tem o maior ganho visível e já tem método pronto, e **C**
(pastas) é irmã dela e sai na mesma folha. **D** e **E** são infraestrutura e não
mudam pixel. **F** é limpeza e pode ir a qualquer momento.

Ela está trabalhando na própria máquina enquanto isto roda. Nada de abrir janela
na tela dela; para ver o resultado, renderize em headless ou peça que ela olhe.
