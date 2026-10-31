defmodule Qualificador.ExtracaoTest do
  use ExUnit.Case, async: true

  alias Qualificador.{Extracao, Pedido}

  @hoje ~D[2026-10-31]

  defp extrair(texto \\ "qualquer", resposta) do
    Extracao.extrair(texto, hoje: @hoje, resposta: resposta)
  end

  defp json(mapa), do: Jason.encode!(mapa)

  describe "pedidos de exemplo, com as respostas escritas à mão no Fake" do
    test "caso claro" do
      texto =
        "cliente procurando 3 suites em itapema, frente ou quadra mar, até 2,5mi, entrega até 2027"

      assert Extracao.extrair(texto, hoje: @hoje) ==
               {:ok,
                %Pedido{
                  cidade: "Itapema",
                  dormitorios_min: 3,
                  suites_min: 3,
                  orcamento_max: 2_500_000,
                  entrega_max: 2027,
                  posicoes: [:frente_mar, :quadra_mar]
                }}
    end

    test "texto sem critérios vira pedido vazio" do
      assert Extracao.extrair("oi, tem algo bom?", hoje: @hoje) == {:ok, %Pedido{}}
    end
  end

  describe "respostas válidas" do
    test "chaves ausentes viram nil e desconhecidas são ignoradas" do
      assert extrair(json(%{"cidade" => "Itapema", "extra" => 1})) ==
               {:ok, %Pedido{cidade: "Itapema"}}
    end

    test "aceita JSON cercado por bloco de código" do
      assert extrair("```json\n{\"perfil\": \"moradia\"}\n```") ==
               {:ok, %Pedido{perfil: :moradia}}
    end

    test "expande apelido de cidade" do
      assert {:ok, %Pedido{cidade: "Balneário Camboriú"}} = extrair(json(%{"cidade" => "BC"}))
    end

    test "orçamento decimal é arredondado" do
      assert {:ok, %Pedido{orcamento_max: 1_200_000}} =
               extrair(json(%{"orcamento_max" => 1_200_000.0}))
    end

    test "lista de posições vazia equivale a não informar" do
      assert extrair(json(%{"posicoes" => []})) == {:ok, %Pedido{}}
    end
  end

  describe "respostas inválidas não derrubam o serviço" do
    test "não é JSON" do
      assert extrair("desculpe, não entendi") == {:error, :json_invalido}
      assert extrair("") == {:error, :json_invalido}
    end

    test "JSON que não é objeto" do
      assert extrair("[1, 2]") == {:error, :json_nao_e_objeto}
      assert extrair("null") == {:error, :json_nao_e_objeto}
    end

    for {campo, valor} <- [
          {:dormitorios_min, -1},
          {:dormitorios_min, 500},
          {:dormitorios_min, "3"},
          {:suites_min, 2.5},
          {:orcamento_max, 1.2},
          {:orcamento_max, 0},
          {:orcamento_max, 1_000_000_000},
          {:orcamento_max, "muito"},
          {:entrega_max, 1999},
          {:entrega_max, 3000},
          {:posicoes, "frente_mar"},
          {:posicoes, ["lua"]},
          {:posicoes, [1]},
          {:perfil, "turista"},
          {:perfil, 1},
          {:cidade, 42}
        ] do
      test "#{campo} = #{inspect(valor)}" do
        campo = unquote(campo)
        valor = unquote(Macro.escape(valor))

        assert extrair(json(%{Atom.to_string(campo) => valor})) ==
                 {:error, {:campo_invalido, campo, valor}}
      end
    end

    test "erro do adapter é repassado" do
      assert extrair({:error, :timeout}) == {:error, :timeout}
    end
  end

  describe "prompt/1" do
    test "informa a data, para resolver prazos relativos" do
      assert Extracao.prompt(@hoje) =~ "2026-10-31"
    end
  end
end
