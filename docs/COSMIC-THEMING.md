# Como o COSMIC se veste — o que foi medido nesta máquina

Este documento guarda **fatos verificados na MeowSystem**, não o que a documentação
promete. Cada um traz a data e como foi medido, para que a próxima sessão possa
refazer o teste em vez de acreditar.

Máquina: Pop!_OS 24.04 · COSMIC (settings 1.0.12 / applets 1.0.15) · Wayland ·
DP-1 1920x1080 numa TV de 52 polegadas.

---

## 1. Não existe CLI de tema, e o daemon não deriva

**Medido em 2026-08-04.** O tema que o sistema lê (`CosmicTheme.Dark/v1` e `/v2`) é
*derivado* do que a GUI edita (`CosmicTheme.Dark.Builder/v1`). A pergunta era: quem
faz essa derivação — algum daemon, ou o app gráfico?

Escrevi o mauve do Catppuccin (`#CBA6F7`) direto em
`~/.config/cosmic/com.system76.CosmicTheme.Dark.Builder/v1/accent` e esperei.

```
mtime Builder/v1/accent : 2026-08-04 17:41:13   (escrito por mim)
mtime Dark/v1/accent    : 2026-04-12 18:49:57   (intocado)
```

O `cosmic-settings-daemon` estava vivo (PID 2825) e **não derivou nada** — nem em 4
segundos, nem depois. Quem deriva é o app `cosmic-settings`, com a janela aberta.

**Consequência de arquitetura:** um tema novo precisa ser importado pela GUI
**uma vez**. Depois disso, `scripts/capturar_tema.sh` fotografa o resultado, a foto
vai para o git, e `scripts/aplicar_tema.sh` reproduz por cópia em qualquer máquina,
sem GUI. É uma vez na vida do projeto, não uma vez por máquina.

**O que NÃO fazer:** escrever chave por chave em `Dark/v1`. As árvores derivadas já
discordam entre si nesta máquina — `Dark/v1` tem 30 chaves e `Dark/v2` tem 17, e o
`window_hint` de uma é `Some(...)` enquanto o da outra é `None`. Reproduzir isso à
mão gera um tema híbrido que *quase* funciona, e o "quase" só aparece semanas depois.

---

## 2. O nome do tema é o laço externo — `hicolor` é o fim da fila

**Medido em 2026-08-04.** A regra de resolução de ícone do COSMIC não é "sistema vence
usuário". É outra coisa, e confundir as duas custou uma conclusão errada aqui.

### A conclusão errada, e por que ela era errada

O primeiro teste plantou um triângulo vermelho em
`~/.local/share/icons/**hicolor**/.../com.system76.CosmicAppLibrary.svg` enquanto o tema
ativo era `breeze-dark`. O triângulo não apareceu, e disso se concluiu que
`/usr/share` vencia `~/.local/share`.

**A causa era outra:** `hicolor` é o **último** elo da cadeia de herança. Ele só é
consultado depois de o tema selecionado e todos os seus `Inherits` falharem — e nesse
caso não falharam. O diretório do usuário nunca esteve em desvantagem; o *tema* é que
estava no fim da fila.

### A regra real

O laço **externo** da busca é o **nome do tema**; o diretório-base é o laço **interno**.
Ordem observada por `strace` (num `Xvfb :99`, sem tocar na sessão dela), para o tema
selecionado `MeowTesteIcones`:

```
1. /usr/share/icons/MeowTesteIcones          <- tema selecionado, base de sistema
2. ~/.local/share/icons/MeowTesteIcones      <- tema selecionado, base do usuário
3. /usr/share/icons/breeze-dark              <- Inherits
4. /usr/share/icons/Cosmic
5. ~/.local/share/flatpak/exports/share/icons/hicolor
```

Disso saem duas consequências:

- **`~/.local/share/icons/<tema-selecionado>` vence `/usr/share/icons/hicolor`** com
  folga. Provado com o `google-chrome`, que só existe no `hicolor` do sistema: um SVG
  plantado apenas no tema do usuário venceu.
- `/usr/share` só vence `~/.local/share` quando **o nome do tema é o mesmo**. Se um dia
  o mesmo nome existir nos dois lugares, o de `/usr/share` ofusca o do usuário em
  silêncio.

### Confirmado na prática, no desktop dela

Montado `~/.local/share/icons/MeowSystem-Icons` com `scalable/apps/` e
`icon_theme = "MeowSystem-Icons"`: **o botão do dock virou o gato Catppuccin na hora**,
sem `sudo`, sem `/usr/share`, sem envolver o Ritual da Aurora.

**Consequência de arquitetura:** o MeowSystem entrega ícones em
`~/.local/share/icons/MeowSystem-Icons` e pronto. A regra "nada em `/usr/share`" da
especificação **está certa** — quem estava errado era o teste.

### Detalhes que economizam tempo

- **Dentro de um tema, a extensão é o laço externo:** todos os `.svg` (em todos os
  tamanhos) são tentados antes de qualquer `.png`. Basta entregar `scalable/apps/*.svg`.
