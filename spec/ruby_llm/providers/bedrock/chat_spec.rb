# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  describe '.render_payload' do
    def render_payload(model_id:, messages:, tools: {}, temperature: nil)
      model = instance_double(RubyLLM::Model::Info, id: model_id)

      described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )
    end

    it 'raises on runtime system instructions in prompt mode' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'System instruction'),
        RubyLLM::Message.new(role: :user, content: 'User message')
      ]

      expect do
        render_payload(model_id: 'arn:aws:bedrock:region:account:prompt/resource', messages: messages)
      end.to raise_error(RubyLLM::UnsupportedPromptArnParameterError, /runtime system instructions/)
    end

    it 'raises on runtime system role messages in prompt mode' do
      messages = [RubyLLM::Message.new(role: :system, content: 'System role message')]

      expect do
        render_payload(model_id: 'arn:aws:bedrock:region:account:prompt/resource', messages: messages)
      end.to raise_error(RubyLLM::UnsupportedPromptArnParameterError, /runtime system instructions/)
    end

    it 'raises on runtime toolConfig in prompt mode' do
      messages = [RubyLLM::Message.new(role: :user, content: 'User message')]
      tool = instance_double(
        RubyLLM::Tool,
        name: 'lookup',
        description: 'Lookup',
        params_schema: nil,
        parameters: {},
        provider_params: {}
      )

      expect do
        render_payload(
          model_id: 'arn:aws:bedrock:region:account:prompt/resource',
          messages: messages,
          tools: { lookup: tool }
        )
      end.to raise_error(RubyLLM::UnsupportedPromptArnParameterError, /toolConfig/)
    end

    it 'raises on explicit runtime inferenceConfig override in prompt mode' do
      messages = [RubyLLM::Message.new(role: :user, content: 'User message')]

      expect do
        render_payload(
          model_id: 'arn:aws:bedrock:region:account:prompt/resource',
          messages: messages,
          temperature: 0.2
        )
      end.to raise_error(RubyLLM::UnsupportedPromptArnParameterError, /inferenceConfig/)
    end

    it 'does not raise for implicit inference settings in prompt mode' do
      messages = [RubyLLM::Message.new(role: :user, content: 'User message')]
      payload = render_payload(model_id: 'arn:aws:bedrock:region:account:prompt/resource', messages: messages)

      expect(payload).not_to have_key(:inferenceConfig)
      expect(payload[:messages]).not_to be_empty
    end

    it 'preserves behavior for non-prompt models with runtime system and tools' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'System instruction'),
        RubyLLM::Message.new(role: :user, content: 'User message')
      ]
      tool = instance_double(
        RubyLLM::Tool,
        name: 'lookup',
        description: 'Lookup',
        params_schema: nil,
        parameters: {},
        provider_params: {}
      )

      payload = render_payload(
        model_id: 'provider.model-family-v1:0',
        messages: messages,
        tools: { lookup: tool },
        temperature: 0.2
      )

      expect(payload[:system]).not_to be_empty
      expect(payload[:toolConfig]).to be_present
      expect(payload.dig(:inferenceConfig, :temperature)).to eq(0.2)
    end
  end
end
