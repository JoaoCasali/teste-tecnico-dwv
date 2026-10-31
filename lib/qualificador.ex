defmodule Qualificador do
  @moduledoc """
  Entende pedidos de corretores em texto livre e sugere empreendimentos.
  """

  alias Qualificador.{Catalogo, Extracao, Matching, Pedido}

  @mais_info "Preciso de mais informação para sugerir empreendimentos. " <>
               "Informe ao menos um critério: cidade, dormitórios, orçamento ou prazo de entrega."

  @doc """
  Executa o fluxo completo: extração, matching e resposta.

  Devolve `{:ok, opcoes}`, em que a lista pode vir vazia se nada atender,
  `{:mais_info, mensagem}` se o pedido não tiver critério útil ou
  `{:error, motivo}`. Em `opts`, `:catalogo` substitui o catálogo padrão; o resto
  vai para a extração.
  """
  def qualificar(texto, opts \\ []) when is_binary(texto) do
    {catalogo, opts} = Keyword.pop(opts, :catalogo)

    if String.trim(texto) == "" do
      {:mais_info, @mais_info}
    else
      with {:ok, pedido} <- Extracao.extrair(texto, opts) do
        responder(pedido, catalogo)
      end
    end
  end

  defp responder(pedido, catalogo) do
    if Pedido.util?(pedido) do
      with {:ok, catalogo} <- carregar(catalogo) do
        {:ok, Matching.buscar(pedido, catalogo)}
      end
    else
      {:mais_info, @mais_info}
    end
  end

  defp carregar(nil), do: Catalogo.carregar()
  defp carregar(catalogo), do: {:ok, catalogo}
end
