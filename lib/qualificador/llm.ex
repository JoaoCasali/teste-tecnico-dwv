defmodule Qualificador.LLM do
  @moduledoc """
  Contrato do cliente de LLM.

  Recebe o prompt de sistema e o texto do usuário e devolve o texto gerado. Quem
  chama é responsável por validar esse texto.
  """

  @callback completar(sistema :: String.t(), texto :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Adapter em uso: `opts[:adapter]` ou o configurado em `:llm_adapter`.
  """
  def adapter(opts \\ []) do
    Keyword.get_lazy(opts, :adapter, fn ->
      Application.fetch_env!(:qualificador, :llm_adapter)
    end)
  end
end
