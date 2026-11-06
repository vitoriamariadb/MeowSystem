# P159 — compartilhar tela e janela no COSMIC (06/11/2026)

Pedido de 06/11/2026: transformar em feature do MeowSystem a correção feita à mão no nitro-5. Hoje ela só
existe naquela máquina. Estado: **o crash daqui acabou**: a tela apareceu no navegador e nenhum panic em
`screencast_thread.rs:456` desde 11:00. O compartilhamento ainda congela por outro defeito, a P160.

## O que se mediu

No nitro-5 (Pop!_OS 24.04, `xdg-desktop-portal-cosmic` 1.11.0, commit `f448ddf`, pipewire 1.6.8, Chrome `.deb`
156, `COSMIC_RENDER_DEVICE` na RTX 3050):

- Todo compartilhamento de janela pelo Chrome fecha na hora, com «The user has ended sharing the screen».
- O portal aborta com core dump a cada tentativa: 15 panics iguais entre 04/11 e 06/11, sempre com
  `invalid modifier prop choice: None(0)` seguido de `src/screencast_thread.rs:456`.
- Portal, PipeWire e as policies do Chrome estão sãos. Não há permissão a conceder: o Chrome `.deb` não tem
  sandbox, e policy não muda nada aqui.

## A causa

Bug do portal, aberto em [pop-os/xdg-desktop-portal-cosmic#286](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/286)
e ainda presente na `master`; o PR #385 foi fechado sem merge. Quando a negociação de dmabuf sobra com um único
modifier (0, LINEAR), o PipeWire entrega `ChoiceEnum::None`. O `param_changed` só aceita `ChoiceEnum::Enum`, sai
sem preencher `self.modifier`, e o `add_buffer` aborta em `self.modifier.unwrap()`, dentro de um callback FFI.

Não é da NVIDIA: a issue traz o mesmo panic numa máquina só com AMD (Radeon 680M, Fedora 44). Trocar o modo
gráfico não é a cura. Por que sobra um modifier só nesta máquina não foi medido.

## A cura na máquina (nitro-5)

Patch de uma função: `format_params` passa a oferecer só SHM, sem dmabuf. O mesmo recorte foi testado por um
usuário da issue na 1.11.0. Custo: cópia pela CPU durante o compartilhamento.

- Fonte: `~/.local/src/xdg-desktop-portal-cosmic`, branch `aurora-shm-only`, commit `9ce8916`.
- Binário: `~/.local/libexec/aurora/xdg-desktop-portal-cosmic`.
- Entra por drop-in: `~/.config/systemd/user/org.freedesktop.impl.portal.desktop.cosmic.service.d/shm-sem-dmabuf.conf`.
  Para desfazer: apagar esse arquivo, `systemctl --user daemon-reload` e reiniciar o serviço.

```diff
+    let _ = (dmabuf, fixated);
     let mut pods = Vec::new();
-    if let Some((fixated_format, fixated_modifier)) = fixated { ... }
-    if let Some(dmabuf) = dmabuf { ... }
     for shm_format in &formats.shm_formats {
```

## A feature

O portal entra no mesmo trilho do `meow compositor` (`patches/`, `patches/versao`, dry-run com `-F0`, marcador
no binário, `reverter`), sem misturar com a série do cosmic-comp, que é `req` e também é a tela de login. Portal
ruim derruba o compartilhamento; não pode barrar o build do compositor.

A decidir na hora de implementar:

1. Instalar por drop-in da unit de usuário ou no lugar de `/usr/libexec`. O drop-in sobrevive ao apt e se desfaz
   apagando um arquivo.
2. Quando o patch sai: `patches/versao` recusa versão nova, e o `meow doctor` avisa se a #286 foi corrigida.
3. Medir o bug no MeowSystem (só RTX) e no Meow-portatil (Intel + RTX). Nenhum dos dois foi testado.

## Como se prova

1. Em https://webrtc.github.io/samples/src/content/getusermedia/getdisplaymedia/ escolher Janela: o vídeo
   aparece e fica no ar.
2. `coredumpctl list --no-pager | grep portal-cosmic` não ganha entrada nova depois da tentativa.
3. Repetir com Tela inteira e no Teams.
