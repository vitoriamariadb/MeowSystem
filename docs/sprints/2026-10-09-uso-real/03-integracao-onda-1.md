# Integração da onda 1 — P75, P74, P73 e P76 — 09/10/2026

Branch `integracao/leva-g`, a partir do `f24868c`, na worktree
`~/Desenvolvimento/.wt-meow/integracao`. O dev e o checkout principal não foram tocados.

**Veredito:** os quatro blocos entraram, com 6 conflitos de texto e 3 de sentido resolvidos
(ninguém perdeu correção). A suíte fica com **três vermelhos, nenhum novo de código**:
1. o gate `app-completo.py`, por uma decisão que é de quem usa (item 1 de «Aberto»);
2. o `portabilidade.sh`, que já vinha do dev;
3. o `doctor-so-le.sh`, que é vermelho só de ambiente (com o HOME da sessão ele passa).

## O que entrou, por bloco

| ordem | merge | bloco | o que resolvi |
|---|---|---|---|
| 1 | `0ba1d3c` | P75: o doctor corrige; nada manda consertar à mão | sem conflito |
| 2 | `eeface3` | P74: o pack Dracula completo e exportável | **`bin/meow`**: a ordem da P75 (`pacotes` e `upstream` logo depois da `ponte`) mais o `indice` da P74 no fim. **`docs/SPRINTS.md`**: 61 etapas e 64 conferências (da P74), 122 chaves (da P75) |
| 3 | `d3b9790` | P73: o seletor mostra o acervo inteiro | **`PROCEDENCIA.md`**: as duas tabelas, 42 linhas da P74 e 214 da P73, sem nenhuma em comum. **`pack.py`** e **`icones_apps_dracula.sh`**: o padrão ligado da P74 e o ramo desligado da P73, que põe as escolhas. **`git-limpo.sh`**: as duas seções, a 3b da P73 e a 4/4 da P75 |
| 4 | `e24ca06` | P76: sobreviver às atualizações do COSMIC | **`SEM_CONSERTO`**: a P75 tirou `conf`, `cursor`, `cli`, `upstream`, `fontes` e `pacotes`; a P76 tirou `midiabin` e `leiturabin`; os dois comentários ficam. Razões: o `[patches]` da P76 e o `[pacotes]` da P75. **`desinstalar.sh`**: `meow-pos-apt.*` (P76) e `meow-som.service` (P74). **`todos.sh`**: as duas listas. **README**: os números da integração |

Os commits da própria integração vêm abaixo. Cada um foi reproduzido vermelho antes e verde depois.

| commit | defeito de sentido | prova |
|---|---|---|
| `af1935b` | A seção 4/4 do `git-limpo.sh` (P75) mandava `pack` + `desenho`. Esse era o corpo do «Usar este ícone» antes da P73. Depois da P73, esse corpo é o do «Levar para o pack», que grava no `apps.map` de propósito. A seção cobrava o contrário do que o painel promete | antes: `+ M packs/dracula/icones/apps.map`, rc=1. Depois, com o corpo `arquivo`: «git status do repositório inteiro idêntico», rc=0 |
| `10a139f` | O passo do pack da P73 nasceu com o padrão antigo (`${ICONES_DRACULA:-nao}`). Com o conf de fábrica sem a chave, o passo entrava pelo instalar (P74) e só punha as escolhas | casa de brinquedo, conf sem `ICONES_DRACULA`: antes «0 escolha(s) do painel no tema» e 0 arquivos em `scalable/apps`; depois 206 arquivos |
| `ef5529e` | O `acervo-da-ficha.sh` (P73) contava como desenho sem pasta os 13 SVG de papel de parede que a P74 versionou em `packs/dracula/wallpapers/` | antes rc=1 (4 pastas, 13 arquivos); depois rc=0 (sobram só `pastas/`, `gatos/`, `logo.svg` e a folha) |
| `1239f9c` | A P74 (`etapa_icones_indice`) e a P76 (`etapa_vigia_apt`) somaram uma etapa cada sobre as 60. Os dois lados escreveram 61, e o certo é 62 | `numeros.sh` acusava 5 lugares; agora diz «todos os números escritos batem» |
| `bc1b2ea` | A spec da P73 escrevia o checkout com o home de pessoa (linha 66) | `portabilidade.sh` passou de 2 achados para 1 (sobrou o do dev) |
| `7588b93` | O inventário do gate ainda listava o cartão `ajuste ICONES_BASE`, que a P75 aposentou | a aba Ícones do gate: antes 4 reprovações; depois «todos os controles acionados, console limpo» (126 s) |

