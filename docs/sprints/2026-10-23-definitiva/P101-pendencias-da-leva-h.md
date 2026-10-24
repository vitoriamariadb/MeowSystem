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
