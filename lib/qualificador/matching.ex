defmodule Qualificador.Matching do
  @moduledoc """
  Filtra o catálogo pelas restrições do pedido e ordena por aderência.

  Só funções puras, sem LLM e sem rede.
  """

  alias Qualificador.Catalogo.{Empreendimento, Tipologia}
  alias Qualificador.Pedido

  @limite 3

  @pesos %{
    nil => %{posicao: 0.7, area: 0.3},
    moradia: %{area: 0.8, posicao: 0.2},
    investimento: %{preco_m2: 0.5, entrega: 0.3, posicao: 0.2}
  }

  @valor_posicao %{frente_mar: 1.0, quadra_mar: 0.7, interna: 0.3}

  @nome_posicao %{frente_mar: "Frente mar", quadra_mar: "Quadra mar", interna: "Interna"}

  @doc """
  Devolve até 3 opções, da mais aderente para a menos aderente.

  Cada opção traz o empreendimento, a tipologia que atende ao pedido, a
  pontuação e uma justificativa de uma linha. A lista nunca é completada com
  opções que não atendem.
  """
  def buscar(%Pedido{} = pedido, catalogo) do
    candidatos = candidatos(pedido, catalogo)
    referencia = referencia(candidatos)

    candidatos
    |> Enum.map(fn {empreendimento, tipologia} ->
      %{
        empreendimento: empreendimento,
        tipologia: tipologia,
        pontuacao: pontuar(empreendimento, tipologia, pedido.perfil, referencia)
      }
    end)
    |> Enum.sort_by(&{-&1.pontuacao, &1.empreendimento.id})
    |> Enum.uniq_by(& &1.empreendimento.id)
    |> Enum.take(@limite)
    |> Enum.map(&Map.put(&1, :justificativa, justificar(&1, pedido.perfil)))
  end

  # Cada tipologia é avaliada inteira, para não combinar os dormitórios de uma
  # com o preço de outra.
  defp candidatos(pedido, catalogo) do
    for empreendimento <- catalogo,
        atende_empreendimento?(empreendimento, pedido),
        tipologia <- empreendimento.tipologias,
        atende_tipologia?(tipologia, pedido) do
      {empreendimento, tipologia}
    end
  end

  defp atende_empreendimento?(%Empreendimento{} = empreendimento, pedido) do
    mesma_cidade?(empreendimento.cidade, pedido.cidade) and
      no_maximo?(empreendimento.entrega, pedido.entrega_max) and
      posicao_aceita?(empreendimento.posicao, pedido.posicoes)
  end

  defp atende_tipologia?(%Tipologia{} = tipologia, pedido) do
    no_minimo?(tipologia.dormitorios, pedido.dormitorios_min) and
      no_minimo?(tipologia.suites, pedido.suites_min) and
      no_maximo?(tipologia.preco, pedido.orcamento_max)
  end

  defp mesma_cidade?(_cidade, nil), do: true
  defp mesma_cidade?(cidade, desejada), do: normalizar(cidade) == normalizar(desejada)

  defp no_maximo?(_valor, nil), do: true
  defp no_maximo?(valor, limite), do: valor <= limite

  defp no_minimo?(_valor, nil), do: true
  defp no_minimo?(valor, limite), do: valor >= limite

  defp posicao_aceita?(_posicao, posicoes) when posicoes in [nil, []], do: true
  defp posicao_aceita?(posicao, posicoes), do: posicao in posicoes

  defp normalizar(texto) do
    texto
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.trim()
  end

  defp referencia([]), do: nil

  defp referencia(candidatos) do
    entregas = Enum.map(candidatos, fn {empreendimento, _} -> empreendimento.entrega end)

    %{
      maior_area: candidatos |> Enum.map(fn {_, t} -> t.area_m2 end) |> Enum.max(),
      menor_preco_m2: candidatos |> Enum.map(fn {_, t} -> preco_m2(t) end) |> Enum.min(),
      primeira_entrega: Enum.min(entregas),
      ultima_entrega: Enum.max(entregas)
    }
  end

  defp pontuar(empreendimento, tipologia, perfil, referencia) do
    @pesos
    |> Map.fetch!(perfil)
    |> Enum.map(fn {fator, peso} ->
      peso * fator(fator, empreendimento, tipologia, referencia)
    end)
    |> Enum.sum()
  end

  defp fator(:area, _empreendimento, tipologia, referencia) do
    tipologia.area_m2 / referencia.maior_area
  end

  defp fator(:preco_m2, _empreendimento, tipologia, referencia) do
    referencia.menor_preco_m2 / preco_m2(tipologia)
  end

  defp fator(:posicao, empreendimento, _tipologia, _referencia) do
    Map.fetch!(@valor_posicao, empreendimento.posicao)
  end

  defp fator(:entrega, _empreendimento, _tipologia, %{
         primeira_entrega: mesma,
         ultima_entrega: mesma
       }) do
    1.0
  end

  defp fator(:entrega, empreendimento, _tipologia, referencia) do
    (referencia.ultima_entrega - empreendimento.entrega) /
      (referencia.ultima_entrega - referencia.primeira_entrega)
  end

  defp preco_m2(tipologia), do: tipologia.preco / tipologia.area_m2

  defp justificar(%{empreendimento: empreendimento, tipologia: tipologia}, perfil) do
    base =
      "#{Map.fetch!(@nome_posicao, empreendimento.posicao)} em #{empreendimento.cidade} " <>
        "(#{empreendimento.bairro}): #{tipologia.dormitorios} dorm., " <>
        "#{tipologia.suites} suíte(s), #{tipologia.area_m2} m², " <>
        "#{formatar_preco(tipologia.preco)}, entrega #{empreendimento.entrega}"

    case perfil do
      :investimento -> base <> ", #{formatar_preco(round(preco_m2(tipologia)))}/m²"
      _ -> base
    end
  end

  defp formatar_preco(preco) when preco >= 1_000_000 do
    "R$ #{formatar_decimal(preco / 1_000_000)} mi"
  end

  defp formatar_preco(preco), do: "R$ #{formatar_decimal(preco / 1_000)} mil"

  defp formatar_decimal(valor) do
    texto = :erlang.float_to_binary(valor, decimals: 2)

    texto
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
    |> String.replace(".", ",")
  end
end
