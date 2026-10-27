# P125 — o painel fantasma, o vidro maximizado e o vigia da luz noturna passam ao MeowSystem

As classes A do levantamento: o que a Aurora faz pelo desktop do COSMIC, que serve a qualquer PC e
que o MeowSystem ainda não faz inteiro.

- **Depende** da P124 (o gatilho no doctor, o tipo `unidade`, o `fim -`).
- **O vigia da #2059 depende também** da P121, porque a luz noturna da Aurora tem de ter saído.
- **Leia antes:** `relatorios/levantamento-aurora.md`, seções 1.1 (linhas 4, 9 e 11), 3 e 5 (D1).

## O que se mediu
- **Painel fantasma.**
  - O `aurora-painel-fantasma.timer` roda a cada 3 min e gasta 1,1 a 1,6 s de CPU por passada, para
    dizer «painel saudável».
  - Ele mata o `cosmic-panel` por quatro sinais, com carência de 600 s:
    1. o journal do PID tem `Can't start notifications applet without a connection|Failed to connect
       to the notifications daemon`;
    2. o applet de notificações está na config, o `cosmic-applet-notifications` não existe e o
       painel é recém-nascido;
    3. a enxurrada de corner radius mais `Failed to render|Erroneous EGL call` no `_PID`;
    4. `tried to grab after being mapped|xdg_(popup|surface|toplevel)#N: error N|wl_(surface|display)#N:
       error N` **no journal inteiro** desde o nascimento.
  - O `lib/painel.sh` `meow_painel_fantasma`, no laço do `meow-painel.service` (carência de 600 s),
    procura `failed to render|erroneous egl|protocol error|error 1 on object` só no `_PID`.
  - Faltam os sinais 1 e 2, e o 4 só é pego quando a linha sai do próprio painel. O episódio de
    16/08 (4h44min sem painel) foi o sinal 4.
  - Dois matadores no mesmo processo. O `vizinhos.sh --conferir` acusa «painel e dock por
    ~/.local/bin/aurora-painel-fantasma.sh».
- **Vidro maximizado.**
  - O `aurora-vidro-maximizado.path` vigia seis arquivos de `CosmicTheme.{Dark,Light}/v2`, e o `.py`
    devolve o alpha em cerca de 1 s.
  - Em 3 dias sincronizou 12 vezes (`Dark/background: alpha 7C -> B5`): a Aparência regrava o tema e
    o vidro some.
  - O `scripts/vidro_janela.py` é o mesmo código portado, mas só o doctor das 05:00 o roda. Não há
    `meow-vidro.path` em `systemd/`.
- **Vigia da #2059.**
  - O `aurora-cosmic-nightlight-watch.timer` faz `curl` diário na API do GitHub e, quando a issue
    fecha, um `notify-send` «Peça ao Claude…», que manda digitar.
  - O `scripts/sentinela.sh` já roda todo dia às 12:00 e não lê issue nenhuma.
- **As âncoras.** Todos os inícios de corte da seção 3 do levantamento aparecem uma vez só no
  self-heal e no `install.sh` de hoje.

## Causa
- **Painel:** o MeowSystem herdou da Aurora a reciclagem do painel, mas não os sinais de
  notificações nem o padrão do sinal 4 fora do `_PID`.
- **Vidro:** o MeowSystem tem a correção, mas não tem o gatilho. Quem reage à Aparência é a Aurora.
- **Vigia:** é da luz noturna, e a luz noturna agora é do MeowSystem (o Modo de leitura); o vigia
  ficou para trás.
- **Nos três casos**, nenhum item do `vizinhos.tsv` tira a Aurora.

## Cura na origem
1. **`lib/painel.sh` `meow_painel_fantasma`.**
   - Ganha o sinal 1: a mensagem de notificações no `_PID`, a qualquer idade.
   - Ganha o sinal 2: o applet de notificações nas `plugins_*` do Panel ou da Dock, o processo
     ausente e o painel com menos de `MEOW_PAINEL_JANELA_STARTUP` segundos.
   - Ganha o padrão do sinal 4 no journal da sessão desde o nascimento do PID, e não só no `_PID`.
   - Os nomes das funções dizem o sinal. A carência de 600 s do `scripts/painel.sh` `laco` fica como
     está.
2. **O vidro.**
   - `systemd/meow-vidro.path`, com os mesmos seis `PathChanged`, e `systemd/meow-vidro.service`:
     `oneshot`, `ExecStartPre=-/usr/bin/sleep 1`, `StartLimitBurst=30`, e `ExecStart` pelo ponteiro
     `raiz` → `scripts/vidro.sh` aplicar.
   - Instalados e conferidos onde o `install.sh` e o `chk_autoreparo` já tratam as unidades
     `meow-*.path`.
   - Com `VIDRO_AO_MAXIMIZAR="nao"`, não instala.
   - A segunda execução não escreve, e por isso o `.path` não se realimenta.
3. **O vigia.**
   - `assets/contratos/vigias.tsv`: uma linha `pop-os/cosmic-comp 2059 leitura-nativa`, com a frase
     da decisão («o COSMIC ganhou luz noturna própria: decidir se o Modo de leitura passa a usar a
     de fábrica»).
   - O `scripts/sentinela.sh` lê o arquivo: `curl` com timeout, e falha de rede é rc 3, calado.
   - Issue fechada → `meow_pendencia_acionavel leitura-nativa "<frase>" ""`, que é a decisão, sem
     comando. Issue aberta → `meow_pendencia_resolvida`.
