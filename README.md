# Qualificador de pedidos

Recebe um pedido de corretor em texto livre, como no WhatsApp, e devolve até 3 empreendimentos do catálogo, com uma justificativa de uma linha para cada um.

## Limitação importante

**Nenhuma chave de API foi fornecida, então o LLM real nunca foi chamado.** O adapter `LLM.Anthropic` foi testado só com HTTP simulado. O prompt nunca rodou em um modelo, e o formato da requisição veio da documentação, sem confirmação da API.

Os pedidos de `priv/pedidos.txt` rodam com o adapter `LLM.Fake`, cujas respostas foram escritas à mão. Isso exercita validação, matching e interface, mas **não prova que um LLM entende "BC" ou "até 1.2"**.

## Como rodar

Requer Elixir 1.15+ e OTP 26+. Desenvolvido e testado com Elixir 1.20.4 e OTP 29.

```bash
mix deps.get
```

```bash
mix test
```

Sem chave, com as respostas escritas à mão (só os 3 pedidos de exemplo são reconhecidos):

```bash
mix qualificar --fake "tem algo 2 dorms em BC até 1.2? investidor, quer pra temporada"
```

Com o LLM real, depois de definir `ANTHROPIC_API_KEY`:

```bash
mix qualificar "tem algo 2 dorms em BC até 1.2? investidor, quer pra temporada"
```

Saída do exemplo com `--fake`:

```text
1. Vista Atlântica: Quadra mar em Balneário Camboriú (Centro): 2 dorm., 1 suíte(s), 78 m², R$ 1,15 mi, entrega 2026, R$ 14,74 mil/m²
2. Studio Pioneiros: Quadra mar em Balneário Camboriú (Pioneiros): 2 dorm., 1 suíte(s), 71 m², R$ 1,19 mi, entrega 2027, R$ 16,76 mil/m²
```

## Estrutura

| Módulo | Papel |
| --- | --- |
| `Qualificador` | Orquestra extração, matching e resposta |
| `Catalogo` | Lê o JSON e converte em structs |
| `Pedido` | Struct, validação de dados externos e critério útil |
| `Extracao` | Prompt, chamada ao LLM e decodificação da resposta |
| `Matching` | Filtro e ranking, em funções puras |
| `LLM` | Behaviour, com os adapters `LLM.Anthropic` e `LLM.Fake` |
| `Mix.Tasks.Qualificar` | Interface de linha de comando |

## Decisões

- **Mix task em vez de endpoint:** é a interface mais simples que atende ao enunciado, sem precisar de servidor.
- **Matching antes do cliente LLM:** é o núcleo do serviço e não depende de rede, como justificado no `PLAN.md`.
- **Campos além do enunciado:** `suites_min` e `posicoes`. Sem `posicoes`, o emp-05 (`interna`) apareceria para quem pediu "frente ou quadra mar".
- **Filtro por tipologia:** uma mesma tipologia precisa atender a todos os critérios. Assim, o emp-07 não combina os 2 dormitórios de uma tipologia com o preço de R$ 690 mil de outra.
- **Menos de 3 resultados:** devolve só o que atende, sem completar a lista.
- **Critério útil:** o perfil só influencia a ordenação, então um pedido só com perfil gera um pedido de mais informação.
- **Validação em faixas plausíveis:** dormitórios e suítes de 0 a 10, orçamento de R$ 50 mil a R$ 100 milhões, entrega entre o ano atual e o atual + 15. Um orçamento de `1.2` vira erro, em vez de buscar imóveis de R$ 1,20.
- **Modo fake explícito:** `--fake` precisa ser pedido. Sem chave e sem a flag, o comando falha, para que uma resposta escrita à mão nunca passe por uma resposta real.
- **Justificativa por template:** usa dados reais da tipologia, sem custo de LLM e sem risco de inventar informação.
- **HTTP direto com `Req`:** não há SDK oficial da Anthropic para Elixir.
- **Fallback de recusa:** o adapter envia `fallbacks: "default"`, com o header beta correspondente. Esse trecho também não foi testado na API real.

## O que ficou de fora

- Chamada real ao LLM, por falta de chave.
- Bônus de retry e cache. Do bônus de timeout, só há o limite de 30 segundos por requisição.
- Justificativa gerada pelo LLM.
- Endpoint `POST /qualificar` (o enunciado pede para escolher um).

## O que faria com mais 2 horas

1. Rodar os 3 pedidos no LLM real com uma chave, ajustar o prompt e guardar as respostas como casos de teste.
2. Criar um teste `@tag :live` e um conjunto de avaliação com mais gírias e abreviações.
3. Adicionar retry para erros 429 e 5xx, além de cache de extrações repetidas.
4. Revisar os pesos do ranking com alguém que conheça o mercado, porque os atuais são uma escolha inicial minha.
5. Explicar no resultado quando faltam critérios, como no pedido "apto grande", em que o tamanho não vira filtro.

## Uso de IA

**Ferramenta:** Claude Code (Claude Opus 5.5), no aplicativo desktop. A IA fez o plano, escreveu o código e os testes e rodou os commits. O condutor do teste decidiu o rumo, criou o repositório e definiu a linguagem e o trabalho sem chave de API.

**Como o resultado foi validado:** os resultados esperados dos pedidos foram calculados a partir do catálogo e gravados no `PLAN.md` antes do código, e os testes verificam esses valores. A mix task também foi executada de verdade nos pedidos de exemplo e nos casos de erro.

**Onde ela errou e o que foi corrigido:**

- **Sintaxe de mapa:** escreveu `@pesos` com uma chave `nil =>` depois de chaves `chave:`, o que não compila. O `mix format` acusou o erro e a ordem foi corrigida antes do commit.
- **Comando inexistente:** usou `mix new --force`, opção que não existe.
- **Validação do ambiente:** cortou a saída do `mix new` com `Select-Object -First 4`, o que quebrou a geração no meio. O `mix test` "passou" sem rodar nenhum teste, e a validação precisou ser refeita.
- **Instalação:** não previu que a instalação silenciosa do `winget` deixaria Erlang e Elixir fora do PATH.
- **Versão gerada:** o `mix new` gerou `elixir: "~> 1.20"`, mais restritivo que o enunciado. Foi trocado por `~> 1.15`.
- **Dependência:** pediu `req ~> 0.5` e os testes usaram um adapter em forma de função, que o Req 0.7 marca como depreciado. Os testes passaram a usar um módulo, e a dependência virou `~> 0.7`.
- **Compatibilidade não testada:** o `mix.exs` declara Elixir 1.15+, mas o projeto só rodou com 1.20.4 e OTP 29.

**O que não foi validado:** a qualidade do prompt e o contrato real da API, como explicado em [Limitação importante](#limitação-importante).
