# Plano: Qualificador de pedidos

## Abordagem

Serviço em Elixir, sem Phoenix, exposto por `mix qualificar "texto do pedido"`. Dependências: `Req` (HTTP) e `Jason` (JSON).

O fluxo é `Extracao` (LLM + validação) → `Matching` (código puro) → resposta com até 3 opções e uma justificativa de uma linha cada.

Módulos: `Qualificador` (orquestra), `Catalogo`, `Pedido`, `Extracao`, `Matching`, `LLM` (behaviour), `LLM.Anthropic` ou `LLM.OpenAI` (conforme a chave fornecida), `LLM.Fake` e `Mix.Tasks.Qualificar`.

## Ordem das etapas

A ordem muda em relação à sugerida: o matching vem antes do cliente LLM. Ele é o núcleo do serviço e não depende de rede, então fica pronto e testado mesmo se a API der problema.

| Tempo | Commit | Entrega |
| --- | --- | --- |
| 0–5 | `docs: plano` | Este arquivo |
| 5–10 | `chore: estrutura do projeto` | `mix new`, dependências e config |
| 10–15 | `feat: catálogo` | Structs e parse do JSON |
| 15–25 | `feat: matching` | `Pedido`, filtro e ranking |
| 25–35 | `feat: cliente LLM` | Behaviour, adapter real e fake |
| 35–45 | `feat: extração de pedido` | Prompt e validação |
| 45–50 | `feat: interface` | Mix task |
| 50–55 | `docs: README` | Como rodar, decisões, o que faria com mais 2 horas, uso de IA |
| 55–60 | Folga | Correções em commits `fix:` |

## Decisões

- **Campos extras no `Pedido`:** `suites_min` e `posicoes`, além dos pedidos no enunciado. Sem posição, o emp-05 (`interna`) entraria no resultado do pedido "frente ou quadra mar".
- **Filtro por tipologia:** uma mesma tipologia precisa atender a todos os critérios, para não combinar os dormitórios de uma com o preço de outra.
- **Menos de 3 resultados:** devolve só o que atende, sem completar a lista.
- **Critério útil:** qualquer campo além de `perfil`. O perfil só influencia a ordenação, então sozinho gera um pedido de mais informação.
- **Retornos:** `{:ok, resultados}`, `{:mais_info, mensagem}` e `{:error, motivo}`. Nenhum resultado vira `{:ok, []}` com uma mensagem clara.
- **Validação do LLM:** trata JSON inválido e tipos errados, e aplica faixas plausíveis: dormitórios de 0 a 10, orçamento de R$ 50 mil a R$ 100 milhões, entrega entre o ano atual e o atual + 15. `perfil` e `posicoes` só de lista fechada, sem `String.to_atom`.
- **Prazo:** ano inteiro, como no catálogo. O prompt recebe a data atual para resolver prazos relativos.
- **Ranking:** filtra e depois pontua, com pesos em atributos de módulo. Moradia favorece área maior; investimento favorece menor preço por m² e entrega próxima; sem perfil, usa a posição. Empate desempata por `id`.
- **Justificativa:** template com dados reais da tipologia, sem LLM.
- **Chave de API:** lida de variável de ambiente, nunca commitada.

## Resultados esperados

Escritos antes da implementação, para validar o que a IA gerar.

| Pedido | Empreendimentos |
| --- | --- |
| 3 suítes em Itapema, frente ou quadra mar, até 2,5 mi, entrega até 2027 | emp-01 e emp-03 |
| 2 dorms em BC até 1.2, investidor | emp-02 e emp-07 |
| Apto grande pra família, 4 milhões | emp-09, emp-04 e emp-01, nesta ordem |
| Sem critério útil ("oi, tem algo bom?") | Pede mais informação |

## O que cortar se faltar tempo

Nesta ordem:

1. Bônus: cache, justificativa gerada pelo LLM e retry. Um timeout simples no `Req` fica.
2. Sofisticação do ranking: ficam pesos simples.
3. Normalização extra de cidade: fica o que o prompt resolve.
4. Testes de borda da validação: ficam JSON inválido e um valor absurdo.

Não entram no corte: behaviour com adapter fake, validação da resposta do LLM, caso sem critério, README e commits feitos na hora.
