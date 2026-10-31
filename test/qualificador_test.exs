defmodule QualificadorTest do
  use ExUnit.Case, async: true

  defp ids({:ok, %{opcoes: opcoes}}), do: Enum.map(opcoes, & &1.empreendimento.id)

  describe "fluxo completo, com o adapter fake" do
    test "pedidos de exemplo" do
      esperados = [
        ["emp-01", "emp-03"],
        ["emp-02", "emp-07"],
        ["emp-09", "emp-04", "emp-01"]
      ]

      pedidos =
        "priv/pedidos.txt"
        |> File.read!()
        |> String.split("\n", trim: true)

      assert Enum.map(pedidos, &ids(Qualificador.qualificar(&1))) == esperados
    end

    test "cada opção traz uma justificativa de uma linha" do
      {:ok, %{opcoes: opcoes}} =
        Qualificador.qualificar("x", resposta: ~s({"cidade": "Itapema"}))

      for opcao <- opcoes do
        assert opcao.justificativa != ""
        refute opcao.justificativa =~ "\n"
      end
    end
  end

  describe "critérios faltantes" do
    test "pedido incompleto lista o que refinaria a busca, sem deixar de trazer opções" do
      assert {:ok, %{opcoes: [_, _, _], faltantes: faltantes}} =
               Qualificador.qualificar("quero um apto grande pra família, orçamento 4 milhões")

      assert faltantes == ["cidade", "dormitórios", "prazo de entrega"]
    end

    test "pedido completo não tem faltantes" do
      texto =
        "cliente procurando 3 suites em itapema, frente ou quadra mar, até 2,5mi, entrega até 2027"

      assert {:ok, %{faltantes: []}} = Qualificador.qualificar(texto)
    end
  end

  describe "pedido sem critério útil pede mais informação" do
    test "nenhum campo" do
      assert {:mais_info, _} = Qualificador.qualificar("oi, tem algo bom?")
    end

    test "só perfil" do
      assert {:mais_info, _} =
               Qualificador.qualificar("x", resposta: ~s({"perfil": "moradia"}))
    end

    test "texto em branco nem chama o LLM" do
      assert {:mais_info, _} =
               Qualificador.qualificar("   ", resposta: {:error, :nao_deveria_chamar})
    end
  end

  test "nada atende: lista vazia, sem opções aleatórias" do
    assert {:ok, %{opcoes: []}} =
             Qualificador.qualificar("x", resposta: ~s({"cidade": "Florianópolis"}))
  end

  test "resposta inválida do LLM vira erro" do
    assert Qualificador.qualificar("x", resposta: "lixo") == {:error, :json_invalido}
  end

  test "catálogo pode ser injetado" do
    assert {:ok, %{opcoes: []}} =
             Qualificador.qualificar("x", resposta: ~s({"cidade": "Itapema"}), catalogo: [])
  end
end
