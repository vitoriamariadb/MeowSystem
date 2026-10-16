# P84 — Os PNG feitos à mão viram vetor (decisão 2 de 09/10)

**Branch:** `sprint/p84` · **Pasta:** `packs/dracula/icones/feitos-a-mao/` (39 arquivos; um deles,
`obsidian.png`, já é SVG com nome de PNG).

## Decisão 2
«Entram já como PNG (nada some), e cada um vira vetor num lote desenhado pelo agente e validado por
RMSE contra o PNG; o PNG sai só quando o vetor passa.» Base: «se precisarmos de SVGs novos, pedimos
pro agente criar e validamos».

## Tarefas
1. Para cada PNG: um SVG desenhado à mão (formas, não `<image>` embutido, não traçado automático
   cru), na paleta Dracula do `paleta.json`, viewBox 0 0 128 128, mesmo enquadramento.
2. Validação: renderizar o SVG (rsvg-convert) no tamanho do PNG e medir RMSE contra o PNG (régua do
   BRIEFING de ícones, `feedback-medir-antes-de-afirmar-qual-arte-e-a-boa`); folha de contato
   lado a lado em `.playwright-mcp/ux-p84/`.
3. Passou → SVG entra no lugar, PNG sai, linha no `PROCEDENCIA.md` (origem = o PNG, sha256);
   não passou → PNG fica, e o motivo vai para a tabela da spec.
4. O seletor (P73/P80) passa a oferecer os novos vetores sem a trava de raster.

## Prova
- tabela PNG × SVG × RMSE × veredito; `tests/acervo-da-ficha.sh` e `tests/pack.sh` verdes.

## Resultado — 15/10/2026

**Os 39 passaram: 39 SVG no lugar, 39 PNG fora do pack.** Três desenhistas fizeram 13 cada; a
conferência mediu tudo de novo com uma régua só, olhou a folha de contato e corrigiu 19.

### A régua
- O PNG vai centrado num quadrado do lado maior (o vetor é 1:1); o SVG é renderizado pelo
  `rsvg-convert` no lado do quadrado, com teto de 512 px (o `hplj1020`, de 45 px, mede a 45).
- Os dois são compostos sobre `#282A36` (o fundo do Dracula) e sobre branco, e o RMSE das três
  cores vai de 0 a 1. **Vale o pior dos dois fundos**: um fundo só esconde erro — o escuro some
  com o que é escuro, o branco com o que é transparente.
- Folha de contato: `.playwright-mcp/ux-p84/folha.png` (as 39) e `folha-1` a `folha-4`
  (dez por folha, maiores). Cada linha: PNG e SVG no escuro, PNG e SVG no branco.

### O critério (o do BRIEFING de ícones, com o pior fundo)
1. **Pior RMSE ≤ 0,15 e a folha confirma** silhueta, a família de cor de cada área grande e
   todos os elementos que dão nome ao ícone → passa.
2. **0,15 a 0,20** → passa só se a folha confirma o mesmo **e** o erro tem causa escrita que não
   é forma (textura do PNG, raster pequeno, traço fino). Os quatro desta faixa estão marcados.
3. **Acima de 0,20, ou a folha mostra o ícone com outra cor ou sem um elemento** → não passa:
   redesenho (até duas tentativas) ou o PNG fica.
4. **A cor é a medida no PNG.** A decisão 2 manda medir contra o PNG, e a paleta estrita do
   lote 2 e do lote 3 apagava identidade (o Easy Effects azul virava cinza, o Opera rosa
   empoeirado virava rosa-choque, os laranjas iam a salmão). O lote 1 já usava as cores medidas
   e media melhor; os outros dois foram trazidos para a mesma regra. O `obsidian` e os que
   já batiam ficaram como estavam.

### A tabela

