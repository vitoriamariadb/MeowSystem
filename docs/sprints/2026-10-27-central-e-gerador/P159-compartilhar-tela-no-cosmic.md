# P159 — compartilhar tela e janela no COSMIC (06/11/2026)

Pedido de 06/11/2026: transformar em feature do MeowSystem a correção feita à mão no nitro-5, para os três PCs. Hoje
ela só existe naquela máquina. Estado: **o crash daqui acabou**: a tela apareceu no navegador e nenhum panic em
`screencast_thread.rs:456` desde 11:00. O compartilhamento ainda congela por outro defeito, a P160.

## Alcance

Produto, não máquina. O bug é do portal e aparece em AMD puro, Intel e híbrida (#286). A decisão 6 põe o compositor na
placa dedicada em toda máquina híbrida, então o próprio MeowSystem deixa esses notebooks no cenário medido aqui; a relação
entre as duas coisas ainda é hipótese. O que é só do nitro-5 fica em «A cura na máquina», e não entra na build.

## O que se mediu

No nitro-5 (Pop!_OS 24.04, `xdg-desktop-portal-cosmic` 1.11.0, commit `f448ddf`, pipewire 1.6.8, Chrome `.deb`
156, `COSMIC_RENDER_DEVICE` na RTX 3050):

- Todo compartilhamento de janela pelo Chrome fecha na hora, com «The user has ended sharing the screen».
- O portal aborta com core dump a cada tentativa: 15 panics iguais entre 04/11 e 06/11, sempre com
  `invalid modifier prop choice: None(0)` seguido de `src/screencast_thread.rs:456`.
- Portal, PipeWire e as policies do Chrome estão sãos. Não há permissão a conceder: o Chrome `.deb` não tem
  sandbox, e policy não muda nada aqui.

## A causa

Medida em 06/11, nos dois lados da negociação, com o stream no ar e a captura lida direto do compositor:

| lado | GPU | formatos |
|---|---|---|
| captura do eDP-1 no `cosmic-comp` | `renderD128`, AMD | 8 modifiers `0x02…` e LINEAR |
| Chrome, nó `Stream/Input/Video` | NVIDIA (`--render-node-override=renderD129`) | 14 valores: `0x03…`, LINEAR e o `0xffffffffffffff` (INVALID) |

Em comum, só o LINEAR. A origem está em `target_node_for_output` (`src/backend/kms/mod.rs:729`): a captura usa a GPU a que a
tela está ligada, não a que renderiza. No notebook híbrido com a decisão 6, o compositor e os apps ficam na placa dedicada,
e o eDP segue na integrada. No PC de uma GPU só os dois lados coincidem, e o caso não deveria acontecer; falta medir.

Com um modifier só, o PipeWire entrega `ChoiceEnum::None`. O `param_changed` aceita só `ChoiceEnum::Enum`, sai sem preencher
`self.modifier`, e o `add_buffer` aborta em `self.modifier.unwrap()`, dentro de um callback FFI. Bug aberto em
[#286](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/286), ainda presente na `master`.

A #286 traz o mesmo panic numa máquina só com AMD, pela via do Electron, então o Chrome híbrido não é o único caminho até
ele. Trocar o modo gráfico não é a cura.

## A cura na origem

O SHM em tudo funciona, mas é contorno: desliga a GPU também em PC onde ela funcionaria. Decisão de 06/11/2026: **os dois,
em etapas**. A build entra com a parte 1, sem o SHM forçado, e a parte 2 é a P163.

1. **Portal:** o [PR #385](https://github.com/pop-os/xdg-desktop-portal-cosmic/pull/385), fechado sem merge e sem comentário,
   trata `None` como lista de um item e limpa o `self.modifier` velho quando o cliente volta para SHM. Mantém dmabuf onde há
   formato em comum. O autor relata que, em híbrida, o Chrome não importa o LINEAR de outra GPU e renegocia para SHM. Falta
   medir aqui, e a #286 aponta um furo: modifier fixado como `Value::Long` também cai no `return`.
2. **Compositor:** para usar a GPU no híbrido, a captura precisa acontecer na placa que renderiza, onde o Chrome já está.
   Sem a P163, o híbrido segue em SHM mesmo com a parte 1.

## A cura na máquina (nitro-5)

Contorno de uma função: `format_params` passa a oferecer só SHM, sem dmabuf. O mesmo recorte foi testado por um usuário da
issue na 1.11.0. Custo: cópia pela CPU durante o compartilhamento. Vale até a cura na origem entrar.

- Fonte: `~/.local/src/xdg-desktop-portal-cosmic`, branch `aurora-shm-only`, commit `9ce8916`.
- Policy: o comando `sudo tee` manual em `/etc/opt/chrome/policies/managed/compartilhar-tela.json`, com o JSON da feature.
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

Decisão de 06/11/2026: a correção entra no MeowSystem, idempotente, para valer em todo PC («tenho outros dois pcs com o
mesmo problema»). Portal, toolkit e policy formam uma build própria, **Aprimoramentos gráficos**, separada da do
compositor, e correção de outro assunto cria a sua: «Cria outra build […] contendo tudo? as demais vai criando separado».
Assim, patch do portal que recusa não barra o compositor nem o login. A P162, a P163 e as áreas seguem pelo compositor.
Cuidado com o nome amplo: entra aqui só o que é da pilha gráfica de captura, não vira caixa de tudo.

**1. O portal entra no molde do `files_menu.sh` e do `garantir_builds.sh`.** Um script `graficos.sh`, por trás de `meow graficos` e
de um cartão «Aprimoramentos gráficos» na página Extensões, com os verbos `conferir`, `aplicar` e `reverter`, e o pacote `xdg-desktop-portal-cosmic` em `_gb_instalados`. Depois de cada apt o
`garantir_builds` recompila sozinho para a versão nova, sem barrar o compositor nem o menu: portal ruim derruba o
compartilhamento, não o login. O build mora em `~/.local/libexec/meow/graficos/<versão>/`.

- Em `patches/`: o `.patch` do portal (P159), o do toolkit (P160) e uma `versao` própria, com dry-run `-F0`. O
  `[patch]` do `Cargo.toml` usa caminho relativo ao fonte baixado, nunca `/home/...`.
- Marcador `MEOW-PORTAL-PATCH-<n>` no binário, conferido depois de compilar, como os do compositor.
- Dependências em `assets/pacotes/compilar.tsv` (decisão 21): `libpipewire-0.3-dev`, `libclang-dev` e `clang` ainda não
  estão lá. PC sem ferramenta recebe do install, sem receita na tela.
- O compositor troca por PATH, mas o portal sobe por caminho absoluto na unit. Por isso um drop-in do Meow aponta para um
  shim que existe sempre, e o shim decide: build válida para a versão instalada ou `/usr/libexec/xdg-desktop-portal-cosmic`.
  Drop-in direto no binário deixaria a máquina sem portal se o build sumisse.
- O shim aplica a regra do `ruim`: build que cai repetido volta ao pacote, e o doctor tenta de novo uma vez por build.
- Conferência nova no `meow doctor`: versão, build, marcador, shim, policy e quedas recentes do portal com a assinatura
  medida (`screencast_thread.rs`, `create_frame sent before`). O doctor conserta e não manda digitar.
- Sair do trilho sozinho quando #286 e #384 tiverem correção oficial no pacote: a versão que traz a correção vai para
  `patches/versao` como fim do patch.
- `docs/FRONTEIRA.md` ganha as linhas do portal e da policy. Hoje a tabela diz que sistema é do vizinho, então a entrada
  precisa dizer por que estes dois são do Meow, como já diz do `cosmic-comp`. Tudo com teste em `tests/`, e HOME temporário.

**2. A policy do Chrome entra no mesmo verbo `aplicar`,** com o arquivo igual em todo PC:
`/etc/opt/chrome/policies/managed/compartilhar-tela.json`.

```json
{
  "ScreenCaptureAllowed": true,
  "VideoCaptureAllowed": true,
  "AudioCaptureAllowed": true
}
```

A escrita passa pela ponte root, num verbo novo do `ponte_root.sh` no molde de `gpu-compositor`: a interface nunca pede
senha (decisão 11).

Decisão de 06/11/2026: a solução do compositor cobre o caso de existir Chrome no PC da pessoa. A policy depende disso,
e o resto da build não:

- Com o pacote `google-chrome-stable` instalado: aplica a policy.
- Sem Chrome: pula em silêncio, sem criar `/etc/opt/chrome`, sem usar a ponte e sem falhar a build. Portal e compositor
  seguem iguais, porque a correção deles vale para qualquer app que compartilhe tela.
- Chrome instalado depois: o gatilho pós-apt que já roda o `garantir_builds` aplica a policy, sem esperar outra build.
- Chrome em Flatpak ou Chromium usam outro caminho de policy: medir antes de cobrir, sem assumir que este arquivo vale.

Os três valores já são o padrão do Chrome, e o efeito próprio deles não foi isolado: o relato é que o compartilhamento
passou a aparecer depois do comando, mas o crash do portal continuou até a cura. Decisão de 06/11: mantém na build.

**3. Idempotência é o critério de aceite.** Rodar `aplicar` duas vezes na mesma versão não compila, não escreve e não
reinicia o portal: a segunda passagem compara e sai `ok`. O `reverter` devolve portal e policy ao estado do pacote.
O portal só reinicia se a versão mudou, e nunca com stream ativo. A policy só passa pela ponte se o conteúdo divergir.

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
