defmodule Qualificador.LLMTest do
  use ExUnit.Case, async: true

  alias Qualificador.LLM
  alias Qualificador.LLM.{Anthropic, Fake}

  # Substitui o HTTP do Req: nada aqui toca a rede.
  defp responder(status, corpo) do
    teste = self()

    fn requisicao ->
      send(teste, {:requisicao, requisicao})
      {requisicao, Req.Response.new(status: status, body: corpo)}
    end
  end

  defp completar(status, corpo) do
    Anthropic.completar("sistema", "texto",
      api_key: "chave-de-teste",
      req_options: [adapter: responder(status, corpo)]
    )
  end

  describe "adapter/1" do
    test "usa o configurado, salvo se opts indicar outro" do
      assert LLM.adapter() == Fake
      assert LLM.adapter(adapter: Anthropic) == Anthropic
    end
  end

  describe "Anthropic" do
    test "extrai o texto e monta a requisição" do
      corpo = %{
        "stop_reason" => "end_turn",
        "content" => [
          %{"type" => "thinking", "thinking" => ""},
          %{"type" => "text", "text" => "{}"}
        ]
      }

      assert completar(200, corpo) == {:ok, "{}"}

      assert_received {:requisicao, requisicao}
      assert Req.Request.get_header(requisicao, "x-api-key") == ["chave-de-teste"]
      assert requisicao.options.receive_timeout == 30_000
    end

    test "sem chave não faz requisição" do
      assert Anthropic.completar("s", "t", api_key: "") == {:error, :sem_api_key}
    end

    test "falhas viram {:error, motivo}" do
      assert completar(500, "erro") == {:error, {:http, 500}}

      assert completar(200, %{"stop_reason" => "refusal", "content" => []}) ==
               {:error, :recusa_do_llm}

      assert completar(200, %{"stop_reason" => "max_tokens", "content" => []}) ==
               {:error, :resposta_truncada}

      assert completar(200, %{"content" => []}) == {:error, :resposta_sem_texto}
      assert completar(200, "html inesperado") == {:error, :resposta_inesperada}
    end

    test "falha de rede vira {:error, motivo}" do
      falha = fn requisicao ->
        {requisicao, %Req.TransportError{reason: :timeout}}
      end

      assert {:error, {:rede, _mensagem}} =
               Anthropic.completar("s", "t", api_key: "x", req_options: [adapter: falha])
    end
  end

  describe "Fake" do
    test "responde aos pedidos de exemplo" do
      for pedido <- File.stream!("priv/pedidos.txt") do
        assert {:ok, json} = Fake.completar("s", pedido)
        assert {:ok, %{"cidade" => _}} = Jason.decode(json)
      end
    end

    test "resposta pode ser forçada" do
      assert Fake.completar("s", "t", resposta: "lixo") == {:ok, "lixo"}
      assert Fake.completar("s", "t", resposta: {:error, :x}) == {:error, :x}
    end
  end
end
