defmodule QualificadorTest do
  use ExUnit.Case, async: true

  defp ids({:ok, opcoes}), do: Enum.map(opcoes, & &1.empreendimento.id)

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
      {:ok, opcoes} =
        Qualificador.qualificar("x", resposta: ~s({"cidade": "Itapema"}))

      for opcao <- opcoes do
        assert opcao.justificativa != ""
        refute opcao.justificativa =~ "\n"
      end
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
    assert Qualificador.qualificar("x", resposta: ~s({"cidade": "Florianópolis"})) == {:ok, []}
  end

  test "resposta inválida do LLM vira erro" do
    assert Qualificador.qualificar("x", resposta: "lixo") == {:error, :json_invalido}
  end

  test "catálogo pode ser injetado" do
    assert Qualificador.qualificar("x", resposta: ~s({"cidade": "Itapema"}), catalogo: []) ==
             {:ok, []}
  end
end
