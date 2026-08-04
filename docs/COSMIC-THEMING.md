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

## 2. `/usr/share/icons` VENCE `~/.local/share/icons`

**Medido em 2026-08-04.** Esta é a descoberta que muda o projeto, porque contradiz a
regra "nada em `/usr/share`" da especificação.

O teste anterior era inconclusivo: os dois arquivos tinham o mesmo conteúdo
(md5 `9b3d3ada...`), então era impossível saber qual vencia. Tornei-os diferentes.

1. Plantei um **triângulo vermelho puro** em
   `~/.local/share/icons/hicolor/{scalable,48x48,256x256}/apps/com.system76.CosmicAppLibrary.svg`
2. Rodei `gtk-update-icon-cache -f` (cache confirmado atualizado às 17:54:04)
3. Reiniciei o `cosmic-panel`

**Resultado: o botão continuou com o gato de `/usr/share`.** O triângulo nunca apareceu.

Um teste anterior, com um tema de ícones inteiro em `~/.local/share/icons/MeowTeste`
(herdando `breeze-dark`, com `index.theme` declarando `scalable/apps` e os tamanhos
fixos), também não teve efeito nenhum sobre painel ou dock.

**Consequência:** botões do painel e do dock só mudam escrevendo em `/usr/share/icons`.
Como isso é território do Ritual da Aurora e do apt, o caminho é:
o MeowSystem **gera** o ícone, e o self-heal do Andromeda **instala** — o mesmo padrão
já usado para o gato do menu de aplicativos, e já aprovado pela Vitória.

**Ainda não medido:** se a mesma preferência vale para os ícones dos aplicativos no
lançador (os 193 `.desktop`). Painel e dock são a *chrome* do próprio COSMIC e podem
resolver ícone por um caminho diferente do resto. Testar antes de decidir a estratégia
dos 193.

### Armadilhas do `~/.local/share/icons/hicolor` nesta máquina

Mesmo onde ele é lido, há duas pedras:

- O `index.theme` declara apenas
  `Directories=48x48/apps,128x128/apps,256x256/apps,512x512/apps` — **`scalable/apps`
  não está declarado**. Um SVG solto em `scalable/` é ignorado pelo padrão freedesktop.
- Existe um `icon-theme.cache`. Quando ele é mais novo que os diretórios, é ele que
  manda: arquivo novo fica invisível até rodar `gtk-update-icon-cache -f`.

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
