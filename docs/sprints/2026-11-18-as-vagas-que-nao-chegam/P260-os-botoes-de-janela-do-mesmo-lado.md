# P260 — os botões de janela do mesmo lado em todo app (19/11/2026)

## Texto de quem usa
«Temos tipo nos navegadores que os botões de abrir fechar e minimizar ficam a esquerda lá. Mas o resto dos programas
fica a direita. Salvo engano isso pq no gnome eu usava assim e o port pra cá mantém isso. Mas no cósmic eu não consigo
jogar tudo pra um lado ou pro outro. Meu sonho é poder jogar pra esquerda em todos os apps. Se for impossível trás os
que estão a esquerda pra manter igual os demais a direita»

## O que se mediu (19/11 14h20)
- Desktop e portátil: `gsettings get org.gnome.desktop.wm.preferences button-layout` = `close,maximize,minimize:` e
  `gtk-decoration-layout=close,maximize,minimize:` no `settings.ini` do GTK 3 e do GTK 4. nitro-5:
  `:minimize,maximize,close`, sem linha no `settings.ini`.
- Quem mantém a esquerda nos PCs da Vitória é o zsh dela: `scripts/aurora-button-layout.service` («manter
  button-layout das janelas à esquerda», vigia de 5 min). O MeowSystem não escreve essa chave em lugar nenhum.
- A libcosmic põe os botões no fim da barra no código (`src/widget/header_bar.rs`, `end.push(self.window_controls(…))`),
  sem opção, também no `master` do upstream de hoje. Esquerda em todo app do COSMIC pede patch na biblioteca e build
  de cada app em cada PC.

## A resposta de quem usa
AskUserQuestion de 19/11 14h25: «Direita já, esquerda medida depois (Recomendado)».

## A cura na origem
- O MeowSystem passa a ser dono do lado: chave `BOTOES_LADO="direita"` (`direita` | `esquerda`) no `meow.conf`, com
  cartão no painel, etapa no install e conferência no doctor. A etapa escreve o `button-layout` do gsettings e o
  `gtk-decoration-layout` do GTK 3 e do GTK 4, mantendo a ordem dos botões que já está lá e trocando só o lado.
- `esquerda` vale para o que lê o GTK; os apps do COSMIC seguem à direita até a sprint da próxima leva (P261: medir
  quantos apps, quanto build por PC e a manutenção, antes de quem usa decidir).
- O `aurora-button-layout` do zsh da Vitória sai pelo espelho (regra da casa), e o coordenador desarma a unidade nos
  dois PCs; sem isso ele devolve a esquerda em 5 minutos.

## Como se prova
- Teste novo com HOME temporário e `gsettings` falso: `direita` e `esquerda` escrevem os três lugares; a segunda
  passada não escreve; a ordem dos botões que a pessoa tinha fica; chave inválida recusa.
- `tests/app.sh`, `tests/chave-etapa.sh`, `tests/decisoes.sh`, `tests/doctor-veredito.sh`, `tests/convergencia.sh`,
  `tests/numeros.sh` e `tests/readme.sh` verdes.
- Foto no palco: Firefox ou Chrome com os botões à direita.

## Nos três PCs
Vale nos três; muda o que se vê no desktop e no portátil.
