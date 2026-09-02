# Botões à esquerda e modo de leitura no COSMIC — o que foi medido em 29/08/2026

Este arquivo existe porque a investigação custou **75 frentes de leitura**, e
porque a conclusão que sobrevive vale menos do que o caminho até ela. Quando alguém reabrir
um destes dois assuntos, a pergunta vai ser "isso já foi medido?" — e a resposta está aqui.

Companheiros deste arquivo, os três feitos em 29/08/2026:

- **[`2026-08-29-modo-leitura.html`](2026-08-29-modo-leitura.html)** — duas abas, um arquivo.
  Na primeira, o applet funcionando: os dois sliders, o agendamento e a rampa, com o HUNK B do
  shader rodando de verdade em WebGL. Na segunda, a folha dos ícones: o par sol/lua que conta o
  estado na barra, os candidatos, os que morreram e por quê, e o desenho novo do
  `com.system76.CosmicEdit`. Abra com duplo clique; é offline.
  **É onde ela decide os dois números que faltam.**
- **[Sprint U — Sobreviver a um dist-upgrade](../SPRINTS.md)** — o que este plano exige que o
  `aurora-cosmic-comp-ws.sh` passe a fazer para que nada disto suma no próximo `apt full-upgrade`.
  Aberta em 29/08/2026, a pedido dela.

O material bruto, íntegro e sem edição, está em:

- `2026-08-29-botoes-cosmic-e-modo-leitura.json` — botões dos apps COSMIC, estado do modo de
  leitura, o que a comunidade já produziu, e o mapa dos cinco donos de decoração de janela.
- `2026-08-29-sliders-modo-leitura.json` — como dar os dois sliders do print do HyperOS
  (temperatura + textura) valendo a quente, e o agendamento por horário.

**Nada aqui foi executado.** Em 29/08 ela estava a 10% do limite semanal e escolheu gravar o
plano em vez de tocar na máquina. O que foi executado nesse dia, e só isso: a ordem dos botões
GTK foi invertida para `minimize,maximize,close:` às 18:08 e **desfeita às 18:15**, porque ela
olhou no Chrome e não gostou. A ordem vale `close,maximize,minimize:` — fechar na quina
esquerda — e está registrada nos comentários do `aurora-button-layout.service` e do
`ritual-aurora-self-heal.sh` para ninguém refazer o teste.

---

## O CARTÃO DE RECUPERAÇÃO — LEIA ANTES DE QUALQUER BUILD

Isto vem primeiro de propósito. `/usr/bin/cosmic-greeter-start` é literalmente
`exec cosmic-comp cosmic-greeter`: **o greeter é o mesmo binário**. Um shader que não compila
não derruba só o desktop, derruba a tela de login junto — e o drop-in
`99-aurora-espera-output.conf` zerou o teto de tentativas, então o laço é infinito e silencioso.

Salve isto **fora deste computador**.

```
O cosmic-comp novo não sobe: tela preta, ou o greeter piscando sem parar.

POR QUE ISTO É PIOR DO QUE PARECE. /usr/bin/cosmic-greeter-start é literalmente `exec cosmic-comp cosmic-greeter` — o greeter É o mesmo binário. Só existe uma sessão wayland instalada e não há X de reserva. E o drop-in 99-aurora-espera-output.conf zerou o teto de tentativas, então o laço é infinito e silencioso: não há login gráfico nenhum.

AS DUAS PORTAS: Ctrl+Alt+F2 (até F6; o greetd ocupa a vt1) ou ssh de outra máquina (o sshd está ativo).

PASSO 1 — CALAR O VIGIA DO GREETER. Sem isto ele ressuscita o greeter em 10 segundos e você briga com a tela enquanto digita.
    sudo systemctl stop aurora-greeter-watchdog.service

PASSO 2 — SAIR DO GRÁFICO. O vigia também se cala quando o alvo padrão não é gráfico, então mude os dois.
    sudo systemctl set-default multi-user.target
    sudo systemctl isolate multi-user.target

PASSO 3 — PARAR O SELF-HEAL. Ele roda de hora em hora e depois de TODO apt, e reinstalaria o binário ruim.
    sudo systemctl stop ritual-aurora-self-heal.timer

PASSO 4 — FREIO E QUARENTENA. As DUAS coisas, não uma: o freio impede o auto-build de COMPILAR, mas NÃO impede o --ensure de reinstalar um artefato que já está no disco.
    sudo touch /var/lib/aurora/cosmic-comp-ws-autobuild-off
    sudo mv /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.aurora-ws \
            /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.QUARENTENA

PASSO 5 — DEVOLVER O BINÁRIO DE FÁBRICA. Use o `.orig`. NÃO use o `.pkg-orig` e NÃO use `aurora-cosmic-comp-ws.sh --restore` — conferi hoje: o `--restore` copia o `.pkg-orig`, cujo md5 é 7a39a055dc1e5e61153219eafedbd49b e NÃO bate com o do dpkg, porque ele já vem com o shader do night light dentro.
    sudo cp -a /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.orig /usr/bin/cosmic-comp.rec
    sudo chmod 755 /usr/bin/cosmic-comp.rec
    sudo mv -f /usr/bin/cosmic-comp.rec /usr/bin/cosmic-comp

PASSO 6 — CONFERIR, a partir da raiz (os caminhos no md5sums são relativos).
    cd / && md5sum -c /var/lib/dpkg/info/cosmic-comp.md5sums
O esperado é usr/bin/cosmic-comp: ÊXITO. O md5 correto, hoje, é 468c46ba3bc3466933737b185624863b.

PASSO 7 — VOLTAR AO GRÁFICO.
    sudo systemctl set-default graphical.target
    sudo systemctl start aurora-greeter-watchdog.service
    sudo systemctl isolate graphical.target

SE O .orig TIVER SUMIDO: só resta a rede — `sudo apt-get install --reinstall cosmic-comp` (não há .deb em /var/cache/apt/archives). O PASSO 4 tem de ter sido feito antes, ou o hook de apt roda o self-heal no fim do próprio comando e reinstala o binário ruim em segundos.

O QUE VOCÊ PERDE ENQUANTO ESTÁ ASSIM: o patch de workspace sai junto, então o workspace vazio a mais volta e o número seco reaparece no painel. É o sintoma que você já conhece, e ele volta ao normal no rebuild.

DEPOIS, com a tela de volta e a causa entendida:
    sudo rm /var/lib/aurora/cosmic-comp-ws-autobuild-off
    sudo rm /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.QUARENTENA
    sudo systemctl start ritual-aurora-self-heal.timer
    aurora-cosmic-comp-ws.sh --build
```

---

> **ERRATA de 29/08/2026, medida por uma frente que releu este arquivo do zero.**
> O campo "Volta" do caminho 1 manda `sudo cp -a …5c93094.aurora-ws /usr/bin/cosmic-comp`
> como o retorno certo. Está incompleto, e o jeito como falha é silencioso. Os
> marcadores dos três backups:
>
> ```
> .orig       -> (nenhum marcador)          binário do PACOTE
> .pkg-orig   -> NIGHT LIGHT (Aurora)       pacote + luz noturna
> .aurora-ws  -> AURORA-COSMIC-WS-PATCH     e SÓ isso
> ```
>
> **O `.aurora-ws` não tem a luz noturna dentro** — ela é patch binário aplicado
> *depois* do build. Restaurar esse arquivo devolve o patch de workspace e **tira a
> luz quente dela em silêncio**, até o self-heal repatchar (até uma hora depois).
> Quem rodar o `cp` achando que é neutro vai ver a tela azular e concluir que o
> restore falhou. Se precisar dos dois, rode o `aurora-night-light.py` logo depois.

## Veredito 1 — os botões dos apps COSMIC

Dá, mas SÓ recompilando: a posição está chumbada numa linha do libcosmic (`end.push(self.window_controls(space_xxs))`, header_bar.rs:378) e não existe chave nenhuma -- nem gsettings, nem portal, nem CosmicTk (que só tem show_minimize/show_maximize, visibilidade e não posição). Como o libcosmic é crate Rust estática vendorizada dentro de cada binário, é um build por aplicativo: sete deles (cosmic-term, files, edit, settings, store, player, monitor). Os apps GTK dela já estão à esquerda e continuam assim; o pedido real é só sobre os apps COSMIC. Duas notícias boas que só apareceram agora: (1) medi que às 18:08 de hoje o alvo do button-layout virou 'minimize,maximize,close:', que é exatamente a ordem que o libcosmic já monta -- então o patch encolheu para DUAS linhas, sem reordenar botão nenhum; (2) instalando os binários em /usr/local/bin nada em /usr/bin é tocado e desfazer é um `rm`, porque as .desktop chamam por nome puro e o PATH da sessão põe /usr/local/bin na frente (conferido no environ dos processos vivos). E três verdades duras: o diálogo de abrir/salvar arquivo (xdg-desktop-portal-cosmic, em /usr/libexec, ativado por D-Bus com caminho absoluto), o Steam e as barras que o próprio compositor desenha ficam à direita de qualquer jeito; cada apt upgrade daquele pacote devolve os botões para a direita só naquele app, o que exige um vigia por binário; e não adianta esperar o upstream -- o PR que fazia isso foi fechado sem merge em 15/08/2026 travado em 'you'll need UX design approval', e a System76 respondeu uma única vez em dois anos na issue #640.

