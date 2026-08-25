# A receita do applet de mídia

Este diretório não guarda um programa — guarda a **diferença** entre o applet
Now Playing do COSMIC e o que ela precisava dele. O programa mora em
`~/.local/state/meowsystem/midia/src`, clonado e patchado pelo
`scripts/midia_build.sh`, e nunca dentro do repositório.

| arquivo | o que é |
|---|---|
| `PINO` | a URL, o commit do upstream e o commit do libcosmic. É o que torna a compilação repetível |
| `0001-meow-capa-cor-controles.patch` | a diferença. 3 arquivos tocados, zero crates novas, `Cargo.toml` e `Cargo.lock` intactos |

## A causa raiz era uma linha

```rust
// src/media.rs, antes
album_art_path: metadata.art_url().and_then(file_url_to_path),
```

`file_url_to_path` recusa, por desenho, toda URL que não seja `file://`. O
Spotify publica `mpris:artUrl` como `https://i.scdn.co/image/ab67616d…` e
**nunca** um `file://` — todo player com catálogo na web faz igual.

As duas queixas dela caíam juntas nessa linha, e isso não é coincidência: a cor
do álbum é **extraída da capa** (`album_color.rs` abre o arquivo e tira a cor
dominante). Sem capa no disco, não há de onde tirar cor. Não eram dois defeitos,
era um.

Vale dizer o que **não** era a causa, porque o palpite óbvio está errado: o
flatpak do applet não tem `--share=network`, mas abrir o sandbox não mudaria um
pixel — **não existe cliente HTTP no código original** (zero `reqwest`, `ureq` ou
`hyper` no `Cargo.toml`). Faltava escrever o download, não faltava permissão.

## O que o patch faz

**Capa remota.** `art_path()` tenta `file://` primeiro (o caminho do upstream,
intocado) e só então o cache remoto. O download é um `curl` com
`--max-time 8`, `--max-filesize 8388608`, `--proto =http,https`, escrita num
`.part` e `rename` atômico para o destino — um download interrompido nunca vira
um JPEG pela metade que o `album_color` leria como cor. O cache vive em
`~/.cache/cosmic-ext-applet-now-playing/art`, com o nome derivado do hash da URL,
e é podado em 256 arquivos (`prune_art_cache`).

**A thread da interface nunca baixa.** `scan()` recebe `allow_download`, e a
subida do applet passa `false`. Um `i.scdn.co` lento penduraria o applet — e,
com ele, o painel inteiro. Na subida vale o que já está em cache; a thread do
monitor busca o resto e o próximo snapshot carrega a capa.

**Controles na barra.** ⏮ e ⏭ passam a ficar ao lado do ⏸, que já estava lá. A
ordem do `Row` é `[capa][nome][⏮][⏸][⏭]`: a capa encosta no título porque as
duas falam da mesma música, e os botões vão para a ponta, longe do texto que
trunca.

**Largura configurável.** O upstream crava `260.0` em `src/ui.rs`. Na tela dela
isso corta em `This City's Tryna Br…`. O padrão daqui é 440 — medi ~215px de
folga na asa direita da dock — e sai do `meow.conf` (`MIDIA_LARGURA`, com clamp
de 80 a 900 dentro do próprio applet).

**O tamanho da letra vem do painel, não do ícone.** O upstream fazia
`.size(suggested_size().0 - 1)`: usava o tamanho do **ícone** como tamanho da
**fonte**. Numa dock de ícone grande a letra sai gigante ao lado do relógio da
topbar — foi a primeira coisa que ela reparou, em 24/08/2026. Agora quem
decide é `core.applet.text()`, o helper do libcosmic que escolhe
`body`/`title4`/`title3`/`title2` conforme a altura da barra, e que é o mesmo
que o relógio usa. `MIDIA_FONTE` crava px (6 a 48) quando ela quiser.

**Título e artista são dois textos, com cores próprias.** O upstream junta tudo
em `now_playing.text` (`"Título - Artista"`), e uma string só não tem como ter
duas cores. Aqui são widgets separados: `MIDIA_COR_TITULO` e
`MIDIA_COR_ARTISTA` aceitam qualquer nome da paleta Catppuccin, e quem traduz
nome para hex é o `scripts/midia.sh`, contra o `FLAVOR` do `meow.conf` — o
applet só lê `#rrggbb`. A paleta é do MeowSystem, e uma cópia dela dentro do
Rust seria a segunda verdade que discorda no dia em que ela trocar de flavor.
Escolha dela: roxo (`mauve`) na música, verde (`green`) na banda.

**Os ⏮⏸⏭ da barra são opcionais (`MIDIA_CONTROLES`), e nascem DESLIGADOS.** O
applet de Som do COSMIC já desenha os dele no painel sempre que há player. Com o
Now Playing colado nele — que é onde ela o pôs em 24/08/2026 — os dois pares
ficam lado a lado e leem como defeito, não como recurso. Desligado, sobra
`[capa] música · banda`, que encosta nos controles do vizinho e forma um bloco
só. O popup do applet mantém os três botões sempre, independente da chave.

