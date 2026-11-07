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
MARCA=$BASE-2

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
grep -q '^+    workspace_state.remove_workspace(area.handle);$' "$PATCH" \
  && ok "a área fundida sai do protocolo" || falha "a área fundida fica no protocolo"
grep -A1 '^+                        fundir_area($' "$PATCH" | grep -q '^+                            workspace,$' \
  && ok "tirar o monitor funde a cópia na irmã" || falha "tirar o monitor não funde a cópia"
grep -q '^+        .chain(area.minimized_windows.iter().flat_map(|m| m.windows()))$' "$PATCH" \
  && grep -q '^+        .chain(area.get_fullscreen_surfaces().map(|f| f.surface.clone()))$' "$PATCH" \
  && ok "janela minimizada e em tela cheia também mudam de área" || falha "a fusão perde janela minimizada ou em tela cheia"

grep -q '^+    let foco = std::mem::take(&mut area.focus_stack);$' "$PATCH" \
  && grep -q '^+    destino.focus_stack.por_baixo(foco);$' "$PATCH" \
  && ok "a pilha de foco da área fundida vai para a irmã" || falha "a fusão perde a pilha de foco"
grep -A2 '^+                        std::mem::swap($' "$PATCH" | grep -q '^+                            &mut copia.focus_stack,$' \
  && ok "a pilha da tela que fica continua em cima" || falha "fechar a tampa tira o foco de quem está na tela de fora"

echo "== a janela volta ao religar"
grep -A1 '^ *self.sets.insert(output.clone(), set);$' "$PATCH" | grep -q '^+        self.devolver_janelas(output, workspace_state);$' \
  && ok "a janela volta ao religar: add_output devolve depois de mover os donos" || falha "add_output não devolve as janelas"
grep -A2 '^+                            output_match_for_output(output),$' "$PATCH" | grep -q '^+                            &mut self.fundidas,$' \
  && ok "a janela da tela que sai lembra a saída dela" || falha "a fusão não lembra a saída que saiu"
grep -q '^+                            output_match_for_output(&new_output),$' "$PATCH" \
  && ok "fechar a tampa: a janela da tela de fora lembra a tela de fora" || falha "o dono que substitui leva a janela da tela de fora sem volta"
grep -q '^+        if let Some(lembrada) = fundidas.iter_mut().find(|f| f.janela == janela) {$' "$PATCH" \
  && ok "fundir de novo não troca a saída lembrada" || falha "a segunda fusão apaga a saída de origem"
grep -q '^+        self.conferir_fundidas();$' "$PATCH" \
  && grep -A2 '^+        fundidas.retain_mut(|fundida| {$' "$PATCH" | grep -q '^+            if !fundida.janela.alive() {$' \
  && ok "fechar a janela apaga a lembrança" || falha "a janela fechada segue lembrada"
sed -n '/^+    fn devolver_janelas/,/^+    }$/p' "$PATCH" > "$T/devolver"
grep -q 'fundida.flutuante.as_ref()' "$T/devolver" \
  && ok "a janela solta volta solta, no lugar dela" || falha "a janela solta volta como ladrilho"
grep -q 'focus_stack.por_baixo(foco)' "$T/devolver" \
  && ! grep -qE 'set_active_output|set_focused_output|activate\(|add_workspace_state|append' "$T/devolver" \
  && ok "a volta não rouba o foco nem troca a área ativa" || falha "a volta mexe no foco ou na área ativa"
grep -q 'while set.workspaces.len() < max.unwrap_or(0) {' "$T/devolver" \
  && [ "$(grep -c 'add_empty_workspace' "$T/devolver")" = 1 ] \
  && ok "a volta só completa até a lista das outras telas, sem área a mais" || falha "a volta cria área além da lista"
grep -q 'self.fundidas.retain(|f| !devolvidas.contains(&f.janela));' "$T/devolver" \
  && ok "a janela devolvida sai da lembrança" || falha "a janela devolvida segue lembrada"
grep -q '^+                self.fundidas.clear();$' "$PATCH" \
  && ok "passar a independentes apaga as lembranças" || falha "as lembranças ficam ao sair de Global"
