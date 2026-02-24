# frozen_string_literal: true
require 'cgi'

module RubyLLM
  module Providers
    # AWS Bedrock Converse API integration.
    class Bedrock < Provider
      include Bedrock::Auth
      include Bedrock::Chat
      include Bedrock::Media
      include Bedrock::Models
      include Bedrock::Streaming

      def api_base
        "https://bedrock-runtime.#{bedrock_region}.amazonaws.com"
      end

      def headers
        {}
      end

      def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, thinking: nil, &) # rubocop:disable Metrics/ParameterLists
        normalized_params = normalize_params(params, model:)
        validate_prompt_arn_runtime_overrides!(
          model: model,
          messages: messages,
          tools: tools,
          temperature: temperature,
          params: normalized_params
        )

        super(
          messages,
          tools: tools,
          temperature: temperature,
          model: model,
          params: normalized_params,
          headers: headers,
          schema: schema,
          thinking: thinking,
          &
        )
      end

      def parse_error(response)
        return if response.body.nil? || response.body.empty?

        body = try_parse_json(response.body)
        return body if body.is_a?(String)

        body['message'] || body['Message'] || body['error'] || body['__type'] || super
      end

      def list_models
        response = signed_get(models_api_base, models_url)
        parse_list_models_response(response, slug, capabilities)
      end

      class << self
        def configuration_requirements
          %i[bedrock_api_key bedrock_secret_key bedrock_region]
        end
      end

      private

      def bedrock_region
        @config.bedrock_region
      end

      def encoded_model_id
        CGI.escape(@model.id.to_s).gsub('+', '%20')
      end

      def sync_response(connection, payload, additional_headers = {})
        signed_post(connection, completion_url, payload, additional_headers)
      end

      def normalize_params(params, model:)
        normalized = RubyLLM::Utils.deep_symbolize_keys(params || {})
        additional_fields = normalized[:additionalModelRequestFields] || {}

        top_k = normalized.delete(:top_k)
        if !top_k.nil? && model_supports_top_k?(model)
          additional_fields = RubyLLM::Utils.deep_merge(additional_fields, { top_k: top_k })
        end

        normalized[:additionalModelRequestFields] = additional_fields unless additional_fields.empty?
        normalized
      end

      def validate_prompt_arn_runtime_overrides!(model:, messages:, tools:, temperature:, params:)
        return unless prompt_arn_model?(model)

        if messages.any? { |message| message.role == :system }
          raise UnsupportedPromptArnParameterError,
                'Bedrock prompt ARN does not allow runtime system instructions. ' \
                'Move instructions into the AWS prompt definition.'
        end

        if tools.any?
          raise UnsupportedPromptArnParameterError,
                'Bedrock prompt ARN does not allow runtime toolConfig. ' \
                'Define tools in the AWS prompt resource.'
        end

        explicit_inference_config = params[:inferenceConfig]
        has_explicit_inference_config = explicit_inference_config.is_a?(Hash) ? explicit_inference_config.any? : !explicit_inference_config.nil?
        return unless !temperature.nil? || has_explicit_inference_config

        raise UnsupportedPromptArnParameterError,
              'Bedrock prompt ARN does not allow runtime inferenceConfig overrides. ' \
              'Configure inference behavior in the AWS prompt resource.'
      end

      def prompt_arn_model?(model)
        model_id = model&.id.to_s
        model_id.start_with?('arn:aws:bedrock:') && model_id.include?(':prompt/')
      end

      def model_supports_top_k?(model)
        Bedrock::Models.reasoning_embedded?(model)
      end

      def api_payload(payload)
        cleaned = RubyLLM::Utils.deep_symbolize_keys(RubyLLM::Utils.deep_dup(payload))
        cleaned.delete(:tools)
        cleaned
      end
    end
  end
end
