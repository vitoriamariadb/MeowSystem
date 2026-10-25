# P104 — A ponte se repara sozinha, sem senha

**Status: CONFERIDA em 25/10 (APROVADO_COM_RESSALVAS), em `sprint/p104`; falta integrar.**
Vem da P98, «ficou de fora» 2.

Quem usa (24/10), sobre o «Conferir e consertar» repor a ponte: «Executar em background, não dá pra fazer um
perf.d da vida? Pra ele funcionar de fato? Não quero recolocar senha direto. Nem que seja script pra reaplicar
no background e ir mostrando o progresso.» Isso amplia a decisão 11 sem desfazê-la: a interface continua sem
pedir senha, e o reparo da ponte também não pede. Registre essa extensão na decisão 11 (`02-decisoes.md` e
`GSD.md`), citando essa frase.

## O que se mediu
- A ponte é `/usr/local/lib/meowsystem/ponte_root.sh` (0755, root) com a regra `/etc/sudoers.d/49-meowsystem-ponte`
  (0440). Só a `etapa_ponte_root` do `install.sh` a instala, e é ela que pede a senha.
- Sem a ponte, o painel mostra o estado e o botão «Conferir e consertar». O doctor não confere a ponte, e nada
  a repõe sem o install (P98, «ficou de fora» 2).

## A cura
1. **Reserva de root:** o install (que já tem a senha) guarda uma cópia da ponte e da regra numa pasta só de
   root (ex.: `/usr/local/lib/meowsystem/reserva/`, 0700 root).
2. **Reparo de root sem argumento:** uma unidade systemd do sistema, `oneshot`, que reinstala a ponte e a regra
   a partir da reserva, conferindo o sha256 e o `visudo -c` antes de pôr no lugar. Não lê nada de quem chama:
   nem caminho, nem arquivo do HOME, nem do repositório.
3. **Sem senha:** uma regra do polkit (`/etc/polkit-1/rules.d/`) deixa o usuário ativo da sessão local dar
   `start` nessa unidade e em nenhuma outra (`org.freedesktop.systemd1.manage-units`, com `unit` e `verb`
   conferidos). Opcional: `.path` ou `.timer` que chama o mesmo reparo sozinho quando a regra some.
4. **Doctor e painel:** o doctor confere a ponte (está no lugar, igual à reserva). O «Conferir e consertar»
   dispara a unidade em segundo plano e o painel mostra o progresso (estado da unidade), sem texto explicativo
   (GSD §2).
5. **O limite:** ponte NOVA no repositório (código que mudou) nunca vira root sem o install. Código que quem
   usa pode editar não é promovido a root. Esse caso continua pendência «rode o install» no doctor, e o painel
   mostra só o estado. Sem reserva (install antigo), também.

## Cuidados
- Nada roda como root no teste. Use falsos para `systemctl`, `pkexec` e `sudo`, e confira a regra do polkit
  como texto (ou com `pkcheck` num container).
- Prova de verdade num container `ubuntu:24.04` com systemd, ou confira com quem usa antes de instalar na
  máquina real.

## Como se prova
- Teste: a regra do polkit só aceita aquela unidade e o verbo `start`. A unidade não tem `ExecStart` com
  argumento vindo de fora. A reserva com sha256 adulterado não é instalada.
- Container: apagar `/etc/sudoers.d/49-meowsystem-ponte`, rodar o «Conferir e consertar» como o usuário sem
  senha, e a ponte volta. Com a reserva adulterada, nada volta e o doctor diz por quê.

## 6. Sobras da P103 (mesma classe: pendência que manda sudo, nome de botão)
- `scripts/nomes_apps.sh:272` ainda diz «precisam de sudo para encurtar». A cura é a mesma do
  `icones_absolutos.sh` na P103 (`86c49cb`).
- No papel de parede devolvido, o botão na tela e o `--onde` dizem «Era escolha minha», mas a busca (`lugares.js`,
  `wallpaper_permitir`) diz «Manter». Fica um nome só, curto, e o teste da P103 passa a cobrar o nome dos
  botões das pendências.
- O comentário do `meow_onde_no_painel` (`lib/comum.sh`) ainda fala em «na aba Seção».

## Execução
Veredito da conferência (25/10): **APROVADO_COM_RESSALVAS**. Os itens 1 a 6 batem com a tarefa, e a extensão da
decisão 11 está registrada com a frase. A conferência achou um defeito de fronteira e o corrigiu com teste.

**Commits:** `0429530` reserva · `378ef48` reparo oneshot · `ff849d5` polkit · `3c427b3` doctor e «Conferir e
consertar» · `3b58791` o limite · `1a03804` sobras da P103 · `9cdf975` decisão 11 · `4485548` veredito velho ·
`0b9d7f2` (conferência) `PONTE_ROOT="nao"`.

