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

### A direção estética, definida por ela olhando as duas telas

Ela comparou a página do Arcticons com o `catwalk.webp` do `catppuccin/vscode-icons`
e fechou o desenho numa frase: *"esse primeiro pack parece que se encaixa legal
no estilo que queremos né? Só precisaríamos deixar as cores mais fortes de acordo
com a logo do app original."*

Isso é **exatamente** o que o `vscode-icons` faz, e é o que dá coerência ao
conjunto: **traço fino monocromático + UMA cor por ícone, escolhida por afinidade
com a marca original.** O Firefox puxa `peach`, o Spotify puxa `green`, o Discord
puxa `blue` — cada um reconhecível, todos na mesma paleta.

O Arcticons é a matéria-prima certa para isso porque já é **traço puro**: o pack
se descreve como *Logos*, grid de 48 px, e vem sem cor própria. Colorir é atribuir
uma cor, não repintar um desenho.

**O método, e ele é automatizável:**

1. para cada aplicativo, pegar a cor dominante da marca real — a fonte natural é
   o ícone que o Papirus já entrega, que é colorido e está no disco
2. converter para **Oklab** e achar a cor Catppuccin mais próxima em matiz, não
   em RGB (frentes deste projeto já escreveram esse conversor duas vezes; a
   pesquisa em `docs/pesquisas/` tem os números)
3. aplicar no `stroke`/`fill` do SVG do Arcticons
4. gerar nos 4 flavors, como todo o resto do projeto

**Duas armadilhas já medidas neste projeto, e as duas mordem aqui:**

- **A paleta não tem cor escura E saturada.** Croma máximo 0,039 entre as cores
  com L < 0,55. Marcas escuras (GitHub, Steam) vão para um tom claro ou para um
  neutro — decidir explicitamente qual, e registrar.
- **Duas marcas podem cair na mesma cor Catppuccin.** Já existe um caso no disco:
  com `--accent green`, `cosmic-files` e `cosmic-term` nascem gêmeos em silêncio.
  O gerador precisa de uma asserção que **estoure** quando dois ícones do mesmo
  contexto recebem a mesma cor, em vez de deixar passar.

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

## Sprint A — Os ícones do próprio COSMIC  ← **FEITA em 05/08/2026, em parte**

> **O que entrou:** as **21 páginas das Configurações** + 7 ícones únicos, pelo
> `icons/sistema.map` e `scripts/icones_sistema.sh`. Provado com `strace`: o
> `cosmic-settings` carrega os ícones novos do `scalable/status`.
>
> **O que NÃO entrou, e é medição, não desistência:** a **barra**. Os applets são
> famílias de estado (`audio-volume-*` em 5, `network-wireless-*` em 7,
> `microphone-sensitivity-*` em 4) e o Arcticons tem **zero** sufixos `-off`,
> `-mute`, `-muted`, `-disabled`, `-low`, `-high`, `-medium` — medido contra o
> índice completo dos 14.996 nomes. Vestir um estado só faria o ícone mudar de
> estilo conforme o volume. Continua no Papirus.
>
> **O que sobrou para decidir com ela:** se vale desenhar as variantes de estado
> à mão (é desenho autoral, que ela já rejeitou uma vez) ou procurar um terceiro
> pack que as tenha. **Enquanto não houver decisão, a barra fica como está.**
>
> Leia `docs/COSMIC-THEMING.md` §4g antes de mexer: a cor do arquivo é jogada
> fora pelo toolkit, e a escolha de tamanho não é pela ordem de `Directories=`.

### O registro de como a sprint foi conduzida (o histórico abaixo continua válido)

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

## Sprint B — Curadoria assistida  ← **folha pronta, ESPERANDO A ESCOLHA DELA**

