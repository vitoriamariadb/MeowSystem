# P127 — O override do Flatpak não quebra os apps libadwaita

**Decidida em 27/10: opção b.** Quem usa: «tira e vamos criar um tema pra cada app» (o tema por app é a P129).
O contorno que roda hoje no Nitro, fora do produto, está em `relatorios/contorno-local.md`.

**Pedido de quem usa (27/10):** «pode ver pq o clapper não abre no meu pc? E se tem outros .desktop do mesmo
jeito?», e depois: «não é mesmo a interface dele. isso é algum problema com o ambiente gráfico». Mais tarde:
«crie uma solução global em .sh que seja idempotente e sobreviva ao sudo apt upgrade», e pensar numa solução
a nível de produto.

## O que se mediu (27/10, no Nitro: Pop!_OS 24.04, COSMIC no Wayland, Flatpak 1.18.1)

O override global do usuário (`~/.local/share/flatpak/overrides/global`) tinha três itens que quebram os
apps GTK4 com libadwaita. Cada um foi isolado com o app aberto e um print da tela:

| item no override global | quem escreve | efeito medido |
|---|---|---|
| `GTK_THEME=adw-gtk3-dark` | `scripts/flatpak_tema.sh:88-92`, que copia o `gtk-theme` do gsettings (`FT_CHAVES`, linha 14) | com a variável definida, o libadwaita não carrega o próprio estilo: ícone de 16 px em vez de 128, botões sem forma, layout cru (Clapper, Gradia, BoxBuddy, Warehouse, Upscaler) |
| `filesystems=xdg-config/gtk-4.0:ro` | veio de fora, da época do NitroKit; o `flatpak_tema.sh` preserva (`tests/flatpak-tema.sh:78`) | expõe o `~/.config/gtk-4.0/gtk.css` gerado pelo COSMIC; o libadwaita 1.8 fica com fundo branco e texto branco por cima |
| `filesystems=xdg-data/icons:ro` | `flatpak_tema.sh` (`_ft_somar_fs` com a raiz do tema de ícones) | o Flatpak já monta os mesmos ícones em `/run/host/user-share/icons`; expostos de novo, os temas aparecem duas vezes no caminho de busca. Quando o app cria um `Gtk.IconTheme.new()` sem tela, o GTK 4.20 entra em recursão infinita em `real_choose_icon` (52 mil chamadas na pilha) e o app morre com SIGSEGV. O Warehouse faz isso em `host_info.py:219` e não abria |

Provas que separam as causas:
- Sem `GTK_THEME` e sem o `gtk-4.0`, o Clapper aparece certo (escuro, título, descrição, dois botões).
  Com só um dos dois removidos, ainda fica errado.
- O Warehouse abre com `--nofilesystem=xdg-data/icons` e continua mostrando os ícones do MeowSystem, que
  chegam por `/run/host/user-share/icons`. Ele crasha com a pasta exposta inteira e não crasha com as
  mesmas subpastas expostas uma a uma (a duplicata só aparece no primeiro caso).
- Renderizador (`GSK_RENDERER=cairo|gl|ngl|vulkan`) e backend não mudam nada.

Apps libadwaita no Nitro, detectados por `grep -a` nos arquivos do app (`libadwaita-1.so`,
`require_version('Adw')`, `gi://Adw`): Clapper, Gradia, BoxBuddy, Warehouse, Upscaler. O Telegram usa o
runtime GNOME, mas é Qt, e fica de fora.

Armadilha medida: no zsh desta máquina `grep` é o `ugrep`, que pula binários. A detecção roda em `bash`
com `grep -a`.

**Duas máquinas.** As medidas desta sprint foram tiradas no Nitro (o PC do André), onde o contorno de `relatorios/contorno-local.md` roda. Na máquina dela (Meow-portatil, medida em 27/10) o override global tem o mesmo problema (`GTK_THEME=adw-gtk3-dark`, `xdg-config/gtk-4.0`, `xdg-data/icons`, `/usr/share/themes`), e os apps libadwaita são outros: Gradia, Upscaler e Calculadora (GNOME 51) e Flatseal (GNOME 50). A lista de apps sai sempre da detecção, nunca de nome fixo.

## A causa, na origem
O `flatpak_tema.sh` trata todos os Flatpaks como se fossem GTK3: `GTK_THEME` serve para GTK3 e quebra o
libadwaita. A exposição de `xdg-data/icons` é redundante desde que o Flatpak passou a montar
`/run/host/user-share/icons` (versão mínima a confirmar), e a redundância derruba o GTK 4.20.

## A cura: opção b (pela `relatorios/auditoria-tema-por-app.md`)

Medido em 27/10: o `GTK_THEME` não muda nada nos apps GTK3 (mesmo tema e mesma cor de fundo com e sem ele), e
nenhum pack declara tema GTK. A dúvida da opção b está respondida: o pack Dracula não precisa do `GTK_THEME`.

- **a) Exceção por app (o que o script local faz hoje).** O `flatpak_tema.sh` continua escrevendo o
  global e grava, para cada app libadwaita, `--unset-env=GTK_THEME --nofilesystem=xdg-config/gtk-4.0
  --nofilesystem=xdg-data/icons`. Funciona com qualquer pack, mas cria uma lista que precisa acompanhar
  instalações (gatilho `.path` do systemd e o doctor).
- **b) Tirar a causa do global (recomendada).** Parar de escrever `GTK_THEME` e `xdg-data/icons` no global. Os apps
  GTK3 recebem o tema pela extensão `org.gtk.Gtk3theme.<nome>`, que o Flatpak escolhe pelo `gtk-theme` do
  portal (a `adw-gtk3-dark` já está instalada aqui). Mais limpa, mas o tema do pack Dracula, que vive em
  `~/.themes`, não tem extensão no Flathub: medir antes se ele precisa do `GTK_THEME`.
- `/usr/share/themes` também sai do que o MeowSystem escreve: o Flatpak recusa montar `/usr` («O caminho "/usr"
  está reservado» em toda execução), e com o `GTK_THEME` fora ele não serve a nada.
- Nos dois casos: `xdg-data/icons` sai do que o MeowSystem escreve, e o `xdg-config/gtk-4.0` herdado do
  NitroKit vira item do `flatpak-global-limpar` da ponte root (P99), sem caixa de senha.
- Par `chk_`/`fix_` no doctor: «app libadwaita com tema quebrado» e «ícones expostos em dobro». O
  `--consertar` aplica; a segunda passada não escreve; o desinstalador devolve o de antes.

## Como se prova
- Casa de brinquedo com `flatpak` falso: o doctor vê os três itens, o `--consertar` aplica, a segunda
  passada não escreve, trocar de pack não traz o `GTK_THEME` de volta para um app libadwaita, o
  desinstalador devolve.
- Na máquina dela, depois do fecho da leva: Gradia, Upscaler e Calculadora abrem com o visual certo, com print, e um app GTK3 Flatpak continua
  escuro.
- `tests/todos.sh` verde duas vezes.
