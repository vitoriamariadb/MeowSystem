# Os jogos da Steam no lançador — o que foi medido em 10/08/2026

Este documento guarda **fatos verificados nesta máquina**, com o comando que os
prova ao lado. Ele existe porque foi uma suposição confortável — *"a Steam deve
criar os atalhos sozinha"* — que produziu o `scripts/jogos_steam.sh` quebrado de
05/08: um script que lia a área de trabalho, encontrava zero arquivos e saía
verde enquanto **nenhum** jogo existia no lançador dela.

Máquina: Pop!_OS 24.04 · COSMIC · Wayland · Steam **nativa (deb)** · duas
bibliotecas (`~/.steam/debian-installation` e `/mnt/Mnemosyne/SteamLibrary`).

---

## 1. Os atalhos de jogo da Steam têm UM dono: o MeowSystem

Existem dois geradores na máquina, e eles escreviam no mesmo diretório com
prefixos diferentes — duplicata garantida, não possível:

| gerador | arquivo gerado | limpeza |
|---|---|---|
| `~/.config/zsh/scripts/steam-gera-atalhos.sh` (Ritual da Aurora, instalado em `/usr/local/bin` pelo self-heal, linha 952) | `steam-jogo-<appid>.desktop` | só os `steam-jogo-*` |
| `scripts/jogos_steam.sh` (MeowSystem, versão de 05/08) | `steam-<appid>.desktop` | nenhuma |
| `scripts/jogos_steam.sh` (a partir de 10/08) | `meow-steam-<appid>.desktop` | os três prefixos, com prova de autoria |

O dono é o MeowSystem. O do Aurora ficou **desarmado por convenção**: ele é
instalado mas nenhum timer o chama (`systemctl --user list-timers --all` não o
lista, e o self-heal só faz `install_if_diff`). **Não o rode à mão** — ele
duplicaria os 21 atalhos com ícones diferentes.

O desarme não é feito por nós: `~/.config/zsh` é o repo Andromeda com
auto-commit a cada 10 min, e `/usr/local/bin` é revertido pelo self-heal em até
uma hora. Se ela quiser o desarme físico, é edição no repo do Aurora, feita por
ela ou por quem tenha esse escopo.

**Corrija esta justificativa onde quer que ela apareça:** a trava
`meow_destino_permitido` (`lib/comum.sh:77-84`) barra `/usr/share`,
`/usr/local/share`, `/usr/bin` e `/usr/lib` — **ela não barra `/usr/local/bin`**.
A razão para não escrever lá é o self-heal, não a trava.

O `Exec` dos atalhos é `/usr/games/steam`, nunca
`/usr/local/bin/steam-resiliente.sh`: aquele wrapper é do Aurora
(`ritual-aurora-self-heal.sh:951`) e um `Exec` apontando para um arquivo que
outro dono pode remover é um jogo que não abre.

---

## 2. Quatro fatos medidos, para ninguém voltar a supor

**1. A Steam NÃO cria `.desktop` de jogo sozinha.** Ela instala um `.desktop`
para o CLIENTE e mais nada; atalho de jogo é ação manual da pessoa, um por vez,
na área de trabalho. Foi assim que nasceram os oito que o script de 05/08
copiava — e que ela apagou depois.

    ls /usr/share/applications | grep -i steam     # -> steam.desktop, só
    ls ~/"Área de trabalho"/ | wc -l                # -> 0
    ls ~/.local/share/Trash/files/                  # -> vazio

**2. A Steam aqui é NATIVA (deb), não flatpak.** O `Exec` dos atalhos é
`/usr/games/steam steam://rungameid/<appid>`.

    which steam                                     # -> /usr/games/steam
    flatpak list --app | grep -i steam              # -> vazio
    grep -n '^Exec=' /usr/share/applications/steam.desktop | head -1
                                                    # -> 32:Exec=/usr/games/steam %U

**3. Existe uma cópia de `steam.desktop` em `~/.local/share/applications`, e ela
é do Aurora.** Duas diferenças: tira o `NoDisplay=true` (por isso a Steam
aparece no lançador dela) e troca o `Exec` por
`/usr/local/bin/steam-resiliente.sh`. O MeowSystem **não** reescreve essa cópia
nem imita o wrapper nos atalhos de jogo.

    diff /usr/share/applications/steam.desktop ~/.local/share/applications/steam.desktop

**4. Todos os 30 manifestos estão com `StateFlags=4`** (instalados por
completo), então nenhum atalho aponta para jogo pela metade.

Se um dia ela pedir o wrapper resiliente nos atalhos, isso vira
`JOGOS_STEAM_EXEC="padrao"|"resiliente"` no `meow.conf` — **com** pergunta no
`meow configurar`, senão é chave inerte (`lib/comum.sh:34-39`) — e com fallback
automático para `/usr/games/steam` quando o wrapper não existir. Nunca o padrão.

