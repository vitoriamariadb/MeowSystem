# P101 — As pendências da leva H, antes da release

**Status: EM VOO em 24/10.** Quem usa (24/10): «manda só pra main do meu fork e gera os release, mas antes dá
conta desses outros problemas pendentes». A P100 (o patch v2 da Vitória) fica de fora: o destino é o fork.

Cada item: teste vermelho antes, verde depois, um commit por item, diff conferido (o gancho troca palavras).

## 1. O FLAVOR acompanha o pack no install
- Medido (conferência final, `03-integracao-final.md` «Ressalvas» 1): `PACK="dracula"` com o `FLAVOR="mocha"` do
  `meow.conf.exemplo` faz 13 etapas falharem; o flavor não cai no padrão do pack. O «Vestir» e o `meow pack usar`
  gravam os dois e não caem nisso.
- Cura na origem: o install resolve o flavor do mesmo jeito que o `meow pack usar` (flavor fora do pack → o
  padrão do pack), sem reescrever o `meow.conf` de quem escolheu um flavor válido.
- Prova: install no HOME temporário com `PACK="dracula"` e `FLAVOR="mocha"`, sem etapa vermelha.

## 2. O mascote acompanha a troca de pack
- Medido (Ressalvas 2): depois de trocar de pack, `LOGO_DIA`, `LOGO_NOITE` e `FASTFETCH_LOGO_GATO` continuam
  `mimir`/`coquinha`; a dock mostra o morcego, Ajustes › Mascote mostra «mimir».
- Cura: a troca de pack leva o mascote do pack, como o ponteiro (decisão 12): valor que é o padrão do pack de
  antes vira o padrão do pack novo; valor que quem usa escolheu dentro do pack novo fica.
- Prova: `meow pack usar` ida e volta no HOME temporário; as três chaves e o painel (Ajustes › Mascote) batem.

## 3. Nenhum sudo fora da ponte
- Medido (Ressalvas 3): `meow_desktop_escrever` cai em `sudo install` sem `-n`; `meow_desktop_pode` usa
  `sudo -n true`; o avatar do `greeter.sh` usa `sudo -n md5sum`. Só nos caminhos em que a ponte não responde.
- Cura: sem ponte, o caminho vira pendência («Conferir e consertar»), nunca sudo. Decisão de 23/10: senha só no
  install (memória `decisao-senha-so-no-install`).
- Prova: teste com a ponte ausente e o falso de `sudo` contando chamadas: zero.

## 4. Procedência sem caminho de outra máquina
- Medido (Ressalvas 4): `assets/temas/capturados/original/captura.txt` guarda `origem: /home/<usuário>/...`, e
  o `bin/meow` lê esse campo.
- Cura: a procedência diz o que é sem caminho absoluto de máquina; o leitor do `bin/meow` continua funcionando.
  Confira se o arquivo deveria estar num pack (P96: tudo de tema mora no pack) e só mova se o resto do código
  já espera assim.
- Prova: `tests/portabilidade.sh` (ou o teste certo) pega `/home/` em dado lido pelo código.

## 5. O nome da volta no teste
- Medido (Ressalvas 5): `tests/app-uso-real.py` chama a primeira volta de «catppuccin», mas ela é o pack
  meowsystem. Cura: o nome do pack de verdade.

## 6. O ícone do ZapZap
- Medido (24/10, na máquina real): o export do flatpak diz `Icon=meow-whatsapp`; o
  `~/.local/share/icons/MeowSystem-Icons/48x48/apps/meow-whatsapp.svg` é de 25/09 e difere da arte escolhida por
  quem usa (`packs/dracula/icones/apps/whatsapp-linux-app.svg`, a do manuais-final). É o único `meow-*` no tema
  instalado. Por isso a `dracula-copia-com.rtosta.zapzap` do `vizinhos.sh` não foi desativada.
- Cura na origem: o ZapZap veste a arte do pack (a escolhida), e o `meow-*` velho não sobra no tema instalado
  (o install ou o doctor tira o que não vem de nenhum pack). Edite o SVG do pack → o ZapZap acompanha (decisão 15).
- Prova: teste no HOME temporário; o nome que o export grava resolve para um arquivo idêntico ao do pack.

## Fora daqui (quem coordena faz)
- `~/.config/zsh/relatorio-mec/pdf_lavar_watch` (Spellbook) com o lock em `/tmp` → `$XDG_RUNTIME_DIR`.
- Depois do bloco: integração no dev, install real, desativar a cópia do ZapZap, push para o `master` do fork,
  release.

