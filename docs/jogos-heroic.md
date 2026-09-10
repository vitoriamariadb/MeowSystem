# Os jogos do Heroic no lançador — o que foi medido em 10/09/2026

Irmão de [`jogos-steam.md`](jogos-steam.md), e escrito pelo mesmo motivo: guardar
**fatos verificados nesta máquina**, com o comando que os prova ao lado, para
ninguém voltar a supor.

Máquina: Pop!_OS 24.04 · COSMIC · Wayland · **Heroic v2.22.1 flatpak**
(`com.heroicgameslauncher.hgl`, instalação `user`) · biblioteca Epic com um jogo
instalado.

Queixa que abriu o assunto: *"os jogos instalados pelo heroic launcher não
aparecem nos .desktop da interface igual eram os da steam antes do projeto
nascer"*.

---

## 1. O Heroic não escreve `.desktop` de jogo — e aqui as chaves estão desligadas

Não é atalho que se perdeu; é atalho que nunca foi escrito. Duas provas:

    grep -rl heroic ~/.local/share/applications \
        ~/.var/app/com.heroicgameslauncher.hgl/data/applications   # -> vazio

    python3 -c "import json;d=json.load(open('$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic/config.json'))['defaultSettings'];print({k:d.get(k) for k in ('addDesktopShortcuts','addStartMenuShortcuts','addSteamShortcuts')})"
    # -> {'addDesktopShortcuts': False, 'addStartMenuShortcuts': False, 'addSteamShortcuts': False}

**Ligar as chaves DELE não resolveria**, e é por isso que não foi o caminho: o
`addShortcuts` do Heroic roda no fim de uma instalação (lido no `app.asar`), de
modo que os jogos **já instalados** continuariam de fora. E o arquivo nasceria
sem dono conhecido — sem marca de autoria, sem escada de ícone e sem ninguém
para removê-lo quando o jogo saísse.

O dono aqui é o `scripts/jogos_heroic.sh`, que relê a biblioteca a cada
passagem. É o mesmo desenho do módulo da Steam.

---

## 2. A fonte de verdade são dois arquivos, e eles se confirmam

| arquivo | o que ele responde | formato |
|---|---|---|
| `store_cache/<runner>_library.json` | título, arte, runner, `is_installed`, `install.is_dlc` | um só para os quatro runners |
| `legendaryConfig/legendary/installed.json` | está no disco (Epic) | dicionário `{app_name: {...}}` |
| `gog_store/installed.json` | está no disco (GOG) | `{"installed": [ {"appName": …} ]}` |
| `nile_config/nile/installed.json` | está no disco (Amazon) | lista `[ {"id": …} ]` |
| `sideload_apps/library.json` | os jogos que ela mesma apontou | não tem backend: a biblioteca é a verdade |

Um jogo entra no lançador quando os **dois** concordam. O cache sozinho não
basta (o frontend o reescreve e ele pode falar de um jogo que saiu); o
`installed.json` sozinho também não (não tem arte, e no GOG/Amazon nem o
título). Quando o `installed.json` de um runner não existe ou não abre, vale o
cache — é o caso dos `sideload`.

**A chave da lista dentro do cache muda de nome conforme o runner**:
`legendary_library.json` guarda em `library`, `gog_library.json` em `games`, e o
`nile_library.json` desta máquina é um `{}` seco. Cravar o nome certo de cada um
é combinar com uma versão do Heroic; o script procura a primeira lista de
objetos que tenha `app_name`, e isso responde à mesma pergunta sem envelhecer.

**DLC não é jogo, e o Heroic pensa igual.** `addShortcuts` começa com
`if (gameInfo.install.is_dlc) return`. Nesta máquina há **dois** registros
instalados para **um** jogo: Marvel's Guardians of the Galaxy (76,9 GiB) e a
roupa Social-Lord (327 KiB), que não abre nada.

---

## 3. O `Exec` é o protocolo do próprio Heroic

O modelo do upstream, lido no `app.asar` da versão instalada:

    [Desktop Entry]
    Name=${gameInfo.title}
    Exec=xdg-open ${launchWithProtocol}     # heroic://launch?appName=<app>&runner=<runner>
    Terminal=false
    Type=Application
    Icon=${icon}
    Categories=Game;