---

## 3. Jogo x ferramenta: o sinal está na capa, não no nome

Dos 30 manifestos das duas bibliotecas, **9 são infraestrutura** — 228980,
1070560, 1391110, 1493710, 1628350, 2180100, 3658110, 4183110 e 4628710 (Proton,
Steam Linux Runtime, Steamworks Common Redistributables). O `.acf` **não tem
campo `type`** (`appid`, `universe`, `name`, `StateFlags`, `installdir`,
`LastUpdated`, ...), e foi por isso que o gerador do Aurora recorreu a uma lista
negra de nome (`Proton*`, `*"Steam Linux Runtime"*`).

A lista negra quebra no dia em que a Valve renomear um runtime, e reprova um jogo
de verdade chamado "Protocol". O critério aqui é estrutural e foi medido um a um:

- **capa vertical** (`library_capsule.jpg` ou `library_600x900.jpg`) no
  `librarycache`: 21 de 21 jogos têm, **0 de 9** ferramentas tem;
- **`steam_icon_<appid>.png`** no hicolor, como guarda-costas para o jogo
  recém-instalado cuja arte ainda não baixou: também 0 das 9 ferramentas.

Comando de reverificação, para quando ela instalar um jogo novo e ele não
aparecer:

    CACHE=~/.steam/steam/appcache/librarycache
    for m in ~/.steam/steam/steamapps/appmanifest_*.acf /mnt/Mnemosyne/SteamLibrary/steamapps/appmanifest_*.acf; do
      [ -e "$m" ] || continue
      id=$(awk -F'"' '/"appid"/{print $4;exit}' "$m"); nm=$(awk -F'"' '/"name"/{print $4;exit}' "$m")
      cap=$(find "$CACHE/$id" -type f \( -name library_capsule.jpg -o -name library_600x900.jpg \) 2>/dev/null | wc -l)
      ico=$(find ~/.local/share/icons -name "steam_icon_$id.png" 2>/dev/null | wc -l)
      printf '%-9s capa=%s icone=%s %s\n' "$id" "$cap" "$ico" "$nm"
    done
    # capa=0 e icone=0 -> o script trata como ferramenta. Se for jogo de verdade,
    # abra a biblioteca da Steam uma vez para ela baixar a arte e rode de novo.

---

## 4. Onde a arte mora hoje — os números certos

A seção 4d deste `docs/COSMIC-THEMING.md` conta o episódio de 05/08 pelo lado do
`index.theme`. Falta o outro lado: **o `librarycache` mudou de layout**. A Steam
renomeou `library_600x900.jpg` para `library_capsule.jpg` e passou a enterrar
cada arte numa subpasta cujo nome é o hash do conteúdo. Recontagem dos 21 jogos:

- **7** com `library_600x900.jpg` na raiz (layout antigo);
- **3** com `library_600x900.jpg` em subpasta-hash;
- **11** com `library_capsule.jpg` (nome novo, sempre em subpasta);
- **0** dos 14 do layout novo tem `header.jpg` na raiz — todos cairiam no jpg de
  nome-hash de 32x32, que ampliado 7,7x vira um borrão. Um borrão é pior que o
  ícone genérico da Steam: quem olha conclui que a arte do jogo se perdeu.

Por isso `arte_do_jogo()` busca por *basename* com `find -type f` **sem
`-maxdepth`** (cobre raiz e subpasta de uma tacada) e deixa o jpg de nome-hash
**fora** da lista de preferências, de propósito.

Nota de portabilidade que morde num teste manual: no shell interativo dela
`find` é uma função que chama `bfs`, não o GNU. Mas `/usr/bin/find` é GNU
findutils 4.9.0 e um script com `#!/usr/bin/env bash` não herda funções de zsh —
então o `-printf` é seguro **dentro** do script, e um teste colado no terminal
pode divergir do que o script faz.

Só **5** dos 21 jogos precisam de ícone plantado por nós (1553260, 1657740,
2369580, 3359390 e 3527290 — os que só têm `steam_icon_` em 32x32/48x48, ou
nenhum). Os outros 16 usam o `steam_icon_<appid>` que a própria Steam já
instalou. O `Icon=` guarda sempre um **nome**, nunca um caminho para dentro de
`~/.steam`: aquilo é cache do cliente e a subpasta muda de nome a cada
atualização de arte.

---

## 5. O verde do doctor voltou a significar alguma coisa

O defeito não era só "faltam atalhos": era que **faltar atalho era
indistinguível de estar tudo certo**. Os três estados que o script novo
distingue:

