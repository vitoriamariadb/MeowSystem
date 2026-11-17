# P231 — vagas novas no pack e no criador de tema (17/11/2026)

Ver `P230`. Ideias aprovadas: `soneca-vaga`, `soneca-texto-fixo`, `soneca-texto-pack`, `botoes-vaga`, `papel-par`,
`papel-creditos`.

## O que se mediu
- A Soneca (`assets/extensoes/soneca.pino`, programa em `~/Desenvolvimento/meowsystem-soneca`, pino no commit
  `72c506e`) traz os ícones dela em `data/icones/` e os instala com o applet: o pack não manda neles, e no Dracula
  aparece o gato.
- Os botões da janela (`window-*-symbolic`, `list-add-symbolic`) estão no `icones/sistema.map` dos packs, mas o
  criador de tema (`app/pagina/oficina.js`, `app/servidor.py`) não os mostra como grupo.
- O mascote já troca por hora (`lib/noite.sh`, `LOGO_MODO="hora"`); o papel de parede não tem par dia e noite.
- `docs/CREDITOS.md` e os `CREDITOS.md` dos packs listam os papéis sem miniatura.

## A cura na origem
1. Soneca: o applet pede `soneca-desperto-symbolic` e `soneca-ronronar-symbolic` ao tema de ícones (os de hoje viram
   o padrão de quem não tem pack), e lê o texto dos dois modos do pack (`pack.json` ou arquivo de tema do applet, no
   contrato que a Soneca já usa para cores: `TEMA_CHAVES`); sem texto no pack, «Desperto» e «Ronronar». Commit no
   repositório da Soneca (sem push: o coordenador faz) e o pino novo no MeowSystem. O mapa de ícones dos dois packs
   ganha as duas vagas (a arte vem dos blocos E e F; até lá o MeowSystem aponta para os SVG atuais da Soneca).
2. Criador de tema: grupo «Botões da janela» em Ícones › Sistema (fechar, minimizar, maximizar, restaurar, +), com
   prévia numa barra de título e troca por arquivo, no padrão dos grupos que já existem; grupo «Soneca» com as duas
   vagas e os dois textos. Interface sem texto explicativo (GSD 2).
3. Par dia e noite do papel: o pack declara pares (`dia`/`noite`) e a troca segue a mesma janela de noite do
   mascote, idempotente, sem pular de cena; papel sem par fica como está.
4. Créditos: a página de créditos do painel e os `CREDITOS.md` mostram cada papel com miniatura, cena, pack,
   licença, data e o par lado a lado.

## Como se prova
Testes com HOME temporário para cada item (vaga no mapa, texto do pack lido pelo applet com fallback, grupo no
criador com troca por arquivo e segunda passada sem escrita, troca do par pela hora com relógio falso, créditos com
miniatura); `tests/decisoes.sh`; foto do painel com os grupos novos. Linha de `docs/DECISOES.md` só pelo
coordenador (proponha).