### O que dá para fazer, em ordem de custo

**1. Ligar o modo de leitura que já está dentro do binário** · alvo `leitura` · 10 minutos; mais um relogin só se ela trocar a temperatura · dono: Aurora

A luz quente de 3500K JÁ está patchada no /usr/bin/cosmic-comp em execução (conferi agora: o marcador 'NIGHT LIGHT (Aurora)' está lá e /var/lib/aurora/night-light-temp diz 3500). O que está desligado é o interruptor: ~/.local/state/cosmic-comp/a11y_screen_filter.ron está em '(inverted: false,)', sem filtro escolhido. Isto acende hoje, sem escrever uma linha de código.

Passos:

- Conferir o patch: rodar 'aurora-night-light.py --status' (roda sem sudo) e ver 'estado: PATCHADO ... temp: 3500K'.
- Abrir Configurações > Acessibilidade > Filtros de cor.
- Escolher 'Escala de cinza' -- é nesse slot que a luz quente mora hoje (o rótulo mente; o caminho 4 conserta o nome).
- Olhar a tela por uns dez minutos antes de julgar.
- Para mais quente: 'sudo aurora-night-light.py --temp 3000' (3000 = mais âmbar; 4000 = mais discreto).
- Relogar depois de trocar a temperatura -- o shader só é recarregado quando o compositor inicia.
- Para desligar: mesma tela, 'Desativado'. Vale na hora, sem relogar.
- NÃO usar 'aurora-night-light.py --restore' como desfazer (ver risco).

- **Risco:** Quase nenhum: a tela fica âmbar e desliga na mesma tela, na hora. O perigo real é o desfazer errado -- medi que /var/lib/aurora/cosmic-comp-...5c93094.orig tem 28.339.864 bytes (binário do PACOTE, sem o patch de workspace) enquanto o instalado tem 33.571.456. Rodar '--restore' rebaixa o compositor e o workspace vazio fantasma volta no próximo login.
- **Volta:** Sim, na hora e sem tocar em binário: Configurações > Acessibilidade > Filtros de cor > Desativado. Se precisar mexer no binário, o retorno certo é 'sudo cp -a /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.aurora-ws /usr/bin/cosmic-comp' (33.571.456 bytes, com o patch de workspace), nunca o .orig.
- **Arquivos:** `/home/vitoriamaria/.local/state/cosmic-comp/a11y_screen_filter.ron`, `/var/lib/aurora/night-light-temp`, `/usr/bin/cosmic-comp`

**2. Os botões que dá para mover sem compilar nada, e um vigia que pare de ser mudo** · alvo `botoes` · 1 hora · dono: ambos

Três coisas baratas: leva os botões do OBS para a esquerda por override de flatpak (é o último app alcançável sem build -- ele empacota só o libbradient.so, que não lê button-layout nenhum); conserta o vigia da issue #640, que hoje só fala por notify-send e o Não Perturbe engole (medido: 22 avisos engolidos em 27-28/08); e escreve o diagnóstico nas docs para ninguém refazer esta investigação.

Passos:

- mkdir -p /home/vitoriamaria/.var/app/com.obsproject.Studio/data/qt-plugins/wayland-decoration-client
- Copiar (cópia, não symlink) o libadwaita.so de <org.kde.Platform 6.11>/files/lib/plugins/wayland-decoration-client/ para essa pasta -- 6.11 porque o Qt do OBS é 6.11.1.
- flatpak override --user --env=QT_PLUGIN_PATH=/home/vitoriamaria/.var/app/com.obsproject.Studio/data/qt-plugins com.obsproject.Studio
- NUNCA apontar o QT_PLUGIN_PATH para a raiz de plugins do runtime KDE -- o OBS passaria a carregar a plataforma Wayland/EGL do runtime em vez da própria.
- Abrir o OBS no workspace OS e conferir os botões.
- No aurora-cosmic-buttons-watch.sh, gravar uma linha em ~/.local/state/aurora/upstream-vigias.tsv (é dela e gravável; /var/lib/aurora é root e o timer é de usuário).
- Trocar o gatilho de '.state == closed' para '.state + .state_reason' -- senão um 'closed as not planned' vira alarme de vitória.
- Fazer o 'meow doctor' imprimir essa linha no stdout, que é o canal que ela realmente lê.
- Registrar em docs/FRONTEIRA.md e docs/SPRINTS.md o comando que reproduz a medição (strings do binário apontando vendor/libcosmic/src/widget/header_bar.rs), nunca o número de linha, que envelhece no próximo upgrade.

- **Risco:** O plugin de decoração usa API privada do QtWayland: hoje o Qt bate exatamente (6.11.1 dos dois lados), mas se o OBS subir para Qt 6.12 num flatpak update ele pode não abrir. Se o plugin simplesmente não carregar, o Qt cai no libbradient embutido e a única consequência é botão à direita. AVISO: a edição do vigia é em ~/.config/zsh, que tem auto-commit a cada 10 min -- vira commit no repositório privado dela.
- **Volta:** Sim, um comando: 'flatpak override --user --unset-env=QT_PLUGIN_PATH com.obsproject.Studio'. Sem reboot, sem reinstalar. O vigia e as docs são texto, revertíveis por git.
- **Arquivos:** `/home/vitoriamaria/.var/app/com.obsproject.Studio/data/qt-plugins/wayland-decoration-client/libadwaita.so`, `/home/vitoriamaria/.local/share/flatpak/overrides/com.obsproject.Studio`, `/home/vitoriamaria/.config/zsh/scripts/aurora-cosmic-buttons-watch.sh`, `/home/vitoriamaria/.local/state/aurora/upstream-vigias.tsv`, `/mnt/Apate/Desenvolvimento/MeowSystem/bin/meow`, `/mnt/Apate/Desenvolvimento/MeowSystem/docs/FRONTEIRA.md`, `/mnt/Apate/Desenvolvimento/MeowSystem/docs/SPRINTS.md`

**3. Um atalho de teclado para ligar e desligar o modo de leitura** · alvo `leitura` · 3 horas · dono: Aurora

Tira o modo de leitura de dentro de três cliques nas Configurações. Já foi provado ao vivo: um cliente Wayland cru em Python (socket+struct, zero dependências) conectou, achou o cosmic_a11y_manager_v1, deu bind em v2 e leu o evento screen_filter. Falta só mandar o request de escrita e pendurar num atalho.

Passos:

- Partir do protótipo já testado em /tmp/meow-trabalho
- Acrescentar o envio: request opcode 1 = set_screen_filter(uint inverted, uint filter).
- Usar filter=2 para LIGAR -- 2 é greyscale no protocolo, que vira color_mode 1.0, que é o bloco patchado com a luz quente. Nunca 5 (5 é tritanopia de verdade).
- Usar filter=0 para DESLIGAR.
- Ecoar o 'inverted' lido no evento em vez de mandar 0 fixo, senão o atalho desliga o 'inverter cores' dela sem avisar.
- Fazer bind em versão 2 fixa: o compositor publica 2, e bind em 3 mataria o cliente com erro de protocolo.
- Mandar wl_display.sync e esperar o done antes de sair, para o script saber se o compositor aplicou.
- Guarda: se 'grep -a "NIGHT LIGHT (Aurora)" /usr/bin/cosmic-comp' falhar (janela entre um apt upgrade e o self-heal), recusar e avisar -- senão a tela dela fica preto-e-branco de verdade.
- Acrescentar a linha install_if_diff no ritual-aurora-self-heal.sh ANTES da chamada do configurar-atalhos-cosmic.sh.
- Rodar o self-heal uma vez para o binário aparecer em /usr/local/bin (a instalação é por cópia, não symlink).
- SÓ DEPOIS registrar o Spawn no MANAGED do aurora-cosmic-shortcuts.py -- na ordem inversa o varredor de Spawn órfão apaga o binding em silêncio.
- Escolher tecla livre: já estão tomados Ctrl+Alt+T, Ctrl+Shift+V, Print, Shift+Super+S, Super+S e Alt+F2.

- **Risco:** Nenhum risco de sessão: é cliente Wayland comum, não-privilegiado, que fala um protocolo que o compositor já publica para qualquer cliente não-sandboxed. Não toca em binário. Dois cuidados: escrever ~/.config/zsh vira commit no repositório privado dela em até 10 min; e escrever direto no a11y_screen_filter.ron NÃO funciona como alternativa (o arquivo só é lido no início da sessão, nenhum inotify o vigia).
- **Volta:** Sim: apagar o script de ~/.config/zsh/scripts e de /usr/local/bin, tirar a linha do self-heal e a entrada do MANAGED, apagar o binding do arquivo custom (o COSMIC relê na hora).
- **Arquivos:** `/home/vitoriamaria/.config/zsh/scripts/aurora-modo-leitura.py`, `/usr/local/bin/aurora-modo-leitura.py`, `/home/vitoriamaria/.config/zsh/scripts/ritual-aurora-self-heal.sh`, `/home/vitoriamaria/.config/zsh/scripts/aurora-cosmic-shortcuts.py`, `/home/vitoriamaria/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom`

**4. Textura de papel e conforto dentro do mesmo patch do shader, e o rótulo parando de mentir** · alvo `leitura` · meio dia, incluindo a validação e o teste aninhado · dono: Aurora

