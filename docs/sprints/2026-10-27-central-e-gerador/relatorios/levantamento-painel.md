# Levantamento do painel e do gerador (itens 1 a 9 e o rabo da QA final)

Medido em 27/10/2026, na branch `dev` (`69ebd802`).
- Navegador: Playwright headless (`~/.local/share/meowsystem/venv-testes/bin/python3`), numa casa de teste montada pelo `tests/app-completo.py`, com HOME temporário e cópia só dos arquivos rastreados.
- Capturas: `capturas/painel/`.
- Nada de código mudou; só estes `.md` foram escritos.

Sprints que saem daqui:

| sprint | área | itens |
|---|---|---|
| `P115-gerador-de-icones.md` | gerador (conversor e oficina) | 7, 8, 9 |
| `P116-previa-e-biblioteca-do-pack.md` | o que o pack mostra | 1, 2 |
| `P117-paridade-dracula.md` | packs | 3 |
| `P118-vocabulario.md` | textos | 4, 6 |
| `P119-programas-e-pendencias-velhas.md` | Definir, Manter, limpeza | 5 e o rabo da QA final |

Arquivos disjuntos entre si, salvo dois pares:
- P116 e P119 encostam em `tests/app-completo.py`, em blocos diferentes;
- P118 e P116 encostam em `app/pagina/paginas.js`; a P118 só troca rótulos.

Ordem sugerida: P115 e P117 juntas, depois P116 e P119, e a P118 por último, porque ela troca textos que as outras tocam.

## 1. A prévia do Tema é a mesma nos dois packs (item 1)
- **Medido** (`tema-1920.png`):
  - os seis SVG do dock têm `innerHTML` de 223, 582, 251, 437, 209 e 172 caracteres nos cartões `dracula` e `meowsystem`;
  - a pasta tem o mesmo hash nos dois;
  - só o mascote difere (`/pack-vitrine?id=dracula&arte=mascote` contra `/previa?tipo=gato&id=coquinha`).
- **Causa:** `app/pagina/mesa.js` tem `ICONES` e `PASTA` fixos (contornos do Arcticons). `_cartoes_de_pack()` (`app/servidor.py`, perto da linha 620) não manda ícone do pack.
- **Cura e prova:** P116.

## 2. Dracula × MeowSystem, pasta por pasta (item 3)
| o quê | meowsystem | dracula | estado |
|---|---|---|---|
| ícones de app | 82 desenhos, `apps*.map` (5 mapas) | 140 desenhos + 85 resgatados, `apps.map` (496 linhas) | ok, cada um com o seu |
| biblioteca | 36 (traço, `currentColor`) | 480 | ok; a do meowsystem fica ilegível na tela (§4) |
| sistema (tipos de arquivo) | 688 SVG | herda o molde do meowsystem, pintado com a paleta dele (`icones.mimetypes.herda`) | ok, de propósito (P96) |
| pastas | `pastas.map` + acervo | `pastas.map` (32 linhas) + 10 desenhos | ok |
| bandeja e status | `bandeja.map` (322), `sistema.map` (191) | nenhum | **buraco**: os quatro scripts leem `packs/meowsystem` fixo e rodam em todo pack (P117) |
| gerador | `traco` | `circle` + `autorais.gerar` | ok |
| mascote | 3 (mimir, coquinha) | 3 (morcego-dia, morcego-noite, morcego) | ok |
| papéis de parede | baixa do `zhichaoh/catppuccin-wallpapers` com curadoria `FONTES.tsv` (5 locais) | 14 locais em 4 pastas + `repo_do_conf` | ok, formas diferentes |
| sons | 28, com `PROCEDENCIA.md` | 27, com `License.txt` | ok (nenhum idêntico, cada um tem o seu) |
| temas de apps | mesmos 11 apps declarados | mesmos 11 | ok |
| conteúdo dos temas de apps | 140 arquivos | 7 arquivos | ok: o Heroic do Dracula é o embutido e o Obsidian vem por URL + sha256 |
| VS Code ícones | `vscode-icones` | nenhum, de propósito | ok (`_nota_vscode_icones`) |
| fontes | `fontes/` (JetBrainsMono) | herda | ok |
| licenças | `licencas/` (arcticons, cursores, vscode-icons) | `PROCEDENCIA.md` | ok para o que ele traz |
| temas capturados | 3 | 3 | ok |
| flavors | 4 (claro: latte) | 2 (claro: alucard) | ok |
| ponteiro | herda | `origens.cursores` pinado (Dracula-cursors v4.0.0) | **resto morto**: `origens.cursores.tema: "catppuccin-mocha-light"`, que ninguém lê (P117) |
| prévia no painel | ícones fixos | os mesmos ícones fixos | **buraco** (§1, P116) |

