# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      class TokenLoader
        DEFAULT_SCOPE = 'https://www.googleapis.com/auth/cloud-platform'
        ACCESS_TOKEN_EXPIRY = 3540 # 59 minutes in seconds
        ACCESS_TOKEN_CACHE_KEY = 'vertex_ai_access_token_expiry'

        def refresh_token!
          ::Gitlab::CurrentSettings.update!(
            vertex_ai_access_token: fetch_fresh_token
          )
          update_access_token_cache
        end

        def current_token
          refresh_token! if should_refresh_access_token?

          vertex_ai_access_token
        end

        private

        def should_refresh_access_token?
          !access_token_valid? || vertex_ai_access_token.nil?
        end

        def fetch_fresh_token
          creds = if vertex_ai_credentials
                    ::Google::Auth::ServiceAccountCredentials.make_creds(
                      json_key_io: StringIO.new(vertex_ai_credentials),
                      scope: DEFAULT_SCOPE
                    )
                  else
                    ::Google::Auth.get_application_default(DEFAULT_SCOPE)
                  end

          response = creds.fetch_access_token!
          response["access_token"]
        end

        def update_access_token_cache
          Rails.cache.write(ACCESS_TOKEN_CACHE_KEY, true, expires_in: ACCESS_TOKEN_EXPIRY)
        end

        def access_token_valid?
          # this is not the actual access token but a string that is cached for 59
          # minutes; a Vertex AI Access Token is valid for 60 minutes so when this
          # value is no longer present, we know that the Vertex token needs refresh
          Rails.cache.read(ACCESS_TOKEN_CACHE_KEY)
        end

        def vertex_ai_access_token
          ::Gitlab::CurrentSettings.vertex_ai_access_token
        end

        def vertex_ai_credentials
          ::Gitlab::CurrentSettings.vertex_ai_credentials
        end
      end
    end
  end
end
