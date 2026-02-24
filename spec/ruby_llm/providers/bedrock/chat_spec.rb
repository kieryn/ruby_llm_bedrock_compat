# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  describe '.render_payload' do
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    def render_payload(model_id:, temperature: nil)
      model = instance_double(RubyLLM::Model::Info, id: model_id)

      described_class.render_payload(
        messages,
        tools: {},
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )
    end

    it 'omits inferenceConfig for prompt resources' do
      payload = render_payload(model_id: 'arn:aws:bedrock:region:account:prompt/resource')

      expect(payload).not_to have_key(:inferenceConfig)
    end

    it 'ignores temperature overrides for prompt resources' do
      payload = render_payload(model_id: 'arn:aws:bedrock:region:account:prompt/resource', temperature: 0.2)

      expect(payload).not_to have_key(:inferenceConfig)
      expect(payload[:messages]).not_to be_empty
    end

    it 'retains inferenceConfig for non-prompt resources' do
      payload = render_payload(model_id: 'provider.model-family-v1:0', temperature: 0.2)

      expect(payload.dig(:inferenceConfig, :temperature)).to eq(0.2)
    end
  end
end