É aqui que entra a TEXTURA que ela pediu -- hoje não existe uma linha sobre isso em nenhum dos dois repositórios. O bloco do shader ganha grão de papel (hash de gl_FragCoord, estático, que é o certo para papel: grão animado exigiria um uniform de tempo, ou seja, recompilar) e um piso de preto que reduz o contraste. E o rótulo 'Escala de cinza' vira 'Luz noturna' por patch de valor no cosmic-settings.

Passos:

- Perguntar a ela a resposta da pergunta 3 ANTES de escrever o bloco -- ela decide em que slot o modo de leitura mora.
- sudo apt-get install glslang-tools -- não existe validador de GLSL nesta máquina.
- Montar o shader inteiro (2415 bytes) e validar com 'glslangValidator -S frag' ANTES de tocar no binário.
- Ficando no slot de hoje (color_mode 1.0), usar a fórmula já dobrada algebricamente, que cabe em 190 dos 195 bytes: color.rgb=(color.rgb*0.9+fract(sin(dot(gl_FragCoord.xy,vec2(13,78)))*4e4)*0.040-0.013)*vec3(1.0000,0.7799,0.5447);
- Encurtar o marcador para //NL-Aurora -- grão e o marcador cheio NÃO cabem juntos nos 195 bytes.
- Fazer o teste de 'já patchado' aceitar OS DOIS marcadores, senão o script trata o binário de hoje como limpo.
- Se ela quiser a Escala de cinza de volta: reescrever a janela grande de 1666 bytes, ancorada no bloco 'if (invert == 1.0) { ... }' (que não muda em nenhum dos estados), interceptando color_mode == 4.0 antes do ramo >= 2.0.
- Nessa variante, copiar a matemática de daltonismo palavra por palavra -- não minificar: com color.a == 0 o un-multiply gera inf e 0.0*inf vira NaN.
- Trocar a guarda de sanidade 'end - start > 512' do find_block por um teste exato do tamanho da janela, senão o patch novo é recusado para sempre.
- Testar o binário patchado ANINHADO no workspace OS, com XDG_CONFIG_HOME e XDG_STATE_HOME isolados e o filtro ligado -- é o único teste que pega o caso 'compila mas pinta lixo'.
- Instalar só depois, relogar e olhar.
- Renomear o rótulo em /usr/bin/cosmic-settings: o valor de '.greyscale = Escala de cinza' tem 15 bytes; 'Luz noturna' (11) ou 'Modo leitura' (12) cabem com espaços de padding, que o Fluent apara. Sem chaves { } no texto novo.
- Se o slot mudou, ajustar a constante do atalho do caminho 3 (filter 2 vira 5) e mirar o rótulo em '.tritanopia' (43 bytes de orçamento).
- Consertar o '--restore' do aurora-night-light.py para apontar ao .aurora-ws quando o binário instalado tiver o marcador AURORA-COSMIC-WS-PATCH.

- **Risco:** O pior caso NÃO é 'ficar sem filtro': o POSTPROCESS_SHADER é compilado de forma ansiosa na inicialização do renderer, então GLSL inválido = compositor não sobe = TELA PRETA no próximo login, e o self-heal reaplica de hora em hora. Por isso os passos de validação e de sessão aninhada são obrigatórios, não opcionais. Segundo: o grão cai sobre TUDO, inclusive vídeo e jogo (por isso a pergunta 3). Terceiro: escrever em ~/.config/zsh vira commit no repositório privado dela em até 10 min.
- **Volta:** Sim, sem reinstalar sistema, por três caminhos: reaplicar com grão 0; TTY (Ctrl+Alt+F3) e 'sudo cp -a /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.aurora-ws /usr/bin/cosmic-comp'; ou 'sudo apt-get install --reinstall cosmic-comp' (mais 'apt-get install --reinstall cosmic-settings' para o rótulo). O filtro em si se desliga pela UI sem relogar.
- **Arquivos:** `/home/vitoriamaria/.config/zsh/scripts/aurora-night-light.py`, `/usr/local/bin/aurora-night-light.py`, `/usr/bin/cosmic-comp`, `/usr/bin/cosmic-settings`, `/var/lib/aurora/night-light-temp`, `/home/vitoriamaria/.config/zsh/scripts/aurora-modo-leitura.py`

**5. Botões à esquerda nos apps COSMIC: piloto com um app e, se prestar, a onda** · alvo `botoes` · piloto: ~1 hora de máquina (build frio, 860 crates). Onda completa: 1 a 2 dias, mais ~30 min de rebuild por apt upgrade de cada pacote (esses sobem quase toda semana) · dono: ambos

O único caminho que existe: recompilar cada app com o libcosmic patchado. MEDIÇÃO NOVA DE AGORA, que barateia o patch: às 18:08 de hoje o alvo do timer da Aurora mudou para 'minimize,maximize,close:' (gsettings, dconf e os dois settings.ini já reescritos). Essa é exatamente a ordem que o libcosmic já monta, então o patch deixa de precisar reordenar nada -- são DUAS linhas, não quinze. Recomendo fazer os passos 1 a 13 (um app só), PARAR e ela olhar; a onda completa (passo 14 em diante) só se ela topar o custo recorrente.

Passos:

- Confirmar a ordem viva antes de patchar: 'gsettings get org.gnome.desktop.wm.preferences button-layout'. Com 'minimize,maximize,close:' não se mexe na ordem; se ela voltar para 'close,maximize,minimize:', aí sim inverter os três push_maybe.
- sudo apt-get build-dep cosmic-term (faltam pacotes de dev; o dpkg-checkbuilddeps diz quais).
- mkdir -p /mnt/Apate/build -- NUNCA compilar no /, que tem só 12 GB livres; cada árvore pesa ~3,2 GB.
- cd /mnt/Apate/build && apt-get source cosmic-term (casa a versão instalada, ~148 MB).
- Dentro da árvore, 'tar pxf vendor.tar' -- o vendor vem como tar aninhado, não como diretório.
- Em vendor/libcosmic/src/widget/header_bar.rs linha 373, trocar 'let start' por 'let mut start' (sem isso não compila).
- Na linha 378, trocar 'end.push(self.window_controls(space_xxs));' por 'start.insert(0, self.window_controls(space_xxs));'.
- Acrescentar '#[used] static MEOW_BOTOES: &str = "MEOW-BOTOES-ESQUERDA-1.0";' e referenciá-lo com std::hint::black_box dentro de window_controls -- const some no LTO e static sem referência em crate dependente pode ser podado.
- Recalcular o sha256 do header_bar.rs e regravar a entrada 'src/widget/header_bar.rs' em vendor/libcosmic/.cargo-checksum.json, senão o cargo aborta.
- Compilar com CARGO_TARGET_DIR=/mnt/Apate/build/target cargo build --release --frozen --offline.
- NUNCA usar 'just build-vendored' nem 'make VENDOR=1': os dois fazem 'rm -rf vendor; tar pxf vendor.tar' e apagam o patch sem erro nenhum.
- Conferir o marcador antes de instalar: strings -a target/release/cosmic-term | grep MEOW-BOTOES-ESQUERDA.
- sudo install -Dm0755 target/release/cosmic-term /usr/local/bin/cosmic-term -- /usr/bin fica intacto e o PATH da sessão põe /usr/local/bin na frente (conferido no environ dos processos vivos).
- PARAR AQUI e ela abrir o cosmic-term. Se não gostar: sudo rm /usr/local/bin/cosmic-term.
- Aprovado, repetir 4-13 para cosmic-files, cosmic-edit, cosmic-settings, cosmic-store, cosmic-player e cosmic-monitor -- o mesmo patch serve nos seis (todos fixam o commit 2a73fbc0 de libcosmic).
- Escrever ~/.config/zsh/scripts/aurora-cosmic-apps-botoes.sh com um --ensure que compare 'dpkg-query -W <pkg>' com a versão gravada no marcador do binário de /usr/local/bin, e reconstrua em background com Nice 19.
- Escrever /mnt/Apate/Desenvolvimento/MeowSystem/scripts/botoes.sh só de LEITURA (conferir/estado), um item por app (arquivo em disco e /proc do processo vivo), devolvendo 4 para 'vale no próximo login' e nunca 1 para o que o Meow não pode consertar.
- NÃO tocar no cosmic-comp neste caminho: o binário é da Aurora, já tem dois patches empilhados, e ali o patch só mudaria janela SSD.