## 7. Achado de segurança no item 2 (quem coordena, 24/10)
- `scripts/migrar_conf.py`: o `_trocar_valor` grava no `meow.conf` (que o bash dá `source`) um valor vindo do
  pack (`mascote_padrao`, e já antes o `ponteiro` do `CURSOR`) entre aspas duplas. Um pack importado com
  `mascote.dia = "$(...)"` executa código no próximo `source`. Pack é dado, nunca código (GSD §2).
- Cura no ralo: `_trocar_valor` recusa valor fora de `^[A-Za-z0-9][A-Za-z0-9._-]*$` (sem troca, sem gravar); e o
  `pack.py validar` recusa `mascote.dia`/`mascote.noite`/ponteiro fora dessa forma.
- Prova: teste em `tests/pack-malicioso.sh` com mascote `$(touch …)` e ponteiro com aspas: nada gravado, nada criado.

## Achados do agente 1 (24/10, fora do pedido)
- `LOGO` (o mascote do modo `fixo`, `coquinha` no exemplo) não acompanha a troca de pack; o item 2 levou só
  `LOGO_DIA`, `LOGO_NOITE` e `FASTFETCH_LOGO_GATO`.
- `scripts/icones_absolutos.sh` ainda diz «Icon= precisa(m) de sudo para trocar» quando não há ponte; o caminho
  agora é pendência, sem sudo.
- `scripts/greeter.sh`: com o avatar atual ilegível, o `md5_atual` fica vazio e o mascote é posto por cima sem
  saber se o avatar era nosso (já era assim quando o `sudo -n md5sum` falhava).

## Execução
Veredito da conferência (24/10): **APROVADO_COM_RESSALVAS**. Os itens 1 a 6 batem com a tarefa; o item 2 abria
o buraco do item 7, que a conferência fechou.

**O que entrou, um commit por item:**
1. `9e10edb` + `16b4e68` o FLAVOR que o pack não tem cai no padrão do pack (`meow_flavor`, `gerar_temas.py`, a
   `etapa_conf` do install), sem reescrever o `meow.conf`; a `MEOW_PALETA` escolhida à mão decide. `tests/flavor-padrao.sh` §5.
2. `e39c832` `LOGO_DIA`, `LOGO_NOITE` e `FASTFETCH_LOGO_GATO` de fábrica acompanham a troca de pack; o escolhido
   fica. `tests/pack.sh` §19, conf e painel.
3. `9dff09b` sem a ponte, nada chama sudo: `.desktop` do sistema, banco do lançador, avatar e tela de login viram
   pendência. `tests/achados-tecnicos.sh` §10.
4. `65d4b9b` a `origem:` da captura `original` é `máquina <sha256>`; a guarda do `bin/meow` faz a mesma conta.
   Sai a isenção do `tests/portabilidade.sh`. O arquivo fica em `assets/` (o `bin/meow` e o `pack.py` o esperam lá).
5. `54d4405` a primeira volta do `app-uso-real.py` é `meowsystem`.
6. `51019cf` o `apps.map` do Dracula veste `meow-whatsapp` com o `whatsapp-linux-app.svg`; o traço de 48 px cede.
   `970d003` (conferência) o teste começa com o `48x48/apps/meow-whatsapp.svg` velho, como na máquina real.
7. `f4f952d` (conferência) o `validar` recusa `mascote.dia`/`mascote.noite` que não é nome, e o `migrar_conf.py`
   só grava no `meow.conf` mascote e ponteiro que são nome (`^[A-Za-z0-9_][A-Za-z0-9._-]*$`). A regra não ficou
   no `_trocar_valor`, como a tarefa dizia: ele também grava os valores de fábrica do exemplo, como `$FLAVOR` e
   `cat-${FLAVOR}-${ACCENT}`, e a regra quebraria os vestígios. `tests/pack-malicioso.sh` §7b: cada metade da
   cura fica vermelha sem a outra.

**Suíte**, duas vezes seguidas na ponta `970d003`:
`== todos os 77 · 76 verde(s), 1 pulado(s), 0 vermelho(s) ==` nas duas. O pulado é o `pack.sh`, que precisa do
`~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual`, apagado desta máquina em 24/10; pulado não é verde.
Os falsos recusaram 6 chamadas de sudo (4 `sudo -n true`, do pré-voo do install, e 2 `estado` da ponte), e
pararam 13 de `busctl`.

**O que ficou:**
- O `pack.sh` só fica provado onde existir o clone do Dracula_OS-Theme (ou com a conferência dele apontando para
  o que está no GitHub).
- Os três achados do agente 1, acima (`LOGO` do modo `fixo`, a frase «precisa(m) de sudo» do
  `icones_absolutos.sh`, o avatar ilegível do `greeter.sh`).
- O «Fora daqui» continua com quem coordena.