grep -E '^\+' "$PATCH" | grep -qE 'cosmic_config|set_pinned_workspaces|\.persist|std::fs' \
  && falha "a lembrança passou da memória" || ok "a lembrança vive só na sessão, em memória"

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
  { sed -n '/^+fn nome_da_area/,/^+}/p;/^+#\[derive(Debug, PartialEq)\]/,/^+}/p;/^+fn area_na_saida/,/^+}/p;/^+fn lembranca_segue/,/^+}/p;/^+fn indice_da_volta/,/^+}/p;/^+fn saida_da_volta/,/^+}/p' "$PATCH" | sed 's/^+//'
    echo "type FocusTarget = &'static str;"
    echo "struct FocusStacks(std::collections::HashMap<u8, Vec<FocusTarget>>);"
    echo 'impl FocusStacks {'
    sed -n '/^+    pub fn por_baixo/,/^+    }$/p;/^+    pub fn separar/,/^+    }$/p' "$PATCH" | sed 's/^+//'
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
#[test]
fn a_janela_que_volta_fica_por_baixo_de_quem_esta_na_tela() {
    use std::collections::HashMap;
    let mut sai = FocusStacks(HashMap::from([(1, vec!["a", "j", "b"]), (2, vec!["c"])]));
    let janela = sai.separar(|alvo| *alvo == "j");
    assert_eq!(sai.0[&1], ["a", "b"]);
    assert_eq!(sai.0[&2], ["c"]);
    let mut fica = FocusStacks(HashMap::from([(1, vec!["n"])]));
    fica.por_baixo(janela);
    assert_eq!(fica.0[&1], ["j", "n"]);
}
#[test]
fn o_dono_que_muda_de_tela_leva_a_lembranca() {
    assert!(lembranca_segue(true, false));
}
#[test]
fn trocar_de_area_na_mesma_tela_guarda_a_lembranca() {
    assert!(lembranca_segue(false, true));
}
#[test]
fn levar_a_janela_a_outra_tela_apaga_a_lembranca() {
    assert!(!lembranca_segue(false, false));
}
#[test]
fn a_janela_volta_ao_mesmo_indice() {
    assert_eq!(indice_da_volta(1, 2), 1);
    assert_eq!(indice_da_volta(0, 2), 0);
}
#[test]
fn a_area_que_sumiu_nao_cria_area_a_mais() {
    assert_eq!(indice_da_volta(3, 2), 1);
    assert_eq!(indice_da_volta(5, 1), 0);
}
fn casa_com<'a>(lembrada: (&'a str, &'a str)) -> impl Fn(&(&str, &str), bool) -> bool + 'a {
    move |saida, exata| saida.1 == lembrada.1 && (!exata || saida.0 == lembrada.0)
}
#[test]
fn a_mesma_porta_volta() {
    let hdmi = ("HDMI-A-1", "x");
    let saidas = [&("eDP-1", "n"), &hdmi];
    assert_eq!(saida_da_volta(&saidas, &hdmi, casa_com(hdmi)), Some(1));
}
#[test]
fn o_mesmo_monitor_em_outra_porta_volta() {
    let outra = ("DP-1", "x");
    let saidas = [&("eDP-1", "n"), &outra];
    assert_eq!(saida_da_volta(&saidas, &outra, casa_com(("HDMI-A-1", "x"))), Some(1));
}
#[test]
fn entre_gemeos_vale_a_porta() {
    let hdmi = ("HDMI-A-1", "x");
    let saidas = [&("eDP-1", "n"), &("DP-1", "x"), &hdmi];
    assert_eq!(saida_da_volta(&saidas, &hdmi, casa_com(hdmi)), Some(2));
}
#[test]
fn o_gemeo_que_ja_estava_nao_recebe_a_janela() {
    let terceiro = ("DP-2", "y");
    let saidas = [&("eDP-1", "n"), &("DP-1", "x"), &terceiro];
    assert_eq!(saida_da_volta(&saidas, &terceiro, casa_com(("HDMI-A-1", "x"))), None);
}
#[test]
fn abrir_a_tampa_devolve_a_tela_de_fora() {
    let interno = ("eDP-1", "n");
    let saidas = [&("HDMI-A-1", "x"), &interno];
    assert_eq!(saida_da_volta(&saidas, &interno, casa_com(("HDMI-A-1", "x"))), Some(0));
}
#[test]
fn saida_ausente_nao_devolve() {
    let interno = ("eDP-1", "n");
    let saidas = [&interno];
    assert_eq!(saida_da_volta(&saidas, &interno, casa_com(("HDMI-A-1", "x"))), None);
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