**A largura é TETO, não tamanho — e a diferença custou uma barra.** Duas versões
erraram antes desta. A primeira dividia a largura em porções fixas (62/38): com
título curto sobrava um buraco visível antes do `·`, e o artista parecia solto,
de outra música. A segunda pôs os textos em `Shrink` com um espaço `Fill` no
fim — o buraco sumiu, mas o `Row` continuava `Fixed`, então o applet
**reservava** 440px estivesse o texto ocupando isso ou não. Medido ao mudá-lo
para a topbar: os 440px empurraram bluetooth, volume e rede para o menu `⋯` de
estouro do painel. Numa dock larga isso não aparecia; numa topbar cheia,
aparece na hora. Agora o `Row` é `Shrink` dentro de um `container` com
`max_width`: o applet mede o próprio texto e ocupa só isso, e a largura do
`meow.conf` passa a ser o limite em que o título começa a elipsar.

**O modo de cor `traco`.** É o padrão daqui, e é uma decisão visual, não técnica.

## Por que `traco`, e não o `chapado` do upstream

O upstream mistura a cor da capa no **fundo** do botão:
`blend_color(theme_base, album, 0.36)` com alpha `0.64`. O `scripts/vidro.sh`
deste projeto escreve a opacidade do painel — um fundo opaco nesse botão abre um
retângulo sólido no meio da dock, que é o oposto da folha visual dela.

O `traco` deixa o fundo em paz e gasta a cor onde ela se lê: contorno e glifos.
Antes de pintar, a cor passa por `readable_on`, que a clareia (ou escurece,
conforme o painel) até fechar contraste WCAG AA de 4,5:1. Sem isso, um álbum
escuro num painel escuro devolve um traço que existe no código e não existe na
tela.

`MIDIA_COR_ALBUM="chapado"` devolve o comportamento do upstream, inteiro.

## A ressalva de gosto, que é dela e não nossa

Medi as duas famílias de cor: os 14 acentos do Catppuccin Mocha vivem em
luminância **0,69–0,86**; a cor do álbum, depois do `normalize_album_color` do
upstream, trava em **0,38–0,62**. **Zero sobreposição.** A cor do álbum não fica
ilegível — o `readable_on` garante isso — mas **destoa** do Catppuccin, num
desktop cujo acento é mauve.

Isso não é defeito a consertar às escuras. Existe um quarto valor possível
(`conciliada`, que puxaria a cor do álbum para dentro da paleta) e ele só deve
ser escrito **depois** de ela ver a cor crua na tela e dizer o que acha. A folha
visual vem antes do código.

## Os testes

```sh
cd ~/.local/state/meowsystem/midia/src
cargo test --release --locked
```

23 testes, todos passando em 24/08/2026. Nove são nossos:

| teste | o que prova |
|---|---|
| `media::https_deixou_de_ser_descartado` | a peneira `file://` caiu — é a queixa inteira |
| `media::cache_e_deterministico_e_separa_urls` | a mesma capa não baixa duas vezes; capas diferentes não colidem |
| `media::esquema_estranho_continua_recusado` | `ftp:`, `data:` e lixo continuam fora |
| `media::sem_download_e_sem_cache_nao_ha_capa` | a thread da interface não bloqueia |
| `media::file_url_nao_passa_pelo_cache` | o caminho do upstream continua o de sempre |
| `style::traco_nao_pinta_o_fundo` | o `vidro.sh` não é atropelado |
| `style::chapado_pinta_o_fundo` | o modo do upstream continua existindo |
| `style::traco_garante_contraste_de_album_escuro` | o traço aparece mesmo com álbum escuro |
| `style::sem_cor_de_album_nada_muda` | sem capa, o botão é o de fábrica |

`cargo clippy --all-targets -- -W clippy::pedantic` não acusa nada nos arquivos
que tocamos. Os dois avisos restantes são do upstream (`album_color.rs:13`,
`window.rs:130`) e ficam onde estão — corrigi-los engordaria o patch com
diferença que não é nossa.

## Como regenerar o patch quando o upstream mexer

```sh
ARV=~/.local/state/meowsystem/midia/src
git -C "$ARV" checkout -- .                       # tira o patch antigo
git -C "$ARV" checkout <commit-novo>              # se for mudar de base
git -C "$ARV" apply /mnt/Apate/Desenvolvimento/MeowSystem/src/applets/now-playing/0001-meow-capa-cor-controles.patch
# ... edite, compile, teste ...
git -C "$ARV" diff > /mnt/Apate/Desenvolvimento/MeowSystem/src/applets/now-playing/0001-meow-capa-cor-controles.patch
```

Se mudar de base, atualize `COMMIT` no `PINO`. O carimbo do `midia_build.sh`
inclui o sha256 deste patch e o `COMMIT` do `PINO`: qualquer um dos dois mudando,
a próxima passagem recompila sozinha. Não há nada a "lembrar de rodar".

## O que não foi feito, e por quê

- **`flatpak override --share=network`** — inútil sozinho; ver a causa raiz acima.
- **`flatpak mask`** no applet — desnecessário com a sombra, e é um "não atualize
  isto" permanente que ela teria de lembrar para sempre.
- **Trocar de applet** — o `cosmic-applet-audio` oficial erra igual
  (`mpris_subscription.rs`, mesma peneira `file://`), e dos applets de mídia do
  COSMIC **só este tem cor de álbum**. Trocar custaria a cor.
- **Escrever um applet do zero** — os dois argumentos que justificariam isso
  caíram na leitura do código: o `mouse_area` **não** engole o clique do botão
  pai (`iced/widget/src/mouse_area.rs` captura o evento e
  `libcosmic/src/widget/button/widget.rs` respeita a captura), e o `style.rs`
  **não** era chapado sem remédio.
- **Reiniciar o `cosmic-panel`** — a issue #13 do upstream derruba topbar e dock
  juntas. O applet novo sobe no próximo login.
