# P212 — os navegadores Chromium vestem os botões do pack (17/11/2026)

## O que se mediu
Ver `00-leva.md`. Chrome e Edge no modo Clássico desenham botões genéricos; no modo GTK o Chrome pede
`window-*-symbolic` ao tema de ícones e mostra a arte do pack (foto provada com perfil temporário).

## A cura na origem
Manifesto novo `scripts/temas-de-apps/chromium/manifesto.sh` (descoberto pelo glob de `bin/meow`), no molde do
`firefox/manifesto.sh` e de `lib/tema_arquivo.sh`:
1. Raízes de perfil por formato: deb/tarball (`~/.config/google-chrome`, `~/.config/microsoft-edge`,
   `~/.config/chromium`, `~/.config/BraveSoftware/Brave-Browser`, canais beta/dev), flatpak
   (`~/.var/app/<id>/config/<pasta>`, ids `com.google.Chrome`, `com.microsoft.Edge`, `org.chromium.Chromium`,
   `com.brave.Browser`) e snap (`~/snap/<nome>/common/…` ou `~/snap/<nome>/current/.config/…`, conferir o caminho
   real do snap do Chromium). Perfis: `Default` e `Profile *` com `Preferences`.
2. Em cada perfil: `extensions.theme.system_theme = 1` e tirar o que faz o navegador manter o tema próprio
   (`extensions.theme.id`, e o que mais o Chrome atual exigir — medir com perfil temporário: copiar o Preferences
   real para um `--user-data-dir` temporário, aplicar, abrir, fotografar). Guardar os valores de antes para o
   reverter.
3. O navegador reescreve o Preferences ao fechar: com o navegador daquela raiz aberto, não escreve; fica pendente
   (o padrão de pendência dos outros manifestos) e entra na próxima passada.
4. Idempotente: segunda passada não escreve. `conferir` só lê. `reverter` devolve os valores guardados.
5. `docs/DECISOES.md`: uma linha nova (navegadores Chromium no modo GTK para os botões e as cores do pack), com o sim
   citado do `00-leva.md`. Ela mesma disse: «se mudar muito fazemos um tema próprio pra eles».

## Como se prova
- Teste em `tests/` com HOME temporário e falsos no PATH (regras do `GSD.md`): perfis falsos de deb, flatpak e snap
  → aplicar põe `system_theme = 1` e tira o tema próprio; segunda passada sem escrita; navegador "aberto" (processo
  falso) → pendente sem escrita; reverter devolve o JSON de antes.
- Foto real: Chrome com cópia do perfil num `--user-data-dir` temporário depois do aplicar → botões do pack.
- Nunca escrever no perfil real do navegador de quem usa; o install e o doctor reais são do coordenador.