## 3. O gerador visto por quem desenha (itens 7, 8 e 9)
Capturas: `gerador-regua.png` e `moldura-hoje-e-com-folga.png`; fotos 4 e 5.

### 3.1 Erros (P115)
1. **A barra fica no meio.** O `--p` das quatro réguas sai vazio, ao abrir e depois de mover o controle. Causa: `oficina.js:oficinaDeDesenho()`, na `regua()`, e o `r-glifo`.
2. **A moldura abre.**
   - Causa: `converter_icone.py:segmentos()`, cuja `moldura()` descarta o contorno que está na borda da imagem.
   - No Cherry Studio sobram 4 cantos soltos.
   - No quadrado laranja de brinquedo, a conversão dá `0 traços` e os cinco cartões saem vazios.
   - 7 de 19 ícones instalados encostam na borda.
   - Com 6 px de folga transparente o retângulo fecha (capturado).

### 3.2 Uso, por ordem de ganho
1. «Desfazer edição» perde a pilha a cada troca de traço (`escolherCartao()`, `OFICINA.historico = []`, `oficina.js:440`). Vai na P115.
2. Não há «Refazer». Vai na P115.
3. O `desenhar()` força `stroke-width="2.25"` (`oficina.js`). Não há como pedir traço mais fino ou mais grosso, e o ícone fino da casa sai do jeito que o conversor quer. Anotado.
4. A lupa não tem grade nem keyline do viewBox de 48. Não se vê se o desenho respira igual aos outros do pack. Anotado.
5. Raramente se edita o SVG cru na caixa de texto. Ela ocupa o meio da ficha e empurra o «Usar» para baixo. Anotado: recolher por padrão.
6. O gerador circle (Dracula) tem menos ajustes que o de traço (só disco, aro, tinta, tamanho). Anotado.
7. Não há consistência em lote: aplicar o mesmo ajuste nos apps que ainda não têm desenho do pack. Anotado.

### 3.3 Integração que escapou
- O mesmo `--p` faltante no `r-glifo` do circle: vai na P115.
- A aba «Do acervo» da ficha mostra glifos crus, escuros no escuro (`conferencia-b.md`). Entra na P116 se usar o mesmo caminho.

## 4. A Biblioteca ilegível (item 2)
- **Medido** (`biblioteca-1920.png`, `biblioteca-um-icone.png`):
  - são 36 `<img src="/previa?tipo=arquivo&id=…/biblioteca/…">`;
  - a luminância do ícone vai de 2 a 31, com média 28, num cartão `rgb(30, 30, 46)`.
- **Causa:** `scripts/pack.py:acervo_para_levar()` dá `svg=None` à biblioteca, e o SVG traz `stroke="currentColor"`, que dentro de `<img>` é preto.
- **Cura e prova:** P116.

## 5. Vocabulário (itens 4 e 6)
Trocas decididas:
- «Mandar» → «Disponibilizar»;
- «Vestir agora» → «Aplicar tema».

As outras seguem a regra da P118:
- *vestir* → aplicar;
- *veste* → usa;
- *vestido de* → com o;
- *nada a vestir* → nada a aplicar.

Identificadores, valores de `data-controle` e a rota `#criar/mandar` ficam.

