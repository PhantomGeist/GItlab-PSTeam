# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Client, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }

  let(:api_key) { 'api-key' }
  let(:options) { {} }
  let(:expected_request_body) { default_body_params }

  let(:expected_request_headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'anthropic-version' => '2023-06-01',
      'x-api-key' => api_key
    }
  end

  let(:default_body_params) do
    {
      prompt: "anything",
      model: described_class::DEFAULT_MODEL,
      max_tokens_to_sample: described_class::DEFAULT_MAX_TOKENS,
      temperature: described_class::DEFAULT_TEMPERATURE
    }
  end

  let(:expected_response) do
    {
      'completion' => 'Completion Response',
      'stop' => nil,
      'stop_reason' => 'max_tokens',
      'truncated' => false,
      'log_id' => 'b454d92a4e108ab78dcccbcc6c83f7ba',
      'model' => 'claude-v1.3',
      'exception' => nil
    }
  end

  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }

  before do
    stub_application_setting(anthropic_api_key: api_key)
    stub_request(:post, "#{described_class::URL}/v1/complete")
      .with(
        body: expected_request_body,
        headers: expected_request_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: response_headers
      )
  end

  describe '#complete' do
    subject(:complete) do
      described_class.new(user, tracking_context: tracking_context).complete(prompt: 'anything', **options)
    end

    context 'when measuring request success' do
      let(:client) { :anthropic }

      it_behaves_like 'measured Llm request'

      context 'when request raises an exception' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError)
        end

        it_behaves_like 'measured Llm request with error', StandardError
      end

      context 'when request is retried' do
        let(:http_status) { 429 }

        before do
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when request is retried once' do
        before do
          stub_request(:post, "#{described_class::URL}/v1/complete")
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'tracks events for AI requests', 2, 4
      end
    end

    it_behaves_like 'tracks events for AI requests', 2, 4

    context 'when feature flag and API key is set' do
      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when using options' do
      let(:options) { { temperature: 0.1, timeout: 50.seconds } }

      let(:expected_request_body) do
        {
          prompt: "anything",
          model: described_class::DEFAULT_MODEL,
          max_tokens_to_sample: described_class::DEFAULT_MAX_TOKENS,
          temperature: options[:temperature]
        }
      end

      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post).with(anything, hash_including(timeout: 50.seconds)).and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when passing stream: true' do
      let(:options) { { stream: true } }
      let(:expected_request_body) { default_body_params }

      it 'does not pass stream: true as we do not want to retrieve SSE events' do
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when the API key is not present' do
      let(:api_key) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '#stream' do
    subject { described_class.new(user, tracking_context: tracking_context).stream(prompt: 'anything', **options) }

    context 'when streaming the request' do
      let(:response_body) { expected_response }
      let(:options) { { stream: true } }
      let(:expected_request_body) { default_body_params.merge(stream: true) }

      context 'when response is successful' do
        let(:expected_response) do
          <<-DOC
          event: completion\r\n
          data: {"completion": "Hello", "stop_reason": null, "model": "claude-2.0"}\r\n
          \r\n
          DOC
        end

        it 'provides parsed streamed response' do
          expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }.to yield_with_args(
            {
              "completion" => "Hello",
              "stop_reason" => nil,
              "model" => "claude-2.0"
            }
          )
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
            .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
            .and_call_original

          expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq("Hello")
        end

        context 'when setting a timeout' do
          let(:options) { { timeout: 50.seconds } }

          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
              .with(anything, hash_including(timeout: 50.seconds))
              .and_call_original

            described_class.new(user).stream(prompt: 'anything', **options)
          end
        end

        it_behaves_like 'tracks events for AI requests', 2, 1
      end

      context 'when response contains multiple events' do
        let(:expected_response) do
          <<-DOC
          event: completion\r
          data: {"completion":"Hello", "stop_reason": null, "model": "claude-2.0" }\r
          \r
          event: completion\r
          data: {"completion":" World", "stop_reason": null, "model": "claude-2.0" }\r
          \r
          DOC
        end

        it 'provides parsed streamed response' do
          expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }.to yield_successive_args(
            {
              "completion" => "Hello",
              "stop_reason" => nil,
              "model" => "claude-2.0"
            },
            {
              "completion" => " World",
              "stop_reason" => nil,
              "model" => "claude-2.0"
            }
          )
        end

        it 'returns response' do
          expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq("Hello World")
        end
      end

      context 'when response is an error' do
        let(:expected_response) do
          <<-DOC
          event: error\r
          data: {"error": {"type": "overloaded_error", "message": "Overloaded"}}\r
          \r
          DOC
        end

        it 'provides parsed streamed response' do
          expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }.to yield_with_args(
            {
              "error" => { "message" => "Overloaded", "type" => "overloaded_error" }
            }
          )
        end

        it 'returns empty response' do
          expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq("")
        end
      end

      context 'when response is a ping' do
        let(:expected_response) do
          <<-DOC
          event: ping\r
          data: {}\r
          \r\n
          DOC
        end

        it 'provides parsed streamed response' do
          expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }.to yield_with_args({})
        end

        it 'returns empty response' do
          expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq("")
        end
      end
    end

    context 'when the API key is not present' do
      let(:api_key) { nil }

      it 'does not provide stream response' do
        expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }.not_to yield_with_args
      end

      it 'returns nil' do
        expect(described_class.new(user).stream(prompt: 'anything', **options)).to be_nil
      end
    end
  end
end
