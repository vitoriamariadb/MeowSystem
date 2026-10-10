# P80 — Acabamento do uso real final (10/10)

**Branch:** `sprint/p80` (a partir de `integracao/leva-g` depois da P79) · **Fonte:** meu uso real
final, como usuário, na integração (prints em `.playwright-mcp/ux-final/`).

## O que vi
1. **Ficha de ícone — nomes técnicos cortados** (`05`, `06`): `net.waterfo…`, `org.gnome.…`,
   `005-potion`. Cura: rótulo amigável (nome do app pelo comentário do `apps.map` ou pelo `.desktop`;
   descrição pt-BR do `catalog.json` para a biblioteca), nome inteiro e origem só na dica.
2. **Ficha de ícone — a paleta «COR» aparece sempre** e só vale para desenho de traço. Cura: a
   paleta nasce quando um traço está selecionado (show, don't tell).
3. **Ficha de ícone — PNG feito à mão aparece apagado** com um selo de sentido obscuro (`06`). Cura:
   se pode usar, aparece normal; se não pode naquele app, o porquê na dica e o selo é o mesmo da
   trava das outras pastas.
4. **Dia e noite** (`07`): «O tema claro termina/começa» usa deslizante pontilhado («como está: 18»)
   enquanto as outras duas linhas usam seletor de hora, e a ordem é invertida (termina à esquerda).
   Cura: o mesmo seletor de hora e a mesma ordem (começa | termina) nas três linhas.
5. **Cabeçalho de página inconsistente**: a fileira «Fundo» (Escuro / Vidro escuro / Vidro claro /
   Claro) aparece em Ícones, Cor e tela, Logo, Papel de parede e some em Dia e noite e outras. Cura:
   uma regra só (ou em toda página, ou só em uma, a de Cor e tela).

## Prova
- prints antes/depois de cada item em `.playwright-mcp/ux-p80/`; `tests/app-uso-real.py` ganha um
  caso por item (vermelho antes, verde depois); suíte inteira verde.

## Abertos da P79 que entram aqui (`04-integracao-onda-2.md`, seção P79)
6. **Corrida do `Trabalho.vivo()`** (`app/servidor.py`): responde por `proc.poll()` antes de a thread
   `_ler` gravar `rc`/`fim`; a página recebe `vivo: false, rc: null` («SAIU NULL · 0S») e o gate fica
   intermitente. Cura na origem: `vivo()` responde por `self.fim is None`. Teste que força a janela.
7. **A instalação recicla o painel até três vezes** (arcticons, dracula, resgatados chamam
   `meow_tela_reler` cada um). Um reciclo do `cosmic-panel` foi o gatilho da faixa verde de 09/10
   (`Migração-OS/levas/leva-08-gpu-regressao.md`). Cura: um reler só, no fim da passada (marcar
   «precisa reler» e reler uma vez), e o `painel.sh reciclar` registra quem o chamou.
8. **Ainda mandam digitar**: o «resolve: <comando>» das pendências (vira o botão que resolve), o
   `meow wallpaper permitir`, o «instale com rustup…» do `leitura_build.sh` (o doctor instala).
9. **Falsos de teste**: o falso de `systemctl` de escrita recusa (como o do sudo), para o
   `convergencia.sh` não mentir.
10. **Decisão 12**: trocar de pack leva o ponteiro do pack mesmo que baixe (o pack decide); o
    download aparece com o selo «baixa da internet», sem pergunta.

## Alerta de segurança (10/10, 15:15, revisão automática do 4e17f5c): ReDoS em `app/servidor.py`

`comeco_svg = rb"\s*(<\?xml[^>]*>\s*)?((<!--.*?-->|<!DOCTYPE[^>]*>)\s*)*<svg[\s>]"` com `re.S`:
o `.*?` dentro de um grupo repetido `(...)*` volta atrás de forma explosiva quando há muitos
`<!--` sem `-->` (ou comentários que podem ser casados de vários jeitos) e o `<svg` final falha.
Um arquivo de acervo (de um pack importado) com 4 KB disso trava a thread do servidor. Cura
(obrigatória para o conferente): trocar a regex por um leitor linear — tirar BOM e espaço, pular
`<?xml … ?>` com `find(b"?>")`, pular comentários com `find(b"-->")` e DOCTYPE com `find(b">")`,
num laço com limite de passos, e então `startswith(b"<svg")`. Teste com `b"<!--" * 1000` e com
`b"<!--a-->" * 500 + b"<x"`: resposta em menos de 50 ms.