Testes que conferem o texto:
- `tests/pastas-do-pack.sh:119`;
- `tests/temas-de-apps.sh:1287`;
- `tests/instalacao.sh:211`;
- `tests/p113-navegador.py:116-119`.

A guarda nova vai em `tests/frases-velhas.sh`. A fonte do README é `docs/readme.toml:15`.

Lista completa, gerada por `git grep` (as formas de *vestir* e «Mandar», sem *vestígio*, só onde chega à tela). Está no apêndice ao fim deste relatório.

## 6. Definir → Programas (item 5)
- **Medido** (`programas-1920.png`):
  - os dois campos têm 160 px, e o texto de exemplo aparece cortado em «Procurar um prog»;
  - a lista é um `<datalist>` nativo.
- **Causa:** `app.js:controleLista()` e `estilo.css:211`. O combobox da maquete aprovada não foi portado, e o CSS dele (`estilo.css:655-659,712-713`) está lá sem uso.
- **Cura e prova:** P119.

## 7. O rabo da QA final
| item | medido | causa | sprint |
|---|---|---|---|
| `spicetify-tema-ausente` sem nome nem «Resolver» | o id falta em `ACAO_DA_PENDENCIA` e `NOME_DA_PENDENCIA` (`servidor.py:4296-4323`) | P109 e P113 | P119 |
| «Regravar o som» deixa «Restaurar» vazio | `som.sh:177` guarda a pasta antes de comparar | `_som_tema()` | P119 |
| citações a `docs/pesquisas/` | 6 arquivos rastreados; a ponta de `arquivo` não tem a pasta; o texto vive em `1b15ccb1^` | P96 | P119 |
| ganchos velhos em `.git/hooks` | 13 `.bak-*` e `.antes-*`, que não rodam (`core.hooksPath` = `~/.config/git/hooks`) | cópias locais | P119, com a palavra dela |
| imagens sem referência | `desktop-claro.png`, `fastfetch.png`, `lancador.jpg`, desde `32ad49d5`, sem citação fora de `docs/sprints/` | decisão 24 | P119 |

## Perguntas para ela (cada uma com a minha recomendação)
1. **Moldura no gerador.** Com a folga, todo ícone que encosta na borda ganha o contorno fechado, e um quadrado opaco vira um quadrado em vez de nada. Fica assim sempre, ou entra um botão «Moldura: com / sem»? Recomendo sempre fechada, sem botão: um traço solto nunca é o que se quer, e tirar o contorno de fora já se faz clicando nele.
2. **Bandeja e status no Dracula.**
   - Hoje eles são os Arcticons do MeowSystem.
   - Opção A: a camada-base pinada (`dracula-icons`) cuida deles.
   - Opção B: herdar o molde do MeowSystem pintado com a paleta Dracula, como os tipos de arquivo.
   - Recomendo medir primeiro a base. Se ela cobre os nomes do `sistema.map`, fica a A, que não traz o traço do outro pack. Se não cobre, fica a B.
3. **Botão do Tema.** O cartão do pack diz «Vestir». Passa a «Aplicar tema», igual ao do Personalizar, ou só «Aplicar»? Recomendo «Aplicar tema» nos dois, porque é a mesma ação (`pack_usar`).
4. **Ganchos `.bak` em `.git/hooks`.** São só desta máquina e não rodam. Apago? Recomendo apagar as 13 cópias e deixar os `.sample`.

## Anotado para depois
- Gerador:
  - controle de espessura do traço (o `desenhar()` força 2.25);
  - grade e keyline na lupa;
  - caixa do SVG cru recolhida por padrão;
  - os ajustes do gerador circle no nível do de traço;
  - ajuste em lote para os apps sem desenho do pack;
  - exportar o SVG da ficha.