> **A folha está em `~/folha-apps-orfaos.html`.** Nada foi aplicado: esta sprint
> termina na escolha dela, e o `icons/apps.map` segue intocado.
>
> **Três números do texto abaixo estão errados, e foram medidos de novo:**
> os órfãos são **12**, não 25 (nem os 35 que o cabeçalho do `apps.map` afirma).
> Os outros já resolvem fora do Papirus: 7 jogos Steam em `hicolor`, 3 flatpaks,
> 1 por caminho absoluto, e o `thunderbird` já está no `MeowSystem-Icons`.
> **Zero candidatos são o mesmo aplicativo** — pela regra dura, nada entra
> sozinho. 18 são genéricos honestos, 26 mentem, 1 app não tem nada.
>
> **A busca por regex sobre nomes é necessária e insuficiente** — três dos
> melhores candidatos são invisíveis a ela, e só apareceram rasterizando os 428
> glifos e olhando: `lib.svg` são três livros (Foliate), `security.svg` é uma
> câmera (Snapshot), `verilog.svg` é um chip (btop).
>
> **O alerta que não estava previsto:** sete dos candidatos mais honestos são
> traço monocromático na cor `text`. Medido em contraste WCAG, o traço macchiato
> `#CAD3F5` dá **11,0:1 sobre Mocha e 1,3:1 sobre Latte** — some. Trocar de
> flavor inverte o lado (`#4C4F69`: 2,1:1 e 7,1:1), e o `icones_apps.sh` instala
> um flavor por vez. É o defeito de 04/08 outra vez, agora com número. Os
> candidatos coloridos e os PNG do acervo de aplicativo não têm esse problema.
>
> **Custo escondido:** candidato do `catppuccin-apps` é uma linha no mapa;
> candidato do pack `vscode-icons` **não é** — o `icones_apps.sh` só lê
> `icons/catppuccin-apps/$VARIANTE/*.png` e escreve em `512x512/apps`.

### O registro de como a sprint foi desenhada (continua válido)

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

## Sprint C — As pastas  ← **a premissa está ERRADA; folha em `~/folha-pastas.html`**

> **O `cosmic-files` não pede 12 das 14.** Medido casando por dicionário os 2.480
> nomes de `places` do disco contra `strings -a /usr/bin/cosmic-files`: o binário
> contém **12** nomes de pasta, e das 14 desta sprint só **duas** aparecem —
> `folder-download` e `folder-templates`.
>
> O motivo é estrutural: `folder-github`, `folder-docker` e companhia são apelidos
> do Papirus para o **Dolphin/KDE**, que lê um `.directory` dentro da pasta. O
> `cosmic-files` **não tem essa lógica** — `.directory` aparece **zero** vezes no
> binário. Instalar as 12 seria instalar ícone que ela nunca veria.
>
> **O casamento que vale é outro:** os nomes XDG que ele de fato pede. O pack
> cobre 8 dos 12, mas com outro nome (`folder_images`→`pictures`,
> `folder_audio`→`music`, `folder_docs`→`documents`, `folder_video`→`videos`,
> `folder_public`→`publicshare`). **Entra por renomeio, e é decisão dela.**
>
> **Dois fatos que ninguém tinha visto:** `folder-docker` **já é azul** hoje (o
> `papirus-folders` não tem variante mauve dela, e ela cai no Papirus) — a mistura
> de estilos que esta sprint pergunta se ela aceita **já está na tela**. E
> **nenhum dos 14 ícones do pack usa `mauve`**, que é o accent dela.
>
> **Dois donos — a resposta medida é (b), e (a) não funciona.** O
> `construir_pastas.sh` reproduz todo apelido do Papirus e reescreve o link quando
> `readlink` diverge; um arquivo regular ali devolve `readlink` vazio e o
> `ln -sfn` o substitui. **9 das 14 seriam apagadas a cada ciclo** (passe 1) e
> **5 passariam batido** (passe 2, que tem `[ -e ] && continue`) — metade quebra
> alto, metade em silêncio. E (a) não decide nada, porque quem escolhe o
> diretório é o **tamanho**, não a ordem de `Directories=` (ver §4g). A saída é o
> `construir_pastas.sh` conhecer a lista e ceder, como o `icones_apps.sh` já faz
> com `INTOCAVEIS`. Cuidado com `folder-videos → folder-video`, que é cadeia de
> nível 2: ceder o segundo faz o primeiro virar pastel de carona.

