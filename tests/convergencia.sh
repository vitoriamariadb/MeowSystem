#!/usr/bin/env bash
# A promessa do README: a instalação CONVERGE — chega uma passagem em que nada
# mais é escrito. E o parágrafo 4 diz quantas: numa máquina nova são TRÊS, não
# duas, porque o `index.theme` descreve os diretórios que já EXISTEM e as pastas
# coloridas nascem na etapa seguinte.
#
# O QUE ESTE TESTE PEGA
#   Etapa que devolve 0 depois de escrever. `etapa_conf` e `etapa_modo` faziam
#   isso (10/08/2026): o resumo as listava em `confere:` na mesma rodada em que
#   elas imprimiram `~~` na tela, e a única prova do contrário era contar linhas.
#   Uma etapa não-idempotente aparece aqui como `mexeu:` que nunca some.
#
# POR QUE ELE OLHA `mexeu:` E NÃO A FRASE FINAL
#   Medido: num HOME de brinquedo sem barramento de sessão, `systemctl --user`
#   falha, o instalador sai 2 e a frase final — "Pronto. 3 passagens, 59 etapas,
#   nada mais a escrever.", que em 21/09/2026 tomou o lugar de "nenhuma etapa
#   precisou escrever nada" — nem chega a ser impressa. Isso é o ambiente, não o
#   defeito que caçamos. O `mexeu:` some do mesmo jeito, e é o que importa.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; FALSO="$(mktemp -d)"; trap 'rm -rf "$H" "$FALSO"' EXIT

# O `sudo` FALSO, E ELE É A SEGUNDA METADE DA MESMA CERCA — 21/09/2026
#   O `MEOW_PONTE=/nao/existe` lá embaixo cobre as etapas que PERGUNTAM pela
#   ponte. Ele não cobre a `etapa_ponte_root`, que não pergunta: ela chama
#   `sudo install` no caminho cravado `/usr/local/lib/meowsystem/`, e o que
#   decide se aquilo escreve ou não é o `sudo -n true` logo acima da chamada.
#
#   NUMA MÁQUINA COM `NOPASSWD: ALL` ESSE `sudo -n true` PASSA, e então a etapa
#   instala de verdade: o `perfil` sai com `raiz=` apontando para o clone de
#   onde o teste foi rodado e `lar=` apontando para o HOME de brinquedo que
#   este arquivo acabou de criar em /tmp — os dois caminhos morrem no `rm -rf`
#   do trap, e a máquina de verdade fica com um perfil que aponta para o vazio.
#   Aconteceu três vezes na sessão de 21/09/2026, e o dono restaurou à mão as
#   três. É a mesma classe do acidente de 08/09/2026 que o comentário do
#   `correr()` narra, por outra porta: um teste cujo alcance depende de quanto
#   o sudo da máquina deixa passar não é teste, é roleta.
#
#   RECUSAR É O ESTADO HONESTO. Sem sudo a `etapa_ponte_root` já sabe se pular
#   sozinha ("sem terminal para pedir a senha — a ponte fica de fora", devolve
#   MEOW_SEM_DEPENDENCIA), e `pulado:` não conta como `mexeu:` — a convergência
#   que este teste mede continua sendo medida, agora sem escrever em /usr.
#   Quem quiser exercitar a instalação da ponte de verdade tem o caminho certo:
#   rodar o `./install.sh` na mão, no clone de verdade, com a senha na mão.
cat > "$FALSO/sudo" <<'FIM'
#!/bin/sh
printf 'sudo: recusado pelo tests/convergencia.sh\n' >&2
exit 1
FIM
chmod 755 "$FALSO/sudo"

# O `systemctl` FALSO, PELA MESMA RAZÃO DO `sudo` — 10/10/2026, P80 (item 9)
#   Na integração da P79 este teste ficou vermelho por um falso de quem rodava
#   a suíte: o `systemctl` dele respondia 0 ao `enable`, enquanto o
#   `is-enabled`, sem barramento, dizia «não». As etapas dos serviços se viam
#   divergentes e «consertadas» a cada passagem, e o `mexeu:` não sumia nunca —
#   um vermelho do ambiente, e não do instalador. Medido de novo hoje com um
#   falso assim à frente do PATH: `painel leitura logo wallpaper assets
#   vigia_flatpak vigia_qt vigia_apt autoreparo` em todas as passagens.
#
#   O teste não pode depender do falso de quem o roda. Este fica à frente de
#   todos: a pergunta (`is-enabled`, `show`, `status`…) segue para o próximo
#   `systemctl` do PATH, e a escrita RECUSA (rc=1), como o `sudo` acima — que
#   é o que um `systemctl --user` sem sessão faz de verdade. O próximo é
#   achado PULANDO este diretório, e não cortando o começo do PATH (o laço
#   infinito que o `tests/doctor-so-le.sh` mediu em 24/09/2026).
cat > "$FALSO/systemctl" <<FIM
#!/bin/bash
case " \$* " in
  *" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*|*" status "*|*" cat "*\
  |*" list-units "*|*" list-unit-files "*|*" list-timers "*|*" show-environment "*\
  |*" get-default "*|*" --version "*)
    IFS=: read -ra _dirs <<< "\$PATH"
    for _d in "\${_dirs[@]}"; do
      [ "\$_d" = "$FALSO" ] && continue
      [ -x "\$_d/systemctl" ] && exec "\$_d/systemctl" "\$@"
    done
    exit 1 ;;
esac
printf 'systemctl: recusado pelo tests/convergencia.sh (%s)\n' "\$*" >&2
exit 1
FIM
chmod 755 "$FALSO/systemctl"

PASSAGENS="${PASSAGENS:-3}"

correr() {
  # `MEOW_PONTE` APONTA PARA O VAZIO, E ISSO NÃO É PARANOIA: este teste roda o
  # instalador num HOME de brinquedo, onde não há `meow.conf` e toda chave cai
  # no padrão. Em 08/09/2026 isso fez a etapa do hook de apt tomar o ramo de
  # REMOVER — e, com a ponte no ar, o ramo FUNCIONOU: o
  # `/etc/apt/apt.conf.d/99-meow-lancador` da máquina de verdade foi apagado por
  # um teste. O `lib/comum.sh` ganhou a cerca do `$HOME` no mesmo dia; esta
  # linha diz a mesma coisa aqui, onde quem lê o teste a vê.
  # O `$FALSO` vem ANTES do `$PATH`, e vazio não serve: é a ordem que faz o
  # `sudo` do teste ser o que recusa. Ver o bloco do `FALSO`, lá em cima.
  env -i PATH="$FALSO:$PATH" HOME="$H" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
    bash "$RAIZ/install.sh" 2>&1
}

saida=""
for i in $(seq 1 "$PASSAGENS"); do
  saida="$(correr)"
  printf 'passagem %s: %s\n' "$i" \
    "$(printf '%s' "$saida" | grep 'mexeu:' || printf 'nada mudou')"
done

if printf '%s' "$saida" | grep -q 'mexeu:'; then
  printf 'FALHOU: ainda mexia na passagem %s — alguma etapa não é idempotente\n' \
    "$PASSAGENS" >&2
  exit 1
fi
printf 'ok: convergiu em %s passagens\n' "$PASSAGENS"
