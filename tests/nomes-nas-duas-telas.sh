#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
pula()  { printf '  pulado: %s\n' "$*"; }
PATCH="$RAIZ/patches/cosmic-comp-nomes-nas-duas-telas.patch"
BASE=AURORA-AREAS-NOMES
MARCA=$BASE-1

echo "== a série"
grep -qE "^req[[:space:]]+cosmic-comp-nomes-nas-duas-telas\.patch[[:space:]]+$BASE\$" "$RAIZ/patches/series" \
  && ok "o patch é req, com marcador próprio" || falha "o patch não está na série como req"
[ "$(awk '$1 == "req" {u = $2} END {print u}' "$RAIZ/patches/series")" = "cosmic-comp-nomes-nas-duas-telas.patch" ] \
  && ok "entra depois dos outros" || falha "o patch não é o último da série"
grep -qF "\"$MARCA\"" "$PATCH" && grep -q '^+#\[used\]' "$PATCH" \
  && ok "o marcador sobrevive ao linker" || falha "falta o marcador com #[used]"

echo "== a cópia não vira alfinete"
grep -q '^+        if self.pinned && !self.nome_copiado {$' "$PATCH" && grep -q '^-        if self.pinned {$' "$PATCH" \
  && ok "a cópia não entra no arquivo: to_pinned recusa, mesmo fixada" || falha "to_pinned grava a cópia"
grep -E '^[+-]' "$PATCH" | grep -q 'pinned = \|WState::Pinned' \
  && falha "o patch mexe no alfinete" || ok "o patch não fixa nem solta área"
[ "$(grep -c '^+            nome_copiado: false,$' "$PATCH")" = 2 ] \
  && ok "toda área nasce sem nome copiado" || falha "falta nome_copiado: false num construtor"

echo "== os caminhos do compositor"
grep -A3 '^+                self.copiar_nomes(workspace_state);$' "$PATCH" | grep -q 'WorkspaceMode::OutputBound' \
  && ok "o refresh copia no fim do ramo Global" || falha "a cópia saiu do fim do ramo Global"
grep -q '^+                    set.soltar_nomes_copiados(workspace_state);$' "$PATCH" \
  && ok "passar a independentes solta as cópias" || falha "as cópias ficam presas ao sair de Global"
grep -q '^+    workspace_state.remove_workspace(de);$' "$PATCH" \
  && ok "a área fundida sai do protocolo" || falha "a área fundida fica no protocolo"
grep -q '^+                        fundir_area(workspace, &mut new_set.workspaces\[i\], workspace_state);$' "$PATCH" \
  && ok "tirar o monitor funde a cópia na irmã" || falha "tirar o monitor não funde a cópia"
grep -q '^+    for mut minimizada in area.minimized_windows.drain(..) {$' "$PATCH" \
  && grep -q '^+        .get_fullscreen_surfaces()$' "$PATCH" \
  && ok "janela minimizada e em tela cheia também mudam de área" || falha "a fusão perde janela minimizada ou em tela cheia"

grep -q '^+    let foco = std::mem::take(&mut area.focus_stack);$' "$PATCH" \
  && grep -q '^+    destino.focus_stack.por_baixo(foco);$' "$PATCH" \
  && ok "a pilha de foco da área fundida vai para a irmã" || falha "a fusão perde a pilha de foco"
grep -A2 '^+                        std::mem::swap($' "$PATCH" | grep -q '^+                            &mut copia.focus_stack,$' \
  && ok "a pilha da tela que fica continua em cima" || falha "fechar a tampa tira o foco de quem está na tela de fora"

echo "== o doctor confere o marcador"
mkdir -p "$T/bin" "$T/casa/.local/state/meowsystem" "$T/proc"
for c in sudo pkexec su apt apt-get cargo just make systemctl pkill; do
  printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done
printf '#!/bin/sh\nprintf 0.1~teste\n' > "$T/bin/dpkg-query"; chmod 755 "$T/bin/dpkg-query"
{ echo 'versao=0.1~teste'; printf 'req %s cosmic-comp-nomes-nas-duas-telas.patch presente\n' "$MARCA"; } > "$T/estado"
conferir() {
  env -i PATH="$T/bin:$PATH" HOME="$T/casa" NO_COLOR=1 MEOW_IGNORA_DESKTOP=1 CP_BIN="$T/binario" CP_ESTADO="$T/estado" \
    CP_PROC="$T/proc" MEOW_ESTADO="$T/casa/.local/state/meowsystem" bash "$RAIZ/scripts/compositor_patches.sh" conferir 2>&1
}
printf 'binario de teste\n' > "$T/binario"
saida="$(conferir)"
grep -qF "FALTA $MARCA" <<< "$saida" && ok "binário sem o marcador: o doctor acusa" || falha "o doctor não acusou: $saida"
printf '%s\n' "$MARCA" >> "$T/binario"
saida="$(conferir)"
grep -qF "FALTA $MARCA" <<< "$saida" && falha "o doctor acusou o marcador presente: $saida" || ok "binário com o marcador: o doctor aceita"
grep -qF 'todo .patch de patches/ está declarado na série' <<< "$saida" \
  && ok "o patch está declarado na série" || falha "o doctor acha patch fora da série: $saida"