- **Risco:** Três riscos reais. (1) Resultado misto e permanente: o diálogo de abrir/salvar arquivo (xdg-desktop-portal-cosmic, em /usr/libexec, ativado por D-Bus com caminho ABSOLUTO), as barras que o próprio compositor desenha (Steam e X11) e o CosmicTweaks (flatpak) ficam à direita de qualquer jeito. (2) Binário congelado: um apt upgrade sobe /usr/bin para 1.8 e ela continua rodando o 1.7 patchado de /usr/local/bin sem sinal nenhum -- é o que o --ensure do passo 16 existe para cobrir. (3) Um build ruim faz aquele app não abrir (se for o cosmic-settings, ela perde a UI de configurações até apagar o arquivo). Não há risco de sessão: o cosmic-comp fica de fora. Custo de disco: ~25 GB de árvores no /mnt/Apate. E o aurora-cosmic-apps-botoes.sh é escrita em ~/.config/zsh, que auto-commita a cada 10 min.
- **Volta:** Sim, imediato e sem reinstalar nada: 'sudo rm /usr/local/bin/<app>' e o pacote original de /usr/bin volta a ser o executado no próximo start do app. Nada em /usr/bin é sobrescrito, nenhuma config dela é tocada, nenhum backup precisa ser mantido.
- **Arquivos:** `/mnt/Apate/Desenvolvimento/MeowSystem/patches/libcosmic-botoes-a-esquerda.patch`, `/mnt/Apate/build/cosmic-term-1.7.0~1787681551~24.04~909a0d3/vendor/libcosmic/src/widget/header_bar.rs`, `/mnt/Apate/build/cosmic-term-1.7.0~1787681551~24.04~909a0d3/vendor/libcosmic/.cargo-checksum.json`, `/usr/local/bin/cosmic-term`, `/usr/local/bin/cosmic-files`, `/usr/local/bin/cosmic-edit`, `/usr/local/bin/cosmic-settings`, `/usr/local/bin/cosmic-store`, `/usr/local/bin/cosmic-player`, `/usr/local/bin/cosmic-monitor`, `/home/vitoriamaria/.config/zsh/scripts/aurora-cosmic-apps-botoes.sh`, `/mnt/Apate/Desenvolvimento/MeowSystem/scripts/botoes.sh`, `/mnt/Apate/Desenvolvimento/MeowSystem/bin/meow`

---

## Veredito 2 — modo de leitura, textura e temperatura

O modo de leitura JÁ EXISTE e já está no binário -- conferi agora: o /usr/bin/cosmic-comp em execução carrega o bloco `// NIGHT LIGHT (Aurora)` a 3500K, e /var/lib/aurora/night-light-temp confirma. O que está desligado é o interruptor: o a11y_screen_filter.ron está em '(inverted: false,)', sem filtro escolhido. Ou seja, ela tem uma luz quente instalada há semanas e nunca acendeu. Ligar é Configurações > Acessibilidade > Filtros de cor > 'Escala de cinza' (é nesse slot que a luz mora; o rótulo mente) e vale na hora. O que falta, em ordem de esforço: um interruptor de um toque -- provei ao vivo que um cliente Wayland de ~40 linhas liga e desliga pelo cosmic_a11y_manager_v1 v2, então cabe num atalho de teclado; o rótulo honesto, que é patch de 15 bytes no cosmic-settings; e a TEXTURA, que é o único dos três pedidos sem uma única linha escrita em qualquer um dos dois repositórios -- ela cabe no mesmo bloco do shader (190 de 195 bytes com a fórmula dobrada algebricamente), é grão estático por gl_FragCoord (grão animado exigiria um uniform de tempo, ou seja, recompilar) e cai sobre tudo, inclusive vídeo e jogo. Duas coisas que precisam ser ditas em voz alta: o `aurora-night-light.py --restore` está armadilhado -- medi que o .orig de /var/lib/aurora é o binário do PACOTE (28,3 MB), então restaurar por ali derruba junto o patch de workspace e o número seco volta no painel; o desfazer certo é o .aurora-ws (33,5 MB). E temperatura 'de verdade', por protocolo, continua morta na fundação (nem o smithay tem gamma_control), embora exista o PR aberto de wlr-gamma-control e a GPU dela exponha GAMMA_LUT nos quatro CRTCs -- é a saída futura que aposentaria o hack do shader e devolveria os quatro filtros de acessibilidade.

Sim, dá — e o caminho é um só: recompilar o cosmic-comp com DOIS uniforms novos. Não existe atalho: medi no fonte da versão que está instalada (5c93094) que os únicos uniforms vivos do offscreen.frag são `invert` (0/1) e `color_mode` (1..4 vindo de `enum as u8 as f32`). Nenhum valor contínuo cabe ali sem recompilar, e o `a11y_screen_filter.ron` é lido UMA vez no boot — escrever nele não muda nada até o próximo login.

O CUSTO, em três linhas:
- Um patch de 5 arquivos + ~4 min de build (30 min se o vendor estiver frio) + UM logout. Depois disso os dois números valem A QUENTE: escrever `~/.config/cosmic/com.system76.CosmicComp/v1/leitura_temperatura` muda a tela no quadro seguinte, porque o cosmic-comp já tem um ConfigWatchSource nesse namespace e os uniforms são remontados a cada quadro.
- O agendamento por horário é o mais barato dos três: um script e dois arquivos de systemd, sem cliente Wayland nenhum. Ele só escreve a mesma chave.
- O slider de ARRASTAR (o do print do HyperOS) é a parte cara: um applet libcosmic novo na barra, mais uma linha à mão no `plugins_wings` (arquivo da Aurora) e um segundo logout. Até ele existir, os dois valores já são reais e mudam a quente por número.

O RISCO É UM SÓ, E É GRANDE: `init_shaders` compila o offscreen.frag na subida do device, e `/usr/bin/cosmic-greeter-start` é literalmente `exec cosmic-comp cosmic-greeter`. Shader com erro de sintaxe = sem desktop E sem tela de login, com o greeter em laço (o drop-in da Aurora tirou o teto de tentativas). Por isso o validador EGL e o cartão de TTY vêm ANTES do primeiro build, e por isso o `.orig` (não o `.pkg-orig`) é a rede: conferi agora, o `.orig` bate byte a byte com o md5 que o dpkg registrou (468c46ba3bc3466933737b185624863b) e o `.pkg-orig` NÃO bate — ele já vem com o night light dentro.

Uma escolha de desenho que evita a armadilha mais cara: o bloco novo NÃO entra na região do `color_mode`. Aquelas três linhas são as âncoras do `aurora-night-light.py`, que o self-heal roda de hora em hora e que reescreve TUDO entre elas com padding de espaços — e o shader resultante ainda compilaria, então a falha seria muda. Deixando a região do color_mode byte a byte igual ao upstream, o patcher velho continua fazendo o que sempre fez (útil na janela entre um `apt upgrade` e o rebuild) e nunca encosta no modo de leitura.

### As seis etapas

#### 1. A tela obedece a dois números

**Entrega:** Depois de um logout, ela digita um número e a tela esquenta na hora; digita outro e a tela ganha grão de papel. `printf '3500' > ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_temperatura` muda a cor no quadro seguinte, sem deslogar de novo. Desligar é escrever `0` nos dois.

**Tempo:** ~2h de escrita, mais 4 min de build (30 min se o vendor estiver frio), mais UM logout. · **Dono:** Aurora

Passos:

- Salvar o cartão de recuperação (campo `recuperacao`) num papel ou no celular — não no computador que pode não ligar.
- Conferir a rede: `md5sum /var/lib/aurora/cosmic-comp-0.1~1787767625~24.04~5c93094.orig` tem de dar 468c46ba3bc3466933737b185624863b.
- Avisar a Vitória em voz alta: a partir daqui eu escrevo em ~/.config/zsh, que tem auto-commit a cada 10 min no repo privado dela.
- Criar ~/.config/zsh/patches/patches.d/ e mover o cosmic-comp-sem-workspace-vazio.patch para lá.
- Criar patches.d/series com a linha `req:cosmic-comp-sem-workspace-vazio.patch`.
- Trocar o compilar() do aurora-cosmic-comp-ws.sh (linhas 385-430) para ler a série: dry-run de TODOS os patches antes de aplicar qualquer um, e `rm -rf` da árvore de fonte em qualquer falha.
- Trocar a idempotência: testar por `grep -q <marcador> <arquivo-fonte>` declarado na série, NUNCA pelo código de saída do patch (medido: `patch --forward` devolve 1 para 'já aplicado').
- Trocar o marcador_de() (linha 230) para concatenar TODOS os marcadores AURORA-*-PATCH-* do binário, senão o --ensure não reinstala quando a série muda — foi esse o bug de 25/08.
- Escrever patches.d/cosmic-comp-modo-leitura.patch com o GLSL do campo `glsl_final` e as cinco edições em Rust listadas abaixo, com o marcador `#[used] static AURORA_READING_MODE: &str = "AURORA-READING-MODE-1";`.
EDIÇÃO 1 — src/backend/render/mod.rs:422: acrescentar `UniformName::new("leitura_temp", UniformType::_3f)` e `UniformName::new("leitura_textura", UniformType::_1f)`.
EDIÇÃO 2 — src/backend/kms/surface/mod.rs:1897 (cursor) E :1931 (tela): acrescentar os dois `Uniform::new` NOS DOIS vetores. É AQUI que a sessão dela desenha; o render/mod.rs:1365 é winit/x11 e não roda nesta máquina.
EDIÇÃO 3 — src/config/mod.rs:151-161: dois campos novos em ScreenFilter (`leitura_temperatura: u32`, `leitura_textura: f32`) com `#[serde(skip)]`, e is_noop() passando a exigir `== 0` e `<= 0.0` — sem isso o passe inteiro é PULADO e nada aparece, sem erro nenhum.
EDIÇÃO 4 — src/config/mod.rs:394: trocar o literal `ScreenFilter { inverted: false, color_filter: None }` por `ScreenFilter { inverted: false, ..Default::default() }`, senão o crate nem compila.
EDIÇÃO 5 — cosmic-comp-config/src/lib.rs:106 e :145: as duas chaves novas com default 0 e 0.0; e src/config/mod.rs:790: um braço `"leitura_temperatura" | "leitura_textura"` no config_changed que chama `state.backend.update_screen_filter(&updated)` na mão (o valor NÃO chega ao renderer sozinho).
EDIÇÃO 5b — src/backend/kms/surface/mod.rs:401: `set_screen_filter` passa a chamar `self.schedule_render()` (que respeita o dpms), senão o slider trava numa tela parada.
EDIÇÃO 5c — no fim de Config::load, copiar `cosmic_comp_config.leitura_*` para o filtro dinâmico, senão um valor escrito com ela deslogada só vale no login DEPOIS do seguinte.
- Escrever ~/.config/zsh/scripts/aurora-glsl-gate.c: abre EGL surfaceless no device NVIDIA, COMPILA E LINKA o shader (linkar é obrigatório — um fragment com varyings demais compila e falha só no link).
- Rodar o gate sobre o offscreen.frag novo nas 6 variantes que o smithay liga: [], [NO_ALPHA], [EXTERNAL], cada uma com e sem DEBUG_FLAGS. Se qualquer uma falhar, PARAR aqui.
- Rodar `aurora-cosmic-comp-ws.sh --build` e conferir que o artefato em /var/lib/aurora tem AURORA-COSMIC-WS-PATCH e AURORA-READING-MODE-1 antes de instalar.
- Deslogar e logar.
- Testar: `printf '3500' > ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_temperatura` — a tela tem de esquentar na hora.
- Testar: `printf '0.4' > ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_textura`.
- Desligar os dois com `0` e confirmar que a tela volta ao normal.