### O registro de como a sprint foi desenhada (o resto continua válido)

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

## Sprint D — O wizard  ← **FEITA em 05/08/2026**

> `meow configurar` (e `./install.sh --wizard`). O esquema — ordem, seções, ajuda
> — é **lido do `meow.conf.exemplo`**, não de uma lista dentro do script: são
> **31 chaves**, e a lista que este arquivo dava estava incompleta.
>
> **O defeito que a implementação revelou:** o `meow.conf.exemplo` tinha
> `LOGO_INTERVALO=` **duas vezes** (`30m` e `1d`). O `.` do shell obedece a
> **última**; o `conf_definir` escrevia a **primeira** — ou seja, o `meow` dizia
> "gravado" e o valor em vigor não mudava. Corrigido, e vale como regra: a
> premissa "o exemplo é a lista de chaves" só se sustenta sem chave repetida.
>
> Provado: ENTER em tudo não escreve um byte · `MEOW_DRY_RUN=1` não escreve ·
> `echo | ./install.sh` não trava e não pergunta · sem tty o wizard diz "sem
> terminal interativo" e segue · o `install.sh` duas vezes não escreve nada.

## O texto original da sprint (o desenho continua válido)

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

## Sprint E — Sincronização automática dos assets  ← **FEITA em 05/08/2026**

> **O que entrou:** o par `systemd/meow-assets.path` + `systemd/meow-assets.service`,
> instalado e conferido por `scripts/vigia_assets.sh`, ligado no `install.sh`
> (`etapa_assets`) e no `meow doctor` (`chk_assets`/`fix_assets`, verificável
> `assets`). Duas chaves novas no `meow.conf`: `ASSETS_VIGIA` e
> `ASSETS_VIGIA_NOTIFICAR`.
>
> **A prova:** com o vigia ligado e 10 s de silêncio medidos antes, um `.svg`
> solto em `assets/gatos/` disparou **exatamente uma vez** (23:22:44) e o gato
> apareceu em `~/.config/cosmic/logos/`; apagá-lo disparou **exatamente uma vez**
> (23:23:10) e o órfão saiu do disco. `./install.sh` rodou duas vezes inteiras
> sem disparar o vigia nenhuma vez, e a segunda não escreveu um byte.
>
> **O que ele NÃO faz, de propósito:** não gira o gato. Acrescentar um arquivo
> não muda qual está no ar — quem gira é o relógio, um por dia, que foi a escolha
> dela. E o gato do dock só troca no login seguinte, porque o `cosmic-panel` não
> tem watch de inotify sobre arquivo de ícone (já medido neste projeto). Por isso
> o serviço avisa por `notify-send` quando o acervo muda: sem o aviso, o recurso
> rodaria, devolveria sucesso e não mostraria nada.

### O que a medição CONTRADISSE nesta sprint

A armadilha 1 desta sprint dizia, textualmente: *"Uma unit `.path` apontando para
um diretório inexistente falha no boot. Precisa de `ConditionPathIsDirectory=` e
de degradação silenciosa."* **As duas metades estão erradas**, e a receita
produziria o defeito que ela queria evitar. Medido em 05/08/2026, systemd 255:

| teste | resultado |
|---|---|
| `.path` com `PathModified=/mnt/NAO-EXISTE/repo/assets/gatos`, sem condição | **`active (waiting)`** — não falha. O systemd vigia o ancestral que existe (`/mnt`) e espera |
| o mesmo, criando o diretório depois e soltando um SVG | disparou **2 vezes** (criação do diretório e chegada do arquivo) — ou seja, o vigia se cura sozinho quando o Ápate monta |
| `.path` **com** `ConditionPathIsDirectory=` e o diretório ausente | `ConditionResult=no`, `ActiveState=inactive` |
| o mesmo, criando o diretório depois e soltando um SVG | disparou **0 vezes** — condição de unidade é avaliada na PARTIDA, e nada a reavalia |

