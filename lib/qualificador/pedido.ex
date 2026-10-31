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

  @criterios [
    cidade: "cidade",
    dormitorios_min: "dormitórios",
    suites_min: "suítes",
    orcamento_max: "orçamento",
    entrega_max: "prazo de entrega",
    posicoes: "posição"
  ]

  @comodos_max 10
  @orcamento_min 50_000
  @orcamento_max 100_000_000
  @horizonte_entrega_anos 15

  @posicoes %{
    "frente_mar" => :frente_mar,
    "quadra_mar" => :quadra_mar,
    "interna" => :interna
  }

  @perfis %{"moradia" => :moradia, "investimento" => :investimento}

  @apelidos_cidade %{
    "bc" => "Balneário Camboriú",
    "balneario" => "Balneário Camboriú",
    "balneário" => "Balneário Camboriú"
  }

  @doc """
  Valida um mapa vindo de fora e o converte em `Pedido`.

  Chaves ausentes viram `nil` e chaves desconhecidas são ignoradas. Valor de tipo
  errado ou fora de uma faixa plausível vira `{:error, {:campo_invalido, campo, valor}}`.
  """
  def validar(dados, ano_atual) when is_map(dados) do
    with {:ok, cidade} <- campo(dados, :cidade, &cidade/1),
         {:ok, dormitorios} <- campo(dados, :dormitorios_min, &comodos/1),
         {:ok, suites} <- campo(dados, :suites_min, &comodos/1),
         {:ok, orcamento} <- campo(dados, :orcamento_max, &orcamento/1),
         {:ok, entrega} <- campo(dados, :entrega_max, &entrega(&1, ano_atual)),
         {:ok, posicoes} <- campo(dados, :posicoes, &posicoes/1),
         {:ok, perfil} <- campo(dados, :perfil, &Map.fetch(@perfis, &1)) do
      {:ok,
       %__MODULE__{
         cidade: cidade,
         dormitorios_min: dormitorios,
         suites_min: suites,
         orcamento_max: orcamento,
         entrega_max: entrega,
         posicoes: posicoes,
         perfil: perfil
       }}
    end
  end

  defp campo(dados, nome, validador) do
    case Map.get(dados, Atom.to_string(nome)) do
      nil ->
        {:ok, nil}

      valor ->
        case validador.(valor) do
          {:ok, valido} -> {:ok, valido}
          :error -> {:error, {:campo_invalido, nome, valor}}
        end
    end
  end

  defp cidade(valor) when is_binary(valor) do
    case String.trim(valor) do
      "" -> {:ok, nil}
      nome -> {:ok, Map.get(@apelidos_cidade, String.downcase(nome), nome)}
    end
  end

  defp cidade(_valor), do: :error

  defp comodos(valor) when is_integer(valor) and valor in 0..@comodos_max, do: {:ok, valor}
  defp comodos(_valor), do: :error

  defp orcamento(valor)
       when is_number(valor) and valor >= @orcamento_min and valor <= @orcamento_max do
    {:ok, round(valor)}
  end

  defp orcamento(_valor), do: :error

  defp entrega(valor, ano_atual)
       when is_integer(valor) and valor >= ano_atual and
              valor <= ano_atual + @horizonte_entrega_anos do
    {:ok, valor}
  end

  defp entrega(_valor, _ano_atual), do: :error

  defp posicoes([]), do: {:ok, nil}

  defp posicoes(valores) when is_list(valores) do
    convertidas = Enum.map(valores, &(is_binary(&1) && Map.get(@posicoes, &1)))

    if Enum.all?(convertidas), do: {:ok, convertidas}, else: :error
  end

  defp posicoes(_valores), do: :error

  @doc """
  Diz se o pedido tem algum critério que restrinja o catálogo.

  O perfil só influencia a ordenação, então sozinho não conta.
  """
  def util?(%__MODULE__{} = pedido) do
    criterios_informados(pedido) != []
  end

  @doc """
  Nomes legíveis dos critérios que o pedido informou.
  """
  def criterios_informados(%__MODULE__{} = pedido) do
    for {campo, nome} <- @criterios, Map.fetch!(pedido, campo) not in [nil, []], do: nome
  end

  @doc """
  Junta nomes em uma enumeração: `["a", "b", "c"]` vira `"a, b e c"`.
  """
  def enumerar([]), do: ""
  def enumerar([unico]), do: unico

  def enumerar(nomes) do
    {inicio, [ultimo]} = Enum.split(nomes, -1)
    Enum.join(inicio, ", ") <> " e " <> ultimo
  end
end