- **Risco:** ALTO e único: shader que não compila = sem desktop E sem tela de login, porque o greeter roda o mesmo binário. O gate EGL do passo 18 é o que impede — nenhum binário vai para /usr/bin sem passar nele. Risco menor: esquecer o is_noop() faz o passe ser pulado e nada aparecer, sem mensagem de erro.
- **Volta:** O cartão de recuperação do campo `recuperacao`, por TTY (Ctrl+Alt+F2) ou ssh, restaurando o `.orig` — que conferi agora que bate com o md5 do dpkg. Antes disso: se o gate reprovar, nada foi instalado e não há o que desfazer.
- **Arquivos:**
  - `/home/vitoriamaria/.config/zsh/patches/patches.d/series`
  - `/home/vitoriamaria/.config/zsh/patches/patches.d/cosmic-comp-modo-leitura.patch`
  - `/home/vitoriamaria/.config/zsh/patches/patches.d/cosmic-comp-sem-workspace-vazio.patch`
  - `/home/vitoriamaria/.config/zsh/scripts/aurora-cosmic-comp-ws.sh`
  - `/home/vitoriamaria/.config/zsh/scripts/aurora-glsl-gate.c`
  - `/mnt/Apate/Desenvolvimento/cosmic-comp-patch/cosmic-comp-0.1~1787767625~24.04~5c93094/src/backend/render/shaders/offscreen.frag`
  - `/mnt/Apate/Desenvolvimento/cosmic-comp-patch/cosmic-comp-0.1~1787767625~24.04~5c93094/src/backend/render/mod.rs`
  - `/mnt/Apate/Desenvolvimento/cosmic-comp-patch/cosmic-comp-0.1~1787767625~24.04~5c93094/src/backend/kms/surface/mod.rs`
  - `/mnt/Apate/Desenvolvimento/cosmic-comp-patch/cosmic-comp-0.1~1787767625~24.04~5c93094/src/config/mod.rs`
  - `/mnt/Apate/Desenvolvimento/cosmic-comp-patch/cosmic-comp-0.1~1787767625~24.04~5c93094/cosmic-comp-config/src/lib.rs`

#### 2. O horário liga sozinho

**Entrega:** Às 18:00 a tela esquenta e ganha papel sem ela tocar em nada; às 07:00 volta ao normal. `meow leitura estado` diz em português qual degrau o relógio pede e o que a tela está mostrando agora.

**Tempo:** ~1h. Nenhum build, nenhum logout. · **Dono:** Meow

Passos:

- Escrever /mnt/Apate/Desenvolvimento/MeowSystem/scripts/leitura.sh com tique|aplicar|conferir|estado|remover.
- Copiar a regra de janela do e_noite() do wallpaper.sh:637: `início > fim` é 'depois do início OU antes do fim'; `início == fim` vale o dia inteiro. A máquina não pode ter duas definições de noite.
- Escrever a chave com redirecionamento `>`, NUNCA com `mv` — o watcher do cosmic-config descarta o evento de rename e a mudança não acordaria ninguém.
- Só escrever quando o valor MUDA, para não gerar uma repintura a cada tique.
- Criar systemd/meow-leitura.service com ConditionEnvironment=WAYLAND_DISPLAY, PartOf=cosmic-session.target, LogLevelMax=notice e SuccessExitStatus=0 1 3.
- Criar systemd/meow-leitura.timer com OnCalendar=*-*-* *:00/5, AccuracySec=10s, Persistent=false, WantedBy=cosmic-session.target. Sem Persistent: um 18:00 perdido não pode ser reproduzido às 3h.
- Pôr as chaves no meow.conf.exemplo, todas com VAZIO = NÃO TOCA: LEITURA_AGENDA, LEITURA_HORARIO_INICIO, LEITURA_HORARIO_FIM, LEITURA_TEMPERATURA, LEITURA_TEXTURA, LEITURA_RAMPA.
- Ligar as chaves no install.sh e no bin/meow (chk_leitura/fix_leitura) — chave que a CLI obedece e o timer ignora é chave que mente.
- Rodar `systemctl --user enable --now meow-leitura.timer`.
- Testar de verdade: pôr o início daqui a 2 minutos e esperar a tela virar sozinha.

- **Risco:** BAIXO. O pior caso é a tela mudar de cor na hora errada. Nada aqui toca em binário, em sudo ou em arranque de sessão.
- **Volta:** `systemctl --user disable --now meow-leitura.timer`, sem sudo e sem sair da sessão. Ou esvaziar LEITURA_AGENDA no meow.conf.
- **Arquivos:**
  - `/mnt/Apate/Desenvolvimento/MeowSystem/scripts/leitura.sh`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/systemd/meow-leitura.service`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/systemd/meow-leitura.timer`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/meow.conf.exemplo`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/bin/meow`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/install.sh`

#### 3. O slider na barra

**Entrega:** Um ícone novo na topbar. Clicando, dois sliders — Temperatura e Textura — que ela ARRASTA e vê a tela mudando enquanto arrasta, mais um botão 'Restaurar padrões'. É o print do HyperOS.

**Tempo:** ~4h de escrita, mais um build frio de libcosmic (dezenas de minutos e ~2 GB de target), mais UM logout. · **Dono:** Meow

Passos:

- Criar /mnt/Apate/Desenvolvimento/MeowSystem/src/applets/leitura/ com um crate libcosmic próprio.
- Pinar o rev do libcosmic no Cargo.toml E commitar o Cargo.lock do crate — sem upstream para herdar lock, o lock tem de ser nosso (já há 5 checkouts distintos de libcosmic em ~/.cargo).
- Copiar a estrutura do cosmic-applet-a11y (393 linhas): popup, padded_control, menu_button, divider.
- Os dois sliders gravam por `cosmic_config::Config::new("com.system76.CosmicComp", 1).set::<u32>("leitura_temperatura", v)` — o MESMO canal do agendador, sem protocolo Wayland nenhum.
- Pôr `step(100)` na temperatura e `step(5)` na textura, para o arrasto não virar uma escrita por pixel.
- Acrescentar uma `watch_config` para o slider SEGUIR o disco quando o agendador mexer às 18:00.
- Escrever scripts/leitura_build.sh clonado do midia_build.sh: carimbo de 4 campos, `--locked`, MEOW_COMPILAR obrigatório, binário em ~/.local/bin/meow-applet-leitura.
- Plantar a sombra ~/.local/share/applications/com.meowsystem.AppletLeitura.desktop com o fail-safe do midia.sh: binário ausente = sombra removida, nunca slot vazio na barra.
- Registrar `leiturabin` em SEM_CONSERTO no bin/meow — compilar não é trabalho do doctor.
- Acrescentar UMA linha ao plugins_wings da topbar, À MÃO, com backup em ~/.local/state/meowsystem/backups/ — é arquivo da Aurora, e nenhum script nosso escreve ali.
- Deslogar (o plugins_wings só vale no próximo início de sessão; nunca reiniciar o cosmic-panel, que derruba topbar e dock juntas).

- **Risco:** MÉDIO, mas contido: applets são processos separados: se o nosso travar ou sumir, a barra continua. O buraco conhecido é sombra sem binário deixando o slot vazio — o fail-safe do passo 8 cobre.
- **Volta:** `rm` da sombra .desktop e do binário, tirar a linha do plugins_wings (o backup do passo 10), próximo login. Sem sudo.
- **Arquivos:**
  - `/mnt/Apate/Desenvolvimento/MeowSystem/src/applets/leitura/Cargo.toml`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/src/applets/leitura/Cargo.lock`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/src/applets/leitura/src/main.rs`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/scripts/leitura_build.sh`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/scripts/leitura.sh`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/bin/meow`
  - `/home/vitoriamaria/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings`

#### 4. Aposentar o night light sem apagá-lo