- **`Directories=` é a única chave de tamanho que importa.** A crate do COSMIC
  (`cosmic-freedesktop-icons`) parseia `[Icon Theme]`, `Inherits` e `Directories`, e
  ignora `Type=`, `MinSize`, `MaxSize` e `Threshold`. Não perca tempo afinando-os.
- **`gtk-update-icon-cache` é irrelevante:** a crate não lê `icon-theme.cache` (zero
  ocorrências do literal no binário). Rodar não faz mal, mas não é o que destrava nada.
- **Reiniciar é obrigatório:** `cosmic-panel` e `cosmic-app-list` leem a config no
  início da sessão e não a vigiam. Um `pkill -x cosmic-panel` basta (o `cosmic-session`
  respawna em ~4ms).
- **O `hicolor` do usuário tem uma armadilha própria:** o `index.theme` dele declara
  só `48x48/apps,128x128/apps,256x256/apps,512x512/apps` — **`scalable/apps` não está
  lá**. SVG solto em `scalable/` daquele tema é ignorado. No nosso tema, declaramos.

---

## 3. O gato do painel não passa por tema de ícones

O applet `dev.cappsy.CosmicExtAppletLogoMenu` guarda o caminho do arquivo direto:

```
custom_logo_active = true
custom_logo_path   = "/home/vitoriamaria/.config/cosmic/logos/gato-pop.svg"
```

Trocar a logo do painel é trocar esse SVG (ou apontar a chave para outro arquivo) —
não passa por `icon_theme`, não precisa de cache, não precisa de `/usr/share`.

**Armadilha do nome:** o applet faz `.symbolic(path.contains("-symbolic.svg"))`. Um
arquivo terminado em `-symbolic.svg` é achatado numa cor só. Portanto
`assets/meow-symbolic.svg` **não serve** como logo do painel.

---

## 4. Onde cada cor mora, e em que formato

Descoberta que já corrigiu código: **o formato difere entre schemas.**

| Caminho | Formato | Exemplo |
|---|---|---|
| `CosmicTheme.Dark/v1/background` | floats | `base: ( red: 0.19223961, ... )` |
| `CosmicTheme.Dark/v2/background` | string hex | `base: "#313250D9"` |

O `aurora-vidro-maximizado.py` só casa `base: "#RRGGBBAA"` — ou seja, atua **apenas
no `v2`**. Um normalizador escrito para o formato errado "passa" no teste sem testar
nada (aconteceu, foi corrigido).

Além disso, `CosmicTheme.Dark.Builder/v2` **não tem nenhuma chave de cor** — só
`active_hint`, `alpha_map`, `corner_radii`, `frosted*` e `window_hint`. Todas as cores
vivem em `Builder/v1`. Receitas que mandam "escrever as chaves de cor do Builder/v2"
criariam chaves que nunca existiram aqui.

---

## 5. Fronteira com o Ritual da Aurora

O Aurora roda como root a cada hora, no boot e após todo apt. Onde os dois querem
mandar no mesmo arquivo, quem cede é o MeowSystem — exceto onde marcado.

| Recurso | Dono | Como conviver |
|---|---|---|
| alpha de `background`/`primary`/`secondary` | Aurora | O `meow` grava em `transparent_*` e deixa o Aurora propagar. O `--conferir` normaliza os 2 dígitos de alpha, senão o doctor acusa divergência eterna e entra em ping-pong com a unit `.path`. |
| `~/.config/cosmic/logos/gato-pop.svg` | Aurora | O gato Catppuccin entra como asset do Andromeda; o self-heal propaga. |
| ícone do App Library em `/usr/share` | Aurora | Idem — mesma fonte, dois destinos. |
| tema do qBittorrent | Aurora | A allowlist dele ganha `catppuccin`; o `meow` chama o script em vez de escrever no `.conf`. |
| `~/.config/fastfetch` | Aurora | É symlink para o repo Andromeda, com auto-commit em 10 min. Mudança ali é deliberada, com commit. |
| atalhos de teclado | Aurora | O `meow` não escreve e exclui do restaurar. |
| `pinned_workspaces` | Aurora | Fora do restaurar: restaurar por cópia derrubaria os workspaces `Meow` e `OS`. |
| `CosmicTerm/v1` | dividido | O `meow` escreve só `color_schemes_*`. Nunca `keybindings` nem `shortcuts_custom` — é o colar dela. |
| `plugins_wings` do painel | Aurora | Entra no backup, sai do restaurar. A ordem dos applets é dela. |

---

## 6. O que nunca fazer nesta máquina

- **`apt upgrade` ou mexer em pacote `cosmic-*`.** O `/usr/bin/cosmic-comp` está
  patchado duas vezes (workspace vazio e night light). Uma versão nova mata os dois de
  uma vez e derruba os workspaces alfinetados junto.
- **`sudo` perto de `~/.config`.** Um arquivo de dono root ali faz a GUI de tema falhar
  **em silêncio**, e o sintoma aparece dias depois.
- **Escrever em `~/.config/zsh`.** É o repo Andromeda, com auto-commit a cada 10 min:
  qualquer arquivo largado lá vira commit e push no repositório privado dela.
