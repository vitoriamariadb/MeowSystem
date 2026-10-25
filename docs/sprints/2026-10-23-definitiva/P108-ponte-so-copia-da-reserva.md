# P108 — A ponte só copia da reserva de root, nunca do repositório

**Status: EM VOO em 25/10.** Achado pela conferência da P104, que o marcou como «problema que já existia antes da
P104». Vem antes da v2.1.0 porque é a fronteira de root. Quem usa (24/10) pediu qualidade máxima e autorizou
rodar tudo sem perguntar.

## O que se mediu (25/10)
- `scripts/ponte_root.sh`, verbo `apt-hook-instalar`: lê `raiz` do perfil gravado como root e copia
  `$raiz/scripts/meow-lancador-apt.sh` para o wrapper (`install -m 755 -o root`), que roda como root em todo
  `apt`. O clone é gravável por quem usa. Ou seja: editar o script no repositório e chamar o verbo (sem senha)
  põe código seu em root, sem passar pelo install.
- Verbo `completion-instalar`: mesma forma, com `$raiz/assets/zsh/_meow` copiado para
  `/usr/local/share/zsh/site-functions/_meow`, que o zsh de todo usuário carrega (root incluído). A ponte confere
  a primeira linha e o tamanho, mas não o conteúdo.
- O `chk_ponte` (P104) não compara a regra de sudo instalada com a da reserva. E apagar só a regra do polkit não
  é detectado (a pasta é 0750 `root:polkitd`).

## A cura
1. **A reserva guarda tudo o que vira root:** o install (que tem a senha) põe na reserva da P104
   (`/usr/local/lib/meowsystem/reserva/`, 0700 root, com sha256) o wrapper do apt já preenchido, o hook e a
   completion. Os verbos `apt-hook-instalar` e `completion-instalar` copiam SÓ da reserva, conferindo o sha256.
   Não leem nada do repositório.
2. **Repositório mais novo que a reserva:** é pendência «entra no próximo Instalar tudo», como a ponte nova na
   P104. Nunca é promovido sem o install.
3. **O doctor confere** a regra de sudo instalada contra a da reserva. A regra do polkit, a ponte confere (ela
   é root) por um verbo `estado` que já existe ou por um verbo novo sem argumento.
4. **Varredura:** procure em `ponte_root.sh` todo verbo que copia arquivo do `$raiz` (ou de qualquer lugar
   gravável por quem usa) para destino de root, e trate da mesma forma. Liste o que achou na seção «Execução».

## Como se prova
- Teste com a ponte de brinquedo: com o script do repositório adulterado, o verbo não o instala. A reserva com
  sha256 adulterado também não. O doctor acusa a regra divergente.
- Container `ubuntu:24.04` com systemd (a imagem `localhost/meow-p104-systemd:1` já existe; veja a «Execução» da
  P104): install, editar `scripts/meow-lancador-apt.sh` no clone, chamar o verbo sem senha, e o wrapper em
  `/usr/local` continua o da reserva.