O handler está registrado, e isso é medido, não suposto:

    xdg-mime query default x-scheme-handler/heroic
    # -> com.heroicgameslauncher.hgl.desktop

    grep -n '^MimeType=' ~/.local/share/flatpak/exports/share/applications/com.heroicgameslauncher.hgl.desktop
    # -> MimeType=x-scheme-handler/heroic;

Duas diferenças em relação ao modelo do upstream, as duas de propósito:

1. **as aspas.** `&`, `?` e `$` são caracteres *reservados* no campo `Exec` da
   especificação freedesktop. O Heroic escreve sem aspas; nós escrevemos
   `Exec=xdg-open "heroic://launch?appName=…&runner=…"`, e o
   `desktop-file-validate` passa limpo.
2. **nada de `flatpak run …` cravado.** O Heroic também existe como deb e
   AppImage; o URI resolve nos três. É a mesma escolha que o módulo da Steam faz
   ao recusar o wrapper do Ritual da Aurora — só que lá o caminho estável é o
   binário, e aqui é o protocolo.

---

## 4. A capa já está no disco — e por isso o script não vai à rede

Um módulo que o `meow doctor` chama às 5h da manhã não baixa arte. As três
fontes locais, na ordem em que o script tenta:

1. **`icons/<app_name>.jpg|.png`** — a arte alta que o próprio Heroic baixa
   (1200x1600 no jogo desta máquina);
2. **GOG:** `<install_path>/goggame-<app_name>.ico` ou
   `<install_path>/support/icon.png` — é o que o `getIcon` do Heroic prefere
   para esse runner;
3. **`images-cache/<sha256 da URL da arte>`** — o cache do frontend. A conta sai
   do `app.asar` (`getImageFromCache`: `sha256(url)`), e a URL que o frontend
   pede leva sufixo. Conferido contra o disco:

       sha256(art_square + "?h=400&resize=1&w=300")  -> 31 dos 33 arquivos do cache

   São 300x400, de sobra para a escada desta tela, que termina em 96.

Sem nenhuma das três, o cartão fica com o ícone do **Heroic** —
`com.heroicgameslauncher.hgl`, que é honesto ("é um jogo do Heroic") e nunca um
borrão. O script diz na saída quantos ficaram assim e o que fazer (abrir a
biblioteca do Heroic uma vez, para ele baixar a arte).

A arte **não é tematizada**, pela mesma razão dos jogos da Steam: capa repintada
na paleta vira um monte de ícone igual, e a capa é a identidade do jogo. A
escada de tamanhos é a mesma `meow_icones_escada` de todo o projeto — plantar num
tamanho só devolve pixbuf grande para todo pedido e serrilha na dock.

---

## 5. Um cartão por jogo — e aqui o rival é o próprio Heroic

Se ela ligar "criar atalho" na interface dele, o arquivo nasce com o **nome do
jogo**: `shortcutFiles()` no `app.asar` devolve `${sanitize(title)}.desktop`.
Nome livre, com espaço e apóstrofo — nenhum glob o descreve. É o
`Future Knight.desktop` de 09/09/2026 com outro sobrenome, e é por isso que a
limpeza pergunta pelo **conteúdo**:

- o `Exec=` carrega `heroic://launch` com um `appName` (as duas formas do URI, a
  de hoje e a antiga `/launch/<app>`), e o app sai **dali**, nunca do nome do
  arquivo;
- o arquivo **não** traz `X-MeowSystem=jogo-heroic`;
- esse mesmo jogo **acabou de receber o nosso cartão** — nunca se tira um cartão
  sem deixar substituto, senão o jogo some da tela dela.

Some com **cópia guardada antes** em
`~/.local/state/meowsystem/backups/<carimbo>-duplicatas/`, e a remoção é
anunciada na saída, nunca silenciosa.

**Biblioteca ilegível não é biblioteca vazia.** Se nenhum `*_library.json` abrir,
o script devolve 3, não escreve e **não apaga nada**: a ausência de um jogo seria
falsa, e a limpeza tiraria da tela cartões de jogos que continuam instalados. É o
mesmo adiamento que o módulo da Steam faz com a biblioteca desmontada.