echo "== as funções do patch, compiladas"
export RUSTUP_HOME="${RUSTUP_HOME:-${SUITE_CASA_REAL:-$HOME}/.rustup}"
if ! rustc --version >/dev/null 2>&1; then
  pula "sem rustc nesta máquina: as funções não foram compiladas"
else
  { sed -n '/^+fn nome_da_area/,/^+}/p;/^+#\[derive(Debug, PartialEq)\]/,/^+}/p;/^+fn area_na_saida/,/^+}/p' "$PATCH" | sed 's/^+//'
    echo "struct FocusStacks(std::collections::HashMap<u8, Vec<&'static str>>);"
    echo 'impl FocusStacks {'
    sed -n '/^+    pub fn por_baixo/,/^+    }$/p' "$PATCH" | sed 's/^+//'
    echo '}'
    cat <<'RS'
#[test]
fn a_pilha_da_tela_que_fica_continua_em_cima() {
    use std::collections::HashMap;
    let mut fica = FocusStacks(HashMap::from([(1, vec!["a"])]));
    fica.por_baixo(FocusStacks(HashMap::from([(1, vec!["b", "c"]), (2, vec!["d"])])));
    assert_eq!(fica.0[&1], ["b", "c", "a"]);
    assert_eq!(fica.0[&2], ["d"]);
}
#[test]
fn a_outra_tela_recebe_o_nome_do_dono() {
    let irmas = [(Some("Pop"), false), (None, false)];
    assert_eq!(nome_da_area(irmas.into_iter()), Some("Pop"));
}
#[test]
fn o_dono_pode_estar_em_qualquer_tela() {
    let irmas = [(None, false), (Some("OS"), false)];
    assert_eq!(nome_da_area(irmas.into_iter()), Some("OS"));
}
#[test]
fn copia_nao_e_dona_de_nome() {
    let irmas = [(Some("Pop"), true), (None, false)];
    assert_eq!(nome_da_area(irmas.into_iter()), None);
}
#[test]
fn sem_dono_a_area_fica_sem_nome() {
    let irmas = [(None, false), (None, false)];
    assert_eq!(nome_da_area(irmas.into_iter()), None);
}
#[test]
fn renomear_o_dono_vale_para_a_copia() {
    let irmas = [(Some("Novo"), false), (Some("Velho"), true)];
    assert_eq!(nome_da_area(irmas.into_iter()), Some("Novo"));
}
#[test]
fn a_copia_que_sai_funde_na_irma() {
    assert_eq!(area_na_saida(true, true, Some(false)), AreaNaSaida::Funde);
    assert_eq!(area_na_saida(true, true, Some(true)), AreaNaSaida::Funde);
}
#[test]
fn o_dono_que_sai_toma_o_lugar_da_copia() {
    assert_eq!(area_na_saida(true, false, Some(true)), AreaNaSaida::Substitui);
}
#[test]
fn area_sem_copia_segue_como_na_fabrica() {
    assert_eq!(area_na_saida(true, false, Some(false)), AreaNaSaida::Segue);
    assert_eq!(area_na_saida(true, true, None), AreaNaSaida::Segue);
}
#[test]
fn independentes_segue_como_na_fabrica() {
    assert_eq!(area_na_saida(false, true, Some(true)), AreaNaSaida::Segue);
    assert_eq!(area_na_saida(false, false, Some(true)), AreaNaSaida::Segue);
}
RS
  } > "$T/nomes.rs"
  if rustc --edition 2021 --test -o "$T/nomes" "$T/nomes.rs" > "$T/rustc" 2>&1 && "$T/nomes" > "$T/saida" 2>&1; then
    ok "$(grep 'test result' "$T/saida")"
  else
    falha "as funções não passaram: $(cat "$T/rustc" "$T/saida" 2>/dev/null)"
  fi
fi

if [ "$falhas" = 0 ]; then echo "nomes-nas-duas-telas: tudo certo"; exit 0; fi
echo "nomes-nas-duas-telas: $falhas falha(s)"; exit 1
