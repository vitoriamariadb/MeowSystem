# P159 — compartilhar tela e janela no COSMIC (06/11/2026)

Pedido de 06/11/2026: transformar em feature do MeowSystem a correção feita à mão no nitro-5, para os três PCs. Hoje
ela só existe naquela máquina. Estado: **o crash daqui acabou**: a tela apareceu no navegador e nenhum panic em
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

Decisão de 06/11/2026: a correção entra na build do MeowSystem, idempotente, para valer nos três PCs («tenho outros
dois pcs com o mesmo problema»). Compositor e Extensões precisam conter todas as correções: P159, P160 e P162.
A P159 é a dona do trilho do portal e da policy; a P160 entrega o patch do toolkit para ele.

**1. O portal entra no molde do `files_menu.sh` e do `garantir_builds.sh`.** Um script `portal_captura.sh`, com os verbos
`conferir`, `aplicar` e `reverter`, e o pacote `xdg-desktop-portal-cosmic` em `_gb_instalados`. Depois de cada apt o
`garantir_builds` recompila sozinho para a versão nova, sem barrar o compositor nem o menu: portal ruim derruba o
compartilhamento, não o login. Aparece no `meow doctor` e na página Extensões.

- Em `patches/`: o `.patch` do portal (P159), o do toolkit (P160) e uma `versao` própria, com dry-run `-F0`.
- O `[patch]` do `Cargo.toml` não pode ter caminho absoluto: hoje aponta para `/home/andrefarias/...`.
- O binário entra por shim, como o do compositor, nunca direto pelo drop-in: drop-in apontando para binário
  ausente deixaria a máquina sem portal nenhum. Sem build válida para a versão instalada, o shim chama
  `/usr/libexec/xdg-desktop-portal-cosmic`.
- Sair do trilho sozinho quando #286 e #384 tiverem correção oficial no pacote.

**2. A policy do Chrome entra no mesmo verbo `aplicar`,** com o arquivo igual nos três PCs:
`/etc/opt/chrome/policies/managed/compartilhar-tela.json`.

```json
{
  "ScreenCaptureAllowed": true,
  "VideoCaptureAllowed": true,
  "AudioCaptureAllowed": true
}
```

Comando manual usado no nitro-5:

```bash
sudo tee /etc/opt/chrome/policies/managed/compartilhar-tela.json >/dev/null <<'EOF'
{
  "ScreenCaptureAllowed": true,
  "VideoCaptureAllowed": true,
  "AudioCaptureAllowed": true
}
EOF
```

Decisão de 06/11/2026: a solução do compositor cobre o caso de existir Chrome no PC da pessoa. A policy depende disso,
e o resto da build não:

- Com o pacote `google-chrome-stable` instalado: aplica a policy.
- Sem Chrome: pula em silêncio, sem criar `/etc/opt/chrome`, sem pedir sudo e sem falhar a build. Portal e compositor
  seguem iguais, porque a correção deles vale para qualquer app que compartilhe tela.
- Chrome instalado depois: o gatilho pós-apt que já roda o `garantir_builds` aplica a policy, sem esperar outra build.
- Chrome em Flatpak ou Chromium usam outro caminho de policy: medir antes de cobrir, sem assumir que este arquivo vale.

Os três valores já são o padrão do Chrome, e o efeito próprio deles não foi isolado: o relato
é que o compartilhamento passou a aparecer depois do comando, mas o crash do portal continuou até a cura. Entra por
decisão, com arquivo próprio, sem tocar no `aurora-no-ai-no-antigravity.json` da Aurora.

**3. Idempotência é o critério de aceite.** Rodar `aplicar` duas vezes na mesma versão não compila, não escreve e não
reinicia o portal: a segunda passagem compara e sai `ok`. O `reverter` devolve portal e policy ao estado do pacote.
O portal só reinicia se a versão mudou, e nunca com stream ativo. A policy só pede sudo se o conteúdo divergir.

**4. Os três PCs.** O nitro-5 mediu tudo. MeowSystem (só RTX 4060) e Meow-portatil (Intel + RTX 4060) relatam o mesmo
problema, sem medição. Rodar a mesma prova em cada um, porque o `req` da série vale para todos.

## Como se prova

1. Em https://webrtc.github.io/samples/src/content/getusermedia/getdisplaymedia/ escolher Janela: o vídeo
   aparece e fica no ar.
2. `coredumpctl list --no-pager | grep portal-cosmic` não ganha entrada nova depois da tentativa.
3. Repetir com Tela inteira e no Teams.
4. Nos três PCs: `aplicar` duas vezes, e a segunda não muda nada.
   Num PC sem Chrome, `aplicar` sai `ok` sem criar a pasta; instalar o Chrome depois e o pós-apt cria a policy.
5. `apt` trazendo versão nova do portal: o `garantir_builds` recompila, ou o shim cai no pacote se o patch recusar.
6. `reverter` deixa o portal do pacote funcionando e tira a policy.
