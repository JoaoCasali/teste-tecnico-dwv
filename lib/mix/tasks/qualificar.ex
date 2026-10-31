defmodule Mix.Tasks.Qualificar do
  @shortdoc "Sugere até 3 empreendimentos para um pedido em texto livre"

  @moduledoc """
  Sugere empreendimentos para um pedido de corretor.

      mix qualificar "tem algo 2 dorms em BC até 1.2? investidor"

  Usa o LLM real, que exige `ANTHROPIC_API_KEY`. Com `--fake`, usa as respostas
  escritas à mão para os pedidos de `priv/pedidos.txt`, sem rede e sem chave.
  """

  use Mix.Task

  alias Qualificador.LLM.Fake
  alias Qualificador.Pedido

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {:ok, _apps} = Application.ensure_all_started(:req)

    case OptionParser.parse(args, strict: [fake: :boolean]) do
      {opcoes, [texto], []} -> executar(texto, opcoes)
      _invalido -> Mix.raise(~s(Uso: mix qualificar [--fake] "texto do pedido"))
    end
  end

  defp executar(texto, opcoes) do
    opts = if opcoes[:fake], do: [adapter: Fake], else: []

    texto
    |> Qualificador.qualificar(opts)
    |> imprimir()
  end

  defp imprimir({:ok, %{opcoes: []}}) do
    Mix.shell().info("Nenhum empreendimento do catálogo atende a esse pedido.")
  end

  defp imprimir({:ok, %{opcoes: opcoes, faltantes: faltantes}}) do
    opcoes
    |> Enum.with_index(1)
    |> Enum.each(fn {opcao, posicao} ->
      Mix.shell().info("#{posicao}. #{opcao.empreendimento.nome}: #{opcao.justificativa}")
    end)

    if faltantes != [] do
      Mix.shell().info("\nPara refinar a busca, informe também: #{Pedido.enumerar(faltantes)}.")
    end
  end

  defp imprimir({:mais_info, mensagem}), do: Mix.shell().info(mensagem)

  defp imprimir({:error, :sem_api_key}) do
    Mix.raise("Defina ANTHROPIC_API_KEY ou use --fake para rodar sem LLM real.")
  end

  defp imprimir({:error, motivo}) do
    Mix.raise("Não foi possível qualificar o pedido: #{inspect(motivo)}")
  end
end
