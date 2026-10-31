# Teste técnico DWV — Elixir + IA (1h)

## Contexto e formato

Você tem 60 minutos para construir, em Elixir, um pequeno serviço que usa IA para entender pedidos de corretores e sugerir empreendimentos. O uso de IA para programar (Claude Code, Cursor, Copilot, ChatGPT etc.) é livre e esperado.

Não esperamos um produto completo. Avaliamos principalmente como você conduz o trabalho: o que planeja antes de codar, em que ordem constrói, como valida o que a IA gera e o que decide cortar quando o tempo aperta.

- Duração: 60 minutos, contados do primeiro commit ao último.
- Stack: Elixir 1.15+ e OTP 26+. Phoenix é opcional e provavelmente desnecessário.
- Depois do teste: conversa de 20 minutos com o time, em que você apresenta o histórico de commits e faz uma pequena alteração ao vivo.

## O desafio: Qualificador de pedidos

Corretores mandam pedidos em texto livre, do jeito que escrevem no WhatsApp. O serviço recebe esse texto e devolve os 3 empreendimentos mais aderentes do catálogo, com uma justificativa curta para cada um.

O fluxo tem três etapas:

1. **Extração (IA):** um LLM transforma o texto em uma struct `Pedido` com cidade, dormitórios mínimos, orçamento máximo, prazo de entrega máximo e perfil (`:moradia` ou `:investimento`). Qualquer campo pode vir `nil` se o texto não disser.
2. **Matching (código puro):** filtra o catálogo pelas restrições preenchidas e ordena por aderência. Sem LLM nessa etapa.
3. **Resposta:** retorna as 3 melhores opções com uma justificativa de uma linha cada, via `mix qualificar "texto do pedido"` ou um endpoint `POST /qualificar` (escolha um).

### Requisitos técnicos

- O cliente de LLM deve ficar atrás de um `behaviour`, com um adapter real (Anthropic ou OpenAI) e um adapter fake para testes. Fornecemos uma chave de API no início do teste.
- A resposta do LLM deve ser validada antes de virar `Pedido`. JSON inválido ou campo absurdo não pode derrubar o serviço: retorne `{:error, motivo}`.
- O matching deve ser testável sem rede.
- Pedido sem nenhum critério útil deve gerar uma resposta que peça mais informação, não uma lista aleatória.

## Dados fornecidos

Esta pasta já traz os dados do teste:

- `priv/catalogo.json`: 10 empreendimentos fictícios em Balneário Camboriú, Itapema e Porto Belo.
- `priv/pedidos.txt`: 3 mensagens de teste, uma por linha. Cobrem um caso claro, um caso com gíria e abreviação e um caso incompleto.

Crie o projeto Elixir nesta mesma pasta (por exemplo, `mix new . --app qualificador`) e mantenha `priv/` como está.

## Commits e condução

Cada função do sistema vira pelo menos um commit próprio, feito no momento em que fica pronta. Não faça squash nem reescreva o histórico: os horários dos commits fazem parte da avaliação.

| # | Commit | O que entra | Tempo sugerido |
| --- | --- | --- | --- |
| 1 | `docs: plano` | `PLAN.md` com abordagem, ordem das etapas e o que vai cortar se faltar tempo. Antes de qualquer código | 5 min |
| 2 | `chore: estrutura do projeto` | `mix new`, dependências, config | 5 min |
| 3 | `feat: catálogo` | Leitura e parse do JSON em structs | 5 min |
| 4 | `feat: cliente LLM` | Behaviour, adapter real e adapter fake | 10 min |
| 5 | `feat: extração de pedido` | Prompt, chamada e validação da resposta em `Pedido` | 10 min |
| 6 | `feat: matching` | Filtro e ranking, funções puras | 10 min |
| 7 | `feat: interface` | Mix task ou endpoint | 5 min |
| 8 | `docs: README` | Decisões, o que ficou de fora, como a IA foi usada | 5 min |

Testes podem vir junto com cada `feat` ou em commits `test:` separados, como preferir. A ordem de 3 a 6 pode mudar se o `PLAN.md` justificar. Commits extras de correção são bem-vindos: preferimos ver o caminho real a um histórico perfeito.

## Entrega

Envie o link do repositório (GitHub ou GitLab, público ou com acesso concedido ao time) até 15 minutos depois do fim do tempo.

- [ ] Histórico de commits intacto, sem squash
- [ ] `PLAN.md` no primeiro commit
- [ ] `README.md` com como rodar, decisões tomadas e o que faria com mais 2 horas
- [ ] Seção "Uso de IA" no README: que ferramenta usou, onde ela errou e o que você corrigiu ou descartou
- [ ] Opcional: export da sessão de IA (transcript do Claude Code, conversa do ChatGPT etc.)

Bônus, só se sobrar tempo: timeout e retry na chamada ao LLM, justificativa gerada pelo LLM a partir do resultado do matching, ou cache de extrações repetidas.
