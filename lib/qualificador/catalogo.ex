defmodule Qualificador.Catalogo do
  @moduledoc """
  Leitura e parse do catálogo de empreendimentos em structs.
  """

  defmodule Tipologia do
    @moduledoc false
    @enforce_keys [:dormitorios, :suites, :area_m2, :preco]
    defstruct [:dormitorios, :suites, :area_m2, :preco]
  end

  defmodule Empreendimento do
    @moduledoc false
    @enforce_keys [:id, :nome, :cidade, :bairro, :posicao, :entrega, :tipologias]
    defstruct [:id, :nome, :cidade, :bairro, :posicao, :entrega, :tipologias]
  end

  @posicoes %{
    "frente_mar" => :frente_mar,
    "quadra_mar" => :quadra_mar,
    "interna" => :interna
  }

  @doc """
  Carrega o catálogo. Sem argumento, lê `priv/catalogo.json`.
  """
  def carregar(caminho \\ Application.app_dir(:qualificador, "priv/catalogo.json")) do
    with {:ok, conteudo} <- File.read(caminho),
         {:ok, dados} <- Jason.decode(conteudo) do
      parse(dados)
    else
      {:error, %Jason.DecodeError{}} -> {:error, :catalogo_json_invalido}
      {:error, motivo} -> {:error, {:catalogo_ilegivel, motivo}}
    end
  end

  @doc """
  Converte a lista decodificada do JSON em structs.
  """
  def parse(dados) when is_list(dados) do
    {:ok, Enum.map(dados, &empreendimento/1)}
  rescue
    _ in [FunctionClauseError, MatchError, KeyError, CaseClauseError] ->
      {:error, :catalogo_malformado}
  end

  def parse(_dados), do: {:error, :catalogo_malformado}

  defp empreendimento(%{
         "id" => id,
         "nome" => nome,
         "cidade" => cidade,
         "bairro" => bairro,
         "posicao" => posicao,
         "entrega" => entrega,
         "tipologias" => tipologias
       }) do
    %Empreendimento{
      id: id,
      nome: nome,
      cidade: cidade,
      bairro: bairro,
      posicao: Map.fetch!(@posicoes, posicao),
      entrega: entrega,
      tipologias: Enum.map(tipologias, &tipologia/1)
    }
  end

  defp tipologia(%{
         "dormitorios" => dormitorios,
         "suites" => suites,
         "area_m2" => area_m2,
         "preco" => preco
       }) do
    %Tipologia{dormitorios: dormitorios, suites: suites, area_m2: area_m2, preco: preco}
  end
end
