# P266 — o COSMIC repõe o override do Flatpak e ninguém vigia (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- `meow.log`: `flatpak_tema.sh override do usuário limpo de xdg-config/gtk-4.0:ro` aparece 13 vezes desde 07/11, em
  oito dias diferentes; a última em 23/11 16h24m07, seis minutos depois do login.
- Foi a única escrita do install das 16h23: `passagem=1 mexeu=1`, e por isso houve segunda passagem. O install
  seguinte, às 16h30, não escreveu nada.
- `/usr/bin/cosmic-settings-daemon` traz os textos `xdg-config/gtk-3.0:ro` e `xdg-config/gtk-4.0:ro`;
  `CosmicTk/v1/apply_theme_global` está `true`.
- `systemd/meow-flatpak.path` vigia só `~/.local/share/flatpak/.changed` e `/var/lib/flatpak/.changed`. O arquivo
  `~/.local/share/flatpak/overrides/global` não tem vigia.

## A causa
Dois donos na mesma linha: o daemon do COSMIC devolve `xdg-config/gtk-4.0:ro` ao override global e o
`flatpak_tema.sh` o tira, porque ele quebra o estilo dos apps libadwaita. Quem tira só roda no install e no doctor;
entre um e outro o override fica como o COSMIC deixou. O momento exato em que o daemon escreve não foi visto: é o
primeiro passo da tarefa.

## A cura na origem
1. Medir: sair e entrar na sessão e comparar a hora do `overrides/global` com o journal do `cosmic-settings-daemon`.
2. Vigia no molde do `meow-qt.path`: `PathChanged=` sobre `overrides/global`, chamando a conferência do libadwaita
   do `flatpak_tema.sh`. A escrita do próprio vigia dispara outra volta, que não acha o que escrever e para.

## Como se prova
- Teste com HOME temporário: o override com `xdg-config/gtk-4.0:ro` é limpo pelo serviço do vigia; a segunda volta
  não escreve; override sem a linha não é tocado.
- No nitro-5: depois de um login, `./install.sh` fecha em 1 passagem com `mexeu=0`.

## Nos três PCs
Medido no nitro-5. A contar no desktop e no portátil: `grep -c 'limpo de xdg-config/gtk-4.0' meow.log`.

## Feito (23/11, bloco `install-sessao`, integrado em `3a2fd5a5`)
- Medido: quem repõe a linha é o `cosmic-settings-daemon` (o binário traz `overrides/global`, `xdg-config/gtk-4.0:ro`
  e `apply_theme_global`). O momento exato da escrita não foi medido: pede sair e entrar na sessão.
- Par novo `meow-flatpak-override.path` e `.service`: qualquer escrita no `overrides/global` dispara a limpeza da
  linha do GTK 4, sem notificação. A chave `FLATPAK_VIGIA` liga e desliga.
- Conferido no fonte do systemd 255 e com `inotifywait`: `PathChanged` cobre a troca por rename, e a escrita do
  próprio serviço não dispara de novo.
- Prova: `tests/flatpak-override-vigia.sh` (8 FALHOU com o conserto desfeito; verde depois).
- Falta, no passo 10: o vigia com o daemon real e o `./install.sh` fechando em 1 passagem com `mexeu=0` depois de um
  login.
- Anotado para depois: o texto de `FLATPAK_VIGIA` no `meow.conf.exemplo` cita só o par antigo; e as unidades de
  vigia usam `${CHAVE:-sim}` dentro do `ExecCondition`, que o systemd troca antes do shell (não verificado).
