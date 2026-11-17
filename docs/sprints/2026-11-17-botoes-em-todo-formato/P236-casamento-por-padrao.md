# P236 — o casamento de janela por padrão: no dock e no mapa (17/11/2026)

Texto de quem usa, 17/11, sobre o P235: «não conseguimos adicionalmente melhorar o regex não?». Escolha
(AskUserQuestion, 17/11): «Os dois» (patch no dock e padrões no mapa).

## O que se mediu
- O `cosmic-app-list` casa a janela com o `.desktop` por igualdade de string inteira, sem normalização (medido em
  27/08, escrito no cabeçalho de `assets/apps/appid.map`). Janela de sistema com id derivado
  (`com.system76.CosmicFilesDialog`) cai na engrenagem.
- O `appid.map` só aceita app_id exato e medido; a ponte só nasce para janela já vista.

## A cura na origem
### Parte 1 — o dock (bloco I, `.meow-wt-dock` / `bloco/dock`)
Patch no `cosmic-app-list` (repositório `pop-os/cosmic-applets`, na versão que esta máquina roda), no molde dos
patches que o MeowSystem já mantém (`patches/series`, `patches/versao`, `patches/graficos.series`, o shim e a
etapa de build que o `bin/meow` e o `install.sh` já usam; leia como a build do compositor e a dos aprimoramentos
gráficos são feitas, e se a regra do registro manda «correção de outro assunto cria a sua build», crie a build do
dock separada). Comportamento: quando o casamento exato falha, uma segunda tentativa, em ordem:
1. o mesmo id sem diferenciar maiúscula;
2. o id sem um sufixo de papel conhecido (`Dialog`, `Portal`, `Prompt`, `Prompter`, `Helper`, `Agent`, com ou sem
   `.`/`-` antes);
3. o `.desktop` cujo id é o prefixo de domínio reverso mais longo do app_id (só se houver exatamente um).
Nunca troca um casamento exato que já existe. Com o patch fora (build caída), tudo volta ao comportamento de fábrica.

### Parte 2 — o mapa (depois do P235, no `bloco/janelas`)
Linhas de padrão no `appid.map` (forma escrita no cabeçalho, ex.: `~com\.system76\.Cosmic(.+)Dialog:com.system76.Cosmic\1`),
aplicadas pela sonda aos app_id medidos e aos sugeridos pelo varrimento do P235, gerando a ponte exata para cada id
concreto. Linha exata vence padrão; dois padrões no mesmo id é erro em voz alta.

## Como se prova
- Dock: teste de unidade do casamento no próprio patch (`cargo test` na árvore com o patch) e teste no MeowSystem
  de que a série aplica limpa na versão fixada; na máquina (coordenador, depois do install): o diálogo de arquivos
  com o ícone do Gestor de Arquivos SEM linha no mapa.
- Mapa: teste com HOME temporário e a sonda falsa: padrão gera a ponte, exato vence padrão, conflito estoura,
  segunda passada não escreve.
