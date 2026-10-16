#!/usr/bin/env bash
# aplicar_tema.sh — devolve ao COSMIC uma captura feita por capturar_tema.sh.
#
# Depois que a Vitória importou o tema uma vez e o capturamos, aplicar deixa de
# precisar do app gráfico: é copiar a foto de volta. Vale em máquina nova, vale
# no `install.sh` sem flag, vale no auto-reparo.
#
# `--conferir` compara arquivo a arquivo e sai 1 se algo divergir, sem tocar em
# nada.
#
# O `aurora-vidro-maximizado.py` copia o alpha de `transparent_X.base` para
# `X.base` cerca de 1s depois de qualquer gravação, e de novo a cada ciclo do
# self-heal.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COSMIC="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
SECO="${MEOW_DRY_RUN:-0}"

# Os três pares em que o alpha do `base:` é território da Aurora.
declare -a CHAVES_ALPHA_AURORA=(background primary secondary)

# --- OS DOIS SLIDERES DE "VIDRO FOSCO" SÃO DELA, NÃO NOSSOS ------------------
# Em Aparência → Vidro fosco a GUI do COSMIC tem dois controles: "Espessura do
# efeito fosco" (grava `frosted`) e "Opacidade do vidro" (grava `alpha_map`).
#
# ELES ESTAVAM DENTRO DA CAPTURA — e por isso não colavam.
#
# A regra que sai daqui vale para além destas duas chaves: o que a GUI expõe com
# um controle contínuo é decisão de quem está na frente da tela.
declare -a CHAVES_DELA=(frosted alpha_map frosted_maximized_apps)

e_chave_dela() {
  local chave; chave="$(basename "$1")"
  case "$1" in
    # `v*` E NÃO `v1`: a escolha dela é a mesma chave em qualquer esquema, e
    # o `v1` cravado deixaria de protegê-la no dia em que o COSMIC subir o
    # `Mode` de esquema.
    com.system76.CosmicTheme.Mode/v*/is_dark|com.system76.CosmicTheme.Mode/v*/auto_switch) return 0 ;;
  esac
  case "$1" in com.system76.CosmicTheme.*) ;; *) return 1 ;; esac
  for k in "${CHAVES_DELA[@]}"; do [ "$chave" = "$k" ] && return 0; done
  return 1
}

# --- A FRONTEIRA É POR ÁRVORE, NÃO POR CHAVE ---------------------------------
#
# Libertar `frosted` e `alpha_map` (acima) resolveu metade do problema e criou a
# outra.
#
#     17:59:12–17:59:46  ela mexe os dois slideres; a GUI DERIVA o tema
#     18:00:36           o install.sh reescreve NOVE arquivos de Dark/v2 de volta
#                        para a captura
#
# Foi a outra proposta em cima da mesa, e ela parte cada arquivo ao meio.
e_produto() {
  case "$1" in
    com.system76.CosmicTheme.Dark/v1/*|com.system76.CosmicTheme.Light/v1/*) return 1 ;;  # a v1 legada, de propósito
    com.system76.CosmicTheme.Dark/*|com.system76.CosmicTheme.Light/*) return 0 ;;
  esac
  return 1
}

# A receita do destino confere com a da captura? Comparação por conteúdo, nas
# chaves que a GUI escreve.
receita_diverge() {
  local arv v a b chave k slider=0
  for arv in Dark Light; do
    for v in v1 v2; do
      for a in "$ORIGEM/com.system76.CosmicTheme.$arv.Builder/$v"/*; do
        chave="$(basename "$a")"
        b="$COSMIC/com.system76.CosmicTheme.$arv.Builder/$v/$chave"
        [ -f "$a" ] && [ -f "$b" ] || continue
        cmp -s "$a" "$b" && continue
        [ "$chave" = "frosted_maximized_apps" ] && continue
        for k in "${CHAVES_DELA[@]}"; do
          [ "$chave" = "$k" ] && { slider=1; continue 2; }
        done
        return 1
      done
    done
  done
  [ "$slider" = "1" ]
}

uso() {
  cat <<'FIM'
uso: aplicar_tema.sh <nome> [--conferir]

Restaura no COSMIC a captura <nome>, resolvida pelo pack ativo.

  <nome>       qual captura aplicar. Ex.: original, mocha-mauve.
  --conferir   não escreve; sai 0 se já está aplicado, 1 se divergente.

Variáveis:
  MEOW_DRY_RUN=1    mostra o que faria e não escreve (igual a --conferir, verboso).
  MEOW_COSMIC_DIR   destino (padrão: ~/.config/cosmic).
FIM
}

[ $# -ge 1 ] || { uso >&2; exit 2; }
NOME="$1"; shift
# Varre TODOS os argumentos, não só o primeiro.
CONFERIR=0
for a in "$@"; do
  case "$a" in
    --conferir)      CONFERIR=1 ;;
    --respeitar-gui) ;;   # lido mais abaixo, junto do bloco que o explica
    *) echo "ERRO: opção desconhecida: '$a'" >&2; uso >&2; exit 2 ;;
  esac
done
[ "$SECO" = "1" ] && CONFERIR=1

case "$NOME" in ''|*/*|.*) echo "ERRO: nome inválido: '$NOME'" >&2; exit 2 ;; esac
# Ela desceu para dentro do pack dono (`packs/<id>/temas/capturados/`), e a
# `original` ficou no motor porque não é tema de pack nenhum.
#
# O `|| ORIGEM=""` NÃO É ENFEITE
#   Captura ausente faz o `pack.py captura` sair 1, e com o `set -e` lá de cima
#   a atribuição morria ALI: o script saía 1, calado, sem a frase de erro nem o
#   3 logo abaixo, que nunca eram alcançados. Medido com `dracula-pink` antes
#   de a derivação existir: `aplicar_tema.sh dracula-pink` devolvia 1, e 1 é
#   "divergente, consertei" para quem lê o código — o avesso de "não existe".
ORIGEM="$(python3 "$RAIZ/scripts/pack.py" captura "$NOME" 2>/dev/null)" || ORIGEM=""
[ -n "$ORIGEM" ] && [ -d "$ORIGEM" ] || {
  echo "ERRO: captura '$NOME' não existe no pack ativo, no que ele herda, nem em assets/temas/capturados/" >&2
  exit 3
}