- `_HEROIC_ORIGEM` fixo em `packs/meowsystem` (`scripts/temas-de-apps/heroic/manifesto.sh:5`), que só pesa num pack de terceiro.
- Comentário `# POR QUE ESTE ARQUIVO EXISTE` em `assets/contratos/cosmic.tsv:3`, contra a regra de zero comentário.
- Rota `#criar/mandar` e `data-controle` com *vestir*: trocar junto com os testes que os usam, se ela quiser a URL no vocabulário novo.
- Capturas do README (`docs/capturas/readme/*.png`) mostram «Vestir» e «Mandar» até o gancho refazê-las.
- Manuais: `docs/PACKS.md:1315,1358,2407` e `docs/ESTADO-FINAL.md:77` citam o rótulo «Vestir».

## Apêndice: termo → troca, arquivo por arquivo

| arquivo:linha | trecho | troca |
|---|---|---|
| `app/LEIA-ME.md:12` | `meow-painel.service`). `apps`, no plural, são os programas que o projeto veste; `app` é este. | usa |
| `app/LEIA-ME.md:36` | \| **Tema** \| um cartão por pack instalado: logo, paleta, o que é próprio e o que herda. **Vestir**, **Remove… | **Aplicar tema** |
| `app/LEIA-ME.md:37` | \| **Personalizar** \| os passos Cores, Ícones, Papel de parede, Sons e Mandar (**Baixar o tema**) \| | Disponibilizar |
| `app/pagina/lugares.js:15` | { a: "pack_usar", r: "Vestir", b: "Vestir" }, | Aplicar tema |
| `app/pagina/lugares.js:66` | { id: "mandar", nome: "Mandar", | Disponibilizar |
| `app/pagina/lugares.js:69` | { a: "pack_usar", r: "Vestir", b: "Vestir" }, | Aplicar tema |
| `app/pagina/lugares.js:235` | { a: "apps_aplicar", r: "Vestir agora", b: "Vestir" }, | Aplicar agora / Aplicar |
| `app/pagina/oficina.js:21` | aviso: r.aviso \|\| "", escolha: r.escolha \|\| null, minha: r.minha \|\| null, veste: r.veste \|\| null }; | fica (identificador) |
| `app/pagina/paginas.js:102` | previa.addEventListener("click", () => vestir(p, p.no_ar ? null : flavor)); | fica (identificador) |
| `app/pagina/paginas.js:107` | direita.push(botao("Vestir", { class: "bt principal", controle: "pack:" + p.id + ":vestir", | Aplicar tema (rótulo; o `controle` fica) |
| `app/pagina/paginas.js:108` | dica: primeiraFrase((ACAO.get("pack_usar") \|\| {}).ajuda), onclick: () => vestir(p, flavor) })); | fica (identificador) |
| `app/pagina/paginas.js:618` | function passoMandar() { | fica (identificador) |
| `app/pagina/paginas.js:639` | disabled: pouco, "aria-disabled": pouco ? "true" : null, dica: dica \|\| "Um .meowpack para mandar", | Um .meowpack para outra máquina |
| `app/pagina/paginas.js:641` | botao("Vestir agora", { class: "bt", icone: "tema", controle: "criar:vestir", | Aplicar tema (rótulo; o `controle` fica) |
| `app/pagina/paginas.js:659` | : sub === "sons" ? passoSons() : sub === "mandar" ? passoMandar() : passoCores(); | fica (identificador) |
| `app/servidor.py:747` | "vestindo o lançador." % (nome_pack, ap["nome_de"])) | no lançador |
| `app/servidor.py:749` | item["frase"] = ("Os desenhos de aplicativo do pack «%s», vestindo o lançador." | no lançador |
| `app/servidor.py:753` | "este ajuste não tem o que vestir." % nome_pack) | não tem o que aplicar |
| `app/servidor.py:3395` | "rotulo": "Programas vestidos", | Programas com o tema |
| `app/servidor.py:3403` | "rotulo": "Vestir os programas", | Aplicar nos programas |
| `app/servidor.py:6434` | "veste": self._o_que_veste(app) if app_ok else None} | fica (chave do JSON) |
| `app/servidor.py:7299` | return ("%s veste %s. %s na oficina «Gerar ícone», acima: %s." | %s usa %s |
| `bin/meow:473` | cauda="o pack no ar (${nome:-?}) veste o '$tema', que o Heroic já traz, e sem arquivo não passa por aí" | usa / aplica |
| `bin/meow:474` | pesa="o pack no ar (${nome:-?}) veste o '$tema', que o Heroic já traz e não passa por essa linha — ela pesa nu… | usa / aplica |
| `bin/meow:2084` | [ "$det" = 0 ] && [ -n "$motivo" ] && t_tema="não veste" ;; | não aplica |
| `bin/meow:3173` | printf '                   o pack num arquivo só, para mandar a alguém\n' | para passar a alguém |
| `lib/preflight.sh:29` | meow_erro "isto veste o COSMIC, e o COSMIC não está rodando aqui" | isto arruma o COSMIC |
| `lib/preflight.sh:97` | "btop\|extra\|btop\|monitor vestido pelo tema" | aplicad(o/a/os/as) / com o tema |
| `lib/preflight.sh:98` | "batcat\|extra\|bat\|o cat colorido vestido pelo tema" | aplicad(o/a/os/as) / com o tema |
| `lib/preflight.sh:102` | "cosmic-term\|extra\|-\|o terminal que este projeto veste (vem com o COSMIC)" | usa / aplica |
| `lib/preflight.sh:207` | motivos+=("vestir a tela de login em /var/lib/cosmic-greeter") | aplicar |
| `scripts/completar_icones.sh:162` | meow_ok "$retirados desenho(s) autorais retirados — quem veste os oito agora é o Arcticons" | usa / aplica |
| `scripts/construir_pastas.sh:153` | _vestido="$(meow_flavor_vestido 2>/dev/null)" | fica (identificador) |
| `scripts/construir_pastas.sh:155` | "cat-$_fl-"?*) [ -n "$_fl" ] && [ -n "$_vestido" ] && [ "$_vestido" != "$_fl" ] \ | fica (identificador) |
| `scripts/construir_pastas.sh:156` | && COR="cat-$_vestido-${COR#"cat-$_fl-"}" ;; | fica (identificador) |
| `scripts/converter_icone.py:796` | "para o TRACO do icones_apps_arcticons.sh mandar)") | fica (sentido de «o que o arquivo manda»/ajuda interna) |
| `scripts/cursor.sh:455` | meow_aviso "o cursor do desktop continuará o que esse arquivo mandar." | fica (sentido de «o que o arquivo manda»/ajuda interna) |
| `scripts/files_menu.sh:59` | [ -n "$ver" ] \|\| { meow_pula "o cosmic-files não está instalado por pacote — nada a vestir"; return "$MEOW_S… | nada a aplicar |
| `scripts/files_menu.sh:97` | meow_ok "menu de contexto vestido: avançar e voltar papel de parede ($ver)" | aplicad(o/a/os/as) / com o tema |
| `scripts/flatpak_tema.sh:23` | printf '  aplicar   o override do Flatpak do usuário veste o tema do pack no ar\n' | usa / aplica |
| `scripts/flatpak_tema.sh:127` | local modo="$1" par args=() e vestido="" | fica (identificador) |
| `scripts/flatpak_tema.sh:128` | meow_tem flatpak \|\| { meow_pula "sem flatpak — nenhum app a vestir"; return "$MEOW_OK"; } | nada a aplicar |
| `scripts/flatpak_tema.sh:136` | for par in "${FT_CHAVES[@]}"; do [ -n "${DESEJO[$par]:-}" ] && vestido+="${vestido:+, }${DESEJO[$par]}"; done | fica (identificador) |
| `scripts/flatpak_tema.sh:137` | meow_ok "apps Flatpak vestem $vestido" | aplicad(o/a/os/as) / com o tema |
| `scripts/flatpak_tema.sh:157` | meow_muda "apps Flatpak vestem o tema do pack: ${args[*]#--}" | usam |
| `scripts/flatpak_tema.sh:178` | meow_tem flatpak \|\| { meow_pula "sem flatpak — nenhum app a vestir"; return "$MEOW_OK"; } | nada a aplicar |
| `scripts/greeter.sh:148` | meow_muda "vestiria a tela de login com '$ALVO' (${#pendentes[@]} arquivo(s))" | aplicaria |
| `scripts/greeter.sh:154` | meow_muda "tela de login vestida com '$ALVO' (${#pendentes[@]} arquivo(s), pela ponte)" | aplicad(o/a/os/as) / com o tema |
| `scripts/greeter.sh:159` | meow_aviso "a ponte recusou vestir a tela de login (${motivo:-ela não disse por quê})" | aplicar |
| `scripts/icones_apps_arcticons.sh:22` | FLAVOR="$(meow_flavor_vestido)" \|\| { | fica (identificador) |
| `scripts/icones_apps_arcticons.sh:257` | meow_pula "sem packs/meowsystem/icones/apps-arcticons.map — nada a vestir" | nada a aplicar |
| `scripts/icones_apps_arcticons.sh:261` | meow_pula "sem $(meow_paleta_nome) — sem fonte de cor, nada a vestir" | nada a aplicar |
| `scripts/icones_apps_arcticons.sh:314` | elif [ "$(_vestido "$arte" "${TRACO[$dir]}" "${HEX[${COR[$nome]}]}")" != "$(cat "$alvo")" ]; then | fica (identificador) |
| `scripts/icones_apps_arcticons.sh:329` | meow_ok "$total aplicativo(s) já vestidos em traço ($FLAVOR)" | com o |
| `scripts/icones_apps_arcticons.sh:342` | "$(_vestido "$arte" "${TRACO[$dir]}" "${HEX[${COR[$nome]}]}")" 644 | fica (identificador) |
| `scripts/icones_apps_arcticons.sh:370` | meow_ok "aplicativos já vestidos em traço ($FLAVOR)" | com o |
| `scripts/icones_bandeja.sh:63` | meow_pula "o acervo Arcticons não está em packs/meowsystem/icones/sistema — nada a vestir" | nada a aplicar |
| `scripts/icones_bandeja.sh:67` | meow_pula "sem packs/meowsystem/icones/bandeja.map — nada a vestir" | nada a aplicar |
| `scripts/icones_bandeja.sh:108` | printf '%s linha(s) no mapa e nenhum glifo em packs/meowsystem/icones/sistema — nada a vestir' "${#MAPA_LIDO[@… | nada a aplicar |
| `scripts/icones_bandeja.sh:110` | printf '%s ícone(s) da bandeja já vestidos de Arcticons' "$total" | com o |
| `scripts/icones_mimetypes.sh:49` | meow_pula "não há acervo de mimetype para o flavor '$FLAVOR_ICONES' — nada a vestir" | nada a aplicar |
| `scripts/icones_mimetypes.sh:53` | meow_pula "o pack não traz mapa de mimetype (icones.mimetypes.mapa) — nada a vestir" | nada a aplicar |
| `scripts/icones_mimetypes.sh:90` | meow_ok "$total tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES" | com o |
| `scripts/icones_mimetypes.sh:129` | meow_ok "tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES" | com o |
| `scripts/icones_pastas.sh:62` | meow_pula "não há acervo de pasta para o flavor '$FLAVOR_ICONES' — nada a vestir" | nada a aplicar |
| `scripts/icones_pastas.sh:66` | meow_pula "sem packs/meowsystem/icones/pastas.map — nada a vestir" | nada a aplicar |
| `scripts/icones_pastas.sh:116` | meow_ok "$total pasta(s) especiais já vestidas $VESTIDAS" | aplicad(o/a/os/as) / com o tema |
| `scripts/icones_pastas.sh:155` | meow_ok "pastas especiais já vestidas $VESTIDAS" | aplicad(o/a/os/as) / com o tema |
| `scripts/icones_sistema.sh:48` | meow_pula "o acervo Arcticons não está em packs/meowsystem/icones/sistema — nada a vestir" | nada a aplicar |
| `scripts/icones_sistema.sh:52` | meow_pula "sem packs/meowsystem/icones/sistema.map — nada a vestir" | nada a aplicar |
| `scripts/icones_sistema.sh:99` | meow_ok "$total ícone(s) do sistema já vestidos de Arcticons" | com o |
| `scripts/icones_sistema.sh:139` | meow_ok "ícones do sistema já vestidos de Arcticons" | com o |
| `scripts/icones_tray_steam.sh:118` | meow_pula "sem o glifo steam em packs/meowsystem/icones — nada a vestir" | nada a aplicar |
| `scripts/icones_tray_steam.sh:122` | meow_pula "a Steam não está instalada (sem $RELATIVO) — nada a vestir" | nada a aplicar |
| `scripts/icones_tray_steam.sh:163` | meow_ok "o ícone da bandeja da Steam está vestido de Arcticons" | com o |
| `scripts/icones_tray_steam.sh:177` | meow_ok "o ícone da bandeja da Steam está vestido de Arcticons" | com o |
| `scripts/icones_tray_steam.sh:205` | meow_info "ícone da bandeja da Steam: vestido de Arcticons (traço $TRACO, $COR)" | com o |
| `scripts/icones_tray_zapzap.sh:54` | meow_pula "não existe $GLIFO — nada a vestir" | nada a aplicar |
| `scripts/icones_tray_zapzap.sh:62` | meow_pula "$APP_ID não está instalado — nada a vestir" | nada a aplicar |
| `scripts/icones_tray_zapzap.sh:130` | print('FABRICA'); print('o bloco _SYMBOLIC e o de fabrica e da para vestir'); sys.exit(0) | fica (protocolo interno do passo) |
| `scripts/icones_tray_zapzap.sh:158` | print('ESCRITO'); print('bloco _SYMBOLIC vestido e hardlink do OSTree quebrado') | fica (protocolo interno do passo) |
| `scripts/icones_tray_zapzap.sh:181` | meow_ok "o ícone da bandeja do ZapZap segue vestido de Arcticons" | com o |
| `scripts/icones_tray_zapzap.sh:208` | meow_ok "o ícone da bandeja do ZapZap já estava vestido" | aplicad(o/a/os/as) / com o tema |
| `scripts/icones_tray_zapzap.sh:211` | meow_muda "ícone da bandeja do ZapZap revestido de Arcticons" | refeito com |
| `scripts/icones_tray_zapzap.sh:216` | meow_info "  nada foi escrito — é código Python, e vestir às cegas quebraria o app" | aplicar |
| `scripts/icones_tray_zapzap.sh:220` | meow_erro "${motivo:-não consegui vestir $alvo}" | aplicar |
| `scripts/logo.sh:314` | 2) meow_erro "não consegui vestir o botão do dock com $_b"; exit "$MEOW_ERRO" ;; | aplicar |
| `scripts/pack.py:2474` | f"{p['id']!r} é o pack-base: todo pack herda dele, e ele não se veste sozinho") | usa / aplica |
| `scripts/pack.py:2724` | if a.endswith(".svg") and os.path.isfile(caminho) and _sha(caminho) not in vestidos: | fica (identificador) |
| `scripts/pack.py:3854` | print(f"       Para vestir: PACK=\"{ident}\" e FLAVOR=\"{r['flavor_padrao']}\" no meow.conf.") | aplicar |
| `scripts/pack.py:4539` | cabeca = ["# icones/apps.map — que desenho de icones/apps/ veste cada aplicativo.", | fica (cabeçalho de dado do pack) |
| `scripts/temas-de-apps/heroic/manifesto.sh:23` | _HEROIC_MOTIVO="Heroic: sem tema neste pack ($nome) — o que a herança traz é o '${MEOW_APP_TEMA//<accent>/$_HE… | usa / aplica |
| `scripts/temas-de-apps/heroic/manifesto.sh:300` | meow_ok "Heroic vestido de $tema, o tema que o próprio Heroic traz — a janela mostra na próxima vez que abrir" | com o |
| `scripts/temas-de-apps/heroic/manifesto.sh:334` | meow_ok "Heroic vestido de $tema — a janela mostra na próxima vez que abrir" | com o |
| `scripts/temas-de-apps/obsidian/filtro_git.py:44` | if len(argv) == 2 and argv[1] == "vestir": | fica (identificador) |
| `scripts/temas-de-apps/obsidian/filtro_git.py:49` | sys.stderr.write("uso: filtro_git.py vestir \| limpar <caminho>\n") | fica (identificador) |
| `scripts/temas-de-apps/obsidian/manifesto.sh:126` | meow_app_sem "obsidian: sem tema neste pack ($_OBS_PACK_NOME) — o que a herança traz é o '$MEOW_APP_TEMA', do … | usa / aplica |
| `scripts/temas-de-apps/obsidian/manifesto.sh:250` | local modo="$1" tema="${2:-}" cofre raiz rel attrs linha filtro limpar vestir | fica (identificador) |
| `scripts/temas-de-apps/obsidian/manifesto.sh:261` | vestir="python3 '$filtro' vestir" | fica (identificador) |
| `scripts/temas-de-apps/obsidian/manifesto.sh:266` | && [ "$(git -C "$raiz" config --local --get filter.meow-obsidian.smudge 2>/dev/null)" = "$vestir" ] \ | fica (identificador) |
| `scripts/temas-de-apps/obsidian/manifesto.sh:282` | && git -C "$raiz" config --local filter.meow-obsidian.smudge "$vestir" \ | fica (identificador) |
| `scripts/temas-de-apps/qbittorrent/manifesto.sh:42` | "O qBittorrent é configurado por outro projeto seu, cuja lista de temas é fechada — enquanto o tema '$MEOW_QBT… | aplicar / Aplicar tema |
| `scripts/temas-de-apps/qbittorrent/manifesto.sh:123` | meow_pula "qBittorrent: já está vestido com '$no_ar', que não veio daqui — o tema do pack não é escrito por ci… | aplicad(o/a/os/as) / com o tema |
| `scripts/temas-de-apps/vscode/manifesto.sh:429` | meow_app_sem "VS Code: sem tema neste pack ($_MEOW_VSCODE_PACK_NOME) — o que a herança traz é o '$MEOW_APP_TEM… | usa / aplica |
| `scripts/temas-de-apps/zapzap/manifesto.sh:226` | meow_seco \|\| meow_ok "ZapZap: o WhatsApp veste o tema do pack (do pack $_ZZ_CSS_DE) — $_ZZ_CSS_QUERO (vale q… | usa / aplica |
| `scripts/temas-de-apps/zapzap/manifesto.sh:276` | meow_info "balão verde retirado de scalable/apps — quem veste é o apps-arcticons.map" | usa / aplica |
| `scripts/temas-de-apps/zapzap/manifesto.sh:371` | meow_info "o ícone da bandeja segue vestido na FONTE do app (tray_icon.py do flatpak)" | aplicad(o/a/os/as) / com o tema |
| `scripts/terminal.sh:301` | meow_pula "cosmic-term não está instalado — nada a vestir" | nada a aplicar |
| `scripts/terminal.sh:358` | [ "$tipo" = "light" ] && meow_info "  e o flavor claro sai de \"claros\" — um pack sem flavor claro não veste … | usa / aplica |
| `scripts/terminal.sh:475` | meow_ok "terminal vestido: $(_nome_esquema "$FLAVOR_ESCURO") no escuro, $(_nome_esquema "$FLAVOR_CLARO") no cl… | aplicad(o/a/os/as) / com o tema |
| `install.sh:952` | passo "Flatpak veste o tema" | usa / aplica |
| `install.sh:2044` | falta)  meow_info "greeter: a tela de login veste o tema do COSMIC, e ele não tem captura — não é falta de roo… | usa / aplica |