| ícone | lote | PNG | RMSE escuro | RMSE branco | pior | antes da conferência | veredito | o que a conferência mudou ou olhou |
|---|---|---|---|---|---|---|---|---|
| `Tweaks` | 1 | 1024x1024 | 0,035 | 0,023 | **0,035** | = | passa | — |
| `krita` | 1 | 744x700 | 0,034 | 0,037 | **0,037** | = | passa | — |
| `obsidian` | 3 | SVG com nome de PNG | 0,040 | 0,039 | **0,040** | = | passa | — |
| `discord` | 1 | 776x776 | 0,025 | 0,041 | **0,041** | = | passa | — |
| `calendario` | 1 | 1024x1024 | 0,039 | 0,042 | **0,042** | = | passa | — |
| `warehouse` | 1 | 1024x1024 | 0,030 | 0,044 | **0,044** | = | passa | — |
| `Antigravity` | 1 | 874x856 | 0,042 | 0,046 | **0,046** | = | passa | — |
| `opera` | 2 | 1024x1024 | 0,048 | 0,051 | **0,051** | 0,120 | passa | cores medidas (o rosa empoeirado tinha virado rosa-choque, o aro vinho, cinza) |
| `calculadora` | 3 | 1024x1024 | 0,054 | 0,053 | **0,054** | = | passa | — |
| `gparted` | 3 | 1024x1024 | 0,061 | 0,058 | **0,061** | = | passa | — |
| `vscode` | 3 | 800x817 | 0,050 | 0,062 | **0,062** | 0,063 | passa | camadas achatadas e cores medidas |
| `cheese` | 3 | 1500x1124 | 0,063 | 0,051 | **0,063** | 0,090 | passa | camadas achatadas e cores medidas (o laranja tinha ido a pastel) |
| `linux-toys` | 2 | 1024x1024 | 0,072 | 0,072 | **0,072** | 0,165 | passa | cores medidas e aro no raio do PNG |
| `obs-studio` | 1 | 1024x1024 | 0,069 | 0,072 | **0,072** | = | passa | — |
| `dbeaver` | 2 | 1536x1024 | 0,062 | 0,073 | **0,073** | = | passa | — |
| `Easy-Effects` | 2 | 1024x1024 | 0,077 | 0,059 | **0,077** | 0,149 | passa | cores medidas (o azul tinha virado cinza) e aro no raio do PNG |
| `gerenciador-de-extensoes` | 1 | 1024x1024 | 0,078 | 0,078 | **0,078** | = | passa | — |
| `gnome-folder` | 2 | 895x786 | 0,039 | 0,078 | **0,078** | 0,089 | passa | camadas translúcidas achatadas e cores medidas |
| `camera` | 2 | 1024x1024 | 0,048 | 0,079 | **0,079** | 0,116 | passa | cores medidas (o bege tinha virado laranja) |
| `visalizador-de-imagens` | 2 | 1024x1024 | 0,073 | 0,082 | **0,082** | 0,185 | passa | cores medidas e aro no raio do PNG |
| `com.system76.CosmicSettings` | 1 | 1024x1024 | 0,084 | 0,080 | **0,084** | = | passa | — |
| `citrix` | 1 | 1024x1024 | 0,088 | 0,085 | **0,088** | = | passa | — |
| `flatseal` | 3 | 1024x1024 | 0,092 | 0,088 | **0,092** | = | passa | — |
| `gradia` | 1 | 1024x1024 | 0,027 | 0,094 | **0,094** | = | passa | — |
| `whatsapp` | 3 | 823x776 | 0,068 | 0,106 | **0,106** | 0,112 | passa | camadas achatadas e cores medidas (o laranja tinha ido a salmão) |
| `Heroic-Games-Launcher` | 2 | 1024x1024 | 0,107 | 0,092 | **0,107** | 0,151 | passa | cores medidas (o verde-azulado tinha virado violeta) e o disco deslocado voltou ao centro |
| `Clapper` | 3 | 842x868 | 0,055 | 0,111 | **0,111** | 0,113 | passa | cores medidas (o cinza tinha ido a azulado) |
| `FileZilla` | 1 | 1024x1024 | 0,032 | 0,113 | **0,113** | = | passa | — |
| `demo-general2018` | 3 | 962x931 | 0,117 | 0,117 | **0,117** | = | passa | — |
| `gimp` | 1 | 1085x885 | 0,100 | 0,124 | **0,124** | = | passa | — |
| `gerenciador-de-menu` | 2 | 754x767 | 0,077 | 0,124 | **0,124** | 0,175 | passa | cores medidas (o verde tinha virado cinza) e aro no raio do PNG |
| `gimp-48` | 3 | 1085x885 | 0,103 | 0,126 | **0,126** | 0,228 | passa | é a mesma arte do gimp.png: o vetor do gimp mede 0,126 contra ela, e o redesenho próprio, 0,228 |
| `spotify` | 3 | 775x775 | 0,110 | 0,130 | **0,130** | 0,132 | passa | camadas achatadas e cores medidas |
| `weylus` | 2 | 1024x1024 | 0,109 | 0,136 | **0,136** | 0,150 | passa | cores medidas; moldura, hastes e gato redesenhados (o gato era um borrão) |
| `clapper` | 2 | 4096x4096 | 0,102 | 0,144 | **0,144** | 0,207 | passa | cores medidas; corpo e braço alargados até a silhueta do PNG |
| `box-buddy` | 2 | 1024x1024 | 0,136 | 0,154 | **0,154** | 0,159 | passa (faixa 0,15–0,20, olhado) | cores medidas no PNG (o disco verde tinha virado cinza-violeta); o erro é o traço fino do cubo, 2 a 3 px; silhueta e cor batem |
| `firefox` | 2 | 838x853 | 0,111 | 0,164 | **0,164** | 0,325 | passa (faixa 0,15–0,20, olhado) | redesenhado em 2 tentativas: miolo vazado com a borda que esmaece, raposa, lua, e casarão e morcegos como vãos; o esmaecimento com textura do PNG; raposa, lua, casa e morcegos batem |
| `hplj1020` | 3 | 45x45 | 0,165 | 0,147 | **0,165** | = | passa (faixa 0,15–0,20, olhado) | o PNG tem 45 px, borrado; a impressora, a bandeja e a fenda batem |
| `edge` | 3 | 834x880 | 0,079 | 0,177 | **0,177** | 0,202 | passa (faixa 0,15–0,20, olhado) | camadas achatadas e o vermelho puro do PNG (era vinho); os respingos do PNG, que o vetor não copia; forma, rosto e pingos batem |

