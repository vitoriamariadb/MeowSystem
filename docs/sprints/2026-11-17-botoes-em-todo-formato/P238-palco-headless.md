# P238 — o palco headless: nenhuma medição abre janela na sessão de quem usa (17/11/2026)

Texto de quem usa, 17/11: «consegue fazer com que seja tudo headless? cada consulta de tudo». Contexto: os agentes da
leva abriram o Chrome, apps flatpak e diálogos do portal na tela dela para fotografar a barra de título (e um diálogo
de arquivos ficou aberto).

## O que se mediu (coordenador, 17/11)
- Instalados: `Xvfb`, `xvfb-run`, `dbus-run-session`, `cosmic-comp` (build do MeowSystem em `~/.local/bin`).
  Ausentes: `weston`, `sway`, `cage`, `labwc`, `grim`, `wayvnc` (o apt oferece `weston 13` e `sway 1.9`).
- O que foi medido na tela dela: barra de título de app GTK, Qt, Electron e Chromium (o desenho é do app: CSD,
  ou do compositor: SSD do COSMIC), app_id de janela (`ext_foreign_toplevel_list_v1`), diálogos do portal.

## A cura na origem
Um palco isolado, `scripts/palco.sh`, que qualquer agente usa para toda consulta visual ou de janela:
1. Sessão própria: `dbus-run-session` (barramento novo: portal, notificação e chaveiro não chegam à sessão dela),
   `XDG_RUNTIME_DIR` temporário, HOME temporário com cópia só do que a medição pede (tema de ícones, `meow.conf`,
   perfil copiado do app), nunca o HOME real escrito.
2. Compositor sem tela: medir primeiro se o `cosmic-comp` sobe sem saída visível (backend X11 dentro do `Xvfb`, ou
   outro modo headless que ele tenha), porque só ele desenha o SSD com a arte do pack; se não subir, um wlroots
   headless (`WLR_BACKENDS=headless`, `cage` ou `sway`) com `grim` para a foto, e dizer em voz alta o que esse palco
   NÃO prova (o SSD do COSMIC). Pacote que precisar de apt: devolva o comando exato ao coordenador, que instala.
   Plano B, sugerido por quem usa («ou usar o workspace os», «ou só o monitor da tela direita»): para o que só o
   COSMIC real prova, abrir a janela direto na área de trabalho «OS» ou na tela da direita, sem roubar o foco nem
   trocar a área que ela está vendo (medir: o `zcosmic_toplevel_manager` move a janela de área e de tela; ver se a
   janela pisca na área dela antes de mover, e se o foco volta). Só se o headless não provar o caso.
3. Comandos: `palco.sh subir`, `palco.sh rodar <cmd…>` (app dentro do palco), `palco.sh foto <saida.png>`
   (tela inteira ou recorte), `palco.sh janelas` (a sonda `appid_sonda.py --janelas` contra o palco),
   `palco.sh descer` (mata só o que o palco subiu). Idempotente; `descer` sem palco não é erro.
4. Regra no `GSD.md` (seção Armadilhas): medição visual ou de janela só pelo palco; nada abre na sessão dela. O
   `tests/decisoes.sh` ganha a prova da regra se o GSD pedir.

## Como se prova
Teste que sobe o palco, roda um app GTK (ex.: `gnome-calculator` ou um `zenity`), tira a foto, lista a janela com o
app_id certo e desce, conferindo que nenhum toplevel novo apareceu na sessão real (sonda antes e depois) e que o
barramento da sessão real não viu o app. Foto de um app GTK com os botões do pack Dracula dentro do palco.
