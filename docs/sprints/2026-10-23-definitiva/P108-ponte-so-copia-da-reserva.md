# P108 — A ponte só copia da reserva de root, nunca do repositório

**Status: CONFERIDA em 25/10, em `sprint/p108` (APROVADO_COM_RESSALVAS).** Achado pela conferência da P104, que o marcou como «problema que já existia antes da
P104». Vem antes da v2.1.0 porque é a fronteira de root. Quem usa (24/10) pediu qualidade máxima e autorizou
rodar tudo sem perguntar.

## O que se mediu (25/10)
- `scripts/ponte_root.sh`, verbo `apt-hook-instalar`: lê `raiz` do perfil gravado como root e copia
  `$raiz/scripts/meow-lancador-apt.sh` para o wrapper (`install -m 755 -o root`), que roda como root em todo
  `apt`. O clone é gravável por quem usa. Ou seja: editar o script no repositório e chamar o verbo (sem senha)
  põe código seu em root, sem passar pelo install.
- Verbo `completion-instalar`: mesma forma, com `$raiz/assets/zsh/_meow` copiado para
  `/usr/local/share/zsh/site-functions/_meow`, que o zsh de todo usuário carrega (root incluído). A ponte confere
  a primeira linha e o tamanho, mas não o conteúdo.
- O `chk_ponte` (P104) não compara a regra de sudo instalada com a da reserva. E apagar só a regra do polkit não
  é detectado (a pasta é 0750 `root:polkitd`).

## A cura
1. **A reserva guarda tudo o que vira root:** o install (que tem a senha) põe na reserva da P104
   (`/usr/local/lib/meowsystem/reserva/`, 0700 root, com sha256) o wrapper do apt já preenchido, o hook e a
   completion. Os verbos `apt-hook-instalar` e `completion-instalar` copiam SÓ da reserva, conferindo o sha256.
   Não leem nada do repositório.
2. **Repositório mais novo que a reserva:** é pendência «entra no próximo Instalar tudo», como a ponte nova na
   P104. Nunca é promovido sem o install.
3. **O doctor confere** a regra de sudo instalada contra a da reserva. A regra do polkit, a ponte confere (ela
   é root) por um verbo `estado` que já existe ou por um verbo novo sem argumento.
4. **Varredura:** procure em `ponte_root.sh` todo verbo que copia arquivo do `$raiz` (ou de qualquer lugar
   gravável por quem usa) para destino de root, e trate da mesma forma. Liste o que achou na seção «Execução».

## Como se prova
- Teste com a ponte de brinquedo: com o script do repositório adulterado, o verbo não o instala. A reserva com
  sha256 adulterado também não. O doctor acusa a regra divergente.
- Container `ubuntu:24.04` com systemd (a imagem `localhost/meow-p104-systemd:1` já existe; veja a «Execução» da
  P104): install, editar `scripts/meow-lancador-apt.sh` no clone, chamar o verbo sem senha, e o wrapper em
  `/usr/local` continua o da reserva.

## Execução
Veredito da conferência (25/10): **APROVADO_COM_RESSALVAS**. Os quatro itens da cura batem com a tarefa e foram
provados de novo no container. A conferência refez a varredura verbo por verbo e achou dois buracos. Os dois foram
corrigidos com teste (ver «A conferência», abaixo).

**Commits:** `c245fb8` a reserva guarda o wrapper, o hook e a completion, e os verbos copiam só dela ·
`a65a58e` o repositório mais novo que a reserva entra no próximo «Instalar tudo» · `c1d4ec2` o doctor confere
a regra de sudo contra a reserva, e a ponte diz o sha256 da regra do polkit · `e46d14f` a varredura ·
(conferência) `5c5752f` o wrapper do apt se troca por quem usa · `44a310a` o `greeter-aplicar` só aceita arquivo
e pasta.

**O desenho.** O install põe na reserva `meow-lancador-apt.sh` (já preenchido), `99-meow-lancador` e `_meow`,
com o sha256 em `/usr/local/lib/meowsystem/reserva-pecas.sha256` (0644 root). É um arquivo separado do
`reserva.sha256` da P104, e o reparo da ponte não mudou. Os verbos leem a peça uma vez para um temporário, conferem
o sha256 ali e só então instalam. O sha256 tem de nomear as três peças e só elas. Reserva adulterada sai com 4, e
sem as peças (install anterior) sai com 3. O verbo nunca cai no repositório. O `estado` ganhou `regra_sha256` e
`polkit_sha256`. O doctor compara o primeiro com a reserva e o segundo com o repositório. A etapa da ponte também
usa o `estado` para ver a regra do polkit, porque a pasta é 0750 e ela não a lê.