| estado | saída | rc |
|---|---|---|
| Steam não instalada | `-- Steam não instalada — nada a fazer` | 0 |
| manifestos de jogo e atalhos faltando | `~~ 21 jogo(s) da Steam: 21 atalho(s) a escrever` | 1 |
| tudo em dia | `ok 21 jogo(s) da Steam no lançador` | 0 |

Quando `/mnt/Mnemosyne` está **desmontado** o script sai 0 com um `!!` visível, e
**adia a limpeza de órfãos**: sem o disco, a ausência do manifesto é falsa, e
apagar o atalho do Wukong para recriá-lo no boot seguinte é o script brigando
consigo mesmo. Devolver 1 aí faria o auto-reparo das 5h tentar consertar todo dia
algo que não tem conserto sem o disco — trocaria uma mentira verde por um alarme
perpétuo.

Duas correções factuais que circularam erradas e não devem ser repetidas:

1. `~/.config/systemd/user/meow-doctor.service:84` diz `SuccessExitStatus=1 3 4`
   — o `4` ("divergente por escolha dela") também está lá.
2. O bloco `show_content` que a versão antiga do script tinha era **código
   morto** quando foi acusado: o guarda era `grep -q 'show_content: *false'` e
   `~/.config/cosmic/com.system76.CosmicFiles/v1/desktop` já traz
   `show_content: true`. O bloco saiu por contradizer o requisito, e **a chave
   fica como está** — o MeowSystem parou de opinar sobre a área de trabalho dela.

---

## 6. O grupo "Jogos" no lançador é decisão dela

O COSMIC **não agrupa por `Categories` sozinho**: `cat
~/.config/cosmic/com.system76.CosmicAppLibrary/v1/groups` devolve `[]` e não há
default de sistema em `/usr/share/cosmic/`. O script garante a matéria-prima
(`Categories=Game;` e `Keywords=steam;jogo;game;` nos 21 arquivos, o que já faz a
busca por "jogo" achar os 21) e **imprime a instrução**, sem tocar no arquivo.

Grupo é gosto, e a folha visual vem antes do código. **Não** ponha esse arquivo
sob o `meow doctor` nem sob o auto-reparo: `groups` é justamente o que ela vai
editar pela interface, e um script que o reescreve todo dia desfaz o que ela fez
— num arquivo em que isso custa caro (RON inválido derruba todos os grupos dela
de uma vez).

Se ela pedir o grupo pronto, o RON abaixo está conferido contra
`pop-os/cosmic-applibrary`, `src/app_group.rs` — `AppLibraryConfig { groups:
Vec<AppGroup> }` (lista), `AppGroup { name, icon, filter }` (struct de três
campos nomeados), `FilterType::Categories { categories, exclude, include }`
(struct-variant). `icon` é `String` e não `Option`, então nada de `Some(...)`;
`name` só passa por tradução para quatro chaves reservadas do upstream, então
`"Jogos"` aparece literal; e a comparação de categoria é `to_lowercase()` dos
dois lados, então `Categories=Game;` casa.

    cp -a ~/.config/cosmic/com.system76.CosmicAppLibrary/v1/groups \
          ~/.config/cosmic/com.system76.CosmicAppLibrary/v1/groups.antes-do-meow

    cat > ~/.config/cosmic/com.system76.CosmicAppLibrary/v1/groups <<'RON'
    [
        (
            name: "Jogos",
            icon: "applications-games-symbolic",
            filter: Categories(
                categories: ["Game"],
                exclude: [],
                include: [],
            ),
        ),
    ]
    RON

Reabra o lançador. Se o grupo **não** aparecer, o RON foi rejeitado — restaure o
backup.

---

## 7. Como conferir, e como desfazer

    cd /mnt/Apate/Desenvolvimento/MeowSystem
    MEOW_DRY_RUN=1 ./scripts/jogos_steam.sh    # rc=1 enquanto houver o que fazer
    ./scripts/jogos_steam.sh                   # rc=1 (consertou)
    ./scripts/jogos_steam.sh                   # rc=0 (convergiu)
    ls ~/.local/share/applications/meow-steam-*.desktop | wc -l   # 21
    desktop-file-validate ~/.local/share/applications/meow-steam-*.desktop

Desfazer, se ela não gostar de ver os 21 no lançador:

    rm -f ~/.local/share/applications/meow-steam-*.desktop \
          ~/.local/share/icons/hicolor/256x256/apps/meow-steam-*.png
    update-desktop-database ~/.local/share/applications

O que torna isso seguro é a marca `X-MeowSystem=jogo-steam` no corpo de cada
arquivo: a limpeza do script só apaga com **prova de autoria** (marca no
conteúdo, ou `steam://rungameid/` para os dois prefixos legados), nunca por
prefixo de nome sozinho. Testado com um `.desktop` escrito à mão contendo
`rungameid` — ele sobreviveu.
