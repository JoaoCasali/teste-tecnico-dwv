defmodule Qualificador.CatalogoTest do
  use ExUnit.Case, async: true

  alias Qualificador.Catalogo
  alias Qualificador.Catalogo.{Empreendimento, Tipologia}

  test "carrega os 10 empreendimentos do catálogo" do
    assert {:ok, catalogo} = Catalogo.carregar()
    assert length(catalogo) == 10
  end

  test "converte campos em structs, com posição como átomo" do
    {:ok, catalogo} = Catalogo.carregar()

    assert %Empreendimento{
             id: "emp-07",
             cidade: "Balneário Camboriú",
             posicao: :quadra_mar,
             entrega: 2027,
             tipologias: [
               %Tipologia{dormitorios: 1, suites: 1, area_m2: 42, preco: 690_000},
               %Tipologia{dormitorios: 2, suites: 1, area_m2: 71, preco: 1_190_000}
             ]
           } = Enum.find(catalogo, &(&1.id == "emp-07"))
  end

  test "arquivo inexistente vira erro" do
    assert {:error, {:catalogo_ilegivel, :enoent}} = Catalogo.carregar("nao/existe.json")
  end

  test "estrutura inesperada vira erro em vez de exceção" do
    assert {:error, :catalogo_malformado} = Catalogo.parse(%{"a" => 1})
    assert {:error, :catalogo_malformado} = Catalogo.parse([%{"id" => "x"}])

    assert {:error, :catalogo_malformado} =
             Catalogo.parse([
               %{
                 "id" => "x",
                 "nome" => "n",
                 "cidade" => "c",
                 "bairro" => "b",
                 "posicao" => "lua",
                 "entrega" => 2027,
                 "tipologias" => []
               }
             ])
  end
end