Cada merge foi conferido contra um `git merge-tree` sem hook. O auto-fix de acentuação do
pre-commit não mudou nenhum byte além das resoluções.

## Testes

Ambiente: HOME temporário novo por rodada e falsos à frente do PATH. Os falsos (`sudo`, `pkexec`,
`su`, `pkill`, `killall`, `notify-send`, `systemd-run`, `loginctl`, `apt`, `apt-get`) registram e
não executam. O `systemctl`, o `gsettings`, o `dconf` e o `busctl` só deixam passar a leitura. O
Playwright vem do Python do pyenv.

**Suíte inteira, `./tests/todos.sh` (52 testes):** 47 verdes, 2 pulados, 3 vermelhos.
- **Pulados:** o `pack.sh` (falta bat/btop e o `Dracula_OS-Theme` no HOME de brinquedo) e o
  `conversor.sh`. Os dois por ambiente.
- **sudo:** a suíte registrou 6 chamadas (4 `sudo -n true`, 2 `ponte_root.sh estado`), e nenhuma
  chegou ao sistema.
- **Gate depois do `7588b93`:** 759 controles, 562 acionados, 2075 conferências, 594 s.
  Fecha em 10 reprovações, todas do item 1 abaixo.

| vermelho | causa | da integração? |
|---|---|---|
| `app-completo.py` (gate) | 10 reprovações, todas «Consertar o que estiver fora tentou baixar sem declarar rede» (5 downloads × 2 lugares) | não: é decisão (item 1 de «Aberto») |
| `portabilidade.sh` | `docs/pesquisas/2026-10-09-cosmic-vivo.md:198`, que veio no `f24868c` | não: já vinha do dev |
| `doctor-so-le.sh` | com HOME de brinquedo não há painel da sessão para achar | não: com o HOME da sessão (só leitura, sudo falso) sai rc=0, «o doctor só lê, e o sinal não sai de casa» |

Depois de cada merge também rodaram os testes que os dois lados tocaram. Tudo saiu verde, menos
os vermelhos esperados de cada momento: o `git-limpo` antes da P73, e o `acervo-da-ficha` e o
`numeros` antes das correções.
- **Depois da P75:** `doctor-veredito`, `chaves-aposentadas`, `sem-receita-no-log` e `flavor-padrao`.
- **Depois da P74:** a portátil inteira e o `pack-dracula-completo`.
- **Depois da P73:** `seletor-do-pack`, `acervo-da-ficha`, `git-limpo`, `fonte-unica`,
  `sem-dracula-os-theme`, `app`, `notas-de-funcao`, `restos-do-painel` e `oficina`.

**Doctor real, só leitura, da árvore de integração (sem `--consertar`):** sai rc=1 com o que
`--consertar` faria. Entre as divergências estão a chave aposentada `ICONES_BASE` (que a P75
migra), o `indice` (P74), o `-Base-2` (P74) e «apagaria `org.kde.ghostwriter.svg`». Este último
é o item 1 da conferência à mão.

**HOME real:** `find -newer` desde o início, em `~/.config/meow`, `~/.local/share/icons`,
`~/.local/bin`, `~/.config/systemd/user`, `~/.config/cosmic`, `~/.local/libexec`,
`/usr/local/lib/meowsystem` e `/etc/sudoers.d`, saiu vazio. Só mudaram o `wallpaper.log` e o
`wallpaper-vistas.txt`, às 22:34:13: o `meow-wallpaper.timer` disparou às 22:34:11.

## Aberto, com dono

