# O prompt — Sprint R

Esta é a única sprint do MeowSystem que **não termina em commit nosso**. O
produto são dois arquivos e um comando que **você** roda.

O motivo é de fronteira, não de preguiça: o prompt do zsh mora em
`~/.config/zsh/env.zsh`, que é o repositório do **Ritual da Aurora**, com
auto-commit a cada 10 minutos. A TRAVA 1 do `lib/comum.sh` recusa aquele caminho
por caminho (`vizinhos.conf`), e está certa.

Mas a configuração do `starship` **não** mora lá — ela mora em
`~/.config/starship.toml`, que não pertence a vizinho nenhum. Então a sprint se
parte exatamente onde a fronteira parte:

| metade | onde | quem faz |
|---|---|---|
| o preset Catppuccin | `~/.config/starship.toml` | **nós** — `scripts/prompt.sh aplicar` |
| ligar o prompt e o fzf | `~/.config/zsh/env.zsh` | **você** — `aurora.patch` |

---

## ATENÇÃO: O aviso que vem antes de tudo

**Aplicar o `aurora.patch` vira um commit no seu repositório privado
(`~/.config/zsh`) em até 10 minutos, sozinho, sem ninguém apertar nada.**

Isso é o comportamento normal do autosync de lá — não é defeito. Mas é decisão
consciente, e por isso está escrito aqui em vez de acontecer calado. Se você não
quiser o commit agora, o caminho é aplicar depois: **nada** neste diretório
escreve em `~/.config/zsh` por conta própria, nem o `meow doctor`, nem o timer
das 05:00, nem o `install.sh`.

---

## O que foi medido antes (25/08/2026)

**1. O `starship` não está no apt do Pop!_OS 24.04.** Confirmado, e a
`docs/SPRINTS.md` estava certa:

```
$ apt-cache policy starship      # devolve VAZIO
$ apt-cache show starship
E: Nenhum pacote encontrado
```

O que existe no `universe` são as caixas de Rust
(`librust-starship-module-config-derive-dev`, `librust-starship-battery-dev`) —
fonte para compilar outra coisa, não o binário. Instala por script oficial ou
pelo `cargo`.

**2. O prompt em uso NÃO era o `agnoster`.** Este é o ponto em que a sprint
errava a causa. O `ZSH_THEME="agnoster"` da linha 9 é lido, o oh-my-zsh carrega o
tema na linha 26 — e a **linha 135 do mesmo arquivo** o joga fora:

```zsh
export PS1='%{$bg[blue]%}%{$fg[white]%} %n@%m %{$reset_color%}%{$bg[black]%}%{$fg[cyan]%} %~ %{$reset_color%} '
```

Medido no shell vivo, `zsh -i -c 'print -r -- $PROMPT'` devolve esse PS1, nunca
um segmento do agnoster. Ou seja: o agnoster era carregado a cada abertura de
terminal **para não aparecer na tela**. O patch mexe nas duas linhas, e é por
isso que mexer só na linha 9 não mudaria nada.

**3. A Nerd Font está pronta.** É a `JetBrainsMono Nerd Font Mono`, instalada
pelo `scripts/instalar_fontes.sh` em `~/.local/share/fonts/MeowSystem/` (16
arquivos), e é a mesma que o `cosmic-term` usa (`font_name` da config dele). Os
**44** codepoints não-ASCII do nosso `starship.toml` existem nela — conferidos um
a um com `fc-query -f '%{charset}'`.

**4. O `FZF_DEFAULT_OPTS` não existe em lugar nenhum.** A paleta que você já
validou está copiada em **cinco** lugares do seu repositório (`env.zsh:42` no
fzf-tab, `functions/mec.zsh:12`, `mec.zsh:147`, `limpeza.zsh:32`,
`projeto.zsh:201`) e em nenhum deles alcança o fzf do dia a dia. O Ctrl+R roda
sem cor nenhuma.

---

## Os arquivos

### `starship.toml`

O preset **oficial** `catppuccin-powerline`, baixado de
<https://starship.rs/presets/toml/catppuccin-powerline.toml>
(sha256 do original: `c23746e4…5febcb`).

Os 26 hex do flavor mocha foram conferidos contra `palette/catppuccin.json` deste
repositório: **batem os 26**, sem divergência.

Quatro mudanças, todas nomeadas no cabeçalho do próprio arquivo:

1. **só o flavor mocha** (o preset traz quatro e usa um);
2. **accent `mauve` no lugar de `red`**, no segmento de cabeça — porque
   `ACCENT="mauve"` governa o resto da máquina, e porque assim vermelho no prompt
   volta a significar só uma coisa: deu errado;
3. **`Pop = "…"` acrescentado** em `[os.symbols]` — sem essa linha o starship cai
   no padrão dele, que para Pop!_OS é um **pirulito "<U+1F36D>" (um pirulito)** (`src/configs/os.rs:77`),
   e o U+1F36D **não existe** na sua fonte: sairia um emoji colorido de outra
   fonte dentro do retângulo mauve;
4. **`show_notifications = false`** — o preset vem com `true` e 45 s, ou seja,
   todo comando demorado penduraria uma notificação de desktop na sua tela.