Conclusão: no cenário exato que a condição existia para cobrir — `/mnt/Apate`
desmontado no boot e montado depois — ela troca um vigia que se recupera sozinho
por um vigia morto e calado. A degradação silenciosa foi para o **serviço**
(`ConditionPathExists=` no ponteiro da raiz, que mora em `/home`, mais o
`[ -x "$R/scripts/logo.sh" ] || exit 0` do `ExecStart`).

A armadilha 2 **se confirmou** e continua valendo: com o diretório de log
ausente, `StandardOutput=append:` derruba o serviço com `Failed to set up
standard output: No such file or directory`, `status=209/STDOUT`, antes de
qualquer comando. Quem garante o diretório é o `mkdir -p` do
`scripts/vigia_assets.sh`.

### O laço: conferido no código, não suposto

Medido que a armadilha é real — escrever **ou apagar** um arquivo dentro do
diretório vigiado dispara a unidade; escrever no diretório **pai** (`assets/`)
**não** dispara, o que é o que torna seguro o `gerar_gato.py` reescrever
`assets/meow-<flavor>.svg` a cada instalação.

Lidas as escritas do `logo.sh`, todas caem fora do caminho vigiado:
`~/.config/cosmic/logos/`, a chave do applet `dev.cappsy`,
`~/.local/state/meowsystem/logo-atual` e os botões do dock em
`~/.local/share/icons/<tema>/scalable/apps/`. O `rm -f` que esta sprint mandava
conferir mira em `$LOGOS_DIR` — que é `~/.config/cosmic/logos` —, nunca no
acervo. E o `StartLimitBurst=20`/`StartLimitIntervalSec=60s` do serviço é o
disjuntor caso alguém quebre essa regra um dia: testado forçando 25 partidas
seguidas, o par foi para `failed`, o `meow doctor` acusou e o `--consertar` fez
`reset-failed` e religou.

### Dois detalhes de systemd que custam uma tarde

- **`$R` sim, `${R}` não.** O systemd expande `${NOME}` na linha de `Exec` mesmo
  dentro de aspas simples, e variável que ele não conhece vira string vazia.
  Testado: `sh -c 'R=abc; printf "[%s][%s]" "$R" "${R}"'` imprimiu `[abc][]`. Já
  `${NOME:-padrão}` passa inteiro (o `:` não é nome de variável válido) e quem
  expande é o shell — `DEF=doshell; "${DEF:-fallback}"` saiu `doshell`. É por
  isso que as unidades deste projeto só usam essas duas formas.
- **Nenhuma aspa dentro do texto do `notify-send`.** O systemd entrega o script
  inteiro ao `sh` como UM argumento; uma aspa dupla escapada no meio da mensagem
  FECHA a string e o corpo se parte em três argumentos, que o `notify-send`
  recusa. Pego aqui com `systemctl --user show -p ExecStopPost` antes de virar
  bug.

---

## Sprint F — A poda  ← **FEITA em 05/08/2026, e não era código**

> **Nenhum dos três itens de código existia.** Medido antes de remover:
> `lib/aurora.sh` não existe (só `comum.sh`); `dnf|pacman|zypper|nix-env|
> rpm-ostree|emerge|apk` dão **zero** ocorrências; não há detecção de schema.
> A poda foi de **promessa**, não de linha — nenhuma função removida, nenhum
> arquivo apagado. Os dois itens do README já tinham sido feitos em `11c758a`.
>
> O que parecia detecção de schema (`e_chave_da_aurora`) é o oposto: ela deduz a
> regra da Aurora em vez de cravar `v2`, para sobreviver a uma migração **nesta**
> máquina. Removê-la seria erro.
>
> **A promessa falsa que a releitura pegou:** o README dizia *"Todo passo faz
> backup antes de sobrescrever"*. São **7 scripts**, não todos. A regra real que
> entrou é melhor que a prometida: backup do que é de outro, e nada nos
> diretórios de dono único, onde o conteúdo anterior é a saída da rodada
> anterior do próprio script.
>
> **Um bug encontrado de raspão, e corrigido:** o `install.sh` gravava o timer
> com `${LOGO_INTERVALO:-1d}` e anunciava na tela `${LOGO_INTERVALO:-30m}`. Não
> aparecia na máquina dela só porque o `meow.conf` dela **tem** a chave.
>
> Intactos de propósito, e conferidos um a um: o `garantir_backup` colado na
> linha anterior ao `rm -f "$vivo"` (361/362), a fronteira com a Aurora e o
> código 4, e a degradação elegante em 26 arquivos.

