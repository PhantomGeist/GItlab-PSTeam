# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CircuitBreaker::Notifier, feature_category: :ai_abstraction_layer do
  subject { described_class.new }

  describe '#notify' do
    context 'when event is failure' do
      it 'sends an exception to Gitlab::ErrorTracking' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)

        subject.notify('test_service', 'failure')
      end
    end

    context 'when event is not failure' do
      it 'does not send an exception to Gitlab::ErrorTracking' do
        expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

        subject.notify('test_service', 'test_event')
      end
    end
  end

  describe '#notify_warning' do
    it do
      expect { subject.notify_warning('test_service', 'test_message') }.not_to raise_error
    end
  end

  describe '#notify_run' do
    it do
      expect { subject.notify_run('test_service') { puts 'test block' } }.not_to raise_error
    end
  end
end
