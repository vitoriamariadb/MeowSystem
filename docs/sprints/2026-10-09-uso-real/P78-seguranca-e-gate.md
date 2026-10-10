# P78 — Pack é dado não confiável; o gate volta a ficar verde

**Branch:** `sprint/p78` (a partir de `integracao/leva-g`) · **Fontes:** seções «Segurança» de
`P73-seletor-e-acervo.md` e `P74-pack-dracula-completo.md` (no dev), `ESTADO.md` passo 2,
`03-integracao-onda-1.md` («Aberto» 1 e 2), `02-decisoes.md` (7 e 8).

## Por que
Seis alertas automáticos de segurança nos commits da onda 1: `scripts/pack.py` (×2, caminho e
parser diferencial), `scripts/icones_apps_dracula.sh` (caminho), `scripts/som.sh` (symlink),
`app/servidor.py` (SVG não confiável servido na mesma origem), `bin/meow` (caminho de busca não
confiável / execução de código). Um pack pode ser importado de terceiros: tudo que vem de
`packs/<id>/`, de um `.meowpack` ou do `icones-escolhidos.map` é dado não confiável.

## Tarefas
1. **Varredura**: todo `cp`, `ln`, `install`, `cat`, `tar`, `rsvg-convert`, `open()`, `source`,
   `.`, `bash`, `python3` sobre caminho vindo de pack, mapa, conf, cwd, PATH ou HOME, em `bin/`,
   `lib/`, `scripts/`, `app/`. Para cada um: seguro, ou corrigido.
2. **Regra única** (um helper em shell e um em Python, usados por todos): `realpath` dentro da
   raiz permitida, symlink para fora recusado, nome de destino de conjunto fechado; validar e
   usar a MESMA forma normalizada. Linha ruim é pulada e contada, sem abortar.
3. **Servidor**: SVG/PNG de acervo com `Content-Security-Policy: default-src 'none';
   style-src 'unsafe-inline'; sandbox`, `X-Content-Type-Options: nosniff`, nunca inline no DOM.
4. **`bin/meow`**: nenhum script executado por caminho relativo ao cwd ou achado no PATH quando
   existe o do repositório; nenhum arquivo de pack executado.
5. **Decisão 7**: `doctor_consertar` declara `rede: True`, mostra o selo, sem caixa de pergunta; o
   gate (`tests/app-completo.py`) passa a exigir o selo para reparo e a pergunta só para ação
   opcional que baixa.
6. **Decisão 8**: o gate e qualquer runner de QA recusam subir o painel com o HOME real sem
   `MEOW_QA_HOME_REAL=1`.
7. **Abertos da integração**: teste para `ICONES_DRACULA` ausente no passo do pack;
   `portabilidade.sh` (o `cosmic-vivo.md:198`) e `doctor-so-le.sh` com HOME de brinquedo.

## Prova
- `tests/pack-malicioso.sh` (novo): pack com `../`, caminho absoluto, symlink para `~/.ssh`,
  nome com `/`, SVG com `<script>`/`onload` — nada lido nem escrito fora da raiz, nada executa,
  token não vaza (curl na URL do SVG mostra os cabeçalhos).
- `tests/todos.sh` inteiro verde, inclusive o gate.
