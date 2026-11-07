# P176 — o que a conferência deixou (06/11/2026)

Achados da conferência da P172 a P175, antes do install.

## O que se mediu

- `meow status` roda `rodar_checks` sem `MEOW_SO_LE`, e um comando só de leitura ainda chama `sudo -n <ponte> estado`. Lido no código.
- `app/servidor.py` crava a versão do esquema em `_flavor_na_tela`, `_acento_na_tela` (`CosmicTheme.Mode/v1`, `CosmicTheme.%s.Builder/v2`) e no programa que lê o teto do painel (`CosmicPanel.$b/v1`, perto da linha 1850). O fallback de `_cosmic_pasta` é `v1`, então trocar direto faria o `Builder/v2` cair em `v1`.
- `CONF_COMP`, em `app/servidor.py`, não tem leitor.
- `meow_travar` troca o cadeado quando o dono não parece meow: com um processo de `comm` só `sleep` segurando o lock, `meow espaco liberar` seguiu e cortou.
- `tests/etapa-compositor.sh` deixa `README.md` e `README.en.md` sujos na árvore (doctor 82→83, 130→131 ajustes, 67→69 ações). O teste não cita o README; o caminho exato não foi achado.

## A cura

- `meow status` lê com `MEOW_SO_LE=1`, sem `sudo`.
- O painel resolve a versão de cada esquema como os escritores, com o fallback certo para cada um.
- `CONF_COMP` sai.
- Medir se um build que perdeu o `bash` e deixou filhos herdando o lock fica desprotegido contra o Liberar; se fica, a trava confere quem segura o `flock` antes de trocar.
- Achar quem regenera o README no teste e fazer o teste não sujar a árvore.

## Como se prova

`tests/doctor-so-le.sh` estendido a `meow status`, sem `sudo` registrado; teste com `Mode/v2` e `Builder/v3` no HOME temporário; teste do cadeado com filho herdeiro; `git status` limpo depois de `tests/etapa-compositor.sh`.