**O defeito da conferência (`0b9d7f2`).** Com `PONTE_ROOT="nao"` no meow.conf e a ponte ainda no disco, o
`chk_ponte` dá divergente e o `--consertar` chamava o `fix_ponte`, que não olhava a chave. Quem desligou a ponte e
apagou a regra a tinha de volta no conserto seguinte, e no auto-reparo das 5h. Antes da P104 a `ponte` estava no
`SEM_CONSERTO`, e o caso não existia. Agora o `fix_ponte` sai 3 com a chave em `nao` («tirar a ponte entra no
«Instalar tudo»»). `tests/ponte-reparo.sh` §6, vermelho antes e verde depois. No container, o código de antes
devolveu a regra, e o de agora a deixou fora.

**Container:** `ubuntu:24.04` COM systemd (`podman run --systemd=always --privileged`, rootless, `/sbin/init`),
systemd 255.4 e polkitd 124, as mesmas versões desta máquina. A conferência abriu uma sessão de logind de verdade
no `seat0`, local e ativa (`systemd-run -p PAMName=login -p User=gata -E XDG_SEAT=seat0`). Assim a regra do
repositório, com `subject.local`, foi exercida sem troca, o que fecha a ressalva da implementação.
1. Install: a `etapa_ponte_root` de verdade, como `gata`, com um sudo temporário no papel da senha. Ela pôs a
   reserva 0700 (`gata` não lista), o `reserva.sha256` 0644, o reparo, a unidade e a regra do polkit. A segunda
   passada deu rc 0. Depois o sudo temporário saiu, e `sudo -n true` pediu senha.
2. Regra apagada e `bin/meow doctor --consertar` na sessão: a regra voltou 0440 root, igual à reserva, e passou
   no `visudo -c`. O `pacotes` foi consertado pela ponte reposta na mesma passada.
3. Do serviço de usuário (o caminho do painel: `systemd-run --user`, `app.slice`), com a sessão viva, o `start`
   passou e a regra voltou. O polkit cai na sessão gráfica de quem chama. Fora de sessão (`su -`, sem seat), o
   doctor disse «o polkit recusou o reparo» e nada voltou.
4. Verbos, com o `systemctl` real na sessão: só o `start` do reparo passa. Foram recusados `stop`, `restart`,
   `reload`, `try-restart`, `reload-or-restart`, `set-property`, `freeze`, `clean`, `enable`, `mask`,
   `daemon-reload` e `set-environment`. Também foram recusados o `start` do `ssh` e do `getty@tty9`,
   `--job-mode=isolate` e o `EnqueueUnitJob restart` pelo `busctl`.
5. Unidade transitória com o mesmo nome (`systemd-run --unit=meowsystem-ponte-reparo.service`), com a unidade
   instalada e com o arquivo dela fora (`not-found`): recusada nos dois casos, e nada rodou como root.
6. Reserva adulterada: o reparo saiu com 4, nada voltou, e o doctor disse «a reserva não confere com o sha256».
   Regra da reserva que o visudo reprova, com o sha256 refeito: saiu com 5, nada voltou, e o doctor disse por quê.
7. Ponte editada no repositório (com uma linha que gravaria em `/root`): o doctor deu a pendência do install, o
   conserto saiu com 3, e o `InvocationID` da unidade não mudou. Com a ponte apagada, o reparo repôs a cópia da
   reserva, e a linha editada não entrou. Com a ponte trocada, a da reserva voltou. `/root/pwned` não existe.
8. Install antigo, sem reserva: o doctor pede o install, o conserto sai com 3, e nada é disparado.

**Leitura de ataque, sem achado:** a unidade não tem argumento, `Environment`, `%` nem `@`, e roda com
`ProtectHome`, `ProtectSystem=strict` e `PrivateTmp`. O reparo fixa o `PATH`, confere os nomes e o sha256 da
reserva antes de cada uso, e roda o `visudo -c` numa cópia antes do `mv`. Tudo o que ele lê e grava é de root.

**Suíte**, duas vezes seguidas na ponta `0b9d7f2`:
`== todos os 78 · 78 verde(s), 0 pulado(s), 0 vermelho(s) ==` nas duas, com rc 0 (41 min e 34 min). Os
falsos recusaram 6 chamadas de sudo (4 `sudo -n true` e 2 `estado` da ponte) e pararam 13 de `busctl`. O
`app-completo.py`, que ficou vermelho na rodada da implementação, passou nas duas.

**O que ficou** (anotado aqui, fora deste bloco):
- O `.path` ou `.timer` opcional não foi feito, e o auto-reparo das 5h já cobre o caso. O auto-reparo só repõe
  com uma sessão gráfica viva. Sem sessão, o polkit recusa e o doctor diz isso.
- Apagar só a regra do polkit não é detectado. A pasta é 0750 `root:polkitd`, e ela só volta junto com outra peça.
- O `chk_ponte` não compara a regra de sudo instalada com a da reserva (a pasta é 0750 root). Uma regra trocada
  que ainda libera a ponte passa como ok.
- Antes da P104: a ponte copia `$raiz/scripts/meow-lancador-apt.sh` do repositório para um hook de apt que roda
  como root (`apt-hook-instalar`). É código que quem usa pode editar e que chega a root sem o install. Isso fica
  fora desta tarefa e vale uma tarefa própria.
- A transitória com o nome do reparo só está segura porque o systemd 255 não manda `unit` ao polkit no
  `StartTransientUnit`. Se uma versão nova mandar, a regra precisa conferir mais.
