# Integração final de 23/10 — P92+P93, P96, P98, P99 numa árvore só

Árvore: `integracao/leva-h` (worktree `.wt-meow/integracao-h`). Já tem P90, P91, P94.

## 1. Integrar (agente 1)
1. Merge, nesta ordem: `sprint/p92` (P92+P93), `sprint/p99`, `sprint/p98`, `sprint/p96` (só traz os dois
   scripts e a spec).
2. Aplicar `docs/sprints/2026-10-23-definitiva/reorganizar-1-raiz.sh` e depois `reorganizar-2-packs.sh`
   (ensaio antes; um commit por script). Eles foram provados sobre a ponta da `sprint/p92`: o código novo da
   P98 e da P99 pode citar caminho velho (`assets/gatos`, `contratos/`, `packs/catppuccin`, subpastas de
   `icones/`, `assets/temas-de-apps`, «gato» na tela). Achar com `git grep` e consertar, commit à parte.
3. O conserto solto de 18/10 no `scripts/painel.sh` do checkout principal (os applets saem antes do painel):
   `.wt-meow/painel-sh-18-10.patch`, commit próprio.
4. `tests/todos.sh` inteiro.

## 2. O que falta (agente 2)
- **Ponte root, segurança (revisão automática de 23/10):** `libreoffice-devolver` não recebe nomes de quem
  chama: lê só a lista que o `libreoffice-remover` gravou como root em `/var/lib/meowsystem/`; a simulação
  confere `Remv` e `Purg` e recusa se faltar a remoção esperada ou se o plano tirar algo fora do LibreOffice e
  da ponte UNO. Teste para cada recusa.
- **Papel de parede, segurança (revisão automática de 23/10, ALTA; acrescentado por quem coordena):** pack é
  dado e pode vir de terceiro. (1) `scripts/wallpaper.sh` faz `${!valor}` com nome que vem do pack
  (`repo_do_conf`/`commit_do_conf`): expansão indireta de `a[$(cmd)]` executa comando. Só chaves de uma lista
  fixa (`WALLPAPER_*_REPO`/`_COMMIT`) e regex `^[A-Z_][A-Z0-9_]*$`; o `pack.py validar` recusa o resto.
  (2) O nome do arquivo da curadoria vira `$ATIVOS/$nome` sem checagem: recusar `/`, `..`, começo com `.`,
  conjunto de caracteres estrito, destino resolvido dentro de `$ATIVOS`; URL só `https`. Teste com pack
  malicioso para os dois (o `tests/pack-malicioso.sh` é o lugar).
- **Decisões de quem usa (23/10):**
  - terminal: o `vizinhos.conf` ganha exceção por arquivo e o MeowSystem escreve o bloco marcado dentro do
    `~/.config/zsh/.zshrc` (ZDOTDIR do Spellbook); no PC sem Spellbook, no `.zshrc`/`.bashrc` de sempre;
  - papéis de parede **separados por pack**: só a coleção do pack no ar gira; trocar de pack troca a coleção;
  - o **starship entra no install** (coberto pela senha única), como o fastfetch.
