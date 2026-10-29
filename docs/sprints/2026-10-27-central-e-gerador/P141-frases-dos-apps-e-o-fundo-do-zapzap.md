# P141 — os módulos de app param de mandar digitar, e o fundo do chat do ZapZap

Anotada em 29/10, das pendências legadas do `ANDAMENTO.md` (28/10 e 29/10).

## O que se mediu
- `scripts/temas-de-apps/qbittorrent/manifesto.sh:445` e `:483`: o reverter termina com «tire 'qbittorrent' de
  APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica». Saída que manda editar arquivo (decisão: o doctor
  corrige; nenhuma saída manda digitar). Sem o passo, o doctor das 05:00 reaplica o tema que ela acabou de tirar.
- `scripts/temas-de-apps/waterfox/manifesto.sh:34`: «nenhum perfil em profiles.ini ainda — abra o Waterfox uma vez».
- ZapZap: anotado em 28/10 «o fundo do chat do ZapZap» sem medida. Medir primeiro: o CSS que o módulo gera
  (`zapzap.modelo.css` preenchido) contra o DOM do WhatsApp Web que o ZapZap carrega; o fundo da conversa
  (a área atrás das bolhas, com o papel de parede do WhatsApp) fica com a cor de fábrica ou com a do pack?

## Cura na origem
- Reverter um app é desligar o app: o reverter do qBittorrent tira `qbittorrent` do `APPS_ATIVOS` pelo mesmo
  caminho de escrita do `meow.conf` que o painel usa (a escrita única da P139), e a frase vira só o fato.
  Se outros módulos têm a mesma frase, o mesmo conserto vale para eles (`grep -rn APPS_ATIVOS scripts/temas-de-apps`).
- Waterfox sem perfil: a saída diz o estado sem ordem («ainda sem perfil; o tema entra quando o perfil existir»), e o
  tema entra sozinho na passada seguinte do doctor depois que o perfil nasce (vigia ou a passada normal; o que for
  mais simples e provado).
- ZapZap: se a medida confirmar o fundo de fábrica, o modelo pinta o fundo da conversa com a cor do pack (as duas
  paletas); se não confirmar, a `## Execução` registra a medida e nada muda.

## Prova
- Teste: reverter o qBittorrent num HOME de brinquedo tira `qbittorrent` do `APPS_ATIVOS`; a segunda passada não
  escreve; nenhuma saída dos módulos tocados contém «meow.conf», «abra», «rode», «digite».
- Waterfox: HOME sem perfil não sai com ordem; com o perfil criado, a passada seguinte aplica.
- ZapZap: o CSS gerado com as paletas `meowsystem` e `dracula` tem a regra do fundo; teste do módulo verde.
