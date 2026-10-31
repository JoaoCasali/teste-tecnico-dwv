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

  @nome_destaque [
    area: "maior área",
    preco_m2: "menor preço por m²",
    entrega: "entrega mais próxima",
    posicao: "melhor posição"
  ]

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
    |> Enum.map(&Map.put(&1, :justificativa, justificar(&1, pedido, referencia)))
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
    {menor_area, maior_area} =
      candidatos |> Enum.map(fn {_, t} -> t.area_m2 end) |> Enum.min_max()

    {menor_preco_m2, maior_preco_m2} =
      candidatos |> Enum.map(fn {_, t} -> preco_m2(t) end) |> Enum.min_max()

    {pior_posicao, melhor_posicao} =
      candidatos
      |> Enum.map(fn {e, _} -> Map.fetch!(@valor_posicao, e.posicao) end)
      |> Enum.min_max()

    {primeira_entrega, ultima_entrega} =
      candidatos |> Enum.map(fn {e, _} -> e.entrega end) |> Enum.min_max()

    %{
      menor_area: menor_area,
      maior_area: maior_area,
      menor_preco_m2: menor_preco_m2,
      maior_preco_m2: maior_preco_m2,
      pior_posicao: pior_posicao,
      melhor_posicao: melhor_posicao,
      primeira_entrega: primeira_entrega,
      ultima_entrega: ultima_entrega
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

  defp justificar(opcao, pedido, referencia) do
    dados(opcao, pedido.perfil) <> motivo(opcao, pedido, referencia)
  end

  defp dados(%{empreendimento: empreendimento, tipologia: tipologia}, perfil) do
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

  defp motivo(opcao, pedido, referencia) do
    atende =
      case Pedido.criterios_informados(pedido) do
        [] -> ""
        criterios -> ". Atende a #{Pedido.enumerar(criterios)}"
      end

    destaques =
      case destaques(opcao, pedido.perfil, referencia) do
        [] -> ""
        lista -> "; destaque: #{Pedido.enumerar(lista)} entre as opções compatíveis"
      end

    atende <> destaques
  end

  # Só cita o que é verdade para esta opção, e só os fatores que pesam no perfil.
  defp destaques(%{empreendimento: empreendimento, tipologia: tipologia}, perfil, referencia) do
    pesos = Map.fetch!(@pesos, perfil)

    for {fator, nome} <- @nome_destaque,
        Map.has_key?(pesos, fator),
        melhor_em?(fator, empreendimento, tipologia, referencia) do
      nome
    end
  end

  # Em empate geral, ninguém se destaca.
  defp melhor_em?(:area, _empreendimento, _tipologia, %{maior_area: igual, menor_area: igual}) do
    false
  end

  defp melhor_em?(:preco_m2, _empreendimento, _tipologia, %{
         menor_preco_m2: igual,
         maior_preco_m2: igual
       }) do
    false
  end

  defp melhor_em?(:posicao, _empreendimento, _tipologia, %{
         melhor_posicao: igual,
         pior_posicao: igual
       }) do
    false
  end

  defp melhor_em?(:entrega, _empreendimento, _tipologia, %{
         primeira_entrega: igual,
         ultima_entrega: igual
       }) do
    false
  end

  defp melhor_em?(:area, _empreendimento, tipologia, referencia) do
    tipologia.area_m2 == referencia.maior_area
  end

  defp melhor_em?(:preco_m2, _empreendimento, tipologia, referencia) do
    preco_m2(tipologia) == referencia.menor_preco_m2
  end

  defp melhor_em?(:posicao, empreendimento, _tipologia, referencia) do
    Map.fetch!(@valor_posicao, empreendimento.posicao) == referencia.melhor_posicao
  end

  defp melhor_em?(:entrega, empreendimento, _tipologia, referencia) do
    empreendimento.entrega == referencia.primeira_entrega
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