**Provas (testes):** `tests/ponte-so-reserva.sh` (novo, na suíte) e `tests/ponte-reparo.sh` §7. Cada item ficou
vermelho antes e verde depois. A varredura (§3) é vermelha contra a ponte da P104
(`PONTE_VARRER=<ponte da p104>`), com 4 falhas, e verde na de agora.

**A varredura** (verbos que escrevem em destino de root, e de onde vem o que escrevem):
| verbo | origem |
|---|---|
| `apt-hook-instalar` | era `$raiz/scripts/` do clone; agora só a reserva, com o sha256 |
| `completion-instalar` | era `$raiz/assets/zsh/_meow` do clone; agora só a reserva, com o sha256 |
| `desktop` | stdin: edita um `.desktop` que já existe; é dado de aplicativo e roda como quem o abre |
| `greeter-aplicar` | stdin: um tar para o lar do `cosmic-greeter`, com o dono dele, não root |
| `flatpak-global-limpar` | o próprio override global, menos linhas; do stdin só passa nome de chave e de tema |
| `libreoffice-remover` | a lista do dpkg, gravada em `/var/lib/meowsystem` |

Os outros verbos não copiam arquivo. `apt-hook-remover` e `completion-remover` só apagam caminhos literais.
`pacotes`, `libreoffice-devolver`, `atualizar` e `limpar` só passam ao apt nomes de uma lista literal ou de root.
`estado`, `regra-sudo` e `desktop-banco` não escrevem nada de quem chama.

**Container** (`localhost/meow-p104-systemd:1`, systemd 255.4, rootless; a sessão de logind de verdade no
`seat0`, `systemd-run -p PAMName=login -p User=gata -E XDG_SEAT=seat0`, sem `XDG_VTNR`, porque o seat não tem VT):
1. Install: a `etapa_ponte_root` e a `etapa_lancador_apt` de verdade, como `gata`, com um sudo temporário no
   papel da senha. A reserva ficou 0700 com as três peças, e o `reserva-pecas.sha256` conferiu. A segunda
   passada das duas deu rc 0. Depois o sudo temporário saiu: `sudo -n true` pede senha, e `gata` não lista a
   reserva.
2. Clone editado como `gata`: `touch /root/pwned-*` no wrapper, um `DPkg::Post-Invoke` no hook e uma linha na
   completion. Depois `sudo -n … apt-hook-instalar` e `completion-instalar`, sem senha, saíram 0. Os três
   instalados ficaram com o mesmo sha256 de antes, o da reserva. Apagados, o verbo os repôs da reserva, sem
   `pwned`. O doctor disse «o hook do repositório mudou — entra no «Instalar tudo»», e o conserto saiu com 3.
   Um `apt-get install --reinstall` de verdade rodou o hook, e `/root/pwned-*` não existe.
3. Peça da reserva adulterada: `completion-instalar` saiu com 4 («a reserva não confere com o sha256: _meow») e
   não instalou nada.
4. Regra de sudo trocada (uma linha a mais, ainda passa no `visudo -c` e ainda libera a ponte): fora de sessão
   e na sessão, o doctor disse «difere da reserva». Na sessão do `seat0`, o `fix_ponte` disparou o reparo pelo
   polkit, sem senha, e a regra voltou igual à da reserva, 0440 root.
5. Regra do polkit apagada (`gata` não lê a pasta): o `estado` deu `polkit_sha256=` vazio, e o doctor disse «falta
   a regra do polkit do reparo — entra no «Instalar tudo»». O conserto saiu com 3. O install com a senha a viu
   pelo `estado` e a repôs. A segunda passada deu rc 0. Com a regra trocada, o doctor disse «difere do repositório».
6. O `meow doctor` de verdade, na sessão: `ponte` ok, `lancadorapt` ok.

**A conferência** (25/10). A varredura foi refeita sozinha, verbo por verbo, perguntando se algum caminho,
arquivo, variável de ambiente ou link de quem usa chega a root.
- **O wrapper do apt rodava o clone como root (`5c5752f`).** A implementação o anotou para depois, mas é a regra
  desta tarefa, e o `atualizar` e o `pacotes` da ponte disparam o apt sem senha. Eram dois buracos. O primeiro:
  o wrapper roda `ocultar_apps.sh` e `nomes_apps.sh` do clone como root. O segundo é independente do clone: o log
  `~/.local/state/meowsystem/apt-lancador.log` era escrito e recebia `chown` de root. No container, com o código
  de antes, `gata` pôs um link do log para `/etc/meow-alvo` (0600 root). O apt seguinte deixou o arquivo
  `gata:gata`, com uma linha anexada. Num `/etc/shadow`, isso é root. A cura: chamado como root, o wrapper só se
  troca por quem usa (`runuser -u "$USUARIA" -- "$0"`), e o resto corre com o uid dela. O `.desktop` de sistema
  passa pela ponte, como no painel. Se a troca falha, ou se o molde foi preenchido com `root`, nada do clone roda.
  `tests/ponte-so-reserva.sh` §4 tem 4 itens, vermelhos com o wrapper de antes e verdes agora.
