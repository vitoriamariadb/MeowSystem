# P200 — o resultado na própria linha (11/11/2026)

Sim de quem usa, 11/11: «Resultado na própria linha (Recomendado)» · «Só a linha» (Carrossel) · «Só o botão
«Aplicar»» (Mascote) · «Sim, a linha se chama «Girar»». O sim de 10/11 «tudo que é registro» continua valendo.

## O que se mediu

Sem a janela de resultado (P189), os botões de ação que só leem rodam, a linha de progresso some e nada aparece.
O retorno 1 («há divergências») nem vira aviso. Lista do conferente do bloco B (`app/pagina/lugares.js`):
`painel_estado` (102), `painel_teto` (103), `areas_ver` (128), `wallpaper` (137), o menu agora (148),
`logo_listar` (170), a leitura agora (212), `jogos` e `jogos_heroic` (234-235), `doctor` (246),
o «O que muda» do atualizar (255), `icones` (279). O «Verificar o sistema» perdeu o «Consertar» que a janela
oferecia com divergência (`conserta_com` = `doctor_consertar`, ainda no JSON do trabalho e no `tests/app.sh`).

Também: o diálogo «Adicionar repositório» ainda mostra o log da compilação (`extensoes.js:348`, `:359`,
`:449-450`), contra o «tudo que é registro».

## A cura na origem

- Toda ação que só lê (`escreve(acao)` falso no servidor) mostra o resultado embaixo da própria linha, na tela,
  sem janela: as linhas que importam da saída, sem prefixo de log, sem caminho de arquivo cru, sem rolagem
  infinita. Some ao rodar de novo ou ao sair da tela. Retorno 1 aparece como divergência, não some calado.
- «Verificar o sistema»: mostra quantas coisas divergem e quais, em nome curto; com divergência, o botão
  «Consertar» aparece ali mesmo e roda o `conserta_com` do trabalho.
- «Conferir» de Modificações continua relendo os cartões e ganha o mesmo resultado na linha.
- Mascote: a linha `logo_trocar` fica sem nome próprio, só o botão «Aplicar».
- Papel de parede: a linha `wallpaper_carrossel` passa a se chamar «Girar» (botão «Girar»). «Próxima imagem» fica.
- Adicionar repositório: sai o `pre` de saída e o `details` «Registro»; fica a linha de progresso e o estado final
  (deu certo / o motivo curto de não ter dado).
- `GLOSSARIO.md` e `tests/glossario.sh` acompanham as três trocas de nome.

## Como se prova

- Gate do navegador: para cada ação que só lê, clicar e achar o resultado na própria linha (texto não vazio,
  sem `pre` de log); com o doctor de brinquedo devolvendo 1, aparecem as divergências e o «Consertar», e o
  clique roda `doctor_consertar`.
- Adicionar repositório com um build de brinquedo que falha: nenhum `pre`/`details` de log; o motivo curto aparece.
- `tests/glossario.sh` e `tests/decisoes.sh` verdes; suíte inteira sem vermelho.

Tamanho: 3 h.
