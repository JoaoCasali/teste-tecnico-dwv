import Config

config :qualificador, llm_adapter: Qualificador.LLM.Anthropic

if config_env() == :test do
  config :qualificador, llm_adapter: Qualificador.LLM.Fake
end
