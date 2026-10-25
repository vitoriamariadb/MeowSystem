# P104 — A ponte se repara sozinha, sem senha

**Status: REGISTRADA em 24/10; entra quando a P102 ou a P103 voltar (máximo de dois blocos ao mesmo tempo).**
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
