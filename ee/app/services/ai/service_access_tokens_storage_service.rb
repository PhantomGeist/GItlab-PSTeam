# frozen_string_literal: true

module Ai
  class ServiceAccessTokensStorageService
    def initialize(token, expires_at)
      @token = token
      @expires_at = expires_at
    end

    def execute
      if token && expires_at
        store_token
        cleanup_expired_tokens
      else
        cleanup_all_tokens
      end
    end

    private

    attr_reader :token, :expires_at

    def store_token
      Ai::ServiceAccessToken.create!(token: token, expires_at: expires_at_time)
      log_event({ action: 'created', expires_at: expires_at_time })
    rescue StandardError => err
      Gitlab::ErrorTracking.track_exception(err)
    end

    def expires_at_time
      return if expires_at.nil?

      Time.at(expires_at, in: '+00:00')
    end

    def cleanup_expired_tokens
      Ai::ServiceAccessToken.expired.delete_all
      log_event({ action: 'cleanup_expired' })
    end

    def cleanup_all_tokens
      Ai::ServiceAccessToken.delete_all
      log_event({ action: 'cleanup_all' })
    end

    def log_event(log_fields)
      Gitlab::AppLogger.info(
        message: 'service_access_tokens',
        **log_fields
      )
    end
  end
end
