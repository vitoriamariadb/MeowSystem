# P216 — o Discord veste os botões do pack pelo Vencord (17/11/2026)

## O que se mediu
Discord flatpak (`com.discordapp.Discord`, Electron) com cópia da config: barra própria em HTML com `– □ ×`
genéricos (foto). O Discord não tem chave de moldura nativa no Linux (`settings.json` não tem `frame`).

## A causa
A barra é HTML do próprio Discord; nem o tema de ícones nem o COSMIC entram nela.

## A cura na origem (preferência 2 do P213)
O tema que o manifesto `discord` já entrega pelo Vencord (`discord.modelo.theme.css`) ganha regras para os botões
da barra (`[class*="winButton"]`): o `svg` some e o botão usa `mask-image` com o SVG
`window-{minimize,maximize,close}-symbolic` do tema de ícones instalado, embutido como `data:` na geração (o
renderer do Discord não lê `file://`). A arte é lida do tema na geração, nunca copiada para o código; precisa de
um marcador novo no `modelo.py` (o mesmo gerador de outros apps: conferir que nenhum outro modelo muda).

## Como se prova
- Teste com HOME temporário: o CSS gerado traz as três máscaras lidas do tema de brinquedo; trocar o pack troca a
  arte; segunda passada sem escrita; reverter tira.
- Foto antes e depois com cópia da config (sem a conta: a cópia leva o token e se apaga ao fim).