- **O `greeter-aplicar` aceitava nó de dispositivo e FIFO (`44a310a`).** O tar extraído por root cria nó de
  dispositivo com o modo do tar (um `/dev/sda` 0666), e o `cp -a` o levava ao lar do greeter. Agora só passam
  arquivo e pasta. `tests/doctor-veredito.sh` §6 tem o item do FIFO, vermelho antes e verde depois.
- Sem achado nos outros verbos. O `desktop` confere o nome e só edita arquivo que já existe, e o `install` troca
  o link em vez de segui-lo (medido). O `apt-hook-instalar` e o `completion-instalar` leem a reserva 0700 para um
  temporário de root. O `flatpak-global-limpar` só tira linha, e o lar do perfil decide só se o tema existe. O
  `libreoffice-*`, o `pacotes`, o `atualizar` e o `limpar` passam nomes de root ou de lista literal. O
  `estado`, o `greeter-ver` e o `desktop-banco` não escrevem nada de quem chama. Os dois `*-remover` só apagam
  caminhos literais. Com o `env_reset` do sudo, `BASH_ENV`, `ENV`, `SHELLOPTS`, `PS4`, `PATH` e `LD_PRELOAD`
  não chegam à ponte (provado no container). Verbo com argumento e o `regra-sudo` pedem senha.

**Container da conferência** (`meow-p108-conf`, da mesma imagem, com `vim` e `zsh` de verdade):
7. Código de antes (`e46d14f`), install como `gata` com o sudo temporário no papel da senha. `gata` pôs uma linha
   no `ocultar_apps.sh` e o link do log para `/etc/meow-alvo`. Um `apt-get install --reinstall` de root: o
   `ocultar_apps.sh` do clone viu uid 0, `/root/pwned-ocultar` existe, e `/etc/meow-alvo` ficou `gata:gata` com
   a linha do log.
8. Código de agora: o clone foi atualizado e o install rodou com a senha. Na reserva, o wrapper novo; a segunda
   passada das duas etapas deu rc 0. O mesmo ataque: o clone viu uid 1001, `/root/pwned-ocultar` não existe, e
   `/etc/meow-alvo` continua `root:root`, 0600, só com «segredo». Sem o ataque, o `--reinstall` do `vim-common`
   devolveu o `vim.desktop`. O hook o ocultou de novo pela ponte (o journal diz `desktop vim.desktop`), o log
   é de `gata`, e nada no lar é de root.
9. Os verbos, como `gata` e sem senha: com o wrapper, o hook e a completion do clone adulterados, o
   `apt-hook-instalar` e o `completion-instalar` saíram 0, e os três instalados têm o sha256 da reserva.
   Apagados, voltaram da reserva, sem `pwned`, e o apt seguinte não criou nada em `/root`. Com a completion da
   reserva adulterada, o verbo saiu 4 e não instalou nada. O `meow doctor` deu `ponte` ok.
10. `greeter-aplicar`: um tar com FIFO, feito por `gata`, foi recusado pela ponte de agora («só arquivo e pasta
   no tar»). Pela de antes, o FIFO chegou ao lar do greeter. O nó de dispositivo não se prova aqui, porque o
   podman sem root não faz `mknod`, e as duas pontes recusaram o tar. A régua que o recusa é a mesma do FIFO.

**Suíte**, duas vezes seguidas na ponta `44a310a`:
`== todos os 79 · 79 verde(s), 0 pulado(s), 0 vermelho(s) ==` nas duas, com rc 0 (33 min e 33 min). Os falsos
pararam 13 chamadas de `busctl` e nenhum sudo.

**O que ficou** (anotado aqui, fora deste bloco):
- **Na máquina de verdade, as duas curas só valem depois do próximo «Instalar tudo» com a senha.** Até lá, a
  reserva e o `/usr/local/sbin` guardam o wrapper de antes, que roda o clone como root. O doctor já acusa
  «o hook do repositório mudou» e «a ponte do repositório mudou», e as duas entram no «Instalar tudo».
- `desktop`: o conteúdo vem de quem chama e vai para um `.desktop` de sistema. Não vira root, mas o `Exec=` é o
  que roda para qualquer usuário que abrir o aplicativo. Uma cerca possível: o verbo só aceita diferença nas
  chaves que o projeto edita (`NoDisplay`, `Name`, `Icon`).
- A regra do polkit é comparada com o repositório, não com uma cópia na reserva. Divergir dá sempre pendência do
  install, que é quem a repõe.

