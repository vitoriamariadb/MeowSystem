# P105 — O Criar tema leva papéis e sons para o pack, e o mockup ganha motor

**Status: REGISTRADA em 24/10; entra depois da P102 (o formato de foto no pack sai dela) e da P104.**
Vem da P98, «ficou de fora» 3 e 4. O desenho de referência é o mockup final da P97:
`docs/design/2026-10-23/final/` (`criar-papel.html`, `criar-sons.html`, `criar-icones.html`,
`ajustes-dia-e-noite.html`).

Cada item: teste vermelho antes, verde depois, um commit por item. QA do painel só com HOME temporário
(decisão 8). Interface sem texto explicativo (GSD §2). Trabalho visual passa pela skill `hallmark`.

## 1. Papéis de parede do Criar tema vão para dentro do pack
- Medido (P98): o passo Papel de parede do Criar tema usa as fotos da máquina, e o «Mandar» (`pack.py novo`)
  não as grava no pack.
- Cura: as fotos escolhidas no passo vão para `packs/<novo>/wallpapers/`, no formato que a P102 criou (leia a
  seção «Execução» da P102). Vestir esse pack põe essas fotos na rotação, sem rede.
- Prova: criar um pack no HOME temporário com 2 fotos, vestir, e as 2 aparecem na rotação.

## 2. Sons do Criar tema vão para dentro do pack
- Medido: o pack já tem o bloco `som` (`packs/dracula/pack.json`, `"tema": "sons/"`), mas o «Mandar» não grava
  os sons escolhidos no passo.
- Cura: os sons escolhidos vão para `packs/<novo>/sons/`, e o bloco `som` aponta para eles. Só formatos que o
  tema de sons já aceita, e nome validado (pack é dado, nunca código).
- Prova: criar o pack, vestir, e o tema de sons instalado é o do pack.

## 3. «Sons de aviso» (Criar › Sons)
- Do mockup: a lista de sons de aviso, um por evento, com prévia ao clicar.
- Cura: liga a lista ao motor de sons do item 2. Se um evento do mockup não tem som no tema de sons, ele não
  aparece (nada de fingir na tela).

## 4. Abas Sistema e Biblioteca em Criar › Ícones
- Do mockup: além da grade de aplicativos, as abas Sistema (`icones/sistema`) e Biblioteca (`icones/biblioteca`).
- Cura: as duas abas leem as pastas do pack, como a de aplicativos. «Levar para o tema» funciona igual.

## 5. «Tudo segue este horário» (Ajustes › Dia e noite)
- Do mockup: um interruptor que faz mascote, papel de parede e o resto seguirem o mesmo horário de dia e de noite.
- Cura: se o motor tem horários separados por área, o interruptor grava todos com o mesmo valor; desligado,
  cada área volta a ter o seu. Se uma área não tem horário próprio, ela não aparece.
- Prova: ligar e desligar no HOME temporário, conferindo o `meow.conf`.

## Como se prova
- `tests/todos.sh` duas vezes, verde. Prints do painel em 1829x1029 e 375 px nas telas tocadas
  (`tests/app-uso-real.py --fotos`).

## 6. O `desbanir` com foto da curadoria de fábrica (quem coordena, 24/10)
- Medido na máquina real: 8 fotos estavam em `ativos/` e no `BANIDOS.txt` vivo (vindas do `.padrao`), mas não
  em `banidos/`. O `wallpaper.sh desbanir <nome>` recusava com «não achei … em banidos/». Quem coordena tirou as
  linhas à mão (backup em `~/.local/state/meowsystem/backup-limpeza-20261024/`).
- Cura: com a foto em `ativos/` e o nome na lista, o `desbanir` só tira a linha (o `grep -vxF` que ele já tem).
  Sem foto em lugar nenhum, a recusa continua.
- Prova: teste com HOME temporário cobrindo os três casos (em `banidos/`, só na lista com foto em `ativos/`,
  nada em lugar nenhum).

## Fora deste bloco
- A P104 (ponte) e a P106/P107 (temas de app) estão em voo ou esperando integração. Não toque em
  `scripts/ponte_root.sh` nem em `scripts/temas-de-apps/`.