`antes da conferência` é o mesmo RMSE (pior fundo) do SVG que o desenhista entregou; `=` quer
dizer que ficou como veio.

### O seletor
`acervos_de_icone` (scripts/pack.py) passa a dar duas pastas aos feitos à mão: `feitos-a-mao`,
os vetores, como desenho que se escolhe (o `_alvo_de_escolha` já aceita `.svg` de dentro de um
pack), e `feitos-a-mao-png`, só para PNG que ainda não tenha vetor, ainda travado. No Dracula a
segunda está vazia e some. O gate de navegador cobra que a pasta dos vetores não leve a trava de
raster, e o print `.playwright-mcp/ux-p84/p80-ficha-firefox.png` mostra o vetor do Firefox na
pasta «feitos à mão», escolhível.

### Provas
`tests/acervo-da-ficha.sh` (a ficha oferece 39, o disco tem 39), `tests/pack.sh`,
`tests/fonte-unica.sh`, `tests/pack-malicioso.sh`, `tests/app.sh` e
`tests/app-uso-real.py` (14 páginas e o acabamento, 0 defeito), todos verdes com HOME de
brinquedo e falsos que recusam escrita; `pack.py validar dracula` ok; `pack.py sincronizar
dracula` sem linha órfã (as 39 linhas do PROCEDENCIA.md apontam o `.svg`, com o sha256 dele e o
do PNG de que nasceu).

### Anotado para depois (fora do escopo)
- `clapper.svg` e `Clapper.svg` só diferem na caixa, como já era com os PNG: num sistema de
  arquivos sem distinção de caixa, um esconde o outro.
- O «Levar para o pack» não aparece para os feitos à mão, porque o `_desenhos_do_pack_no_ar`
  lista só `apps/`, a biblioteca e os autorais; a escolha de quem usa funciona.
- `gimp.svg` e `gimp-48.svg` são o mesmo desenho (os dois PNG são a mesma arte).
