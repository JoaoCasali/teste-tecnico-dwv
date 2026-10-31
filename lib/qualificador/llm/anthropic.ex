defmodule Qualificador.LLM.Anthropic do
  @moduledoc """
  Adapter real, via HTTP na Messages API (não há SDK oficial para Elixir).

  A chave vem de `ANTHROPIC_API_KEY`. Em `opts`, `:api_key`, `:model` e
  `:req_options` sobrepõem os padrões, o que permite testar sem rede.
  """

  @behaviour Qualificador.LLM

  @url "https://api.anthropic.com/v1/messages"
  @versao_api "2026-10-21"
  @beta_fallback "server-side-fallback-2026-07-01"
  @modelo "claude-opus-5-5"
  @max_tokens 16_000
  @timeout_ms 30_000

  @impl true
  def completar(sistema, texto, opts \\ []) do
    case Keyword.get_lazy(opts, :api_key, fn -> System.get_env("ANTHROPIC_API_KEY") end) do
      chave when chave in [nil, ""] -> {:error, :sem_api_key}
      chave -> requisitar(chave, sistema, texto, opts)
    end
  end

  defp requisitar(chave, sistema, texto, opts) do
    corpo = %{
      model: Keyword.get(opts, :model, @modelo),
      max_tokens: @max_tokens,
      system: sistema,
      messages: [%{role: "user", content: texto}],
      output_config: %{effort: "low"},
      fallbacks: "default"
    }

    [
      url: @url,
      json: corpo,
      headers: [
        {"x-api-key", chave},
        {"anthropic-version", @versao_api},
        {"anthropic-beta", @beta_fallback}
      ],
      receive_timeout: @timeout_ms,
      retry: false
    ]
    |> Keyword.merge(Keyword.get(opts, :req_options, []))
    |> Req.post()
    |> interpretar()
  end

  defp interpretar({:ok, %Req.Response{status: 200, body: %{"stop_reason" => "refusal"}}}) do
    {:error, :recusa_do_llm}
  end

  defp interpretar({:ok, %Req.Response{status: 200, body: %{"stop_reason" => "max_tokens"}}}) do
    {:error, :resposta_truncada}
  end

  defp interpretar({:ok, %Req.Response{status: 200, body: %{"content" => blocos}}})
       when is_list(blocos) do
    case for(%{"type" => "text", "text" => texto} <- blocos, do: texto) do
      [] -> {:error, :resposta_sem_texto}
      textos -> {:ok, Enum.join(textos)}
    end
  end

  defp interpretar({:ok, %Req.Response{status: 200}}), do: {:error, :resposta_inesperada}
  defp interpretar({:ok, %Req.Response{status: status}}), do: {:error, {:http, status}}
  defp interpretar({:error, excecao}), do: {:error, {:rede, Exception.message(excecao)}}
end
