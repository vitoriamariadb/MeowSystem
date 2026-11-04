# P158 — Criar o meu tema ≠ Personalizar

Pedido dela, 04/11/2026: «Criar o meu tema =/= Personalizar. A interface é a mesma. Mas o outro vai cuidar de
gerar um tema próprio. Pensa num designer que não manja nada de ti. Pra um será o disponibilizar, outro vira
aprimorar.» Respostas no AskUserQuestion do mesmo dia.

## O que se mediu

O botão «Criar o meu tema» (`paginaTema`) leva a `#criar/cores`, que é o próprio Personalizar. Esse assistente
hoje parte de um pack base, guarda um pack NOVO (`guardarTemaAgora` → `/api/pack-importar`) e termina no passo
«Disponibilizar» (Baixar o tema `.meowpack` / Aplicar tema). Ou seja: o Personalizar de hoje já é o «criar».

## A cura

Os mesmos passos e as mesmas telas, dois destinos:

- **Criar o meu tema** (rota própria, ex. `#novo/<passo>`, rascunho próprio no `localStorage`): é o fluxo de
  hoje. Começa de uma base, pede nome, guarda um pack novo, último passo **Disponibilizar** (Baixar o
  `.meowpack` / Aplicar). Papel de parede: o designer sobe as fotos dele («Trazer imagens»), e a galeria
  mostra só as fotos do tema novo, sem o carrossel dela.
- **Personalizar** (`#criar/<passo>`, o item do menu de cima): **aprimora o tema em uso**. Abre com o pack
  vestido carregado, grava nele mesmo, último passo **Aprimorar** (aplica no tema em uso). Pack pessoal grava
  em `~/.local/share/meowsystem/packs/<id>/`; pack de fábrica (MeowSystem, Dracula) grava em `packs/<id>/` do
  repositório quando o painel roda de um checkout git, sem commit (o commit é de quem fecha o bloco). Sem
  checkout, pack de fábrica não se aprimora no lugar: o botão diz o porquê. Papel de parede: a galeria do
  carrossel (P157).
- Para um designer que não conhece o projeto, o título de cada página diz o que vai sair dela, em poucas
  palavras («Tema novo» / «Aprimorar <nome do tema>»). Interface mostra, não explica.

Depende da P157 (a galeria sem «Levar»): a branch sai da branch da P157.

## Como se prova

Testes de navegador em HOME temporário: Criar guarda um pack novo e Baixar devolve um `.meowpack`; Personalizar
num pack pessoal muda o próprio pack (nenhum pack novo aparece); num pack de fábrica com raiz-checkout falsa
grava em `packs/<id>/`; sem `.git`, recusa com o porquê. Os dois rascunhos não se misturam. Suíte inteira verde.