# Zera os dois dígitos de alpha do `base:` de primeiro nível, para comparar só o
# que é nosso.
#
# O casamento é com `base: "#RRGGBBAA"`, o formato de STRING HEX.
normalizar() {
  sed -E 's/^(    base: "#[0-9A-Fa-f]{6})[0-9A-Fa-f]{2}"/\1XX"/'
}

# Espelha a regra da própria Aurora em vez de fixar "v2": lá
# (aurora-vidro-maximizado.py, temas() e pares()) um diretório só entra se NÃO
# for .Builder e tiver arquivos `transparent_*`; e o par de `X` é
# `transparent_X`.
e_chave_da_aurora() {
  local rel="$1" chave dir
  chave="$(basename "$rel")"
  dir="$(dirname "$rel")"
  case "$rel" in *.Builder/*) return 1 ;; esac
  case "$rel" in com.system76.CosmicTheme.*) ;; *) return 1 ;; esac
  for k in "${CHAVES_ALPHA_AURORA[@]}"; do
    if [ "$chave" = "$k" ] && [ -f "$ORIGEM/$dir/transparent_$k" ]; then
      return 0
    fi
  done
  return 1
}

# --- BACKUP: ESTE SCRIPT É O ÚNICO DO PROJETO QUE APAGA ARQUIVO ALHEIO -------
# Ele sobrescreve arquivos de tema e REMOVE os que sobram em relação à captura
# (ver o bloco "os arquivos que SOBRAM", mais abaixo, para saber por que remover
# é necessário).
#
# Já se escreveu aqui que o risco "real" era o de outra máquina, e que nesta ele
# seria pequeno porque as capturas nasceram aqui.
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
BACKUPS_MANTIDOS="${BACKUPS_MANTIDOS:-10}"
BACKUP_DIR=""

garantir_backup() {
  [ -n "$BACKUP_DIR" ] && return 0            # já feito nesta execução
  # A pasta `backups/` é COMPARTILHADA por todos os módulos e todos os outros
  # usam esse formato (`MEOW_CARIMBO`, em lib/comum.sh; a razão está escrita por
  # extenso em assets/temas-de-apps/vscode/manifesto.sh §helper 3).
  local marca="" velho
  for velho in "$MEOW_ESTADO"/backups/*-tema-*; do
    [ -d "$velho" ] && { marca="ja-rodou"; break; }
  done
  [ -n "$marca" ] || marca="PRIMEIRO-"
  [ "$marca" = "ja-rodou" ] && marca=""
  BACKUP_DIR="$MEOW_ESTADO/backups/$(date +%Y-%m-%dT%H-%M-%S)-tema-$marca$NOME"
  mkdir -p "$BACKUP_DIR" || { echo "ERRO: não consegui criar $BACKUP_DIR" >&2; exit 2; }

  # Guarda as árvores INTEIRAS que esta execução pode tocar, não só os arquivos
  # que vão mudar: restaurar meia árvore devolveria o híbrido que este script
  # existe para evitar.
  for a in "$ORIGEM"/com.system76.CosmicTheme.*; do
    [ -d "$a" ] || continue
    n="$(basename "$a")"
    [ -d "$COSMIC/$n" ] || continue
    cp -a "$COSMIC/$n" "$BACKUP_DIR/" 2>/dev/null || true
  done

  ( cd "$BACKUP_DIR" && find . -type f ! -name manifesto.sha256 -exec sha256sum {} + \
      > manifesto.sha256 2>/dev/null ) || true

  # Como voltar, escrito AO LADO do backup. Um backup que só o autor sabe
  # restaurar é meia rede de segurança: quem vai precisar dele é justamente
  # alguém que não leu este script.
  cat > "$BACKUP_DIR/COMO-RESTAURAR.txt" <<FIM
Estado de ~/.config/cosmic (só as árvores de tema) antes de aplicar a captura
'$NOME', em $(date '+%d/%m/%Y %H:%M:%S').

Para voltar exatamente a este estado:

    cp -a $BACKUP_DIR/com.system76.CosmicTheme.* ~/.config/cosmic/

Para conferir que nada se corrompeu aqui dentro:

    cd $BACKUP_DIR && sha256sum -c manifesto.sha256

O COSMIC relê por inotify: a interface acompanha em segundos, sem relogar.
FIM
  echo "  backup em $BACKUP_DIR (veja COMO-RESTAURAR.txt)"

  # Retenção: as N mais recentes DESTE script, DESTA captura.
  #
  # `*-tema-*` casava também `<carimbo>-tema-v1`, que é do `gerar_tema_v1.py` e
  # é o único registro do que havia nas capturas antes de o gerador escrever
  # nelas.
  #
  # O `-tema-PRIMEIRO-` também é excluído explicitamente.
  local -a antigas=()
  for velho in "$MEOW_ESTADO"/backups/*-tema-"$NOME"; do
    [ -d "$velho" ] || continue
    case "$velho" in *-tema-PRIMEIRO-*) continue ;; esac
    antigas+=("$velho")
  done
  [ "${BACKUPS_MANTIDOS:-10}" -eq 0 ] 2>/dev/null && return 0
  if [ "${#antigas[@]}" -gt "$BACKUPS_MANTIDOS" ]; then
    printf '%s\n' "${antigas[@]}" | sort | head -n "-$BACKUPS_MANTIDOS" \
      | while read -r velho; do rm -rf "$velho"; done
  fi
  return 0
}

# --- O VIDRO SEGUE O COSMIC INSTALADO ----------------
# O `alpha_map` e o `frosted` são dela (`CHAVES_DELA`, lá em cima) e ficam; as
# CORES que carregam o vidro iam como a captura as fotografou, com o `alpha_map`
# do dia da foto.
#
# A CAPTURA PASSA A SER LIDA COMO ESTE COSMIC A DERIVA.
#
# `CAPTURA` guarda a foto: a cessão, no laço, precisa das duas (ver lá).
CAPTURA="$ORIGEM"
VISTA=""
if VISTA="$(mktemp -d "${TMPDIR:-/tmp}/meow-vidro.XXXXXX")"; then
  trap 'rm -rf "$VISTA"' EXIT
  rc_vidro=0
  frase_vidro="$(MEOW_COSMIC_DIR="$COSMIC" python3 "$RAIZ/scripts/derivar_vidro.py" \
                   "$CAPTURA" --vista "$VISTA/captura" 2>&1)" || rc_vidro=$?
  # 1 = a cópia está pronta, e só ela: a escrita é atômica lá dentro.
  [ "$rc_vidro" = "1" ] && [ -d "$VISTA/captura" ] && ORIGEM="$VISTA/captura"
  # A frase vai para a tela quando há o que dizer, e nunca no `--conferir`: a
  # primeira linha dele é o veredito que a tabela do doctor mostra.
  case "$rc_vidro" in
    1|3) if [ "$CONFERIR" != "1" ] || [ "$SECO" = "1" ]; then
           printf '  %s\n' "$frase_vidro"
         fi ;;
  esac
fi

# O laço mede com ela se o destino já está certo, e o `e_a_foto` mede se o
# destino ainda é a FOTO da captura.
confere() {   # confere <rel> <um> <outro>
  if e_chave_da_aurora "$1"; then
    diff -q <(normalizar < "$2") <(normalizar < "$3") >/dev/null 2>&1
  else
    cmp -s "$2" "$3"
  fi
}

# O destino ainda é a FOTO da captura? É o que separa, na cessão, a derivação
# da GUI dela da cópia que um `aplicar_tema` de antes deixou.
e_a_foto() { confere "$1" "$CAPTURA/$1" "$COSMIC/$1"; }

divergentes=0
escritos=0
iguais=0
cedidos=0

# Numa DECISÃO dela é o oposto.
#
# Quem chama para manter, passa; quem chama porque ela mandou, não.
RESPEITAR_GUI=0
[ "${MEOW_RESPEITAR_GUI:-0}" = "1" ] && RESPEITAR_GUI=1
for a in "$@"; do [ "$a" = "--respeitar-gui" ] && RESPEITAR_GUI=1; done

# Resolvido UMA vez, antes do laço: é a mesma resposta para todos os arquivos, e
# dentro do laço custaria uma varredura por arquivo.
RECEITA_VELHA=0
[ "$RESPEITAR_GUI" = "1" ] && receita_diverge && RECEITA_VELHA=1

# AS FICHAS DA CAPTURA SÃO UMA LISTA SÓ
fichas="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import derivar_acento
print("\n".join(derivar_acento.FICHAS))' "$RAIZ/scripts" 2>/dev/null)" && [ -n "$fichas" ] || {
  echo "ERRO: não consegui ler do scripts/derivar_acento.py quais arquivos da captura são fichas" >&2
  exit 2
}
mapfile -t FICHAS <<< "$fichas"

while IFS= read -r -d '' arq; do
  rel="${arq#"$ORIGEM"/}"
  # O `.gitignore` é da captura DERIVADA (scripts/derivar_acento.py): ela é
  # produto, mora dentro do pack e se esconde do git sozinha. É metadado, como
  # os outros dois — copiá-lo poria um `.gitignore` na raiz do ~/.config/cosmic.
  for ficha in "${FICHAS[@]}"; do [ "$rel" = "$ficha" ] && continue 2; done
  destino="$COSMIC/$rel"

  # O vidro que ela ajustou na GUI vence a captura, sempre — inclusive numa
  # captura recém-aplicada. Só se escreve quando a chave ainda NÃO existe no
  # destino (máquina nova), para que o valor da captura sirva de ponto de
  # partida e nunca de correção diária.
  if e_chave_dela "$rel" && [ -f "$destino" ]; then
    iguais=$((iguais+1)); continue
  fi

  if [ -f "$destino" ] && confere "$rel" "$arq" "$destino"; then
    iguais=$((iguais+1)); continue
  fi

  # O produto derivado só é imposto quando a receita ainda bate — ver a fronteira
  # por árvore, acima. Divergiu a receita, quem manda é a derivação da GUI dela.
  # A comparação vem ANTES desta guarda de propósito: um arquivo que já está
  # idêntico não foi "cedido", ele só está certo. Contá-lo aqui faria o script
  # anunciar "120 arquivos preservados" numa árvore em que nove divergiam.
  #
  # A FOTO NO DESTINO NÃO É OBRA DA GUI — 25/09/2026, sprint P58
  #   Com o vidro vindo do `alpha_map` dela (o bloco de antes do laço), um
  #   produto que diverge da vista pode ser a própria foto da captura, que um
  #   `aplicar_tema` anterior gravou com o vidro do mapa da foto. Isso não é
  #   derivação dela, é cópia nossa — e ceder deixava o AA na tela para sempre.
  #   Medido nesta máquina: a receita no disco difere da `dracula-mauve` só no
  #   `alpha_map` (o slider o reescreveu em 17/09), então todo «Salvar e
  #   aplicar» (`--respeitar-gui`) cairia aqui e sairia 4, dizendo «você mexeu
  #   em Aparência». Sem vista, a foto É a origem, e o arquivo que chega aqui
  #   já diverge dela: nada muda.
  if [ "$RECEITA_VELHA" = "1" ] && e_produto "$rel" && [ -f "$destino" ] \
     && ! e_a_foto "$rel"; then
    cedidos=$((cedidos+1)); continue
  fi

  divergentes=$((divergentes+1))
  if [ "$CONFERIR" = "1" ]; then
    [ "$SECO" = "1" ] && echo "  mudaria  $rel"
    continue
  fi

  garantir_backup
  mkdir -p "$(dirname "$destino")"
  # Temporário no diretório de DESTINO: /mnt/Apate e /home são sistemas de
  # arquivos diferentes, e mv entre eles não é atômico.
  tmp="$(mktemp -p "$(dirname "$destino")" ".meow.XXXXXX")"
  cat "$arq" > "$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino"
  escritos=$((escritos+1))
done < <(find "$ORIGEM" -type f -print0)

# --- os arquivos que SOBRAM ------------------------------------------------
# Restaurar não é só copiar de volta: é preciso remover o que não pertence à
# captura. Isto não é hipotético — o import do tema pela GUI CRIOU 33 arquivos
# novos (o COSMIC migrou o tema para o schema v2, escrevendo Builder/v2/accent,
# palette, bg_color...). Sem esta etapa, voltar para a captura "original"
# deixaria os 33 para trás, e o tema resultante seria um híbrido: as chaves
# antigas restauradas convivendo com as novas do tema que se queria desfazer.
# É exatamente o "quase funciona" que este projeto evita desde o começo.
#
# Só se remove dentro das árvores que a captura conhece: um diretório de tema
# que não foi fotografado não é da nossa conta.
sobrando=0
for arvore in "$ORIGEM"/com.system76.CosmicTheme.*; do
  [ -d "$arvore" ] || continue
  nome_arvore="$(basename "$arvore")"
  [ -d "$COSMIC/$nome_arvore" ] || continue
  while IFS= read -r -d '' vivo; do
    rel="${vivo#"$COSMIC"/}"
    [ -e "$ORIGEM/$rel" ] && continue
    # Com a receita divergente, um arquivo "a mais" dentro das árvores de produto
    # provavelmente foi a GUI dela que derivou — remover seria desfazer o ajuste
    # por outra porta, depois de ter cedido na porta da frente.
    if [ "$RECEITA_VELHA" = "1" ] && e_produto "$rel"; then
      cedidos=$((cedidos+1)); continue
    fi
    sobrando=$((sobrando+1))
    if [ "$CONFERIR" = "1" ]; then
      [ "$SECO" = "1" ] && echo "  removeria $rel"
      continue
    fi
    garantir_backup
    rm -f "$vivo"
  done < <(find "$COSMIC/$nome_arvore" -type f -print0)
done

# --- O CÓDIGO 4: "A CAPTURA ESTÁ VELHA" NÃO É DIVERGÊNCIA ---------------------
# Ele existe por causa do timer. O `meow-doctor.service` roda todo dia às 5h e o
# `ExecStopPost` notifica QUANDO O CÓDIGO É 1 — porque 1 significa "divergia e foi
# consertado". Se "a captura está velha" saísse 1, ela receberia
# "o auto-reparo corrigiu" toda madrugada, sem nada ter sido corrigido e sem nada
# PODER ser: quem decide recapturar é ela. Seria a notificação mentirosa diária,
# o mesmo anti-padrão que o projeto recusou no F11.
#
# 4 = divergente por escolha dela. O doctor mostra e não conserta; a unidade o
# aceita como sucesso (`SuccessExitStatus=1 3 4`) e o ExecStopPost fica calado,
# porque só olha o 1.
MEOW_CAPTURA_VELHA=4

aviso_receita() {
  echo "a captura '$NOME' está velha: você mexeu em Aparência e a GUI derivou um tema novo."
  # [P82: dizia «Para fixar o que está na tela: meow tema capturar»; fica o estado.]
  echo "  $cedidos arquivo(s) preservados."
}

if [ "$CONFERIR" = "1" ]; then
  if [ "$divergentes" -eq 0 ] && [ "$sobrando" -eq 0 ]; then
    if [ "$cedidos" -gt 0 ]; then
      aviso_receita
      exit "$MEOW_CAPTURA_VELHA"
    fi
    echo "tema '$NOME' já aplicado ($iguais arquivos conferem)"
    exit 0
  fi
  echo "tema '$NOME' divergente: $divergentes de $((divergentes+iguais)) arquivos" \
       "${sobrando:+e $sobrando sobrando}"
  exit 1
fi

if [ "$escritos" -eq 0 ] && [ "$sobrando" -eq 0 ] && [ "$cedidos" -gt 0 ]; then
  aviso_receita
  exit "$MEOW_CAPTURA_VELHA"
fi

echo "tema '$NOME' aplicado: $escritos escritos, $iguais já estavam certos${sobrando:+, $sobrando removidos}${cedidos:+, $cedidos preservados da sua GUI}"
exit 0
