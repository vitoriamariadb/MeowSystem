# P294 — o fundo que o cosmic-bg lê por modo do tema (24/11/2026)

Pedido de quem usa, 24/11: «ver pq meus papeis de parede não funcionam» e «isso aconteceu no spellbook também?».

## O que se mediu (24/11, MeowSystem e nitro-5)
- A tela atrás das janelas é um cinza liso, `(38,40,41)`: a cor de limpeza do compositor. Nenhuma imagem desenhada.
- O `cosmic-bg` (1.11.0, pacote de 12/11) registrou no início da sessão `No source for wallpaper` e não disse mais nada.
- Os três `inotify` do processo vigiam `com.system76.CosmicTheme.Mode/v1`, `com.system76.CosmicBackground.Dark/v1` e
  `com.system76.CosmicBackground.Light/v1`. Nenhum vigia `com.system76.CosmicBackground/v1`.
- `com.system76.CosmicBackground/v1` (a pasta em que o `scripts/wallpaper.sh` escreve) está certa, e ninguém a lê.
- `.Dark/v1` e `.Light/v1` nasceram em 20/11 (MeowSystem) e 23/11 (nitro-5) como cópia da pasta antiga daquele dia, e
  apontam para `ativos-noite/` e `ativos-dia/`, que a P285 apagou em 24/11 ao levar o acervo para uma pasta por pack.
- O «próximo papel de parede» fixa sempre a primeira imagem da lista: o estado do `cosmic-bg` cita um arquivo que não
  existe, e a conta recomeça do zero.

## A causa
O `cosmic-bg` passou a ler a config de fundo de uma casa por modo do tema (`…CosmicBackground.Dark` e `.Light`), e o
MeowSystem continuou escrevendo, conferindo e vigiando só a casa de antes. Entre 20/11 e 24/11 o carrossel ficou
congelado no grupo do dia da cópia; quando a pasta desse grupo saiu, o fundo ficou sem fonte.

## A cura na origem
1. `scripts/wallpaper.sh`: a config do carrossel vai para todas as casas que o COSMIC instalado conhece — a de antes
   e, quando o sistema ou a pessoa têm, a `.Dark` e a `.Light`. Vale para escrever (`aplicar`), reler
   (`forcar_releitura`), conferir (`estado`, e por ele o doctor) e mudar de base (`apontar_fundo_para`).
2. O campo `transition_duration`, que o esquema novo traz, fica com o valor que a casa já tem; sem ele, o do sistema.
3. `dados/systemd/meow-fundo.path` vigia as três casas: a janela de papel de parede do COSMIC escreve nas novas.
4. `dados/contratos/cosmic.tsv` ganha os dois esquemas.

## Como se prova
- `tests/contrato-cosmic.sh`, bloco «o fundo por modo do tema»: vermelho antes da cura, verde depois. Sem a casa por
  modo no sistema, nenhuma pasta nasce; com ela, as duas apontam para `.girando`, o `transition_duration` da casa se
  mantém, a segunda passada não escreve, e o `estado` acusa a casa que aponta para outro lugar.
- Na máquina: `wallpaper.sh aplicar`, um print da tela com a imagem no lugar do cinza, e o `wallpapers` do estado do
  `cosmic-bg` com caminho que existe.
- A suíte de papel de parede (`wallpaper-base`, `papel-em-par`, `papeis-por-pack`, `semente-dos-papeis`,
  `apagar-papel`, `casa-real`) e `tests/decisoes.sh`.