1. **O gate barra o dev: o «Consertar» baixa sem declarar rede.** Dono: **decisão de quem usa**,
   depois P77 ou a próxima leva.
   - A P75 tirou `upstream` e `fontes` do `SEM_CONSERTO` (o doctor corrige, e o que baixa é
     pinado). A P76 tirou `midiabin` e `leiturabin` (rebuild sem sudo).
   - Agora o `doctor --consertar` clona o papirus-folders e o now-playing, baixa a fonte e o
     `Cargo.lock` do painel e roda `cargo build`. A ação `doctor_consertar` do painel continua
     com `rede: False`.
   - Declarar `rede: True` (a verdade) acende a regra do gate da P46: ação que baixa não roda sem
     caixa de pergunta. Isso põe uma pergunta no botão de consertar, e o princípio da P75 diz que
     o doctor corrige sem perguntar.
   - As duas regras são dela. Não escolhi entre elas, e não pus a frase em «defeitos conhecidos»
     do gate, porque seria contorno.
2. **A segurança da P73 não chegou à branch.** Dono: **a varredura de segurança** do `ESTADO.md`
   do dev, o próximo passo 2.
   - A seção «Segurança» foi acrescentada à spec da P73 no dev às 18:40, depois de a worktree
     nascer, e o conferente não a viu. Ela pede:
     - `realpath` e recusa de symlink no acervo da ficha;
     - CSP com `sandbox` e `nosniff` em todo SVG ou PNG de acervo, com teste de SVG com `<script>`.
   - Não conferi esses itens aqui. A P74 tratou os dela.
3. **O dev vai conflitar ao receber a integração** nas specs P73 e P74, porque o dev acrescentou
   a seção «Segurança» nas duas. Dono: **quem fizer o merge no dev**. São só documentos: fica a
   seção do dev mais a conferência da branch.
4. **Sem teste para o `ICONES_DRACULA` ausente no passo do pack.** O `10a139f` foi provado com um
   script de rodada, não com um teste. Dono: **próxima leva**.
5. **O `portabilidade.sh` vermelho pelo `cosmic-vivo.md:198`** e o **`doctor-so-le.sh` que
   depende do HOME da sessão.** Dono: **próxima leva**. Os dois já vinham do dev.

Os achados de cada bloco continuam nas specs, em «Achados para a próxima leva». A P75 traz o
runner que só falsifica sudo. A P74 traz os gatos com cor do Catppuccin e os 24 ícones do COSMIC
Ajustes, as duas decisões dela. A P73 traz o Waterfox sem marca e a raposa resgatada. A P76 traz
o coredump e o `meow-doctor.service` sem `~/.cargo/bin`.

## O que quem usa confere com a mão

1. **Antes de o dev receber, guarde a escolha do ghostwriter, que hoje está como ` M` no dev.**
   Acrescente ao `~/.config/meow/icones-escolhidos.map` a linha:
   `org.kde.ghostwriter : packs/dracula/icones/apps/org.gnome.gitlab.somas.Apostrophe.svg   # ghostwriter — escolhido no painel`.
   Depois rode `git -C ~/Desenvolvimento/MeowSystem checkout -- packs/dracula/icones/apps.map`.
   Sem isso, o merge recusa o arquivo sujo, e o doctor da integração apaga o ícone.
2. **O `.gitignore` do dev também está ` M`** (a linha `.aider*`). Faça commit ou guarde antes do
   merge. Não há conflito de conteúdo com a mudança da P73.
3. **Decida o item 1 de «Aberto».** Sem isso o gate não fica verde e, pela regra do
   `docs/SPRINTS.md`, nada entra no dev.
4. **Depois do merge no dev, rode `./install.sh` uma vez.** Ele instala a ponte nova da P75 (S4)
   e as unidades `meow-pos-apt` da P76. O doctor diz hoje que a ponte «diverge do repositório».
5. **À mão, na sessão:**
   - o login com o shim do compositor e o primeiro `full-upgrade` (passo a passo na spec da P76);
   - o seletor de ícone com três escolhas (com um HOME de teste, porque «Usar este ícone» aplica
     na hora).
