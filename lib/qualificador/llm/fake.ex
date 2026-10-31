defmodule Qualificador.LLM.Fake do
  @moduledoc """
  Adapter sem rede, para testes e para rodar sem chave de API.

  As respostas dos pedidos de `priv/pedidos.txt` foram escritas à mão: mostram o
  que se espera do LLM, não o que um LLM de fato respondeu. Qualquer outro texto
  vira um pedido sem critérios. `opts[:resposta]` força a resposta, inclusive
  `{:error, motivo}`.
  """

  @behaviour Qualificador.LLM

  @sem_criterios ~s({"cidade":null,"dormitorios_min":null,"suites_min":null,"orcamento_max":null,"entrega_max":null,"posicoes":null,"perfil":null})

  @respostas %{
    "cliente procurando 3 suites em itapema, frente ou quadra mar, até 2,5mi, entrega até 2027" =>
      ~s({"cidade":"Itapema","dormitorios_min":3,"suites_min":3,"orcamento_max":2500000,"entrega_max":2027,"posicoes":["frente_mar","quadra_mar"],"perfil":null}),
    "tem algo 2 dorms em BC até 1.2? investidor, quer pra temporada" =>
      ~s({"cidade":"Balneário Camboriú","dormitorios_min":2,"suites_min":null,"orcamento_max":1200000,"entrega_max":null,"posicoes":null,"perfil":"investimento"}),
    "quero um apto grande pra família, orçamento 4 milhões" =>
      ~s({"cidade":null,"dormitorios_min":null,"suites_min":null,"orcamento_max":4000000,"entrega_max":null,"posicoes":null,"perfil":"moradia"})
  }

  @impl true
  def completar(_sistema, texto, opts \\ []) do
    case Keyword.fetch(opts, :resposta) do
      {:ok, {:error, _motivo} = erro} -> erro
      {:ok, resposta} -> {:ok, resposta}
      :error -> {:ok, Map.get(@respostas, String.trim(texto), @sem_criterios)}
    end
  end
end
