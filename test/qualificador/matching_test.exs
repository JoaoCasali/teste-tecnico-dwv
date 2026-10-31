defmodule Qualificador.MatchingTest do
  use ExUnit.Case, async: true

  alias Qualificador.{Catalogo, Matching, Pedido}

  setup_all do
    {:ok, catalogo} = Catalogo.carregar()
    %{catalogo: catalogo}
  end

  defp ids(resultados), do: Enum.map(resultados, & &1.empreendimento.id)

  describe "pedidos de teste" do
    test "3 suítes em Itapema, frente ou quadra mar, até 2,5 mi, até 2027", %{catalogo: catalogo} do
      pedido = %Pedido{
        cidade: "Itapema",
        dormitorios_min: 3,
        suites_min: 3,
        orcamento_max: 2_500_000,
        entrega_max: 2027,
        posicoes: [:frente_mar, :quadra_mar]
      }

      assert ids(Matching.buscar(pedido, catalogo)) == ["emp-01", "emp-03"]
    end

    test "2 dorms em BC até 1,2 mi, investidor", %{catalogo: catalogo} do
      pedido = %Pedido{
        cidade: "Balneário Camboriú",
        dormitorios_min: 2,
        orcamento_max: 1_200_000,
        perfil: :investimento
      }

      assert ids(Matching.buscar(pedido, catalogo)) == ["emp-02", "emp-07"]
    end

    test "apto grande para família, 4 mi, ordena por área", %{catalogo: catalogo} do
      pedido = %Pedido{orcamento_max: 4_000_000, perfil: :moradia}

      assert ids(Matching.buscar(pedido, catalogo)) == ["emp-09", "emp-04", "emp-01"]
    end
  end

  describe "filtros" do
    test "uma mesma tipologia precisa atender a todos os critérios", %{catalogo: catalogo} do
      # O emp-07 tem 2 dorm. por 1,19 mi e 1 dorm. por 690 mil: combinar os dois daria falso positivo.
      pedido = %Pedido{cidade: "Balneário Camboriú", dormitorios_min: 2, orcamento_max: 700_000}

      assert Matching.buscar(pedido, catalogo) == []
    end

    test "usa a tipologia que atende, não a primeira", %{catalogo: catalogo} do
      pedido = %Pedido{cidade: "Itapema", dormitorios_min: 4, orcamento_max: 3_500_000}

      assert [%{empreendimento: %{id: "emp-01"}, tipologia: %{dormitorios: 4}}] =
               Matching.buscar(pedido, catalogo)
    end

    test "posição interna fica de fora quando o pedido exige mar", %{catalogo: catalogo} do
      pedido = %Pedido{cidade: "Itapema", posicoes: [:frente_mar, :quadra_mar]}

      refute "emp-05" in ids(Matching.buscar(pedido, catalogo))
    end

    test "cidade ignora acento e caixa", %{catalogo: catalogo} do
      pedido = %Pedido{cidade: "balneario camboriu"}

      assert length(Matching.buscar(pedido, catalogo)) == 3
    end

    test "cidade fora do catálogo não traz nada", %{catalogo: catalogo} do
      assert Matching.buscar(%Pedido{cidade: "Florianópolis"}, catalogo) == []
    end
  end

  describe "resultado" do
    test "devolve no máximo 3 opções, sem repetir empreendimento", %{catalogo: catalogo} do
      resultados = Matching.buscar(%Pedido{dormitorios_min: 1}, catalogo)

      assert length(resultados) == 3
      assert ids(resultados) == Enum.uniq(ids(resultados))
    end

    test "é determinístico", %{catalogo: catalogo} do
      pedido = %Pedido{cidade: "Itapema"}

      assert Matching.buscar(pedido, catalogo) == Matching.buscar(pedido, Enum.reverse(catalogo))
    end

    test "justificativa traz os dados da tipologia escolhida", %{catalogo: catalogo} do
      pedido = %Pedido{cidade: "Itapema", dormitorios_min: 3, orcamento_max: 2_500_000}
      [primeiro | _] = Matching.buscar(pedido, catalogo)

      assert primeiro.justificativa ==
               "Frente mar em Itapema (Meia Praia): 3 dorm., 3 suíte(s), 142 m², " <>
                 "R$ 2,35 mi, entrega 2027"
    end

    test "justificativa de investimento inclui o preço por m²", %{catalogo: catalogo} do
      pedido = %Pedido{cidade: "Balneário Camboriú", dormitorios_min: 2, perfil: :investimento}
      [primeiro | _] = Matching.buscar(pedido, catalogo)

      assert primeiro.justificativa =~ "/m²"
    end

    test "catálogo vazio não quebra" do
      assert Matching.buscar(%Pedido{cidade: "Itapema"}, []) == []
    end
  end

  describe "Pedido.util?/1" do
    test "perfil sozinho não é critério útil" do
      refute Pedido.util?(%Pedido{})
      refute Pedido.util?(%Pedido{perfil: :moradia})
      refute Pedido.util?(%Pedido{posicoes: []})
    end

    test "qualquer restrição é critério útil" do
      assert Pedido.util?(%Pedido{orcamento_max: 4_000_000})
      assert Pedido.util?(%Pedido{posicoes: [:frente_mar]})
    end
  end
end