---

## 6. Como conferir, e como desfazer

    cd /mnt/Apate/Desenvolvimento/MeowSystem
    ./scripts/jogos_heroic.sh --conferir     # rc=1 enquanto houver o que fazer
    ./scripts/jogos_heroic.sh                # rc=1 (consertou)
    ./scripts/jogos_heroic.sh                # rc=0 (convergiu)
    desktop-file-validate ~/.local/share/applications/meow-heroic-*.desktop
    bash tests/jogos-heroic.sh               # o teste, num HOME de brinquedo

No painel, aba **Lançadores e jogos**: "Ver o que mudaria nos jogos do Heroic" e
"Pôr os jogos do Heroic no lançador". No `meow doctor`, linhas **`jogosheroic`**
(os cartões) e **`heroicvigia`** (o gatilho). No instalador, etapas
**`jogos_heroic`** e **`vigia_heroic`**.

    ./scripts/vigia_heroic.sh --conferir      # o gatilho está ligado?
    systemctl --user status meow-heroic.path
    journalctl --user -u meow-heroic.service -n 20

Desfazer:

    rm -f ~/.local/share/applications/meow-heroic-*.desktop \
          ~/.local/share/icons/hicolor/*/apps/meow-heroic-*.png
    update-desktop-database ~/.local/share/applications

O que torna isso seguro é a marca `X-MeowSystem=jogo-heroic` no corpo de cada
arquivo: a limpeza do script só apaga com **prova de autoria**, nunca por prefixo
de nome sozinho.

---

## 7. O gatilho: jogo instalado entra no lançador sozinho

Pedido dela no mesmo dia, depois de ver o primeiro cartão: *"o ponto é que
qualquer jogo que eu instalar quero que automaticamente isso se corrija"*.

O par `systemd/meow-heroic.path` + `.service` faz isso, e é a **quinta** unidade
`.path` do projeto. Liga-se com `HEROIC_VIGIA="sim"` no `meow.conf` (o padrão),
instala-se pelo `scripts/vigia_heroic.sh`, e o `meow doctor` o confere na linha
**`heroicvigia`**.

**O evento são os ARQUIVOS do `store_cache`, e cada palavra dessa frase é uma
decisão medida:**

- **arquivos, não a pasta.** No irmão da Steam o evento é o diretório
  `steamapps/`, e funciona porque lá cada jogo é um arquivo que nasce e morre.
  Aqui o arquivo é sempre o mesmo e o que muda é o conteúdo — uma reescrita no
  lugar **não** mexe no mtime do diretório, e um `PathChanged` na pasta dormiria
  para sempre;
- **`store_cache`, não o `installed.json` do backend.** É do cache que o módulo
  tira título e capa. Acordar no `installed.json` seria acordar num momento em
  que ainda não há o que escrever.

A espera é de **20 segundos** (a da Steam é 45): lá o `.acf` é reescrito a cada
avanço do download; aqui o cache só é reescrito ao terminar de instalar, ao
desinstalar e ao sincronizar.

**Medido de ponta a ponta em 10/09/2026**, e não deduzido do arquivo de unidade:
o cartão do jogo foi apagado à mão, a biblioteca do Heroic recebeu um `touch`, e
o `.path` disparou o serviço **no mesmo segundo** — o cartão voltou sozinho na
passagem seguinte, sem ninguém rodar nada.

---

## 8. O que ficou de fora, e por quê

- **O `jogos-fora.map`.** Ele existe para os appids da Steam, e a ação `apagar`
  dele remove **arquivos de jogo** do disco. Nada disso foi estendido ao Heroic
  nesta leva: aqui o módulo não encosta nos arquivos do jogo, só no atalho e no
  ícone.
- **A grade de capas do painel.** A aba "Jogos da Steam" lê o `librarycache` da
  Steam e continua só dela. Os jogos do Heroic aparecem no painel pela aba
  "Lançadores e jogos" (o `Categories=Game;` do cartão basta), mas sem grade
  própria.