4. **`assets/contratos/vizinhos.tsv`:** os itens da seção 3 do levantamento, com início, fim e
   requer exatos.
   - `aurora-painel-fantasma-{instalar,ligar,passo,unidade}`, com requer da função nova do sinal 2;
   - `aurora-vidro-{instalar,reconciliar,passo,unidade}`, com requer `systemd/meow-vidro.path:PathChanged`;
   - `aurora-leitura-vigia-{instalar,unidade}`, com requer `scripts/sentinela.sh:vigias.tsv`.

   As linhas `enable --now` do vigia, que não têm âncora única, ficam: sem a unidade, elas falham
   caladas (`|| true`).
5. **Se o coordenador aceitar a D1 (alfinetes):**
   - `chk_areas` e `fix_areas` no `bin/meow` (`scripts/areas.sh conferir`/`aplicar`, entram no
     `VERIFICAVEIS`);
   - o conserto só refaz o alfinete que caiu e respeita `AREAS_NOMES`;
   - os itens `aurora-alfinetes` (bloco `install_user_if_diff "$SRC/aurora-cosmic-workspaces.py"` →
     `aurora-cosmic-workspaces[.]py falhou`) e `aurora-alfinetes-passo` (linha
     `        _step_workspaces_alfinetados`), com requer `bin/meow:chk_areas`.

   Se não aceitar, este passo sai inteiro.

## Prova
- **`tests/painel-fantasma.sh`** (novo), com `journalctl`, `pgrep` e `ps` falsos:
  - cada um dos quatro sinais dá fantasma;
  - o sinal 2 com o painel velho não dá fantasma;
  - o painel saudável não dá fantasma;
  - a carência do laço impede um segundo kill em 600 s.
- **`tests/vidro-do-cosmic.sh`:** bloco novo.
  - O `meow-vidro.path` instalado tem os seis `PathChanged`.
  - Com o alpha derrubado (`7C`), uma execução do serviço devolve `B5`, e a segunda não muda o
    `mtime`.
  - Com `VIDRO_AO_MAXIMIZAR="nao"`, nada é instalado.
- **`tests/sentinela.sh`:** bloco novo com `curl` falso.
  - Issue fechada → a linha `leitura-nativa` no `pendencias.tsv`, sem comando.
  - Issue aberta → resolvida.
  - Rede fora → rc 3, e nada é escrito.
- **`tests/vizinhos.sh`:** os itens novos cortam nas cópias reais do self-heal e do `install.sh`.
  - O self-heal cortado passa `bash -n`.
  - A `unidade` espera a marca e depois move o `.timer`/`.path` e o `.service`.
  - O `--restaurar` devolve tudo.
- **`tests/contrato-cosmic.sh`, se a D1 entrar:** com o alfinete caído, `chk_areas` diverge e o
  conserto o refaz. A segunda passada não escreve.
- `tests/decisoes.sh` e `tests/todos.sh --portatil` verdes.
- **Manual, com ela:**
  - depois do corte, `systemctl --user list-timers` não tem `aurora-painel-fantasma`,
    `aurora-cosmic-nightlight-watch` nem `aurora-vidro-maximizado.path`;
  - mexer na Aparência (trocar o acento) e maximizar uma janela mantém o vidro em cerca de 1 s;
  - `journalctl --user -u meow-vidro.service` mostra a passada.

## Arquivos
- `lib/painel.sh`: só `meow_painel_fantasma` e as funções novas dos sinais;
- `systemd/meow-vidro.path`, `systemd/meow-vidro.service`;
- `install.sh`: só a lista de unidades;
- `bin/meow`: só `chk_autoreparo` (a lista de unidades) e, com a D1, `chk_areas`/`fix_areas` e o
  `VERIFICAVEIS`;
- `scripts/sentinela.sh`, `assets/contratos/vigias.tsv`;
- `assets/contratos/vizinhos.tsv`;
- `tests/painel-fantasma.sh` (novo), `tests/vidro-do-cosmic.sh`, `tests/sentinela.sh`,
  `tests/vizinhos.sh` e, com a D1, `tests/contrato-cosmic.sh`.

## Item do coordenador (27/10)
- `tests/restaurar.sh` ação `sistema_limpar` vermelha já no `dev`: o `.deb` do cosmic-comp em `~/.local/share/meowsystem/debs` muda e não deixa «Restaurar» (`scripts/atualizar_sistema.sh limpar`). Cura junto do resto do compositor: a ação guarda o restauro ou não toca no `.deb` em uso; o `restaurar.sh` sai verde nessa ação.

## Fora desta sprint
- O mecanismo do vizinho (P124).
- A cadeia do clipboard (depois da P122).
- A porta única `meowsystem-reciclar-painel` para o Alt+F2 (anotado).
- A ordem dos botões e o vigia da #640 (ficam na Aurora).
- Os trechos de instalação do compositor (D10, P121).
- Apagar arquivos da Aurora.
- Os vigias de outras issues.