### `aurora.patch`

Três mudanças em `env.zsh`, 67 linhas de diff:

1. `ZSH_THEME="agnoster"` → `ZSH_THEME=""` (com string vazia o oh-my-zsh não
   sourceia tema nenhum — `oh-my-zsh.sh:223`);
2. a seção 5 passa a chamar `eval "$(starship init zsh)"`, **com guarda**:
   se o `starship` sumir do PATH, o `else` devolve exatamente o PS1 de antes, em
   vez de abrir um shell sem prompt;
3. `FZF_DEFAULT_OPTS` ganha a paleta — o valor **exato** de
   `functions/mec.zsh:12`, sem uma vírgula de diferença.

---

## Como fazer

### 1. Instalar o starship (é sua decisão — nada aqui instala)

Sem `sudo`, em `~/.local/bin` (que já está no seu PATH, `env.zsh:11`):

```sh
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$HOME/.local/bin"
```

Ou pelo `cargo`, que você já tem em `~/.cargo/bin`:

```sh
cargo install starship --locked
```

### 2. A metade nossa

```sh
meow doctor --consertar          # ou: ./scripts/prompt.sh aplicar
```

Escreve `~/.config/starship.toml` e mais nada. Idempotente, e o `meow doctor`
passa a conferir esse arquivo todo dia.

### 3. A metade sua

```sh
cd ~/.config/zsh
patch -p1 --dry-run < /mnt/Apate/Desenvolvimento/MeowSystem/src/prompt/aurora.patch
patch -p1           < /mnt/Apate/Desenvolvimento/MeowSystem/src/prompt/aurora.patch
```

O `--dry-run` não escreve nada e acusa antes se o `env.zsh` tiver mudado desde
12/08/2026 (o patch foi gerado contra a versão de 181 linhas).

Vale no **próximo terminal**. Para ver na hora: `exec zsh`.

### Conferir

```sh
./scripts/prompt.sh conferir
```

- `0` tudo no lugar
- `1` o **nosso** arquivo divergiu (o doctor conserta)
- `3` falta o starship, ou `PROMPT_STARSHIP="nao"` no meow.conf
- `4` o nosso lado está certo e o `env.zsh` ainda não foi patcheado — **não é
  divergência, é a sua metade**, e o auto-reparo nunca mexe nela

---

## Como desfazer

Byte a byte, e está conferido (`cmp` devolve igualdade com o original):

```sh
cd ~/.config/zsh
patch -R -p1 < /mnt/Apate/Desenvolvimento/MeowSystem/src/prompt/aurora.patch
```

E, se quiser tirar também o nosso arquivo:

```sh
./scripts/prompt.sh remover
```

**Nesta ordem.** Ao contrário, o `env.zsh` continua chamando o starship sem
configuração e você não volta ao prompt antigo — volta ao prompt **padrão** do
starship, que ninguém escolheu. O `remover` avisa isso antes de agir.

---

## O que ficou de fora de propósito, porque é gosto e não técnica

Nada abaixo está aplicado. As linhas estão prontas para você decidir depois.

**O relógio no prompt.** O preset desenha `%R` no fim da linha, e o seu painel já
tem relógio. Para tirar, em `~/.config/starship.toml`:

```toml
[time]
disabled = true
```

(e tirar `$time` e o `[](fg:sapphire bg:lavender)` do `format`, senão sobra um
retângulo lavanda vazio.)

**Os milissegundos do `cmd_duration`.** `show_milliseconds = false` deixa
`2m 13s` em vez de `2m 13s 402ms`.

**A altura e a borda do fzf.** O `FZF_DEFAULT_OPTS` do patch leva **só a cor**,
porque era só a cor que a sprint pedia promover. Se quiser que o Ctrl+R também
abra em painel, como o fzf-tab já abre, é acrescentar ao fim daquela string:

```
 --height=60% --layout=reverse --border
```

Nada disso quebra o que já existe: o fzf lê o `FZF_DEFAULT_OPTS` primeiro e a
linha de comando depois, e a última opção repetida vence — então os cinco lugares
que já passam o próprio `--color=` continuam exatamente como estavam.

---

## Duas interações conhecidas, para ninguém perseguir fantasma depois

**O `RPROMPT` não é do starship, e tudo bem.** O seu
`functions/prompt-hint.zsh` escreve `RPROMPT` num hook de `zle-line-pre-redraw`,
que roda **depois** do `precmd` do starship. Na prática o prompt-hint é o dono do
lado direito da linha. Como o preset `catppuccin-powerline` não define
`right_format`, o starship não desenha nada ali de qualquer jeito — não há perda,
e ainda se economiza um subprocesso por prompt. Mas se um dia alguém configurar
um prompt à direita no starship e ele não aparecer, **a causa é esta**.

**O oh-my-zsh continua carregando.** O patch zera o `ZSH_THEME`, não desliga o
framework: os plugins (`git`, `fzf`, `fzf-tab`, `autosuggestions`,
`history-substring-search`, `syntax-highlighting`) continuam exatamente como
estão. Só o tema sai.
