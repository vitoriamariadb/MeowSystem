# P269 — o Hefesto sai do mapa de janelas do produto (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- Etapa 45 do install: `'__main__.py': o alvo 'hefesto-dualsense4unix.desktop' não está instalado — fica como está`.
  A linha sai em todo PC sem o Hefesto.
- `assets/apps/appid.map:101`: `__main__.py:hefesto-dualsense4unix`. O texto do próprio mapa diz que `__main__.py`
  é um app_id genérico (qualquer `python3 -m` anuncia o mesmo) e que o conserto de raiz é uma linha no app.
- Decisões 4 e 29: projeto pessoal fica fora do produto; o que é de uma máquina mora no conf dela.

## A causa
O Hefesto não fixa o nome do programa antes de criar a janela, e a ponte que cobre isso foi parar no mapa que todo
PC recebe.

## A cura na origem
- No repositório do Hefesto (`~/Desenvolvimento/hefesto-dualsense4unix`): `GLib.set_prgname("hefesto-dualsense4unix")`
  antes de a janela nascer, para o app_id casar com o `.desktop` dele.
- No MeowSystem: a linha `__main__.py` e o texto dela saem do `appid.map`.
- Sim de quem usa, 23/11/2026, para mexer nos dois repositórios.

## Como se prova
- No palco (`scripts/palco.sh rodar` e `janelas`): a janela do Hefesto anuncia `hefesto-dualsense4unix`.
- `tests/janela-sem-app-id.sh` e o `--conferir` do `appid_dock.sh` verdes sem a linha.
- No nitro-5: a etapa 45 do install sem a linha `--`.

## Nos três PCs
O Hefesto mora no desktop da Vitória. A ponte instalada lá (`~/.local/share/applications`) some na passada do
install que vem depois da troca do mapa; conferir que a janela dele segue na dock.

## Medido (23/11): a causa escrita acima estava errada, e a linha fica
- No Wayland nativo o GTK 3 lê o nome do programa quando a janela é mapeada. O `GLib.set_prgname` que o Hefesto já
  chama depois do import do Gtk (`src/hefesto_dualsense4unix/app/main.py`) funciona: no palco, a janela anuncia
  `hefesto-dualsense4unix`, direto e por `python3 -m`. Medido duas vezes (agente e coordenador).
- A medida do bloco `install-ruido` («posto depois não muda») foi feita pelo XWayland sem perceber: lá a classe é
  derivada no import do Gtk, e a janela sem `set_wmclass` sai com o nome do script.
- A janela principal do Hefesto chama `set_wmclass`, e pelo XWayland já anuncia `Hefesto-Dualsense4Unix`, igual ao
  `StartupWMClass` dos `.desktop` dele.
- No desktop (leitura por ssh, 23/11): o `hefesto-dualsense4unix.desktop` está instalado e o processo no ar é
  `python3 -m hefesto_dualsense4unix.cli.app tray`. É a CLI, que não passa pelo `app/main.py`: candidata a origem
  do `__main__.py`. Não medido.
- Tirar a linha do `assets/apps/appid.map` sem essa medida pode quebrar o ícone do Hefesto na dock. Nada foi tirado.

## Feito no repositório do Hefesto (23/11, sem merge)
Branch `fix/app-id-antes-do-gtk` (`246085a90`), numa árvore à parte (`~/Desenvolvimento/.hefesto-wt-app-id`): o
nome do programa é fixado antes do import que traz o Gtk e a classe do programa depois dele. Conserta o que se
mediu de verdade: diálogo sem `set_wmclass` pelo XWayland saía `Lancador.py` e passa a sair
`Hefesto-Dualsense4Unix`. Teste por AST vermelho antes e verde depois; 87 testes do Hefesto verdes. O checkout do
Hefesto tem trabalho sem commit na `dev`: a entrada da branch é de quem cuida dele.

## Falta
- No desktop, com o Hefesto aberto (passo 10): ler o app_id da janela principal, da bandeja e de um diálogo com
  `scripts/appid_sonda.py`. Se nenhuma anunciar `__main__.py`, a linha do mapa está morta e sai; se a da bandeja
  anunciar, o conserto é fixar o nome também no caminho da CLI.