## O texto original da sprint (o critério continua valendo)

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

## Por onde começar, em concreto

Quem pegar isto do zero, sem nenhum contexto de conversa, faz nesta ordem:

1. **Leia** este arquivo inteiro e `docs/COSMIC-THEMING.md` (os fatos medidos
   nesta máquina, com data e método — inclusive conclusões erradas anteriores e
   por que eram erradas).
2. **Confira o estado**: `./bin/meow doctor` e `git log --oneline -12`.
3. **Sprint A**, e comece pela **medição**, não pelo código: descobrir quais
   ícones o `cosmic-settings` pede e onde cada um resolve hoje.
4. **Baixe uma amostra do Arcticons** (10 ícones, pela API do Iconify), colora
   pelo método acima, e **monte a folha visual** a 22 px e 48 px, nos dois
   fundos. Mostre a ela **antes** de processar 13 mil.
5. Só depois de ela aprovar a folha, escreva o gerador.

A regra que atravessa tudo: **a folha visual vem antes do código.** Foi assim que
se descobriu que 19 dos 27 candidatos a desenho autoral eram logomarca, e foi a
folha que fez ela decidir abandonar os ícones autorais.

---

## Estado atual — o que já está no ar

| entregue em 05/08/2026 | prova |
|---|---|
| 123 tipos de arquivo em Catppuccin | 14/14 alvos resolvem no pack pelo `Gtk.IconTheme` |
| 16 aplicativos do lançador em Catppuccin | Firefox, Discord, Spotify, VLC, Steam conferidos no resolvedor |
| 242 wallpapers (eram 239) | 3 faltavam por bug de URL não escapada, calado desde a 1ª semeadura |
| o tema parou de desfazer o vidro dela | fronteira por árvore + código 4, testados em COSMIC isolado |
| o doctor enxerga receita ≠ produto | `'Low2' pede alpha 7C, está gravado D9` |
| 28 ícones do próprio COSMIC em Arcticons | `strace` no `cosmic-settings`: 9 carregados do nosso tema já na 1ª tela |
| o acervo de gatos responde na hora | `.svg` solto → **1** disparo no journal, não laço |
| `meow configurar` edita o `meow.conf` | ENTER em tudo não escreve um byte |
| nenhuma promessa de portabilidade no repo | e nada do que a poda ia remover era código |

**O que espera decisão dela, e só isso:** as folhas da **Sprint B**
(`~/folha-apps-orfaos.html`) e da **Sprint C** (`~/folha-pastas.html`). Nada foi
aplicado nas duas — `icons/apps.map` e `scripts/construir_pastas.sh` estão
intocados.
| `assets/gatos/` responde na hora, sem esperar o relógio | um `.svg` solto disparou 1 vez e entrou; apagado, disparou 1 vez e saiu — e `install.sh` duas vezes não disparou nenhuma |

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
(pastas) é irmã dela e sai na mesma folha. **D** é infraestrutura e não muda
pixel (**E** já foi feita, em 05/08). **F** é limpeza e pode ir a qualquer
momento.

Ela está trabalhando na própria máquina enquanto isto roda. Nada de abrir janela
na tela dela; para ver o resultado, renderize em headless ou peça que ela olhe.
