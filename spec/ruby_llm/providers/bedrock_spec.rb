# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      bedrock_api_key: 'test-api-key',
      bedrock_secret_key: 'test-secret-key',
      bedrock_region: 'us-east-1'
    )
  end

  let(:prompt_arn) { 'arn:aws:bedrock:region:account:prompt/resource' }
  let(:model) { instance_double(RubyLLM::Model::Info, id: prompt_arn) }

  before do
    provider.instance_variable_set(:@model, model)
  end

  describe '#completion_url' do
    it 'URL-encodes model IDs for converse requests' do
      expect(provider.send(:completion_url)).to eq(
        '/model/arn%3Aaws%3Abedrock%3Aregion%3Aaccount%3Aprompt%2Fresource/converse'
      )
    end
  end

  describe '#stream_url' do
    it 'URL-encodes model IDs for converse-stream requests' do
      expect(provider.send(:stream_url)).to eq(
        '/model/arn%3Aaws%3Abedrock%3Aregion%3Aaccount%3Aprompt%2Fresource/converse-stream'
      )
    end
  end

  describe '#validate_prompt_arn_runtime_overrides!' do
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'hello')] }

    it 'raises on explicit inferenceConfig overrides passed via params' do
      expect do
        provider.send(
          :validate_prompt_arn_runtime_overrides!,
          model: model,
          messages: messages,
          tools: {},
          temperature: nil,
          params: { inferenceConfig: { temperature: 0.2 } }
        )
      end.to raise_error(RubyLLM::UnsupportedPromptArnParameterError, /inferenceConfig/)
    end

    it 'does not raise for empty inferenceConfig params' do
      expect do
        provider.send(
          :validate_prompt_arn_runtime_overrides!,
          model: model,
          messages: messages,
          tools: {},
          temperature: nil,
          params: { inferenceConfig: {} }
        )
      end.not_to raise_error
    end
  end
end
