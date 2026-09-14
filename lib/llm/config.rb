require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      initialize!
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key if api_key.present?
        config.openai_api_base = api_base.chomp('/') if api_base.present?
        config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present?
        config.gemini_api_key = gemini_api_key if gemini_api_key.present?
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
        config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present?
        config.gemini_api_key = gemini_api_key if gemini_api_key.present?
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
      end
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value || ENV.fetch('OPENAI_API_KEY', nil)
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value || ENV.fetch('OPENAI_API_BASE', nil)
    end

    def anthropic_api_key
      InstallationConfig.find_by(name: 'ANTHROPIC_API_KEY')&.value || ENV.fetch('ANTHROPIC_API_KEY', nil)
    end

    def gemini_api_key
      InstallationConfig.find_by(name: 'GEMINI_API_KEY')&.value || ENV.fetch('GEMINI_API_KEY', nil)
    end
  end
end