- **Defeitos achados:** instalar com `PACK=dracula` já no conf deixa o ponteiro do Catppuccin (decisão 12:
  o pack leva o ponteiro); o doctor manda «acrescente à mão» na linha do applet de leitura (nenhuma saída manda
  digitar); textos do servidor que a P98 não pôde mexer (`onde_na_tela`, `ABA_INICIO`, `DESCRICAO_SECAO` com
  as abas velhas; nomes de pendência e botões com mais de três palavras; maiúscula no começo);
  `docs/PACKS.md`, `docs/FRONTEIRA.md` (#667) e afins com as subpastas e a regra velha.
- `tests/todos.sh` inteiro duas vezes.

## 3. Conferência final (agente 3)
Regressão no todo: suíte duas vezes; instalação limpa num container `ubuntu:24.04` com os dois packs (a senha
uma vez só; depois, zero `sudo` fora da ponte); o painel novo em 1829x1029 nos dois packs; corrige o que achar.

**Acrescentado por quem coordena (revisão automática de 24/10, ALTA):** a cura do `wallpaper.sh` ainda tem
diferença de leitura: o `awk -F'\t'` valida um campo e o `read` com `IFS=$'\t'` junta tabs seguidos e lê
outro; a URL que vai ao `curl` pode não ser a validada. Ler uma vez só (o `awk` imprime só os campos já
validados, com separador que não colapsa, `\x1f`), conferir de novo no bash (`[[ $url == https://* ]]`) e
chamar `curl --proto '=https' --proto-redir '=https' -o "$tmp" -- "$url"`. Teste com linha de dois tabs e
URL `file://`/`-o` no `tests/pack-malicioso.sh`.

## Depois (eu, com quem usa)
Merge no dev, `./install.sh` real, a linha dos 11 apps no `meow.conf`, as desativações nos vizinhos (Spellbook,
Dracula, Aurora, NitroKit), a P95, o histórico sem a senha, push do master do fork e a PR.

## Execução

### Agente 3, conferência final (24/10)
Veredito: **APROVADO_COM_RESSALVAS**. As duas rodadas da suíte na ponta `9877833`:
`== todos os 77 · 77 verde(s), 0 pulado(s), 0 vermelho(s) ==` nas duas. Os falsos recusaram 6 chamadas de
sudo (4 `sudo -n true` e 2 `estado` da ponte) e pararam 13 de `busctl`.

**Correções, uma por commit, cada uma com o teste vermelho antes e verde depois:**
1. `bfb782e` papel de parede: o `awk` imprime só nome e URL já validados, separados por `\x1f`; o bash confere
   `https://` de novo; o `curl` leva `--proto '=https' --proto-redir '=https' -- "$url"`. Teste no
   `tests/pack-malicioso.sh`: linha com dois tabs seguidos e `file:///etc/passwd` ou `-o` no quarto campo.
2. `eb3f40c` as saídas do terminal dizem «mascote» (o `logo.sh`, a ajuda do `meow logo`, o relógio e o pré-voo).
3. `43a2883` o cartão de cada pack mostra o mascote dele na prévia (antes, os dois mostravam o do pack no ar).
   Teste no `tests/pack.sh`.
4. `8a8f422` a frase curta do Dracula diz os morcegos, não «o mascote do MeowSystem».
5. `117f374` sem `update-desktop-database`, o `lancador.sh` não dizia «mexeu» em toda passada, e o install no
   container não convergia. Teste no `tests/lancador-do-meow.sh`.
6. `fd251e0` sem cosmic-greeter, o `greeter.sh` aceita a resposta da ponte e não chama `sudo -n test`/`true`
   fora dela. Teste no `tests/achados-tecnicos.sh`.
7. `9877833` o doctor respeita o opt-in do install: sem `LANCADOR_SISTEMA="sim"`, o `ocultar` e o `absolutos`
   não escrevem em `/usr/share`. Antes, o `doctor --consertar` do container ocultou o `display-im6.q16`.
   Teste no `tests/lancador-do-meow.sh`.

O gancho não trocou nenhuma palavra em nenhum dos sete commits; conferi a árvore antes e depois de cada um.

**Container** (`ubuntu:24.04` descartável, um por pack, usuário com senha, log do sudo):
- Clean install `./install.sh` com `PACK=""` (meowsystem) e com `PACK="dracula"`/`FLAVOR="dracula"`: a senha
  foi pedida **1 vez** em cada, no pré-voo. Converge em 3 passagens.
- Depois de `sudo -K`: install de novo, `meow doctor`, `meow doctor --consertar`, `meow pack usar` o outro pack
  (o ponteiro foi junto, decisão 12), doctor e install. **0 pedidos de senha**.
- Com as correções 6 e 7, a última volta deu 25 chamadas de sudo e todas pela ponte (`estado`, `greeter-ver` e
  `pacotes`). Nenhuma chamada foi negada e nenhum comando rodou fora da ponte.
- O que só falha no container: o `cursor`, porque o gsettings não tem o schema `org.gnome.desktop.interface`.
  O `assets` e o auto-reparo pulam porque não há systemd --user.

**Painel em 1829x1029, nos dois packs:** `tests/app-uso-real.py --fotos` está verde. As 14 páginas estão em
`.wt-meow/integracao-final/prints-a3-final/`.

**A forma pedida:**
- Só dois packs: `meowsystem` e `dracula`.
- Cada `icones/` tem `apps`, `biblioteca` e `sistema`, sem subpasta.
- `assets/` tem só o que o programa usa.
- `find -type d -empty` não acha nada.
- Nenhum caminho desta máquina em código: o `portabilidade.sh` passa, e o que sobra está em comentário.

**Ressalvas, não consertadas (para o próximo bloco):**
1. Com `PACK="dracula"` e o `FLAVOR="mocha"` do exemplo, 13 etapas falham, porque o flavor não cai no padrão do
   pack. O «Vestir» e o `meow pack usar` escrevem os dois e não caem nisso.
2. Depois de trocar de pack, `LOGO_DIA`, `LOGO_NOITE` e `FASTFETCH_LOGO_GATO` continuam `mimir`/`coquinha`.
   O dock usa o morcego do pack, mas Ajustes › Mascote mostra «mimir».
3. Há sudo fora da ponte em três caminhos de exceção, quando a ponte não responde: `meow_desktop_escrever`
   cai em `sudo install` sem `-n`, o `meow_desktop_pode` usa `sudo -n true` e o avatar do `greeter.sh` usa
   `sudo -n md5sum`. Nenhum deles rodou no container.
4. `assets/temas/capturados/original/captura.txt` guarda `origem: /home/<usuário>/...`. É procedência que o
   `bin/meow` lê.
5. O `tests/app-uso-real.py` chama a primeira volta de «catppuccin», mas ela é o pack meowsystem.

Os logs ficam fora do repositório, em `.wt-meow/integracao-final/`: `suite-a3-2.log`, `suite-a3-3.log`,
`container/`, `prints-a3-final/` e `a3-antes-*.diff`.
