# P210 — o clique destrava o acervo (16/11/2026)

Decisão de quem usa, 16/11: «clique destrava». O item travado aparece normal, e o clique destrava e aplica.

## O que se mediu
- `app/servidor.py` `_motivo_da_trava` (≈ linha 8114): trava o traço do app intocável (`INTOCAVEIS` e
  `INTOCAVEIS_PREFIXO` em `scripts/icones_apps_arcticons.sh:29-30`), curado (`assets/icones/curadoria.map`) ou
  convertido (`apps-convertidos.map` e `icones-convertidos.map`). A recusa mora no `_api_app_icone` (≈ 7351).
- `app/servidor.py` `_trava_do_pack` (≈ 6880): trava o desenho do pack nos mesmos intocável e curado, no app
  cujo `.desktop` aponta o ícone por caminho, e no ícone que é de outro passo (`AUTORAL`/`APELIDO` do
  `scripts/completar_icones.sh:27,44`, `BOTOES_DOCK` do `scripts/logo.sh:333`). Recusa no `_escolher_desenho`
  (≈ 7290) e no `_escolher_do_pack`.
- `app/servidor.py` ≈ 7097: o PNG feito à mão ganha a trava «vale no tema quando ganhar a versão em vetor»; o
  `_escolher_desenho` recusa o que não é `desenho` (≈ 7292), porque o passo do pack só põe `.svg`.
- `scripts/pack.py` `trava_de_sistema`/`desenho_de_sistema` (≈ 4923, 4931): no Personalizar, o ícone de Sistema
  herdado de outro tema («vem do tema X») é recusado; os instaladores de tipos de arquivo, sistema e bandeja só
  leem o bloco do mapa, sem desenho por nome no pack que herda.
- `scripts/pack.py` `motivo_para_nao_aprimorar` (≈ 4292), lido em `app/pagina/paginas.js` `motivoDoAprimorar`:
  tema de fábrica fora do checkout, tema de fora da casa de temas, nenhum tema no ar.
- Depois da P204 (conferente), esses itens sumiam (`oficina.js:72`, `paginas.js:625` e os botões do Criar).

## A cura na origem
- Uma lista de quem usa, `icones-destravados.list` ao lado do `meow.conf`: o clique num item travado manda
  `destravar`, o servidor grava o app nela e aplica. A trava ignora quem está na lista, e os passos também:
  `icones_apps_arcticons.sh` (intocável, curadoria, e o convertido do projeto cede ao traço escolhido),
  `completar_icones.sh` e `logo.sh` (o dono de outro passo cede), `icones_absolutos.sh` (o `Icon=` de caminho
  vira o nome do app, para o tema valer).
- PNG feito à mão: o servidor embrulha o PNG num `.svg` na pasta de enviados e grava essa escolha.
- Sistema herdado: o desenho vai para `icones/sistema/<nome>.svg` do tema em edição, e os instaladores de
  sistema, bandeja e tipos de arquivo usam o desenho do pack em edição por nome, antes do bloco herdado.
- `motivoDoAprimorar`: tema de fábrica fora do checkout ou de fora da casa vira cópia na casa de temas, no
  gesto, e o gesto segue nela; sem tema no ar, o gesto guarda um tema novo.

## Decisão
Linha 57 do `docs/DECISOES.md` ganha «clique destrava» (sim de 16/11).

## Como se prova
- Teste de página com HOME temporário: o item travado aparece como botão normal, sem dica de porquê; o clique
  grava o app em `icones-destravados.list` e a escolha no mapa; a segunda leitura do esquema não traz a trava.
- Teste dos passos: com o app na lista, `icones_apps_arcticons.sh` seco não pula o intocável e não acusa
  DUPLO; `completar_icones.sh` não reescreve o autoral destravado.
- Afetados verdes e a suíte inteira.
