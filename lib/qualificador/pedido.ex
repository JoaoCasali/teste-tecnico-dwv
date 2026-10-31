defmodule Qualificador.Pedido do
  @moduledoc """
  O que o corretor pediu. Qualquer campo pode ser `nil` se o texto não disser.

  `suites_min` e `posicoes` vão além do enunciado: sem eles, "3 suítes, frente
  ou quadra mar" traria apartamentos que o corretor excluiu explicitamente.
  """

  defstruct [
    :cidade,
    :dormitorios_min,
    :suites_min,
    :orcamento_max,
    :entrega_max,
    :posicoes,
    :perfil
  ]

  @criterios [:cidade, :dormitorios_min, :suites_min, :orcamento_max, :entrega_max, :posicoes]

  @doc """
  Diz se o pedido tem algum critério que restrinja o catálogo.

  O perfil só influencia a ordenação, então sozinho não conta.
  """
  def util?(%__MODULE__{} = pedido) do
    Enum.any?(@criterios, &(Map.fetch!(pedido, &1) not in [nil, []]))
  end
end