**Entrega:** 'Acessibilidade > Filtros de cor > Escala de cinza' volta a deixar a tela CINZA de verdade — como sempre deveria ter feito. A luz quente passa a ser só o slider, com o valor que ela escolher, e `aurora-night-light.py --status` diz 'aposentado'.

**Tempo:** ~20 min, mais um logout para ver o cinza voltar. · **Dono:** Aurora

Passos:

- Acrescentar `NEW_MARK = "AURORA-READING-MODE"` ao lado do MARK, na linha 69 do aurora-night-light.py.
- Pôr a trava IMEDIATAMENTE ANTES do `blk = find_block(data)`, por volta da linha 231 — nunca na linha 192, onde ela comeria o --status e o --restore, que são caminhos de recuperação.
- A mensagem TEM de conter as palavras 'já aplicado': é o que o `grep -qE "j[aá] aplicado"` do self-heal procura. Sem isso ele imprime 'REAPLICADO' falso de hora em hora, para sempre.
- Sair com 0, nunca com 3 — o 3 significa 'shader mudou upstream' e viraria um AVISO horário sobre algo que está certo.
- Acrescentar uma linha de diagnóstico no ramo --status dizendo que o binário traz o modo de leitura compilado.
- Rodar `sudo /usr/local/bin/aurora-night-light.py` e conferir que ele NÃO escreveu (o md5 do /usr/bin/cosmic-comp não muda).
- Deslogar e confirmar que 'Escala de cinza' agora deixa a tela cinza, e que o slider de temperatura continua funcionando.

- **Risco:** BAIXO. A trava não escreve byte nenhum. Se ela for posta no lugar errado (linha 192), o `--restore` do patcher para de funcionar — e ele é um dos caminhos de volta. O passo 2 existe só por causa disso.
- **Volta:** Tirar as 6 linhas da trava. E, mesmo com a trava errada, a recuperação principal continua sendo o `.orig` por TTY, que não passa pelo patcher.
- **Arquivos:**
  - `/home/vitoriamaria/.config/zsh/scripts/aurora-night-light.py`
  - `/usr/local/bin/aurora-night-light.py`

#### 5. O doctor conta a verdade sobre o compositor

**Entrega:** `meow doctor` passa a dizer, em uma linha em português, se o modo de leitura está no binário do disco e se está na SESSÃO que ela está usando agora — e a diferença entre as duas coisas, que hoje ninguém vê.

**Tempo:** ~40 min. Sem build e sem logout. · **Dono:** ambos

Passos:

- No fim do cmd_build e do cmd_build_auto, gravar /var/lib/aurora/cosmic-comp-patches.estado com a lista de marcadores ESPERADOS, declarada na série (não derivada do que o build produziu).
- Escrever essa lista com escrita atômica e `|| true`, nunca dentro de um `&&` que decida instalação.
- No bin/meow, escrever chk_leitura_compositor() comparando o esperado contra `strings /usr/bin/cosmic-comp` E contra /proc/<pid do cosmic-comp>/exe.
- Três respostas, nunca duas: falta no disco = MEOW_DIVERGENTE (1, com o comando do conserto); no disco mas não na sessão = 4, com a frase 'vale no próximo login'; sem compositor visível = 3.
- Generalizar meow_painel_compositor_clampa() (lib/painel.sh:167) para receber o marcador como argumento, em vez de escrever uma segunda sonda de 'processo versus arquivo' para envelhecer em paralelo.
- Acrescentar a linha ao MOTIVO_SEM_FIX do bin/meow: 'o conserto compila, e o doctor não compila'.

- **Risco:** BAIXO. O doctor é read-only por contrato (nunca usa sudo, nunca baixa nada). O único risco é de SINAL: se a linha nova acender '~~' todo ciclo por algo que só o logout resolve, ela para de olhar — por isso o código 4 do passo 4.
- **Volta:** Tirar a função do bin/meow e apagar o arquivo de estado. Nada mais.
- **Arquivos:**
  - `/mnt/Apate/Desenvolvimento/MeowSystem/bin/meow`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/lib/painel.sh`
  - `/home/vitoriamaria/.config/zsh/scripts/aurora-cosmic-comp-ws.sh`

#### 6. Fechar a dívida do raio de canto

**Entrega:** O raio de canto que ela pedir passa a valer sem o teto de 8, e o `meow painel teto` para de dizer 'sem o patch'. Ela pede 20 e a barra não some.

**Tempo:** ~15 min de escrita, mais um build e um logout (dá para juntar com o build de outra etapa). · **Dono:** ambos

Passos:

- Copiar /mnt/Apate/Desenvolvimento/MeowSystem/patches/cosmic-comp-raio-clampado.patch para ~/.config/zsh/patches/patches.d/ — o binário é da Aurora, e um patch do lado do Meow fica órfão (foi exatamente o que aconteceu com este).
- Acrescentar `opt:cosmic-comp-raio-clampado.patch` à série, depois do req do workspace.
- Rodar `aurora-cosmic-comp-ws.sh --build` e conferir que AURORA-COSMIC-RADIUS-PATCH-1 aparece no artefato — hoje ele tem ZERO ocorrências no binário instalado.
- Corrigir o README.md:195, que afirma no presente que este patch é aplicado pelo --build.
- Corrigir o scripts/forma.sh nas linhas 115-117, 194 e 497, que imprimem NA TELA DELA a mesma afirmação falsa, justamente quando o raio é cortado.
- Deslogar e pedir um raio de 20 para confirmar que a barra continua de pé.

- **Risco:** MÉDIO. É `opt`, então se não aplicar o build segue sem ele. Mas ele MEXE no protocolo de canto do painel — e é o painel que já sumiu por causa desse arquivo. Um build que sobe e desenha errado não dispara alarme nenhum; o sintoma é o painel fantasma.
- **Volta:** Tirar a linha `opt:` da série e rebuildar. O teto de 8 do lado do Meow continua valendo enquanto o marcador não estiver no binário, então a barra dela não fica desprotegida no meio do caminho.
- **Arquivos:**
  - `/home/vitoriamaria/.config/zsh/patches/patches.d/cosmic-comp-raio-clampado.patch`
  - `/home/vitoriamaria/.config/zsh/patches/patches.d/series`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/README.md`
  - `/mnt/Apate/Desenvolvimento/MeowSystem/scripts/forma.sh`

---

## O shader final

GLSL ES 1.00 (`#version 100`) — restrição dura do `offscreen.frag` do cosmic-comp: sem
`texelFetch`, sem funções de GLSL 3.x, sem loop de contagem variável. Uma frente compilou **e
linkou** este bloco num contexto EGL real antes de ele entrar aqui.

```glsl
// ===========================================================================
// src/backend/render/shaders/offscreen.frag  -- ESTADO FINAL
//
// COMO LER ESTE ARQUIVO: o patch tem SÓ DOIS HUNKS.
//   HUNK A -- as duas declaracoes de uniform + a funcao meow_grao(), inseridos
//             logo depois de `uniform float color_mode;`.
//   HUNK B -- o bloco MODO DE LEITURA, inserido entre o fim da cadeia do
//             color_mode e o comentario `// re-multiply`.
// Todo o resto (marcado abaixo com "NAO TOCAR") tem de ficar BYTE A BYTE igual
// ao upstream. O motivo esta no comentario dentro do main(), e ele e a razao
// pela qual este patch nao apaga a luz noturna dela nem e apagado por ela.
// ===========================================================================

#version 100

//_DEFINES_

#if defined(EXTERNAL)
#extension GL_OES_EGL_image_external : require
#endif

precision highp float;
#if defined(EXTERNAL)
uniform samplerExternalOES tex;
#else
uniform sampler2D tex;
#endif

uniform float alpha;
varying vec2 v_coords;

#if defined(DEBUG_FLAGS)
uniform float tint;
#endif

uniform float invert;
uniform float color_mode;

// ======================= HUNK A ==========================================
// MODO DE LEITURA (Aurora/MeowSystem) -- os DOIS uniforms novos.
//
// POR QUE A TEMPERATURA CHEGA COMO vec3 E NAO COMO KELVIN:
//   Converter Kelvin -> RGB dentro do shader custa log() e pow() POR PIXEL, em
//   tela cheia, todo quadro. E a conta e sempre a mesma. O lado Rust ja faz a
//   interpolacao UMA vez, com a tabela de whitepoints do redshift/colorramp.c
//   que o aurora-night-light.py ja carrega (1000K..6500K), e manda o resultado
//   pronto em ScreenFilter::leitura_tint().
//   vec3(1.0, 1.0, 1.0) = 6500K = neutro = modo de leitura DESLIGADO.
uniform vec3 leitura_temp;

// 0.0 = sem papel .. 1.0 = papel cheio. E o "Textura" do print do HyperOS:
// faixa dinamica comprimida + dessaturacao + grao.
uniform float leitura_textura;

// Grao pseudoaleatorio a partir da coordenada de PIXEL do framebuffer.
//
// SEM TEMPO E SEM UNIFORM: para uma dada coordenada o valor e SEMPRE o mesmo.
// Tres coisas caem de graca disso:
//   1) nao chuvisca entre quadros;
//   2) nao anda quando a janela anda;
//   3) sobrevive ao damage tracking, porque a regiao redesenhada recalcula
//      exatamente os mesmos valores. Um grao com termo temporal deixaria uma
//      costura visivel na borda da regiao suja, e forcaria dano de tela cheia
//      todo quadro -- o mesmo erro que o applet conta-gotas ja cobra em CPU.
//
// POR QUE COM sin(), CONTRARIANDO O CONSELHO DE SHADERTOY: medido nesta
// maquina (RTX 4060, driver 580.173.02), o sin() e 1,5x a 2x MAIS BARATO que o
// hash "sem seno" do Hoskins, porque na NVIDIA o seno e uma instrucao da SFU e
// nao disputa o caminho ALU do resto do shader. O conselho de nunca usar sin
// em hash nasceu de GPU movel com mediump, e nao vale aqui.
//
// PRECISAO: a spec da GLSL ES 1.00 declara gl_FragCoord como mediump; na NVIDIA
// de desktop mediump E fp32, e foi por isso que o teste passou -- renderizei
// cinza chapado em 3840x2160 e li de volta os cantos (0,0) e (3400,1800): mesmo
// desvio padrao, e autocorrelacao |r| <= 0,155 para deslocamentos de 8 a 512 px,
// ou seja sem faixa e sem repeticao. Se um dia isto rodar em GPU movel, trocar
// por: vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
//       p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z);
float meow_grao(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
// ===================== FIM DO HUNK A ======================================

void main() {
    // ------------------- NAO TOCAR (upstream) ---------------------------
    vec4 color = texture2D(tex, v_coords);

#if defined(NO_ALPHA)
    color = vec4(color.rgb, 1.0) * alpha;
#else
    color = color * alpha;
#endif

    // un-multiply
    color.rgb /= color.a;

    // First invert then filter

    if (invert == 1.0) {
        color.rgb = 1.0 - color.rgb;
    }

    // ATENCAO -- A REGIAO ABAIXO E INTOCAVEL, E NAO E PRECIOSISMO.
    //
    // As strings `    if (color_mode == 1.0) {` e
    // `    } else if (color_mode >= 2.0) {` sao as ANCORAS do
    // aurora-night-light.py (find_block, linha 105). Ele acha o bloco por elas
    // e REESCREVE tudo que houver entre as duas, com padding de espacos, de
    // hora em hora pelo self-heal e depois de todo apt.
    //
    // Se o modo de leitura morasse aqui dentro, seria apagado em silencio -- e
    // o shader resultante AINDA COMPILARIA. Os sliders dela parariam de fazer
    // efeito sem nenhum erro em lugar nenhum: a pior classe de falha.
    //
    // Deixando esta regiao byte a byte igual ao upstream, o patcher velho
    // continua fazendo o que sempre fez (util na janela entre um apt upgrade e
    // o rebuild, quando o binario e de fabrica) e NUNCA encosta no bloco novo.
    if (color_mode == 1.0) {        // greyscale
        float value = (color.r + color.g + color.b) / 3.0;
        color = vec4(value, value, value, color.a);
    } else if (color_mode >= 2.0) {
        float L = (17.8824 * color.r) + (43.5161 * color.g) + (4.11935 * color.b);
        float M = (3.45565 * color.r) + (27.1554 * color.g) + (3.86714 * color.b);
        float S = (0.0299566 * color.r) + (0.184309 * color.g) + (1.46709 * color.b);

        float l, m, s;
        if (color_mode == 2.0) { // Protanopia
            l = 0.0 * L + 2.02344 * M + -2.52581 * S;
            m = 0.0 * L + 1.0 * M + 0.0 * S;
            s = 0.0 * L + 0.0 * M + 1.0 * S;
        } else if (color_mode == 3.0) { // Deuteranopia
            l = 1.0 * L + 0.0 * M + 0.0 * S;
            m = 0.494207 * L + 0.0 * M + 1.24827 * S;
            s = 0.0 * L + 0.0 * M + 1.0 * S;
        } else if (color_mode == 4.0) { // Tritanopia
            l = 1.0 * L + 0.0 * M + 0.0 * S;
            m = 0.0 * L + 1.0 * M + 0.0 * S;
            s = -0.395913 * L + 0.801109 * M + 0.0 * S;
        } else {
            // unknown
            l = L;
            m = M;
            s = S;
        }

        vec3 error;
        error.r = (0.0809444479 * l) + (-0.130504409 * m) + (0.116721066 * s);
        error.g = (-0.0102485335 * l) + (0.0540193266 * m) + (-0.113614708 * s);
        error.b = (-0.000365296938 * l) + (-0.00412161469 * m) + (0.693511405 * s);

        vec3 diff = color.rgb - error;
        vec3 correction;
        correction.r = 0.0;
        correction.g = (diff.r * 0.7) + (diff.g * 1.0);
        correction.b =  (diff.r * 0.7) + (diff.b * 1.0);

        color.rgb += correction;
    }
    // ----------------- FIM DO NAO TOCAR (upstream) ----------------------

    // ======================= HUNK B ======================================
    // MODO DE LEITURA. Mora AQUI por dois motivos, os dois deliberados:
    //   - DEPOIS da cadeia do color_mode, para ficar fora do bloco que o
    //     night light reescreve (ver o aviso acima);
    //   - ANTES do `color.rgb *= color.a`, porque toda a conta abaixo pressupoe
    //     cor NAO pre-multiplicada -- que e o estado em que o
    //     `color.rgb /= color.a` la em cima deixou tudo.
    //
    // GLSL ES 1.00, conferido: so fract, sin, dot, floor, mix, clamp e
    // gl_FragCoord. Nenhum texelFetch, nenhum inverse(), nenhum operador de
    // bit, nenhum laco de contagem variavel, nenhum switch -- tudo isso e
    // proibido ou inexistente em #version 100.

    // (1) TEXTURA / PAPEL
    if (leitura_textura > 0.0) {
        float t = clamp(leitura_textura, 0.0, 1.0);

        // Faixa dinamica de PAPEL, nao de tela: o preto sobe e vira TINTA
        // (~0.12, nunca 0) e o branco desce e vira PAPEL levemente amarelado
        // (~0.93, nunca 1). E essa compressao que tira o brilho de painel e faz
        // a tela parecer uma pagina -- e ela vem ANTES do grao de proposito,
        // porque o grao tem de modular o papel, nao a imagem crua.
        vec3 papel = vec3(0.118, 0.113, 0.104)
                   + vec3(0.815, 0.800, 0.760) * color.rgb;

        // Dessatura 30%: papel colorido nunca satura como um painel. Mantem a
        // cor -- o "Cores: Cores totais" do print dela -- e so tira o exagero.
        float tinta = dot(papel, vec3(0.2126, 0.7152, 0.0722));
        papel = mix(papel, vec3(tinta), 0.30);

        color.rgb = mix(color.rgb, papel, t);

        // Grao em duas oitavas: uma fina (o poro) e uma a ~1/3 de escala (a
        // fibra). Uma oitava so ja funciona e custa metade; tres dao fibra mais
        // rica e custam mais -- e escolha de gosto, nao de correcao.
        //
        // TEM de ser gl_FragCoord.xy, e nao v_coords: o MESMO programa, com os
        // MESMOS uniforms, e aplicado a DOIS elementos -- a textura de tela
        // cheia E a textura do CURSOR. v_coords vai de 0..1 DENTRO de cada
        // elemento, entao o grao inteiro seria desenhado dentro de um cursor de
        // 24 px. gl_FragCoord e espaco de framebuffer e casa nos dois.
        vec2 pix = floor(gl_FragCoord.xy);
        float g = (meow_grao(pix) + meow_grao(floor(pix * 0.34) + 11.0)) * 0.5 - 0.5;

        // MULTIPLICATIVO, nao aditivo: papel modula a REFLETANCIA, entao o grao
        // aparece no branco e some na tinta -- que e o comportamento real de uma
        // pagina, e de quebra nao serrilha o texto.
        //
        // Amplitude ~4 niveis de 255 no papel: da MESMA ordem do passo de
        // quantizacao de 8 bits, entao ele funciona tambem como dither e MATA
        // banding em gradientes, em vez de criar. A contrapartida honesta:
        // ruido estatico por pixel e o pior caso para codificador de video --
        // gravacao de tela e OBS gastariam mais bitrate se o vissem. Nao veem:
        // com filtro ligado, o blit da captura sai do buffer PRE-shader.
        color.rgb *= 1.0 + g * (0.085 * t);
        color.rgb = clamp(color.rgb, 0.0, 1.0);
    }

    // (2) TEMPERATURA
    // SEM `if`, de proposito. Com o modo desligado o lado Rust manda
    // vec3(1.0, 1.0, 1.0) e isto vira uma multiplicacao neutra: tres ALU, mais
    // barato que um desvio e sem divergencia entre fragmentos.
    //
    // Vem DEPOIS do papel, tambem de proposito: assim a luz quente amornece
    // tambem o branco do papel. Na ordem inversa o papel sairia frio com o
    // resto quente, e a tela ficaria com duas temperaturas brigando.
    color.rgb *= leitura_temp;
    // ===================== FIM DO HUNK B =================================

    // ------------------- NAO TOCAR (upstream) ---------------------------
    // re-multiply
    color.rgb *= color.a;

    gl_FragColor = color;
}
```

---

## Decisões dela, tomadas na noite de 29/08/2026

Estas três fecham perguntas que o plano deixou em aberto. Elas mandam sobre o que está
escrito acima.

### 1. O slider vai de 1000K a 6500K — a faixa inteira

Ela perguntou: *"se é um slider por que não dá pra comportar todos?"*. Está certa, e a
pergunta derrubou a minha proposta de cortar em 1700K ou 2500K. A tabela `WHITEPOINTS` do
redshift que o `aurora-night-light.py` já carrega vai de **1000K a 6500K** em passos de
500K, com interpolação entre os pontos — e 6500K é o neutro, ou seja, o slider no topo é o
modo de leitura desligado.

Cortar a faixa seria decidir por ela o que é "quente demais" sem ela nunca ter visto. É
exatamente a decisão que o slider existe para devolver.

### 2. O agendamento mora DENTRO do applet, não no meow.conf

Ela pediu para determinar a faixa horária ela mesma, pela interface. Isso muda a etapa 2
do plano acima: as chaves de horário passam a ser gravadas em `cosmic-config` junto com a
temperatura e a textura, e o systemd timer **lê** dali em vez de ter configuração própria
no `meow.conf`.

É melhor do que o desenho original: uma fonte de verdade só, em vez de duas que podem
divergir em silêncio. O applet fica com seis controles:

    Modo de leitura   [toggle]      -- liga agora
    Temperatura       [slider]      -- 1000K .. 6500K
    Textura           [slider]      -- 0% .. 100%
    Agendar           [toggle]
      das [HH:MM] às [HH:MM]
    Restaurar padrões [botão]

As chaves em `~/.config/cosmic/com.system76.CosmicComp/v1/` passam a ser cinco:
`leitura_temperatura`, `leitura_textura`, `leitura_agenda`, `leitura_hora_inicio`,
`leitura_hora_fim`. As duas primeiras são as que o shader lê por quadro; as três últimas
só o timer lê.

**A ressalva que não pode ser esquecida:** o applet sozinho NÃO pinta um pixel. Ele grava
chave; quem pinta é o compositor recompilado. A etapa 3 depende da etapa 1 existir — até
lá os sliders arrastam e a tela não muda.

### 3. A rota sem rebuild está morta, e agora é definitivo

O cético da trilha `ui-slider` sugeriu que temperatura e agendamento poderiam sair por
`cosmic-randr` / CTM de gamma no KMS, sem tocar no shader — e pediu que se medisse antes
de amarrar tudo ao rebuild. Medido em 29/08/2026, 18h40:

    cosmic-randr --help                              -> sem subcomando de gamma
                                                        (disable/enable/mirror/list/mode/
                                                         position/xwayland/kdl)
    strings /usr/bin/cosmic-comp | grep -c GAMMA_LUT -> 0
    /sys/class/drm/card0/device/driver               -> nvidia, DRM master = o compositor

Nenhum processo externo seta propriedade de CRTC enquanto o compositor detém o DRM master
— isso é regra do kernel, não característica desta máquina. **O rebuild do `cosmic-comp` é
obrigatório para os três alvos.** Não existe atalho, e não vale procurar de novo.

---

## O que foi investigado e NÃO vai dar

Esta é a parte mais valiosa do arquivo. Cada linha custou uma medição.

### Botões

- Patch binário para mover os botões, no estilo do aurora-night-light.py: a ordem é fluxo de controle Rust compilado e inlined (blocos de tamanhos diferentes, frames de pilha diferentes, duas cópias monomorfizadas), não texto embutido -- foi desmontado e provado, não suposto.
- Qualquer chave de configuração para os apps COSMIC (gsettings button-layout, gtk-decoration-layout, portal, CosmicTk) e também esperar o upstream: o libcosmic não lê nenhuma delas (grep zero na árvore inteira) e o PR libcosmic#1390, que fazia exatamente isso, foi fechado sem merge em 15/08/2026 travado em aprovação de UX, sem sucessor até hoje.
- Mexer só no cosmic-comp para os botões (rebuild, hook de decoração em src/hooks.rs, ou forçar SSD): só alcança janela SSD e pilha, porque os seis apps são CSD e desenham a própria barra -- e forçar SSD daria barra DUPLA neles; além disso o 'make VENDOR=1' apaga o vendor patchado antes de compilar, em silêncio.
- Pôr o applet de acessibilidade no painel como interruptor do modo de leitura: a linha 'Filtros de cor' só é desenhada com o protocolo v3 e o compositor desta máquina publica v2 -- e o applet manda ColorFilter::Unknown, que o compositor ignora por especificação.
- wlsunset, gammastep, wl-gammarelay, DDC/CI e o cosmic-nightlight de terceiros para temperatura: o protocolo de gamma não existe nem no smithay vendorizado (é ausência de fundação, não escolha do cosmic-comp), a TV PHILCO não responde DDC, e o cosmic-nightlight troca de VT e pisca a tela a cada mudança.
- Textura por papel de parede ou por gtk.css próprio: o carrossel sorteia 1 entre 23 imagens e troca para ativos-noite das 18h às 7h (com o meow-fundo.path revertendo fonte não autorizada em ~2s), e o cosmic-settings-daemon recria os symlinks do gtk.css a cada evento de tema, renomeando o arquivo dela para .bak (medido: recriados hoje às 17:40).

### Modo de leitura

- Escrever ~/.local/state/cosmic-comp/a11y_screen_filter.ron — REFUTADO: é lido UMA vez no boot, não tem watcher, e o compositor sobrescreve o arquivo no próximo toggle.
- Escada de 4 degraus pelo patch binário (sem recompilar) — PLAUSÍVEL, mas perde: exige o MESMO logout, não é slider, e os degraus apareceriam para ela com os nomes 'Protanopia/Deuteranopia/Tritanopia' no menu.
- Pendurar os sliders na página Acessibilidade do cosmic-settings — REFUTADO: o build nem começa nesta máquina (falta libdav1d-dev) e o apt troca esse binário a cada ~6 dias.
- Atalho de teclado + OSD para subir/descer a temperatura — REFUTADO: o cosmic-osd não tem método D-Bus para mostrar um OSD arbitrário, e o Não Perturbe dela engole notify-send (22 avisos comidos em 27/08).
- App GTK/Python próprio com dois Gtk.Scale — REFUTADO: mora fora de tudo que ela usa, e o repositório não tem uma única janela GTK para reaproveitar.
- Carona nos uniforms `alpha`/`tint`, ou alargar o enum do protocolo a11y para carregar um número — REFUTADO: alpha é hardcoded Some(1.0), tint só existe sob DEBUG_FLAGS que o compositor nunca liga, e o enum do protocolo colide com valores já definidos.

---

## Decisões de gosto ainda em aberto

Não são técnicas — são dela. Duas das cinco originais foram fechadas na noite de 29/08
(faixa do slider e onde mora o horário); ver a seção "Decisões dela" acima.

- **Intensidade máxima da textura.** No 100% o papel sobe o preto para ~0.12, desce o
  branco para ~0.93 e dessatura 30%. Isso é o teto do slider, ou ela prefere que se ligue
  e desligue na frente dela umas três vezes antes de fixar o número? (Com o slider
  existindo, este teto importa menos: ela acha o ponto arrastando.)
- **A virada do agendamento: seca ou rampa?** Com o horário dentro do applet, a rampa vira
  uma escolha de implementação do timer: virada seca é um `OnCalendar` por horário; rampa
  de N minutos exige o timer rodar de minuto em minuto durante a transição, escrevendo a
  chave a cada passo. O GNOME usa rampa. Falta ela dizer se quer, e de quantos minutos.
- **A ordem dos botões, se um dia os apps COSMIC forem recompilados.** Fechada em 29/08
  como `close,maximize,minimize:` — fechar na quina esquerda — depois de ela testar a
  inversão e desfazer em sete minutos. Registrada aqui porque decide o tamanho do patch do
  libcosmic: com esta ordem ele move E reordena (~15 linhas); com a invertida seria só
  mover (2 linhas), porque é a ordem que o `header_bar.rs` já monta internamente.

---

## Como ler o JSON bruto

```bash
# os vereditos e os caminhos, sem abrir 500 KB no editor
python3 -c "
import json;d=json.load(open('docs/pesquisas/2026-08-29-sliders-modo-leitura.json'))
for e in d['plano']['etapas']: print(e['ordem'], e['nome'], '|', e['tempo'])"

# o que cada trilha derrubou (hipóteses testadas e mortas)
python3 -c "
import json;d=json.load(open('docs/pesquisas/2026-08-29-botoes-cosmic-e-modo-leitura.json'))
for t in d['dossie_bruto']:
    print('##', t['trilha'])
    for x in (t['achados'] or {}).get('derrubado',[]): print(' -', x)"

# os trechos de código prontos que os frentes extraíram (GLSL, Rust, bash, systemd)
python3 -c "
import json;d=json.load(open('docs/pesquisas/2026-08-29-sliders-modo-leitura.json'))
for t in d['dossie_bruto']:
    for c in (t['achados'] or {}).get('codigo',[]):
        print('###', c['para_que'], '|', c['linguagem'], '|', c['fonte'])"
```

A estrutura é `plano` (a síntese) e `dossie_bruto[]` (uma entrada por trilha, cada uma com
`achados`, `codigo`, `derrubado` e `solucoes` já passadas por um cético adversarial que
tentou refutá-las).

