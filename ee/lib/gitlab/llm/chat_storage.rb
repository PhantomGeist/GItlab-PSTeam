# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      # Expiration time of user messages should not be more than 90 days.
      # EXPIRE_TIME sets expiration time for the whole chat history stream (not
      # for individual messages) - so the stream is deleted after 3 days since
      # last message was added.  Because for each user's message there is also
      # a response, it means that maximum theoretical time of oldest message in
      # the stream is (MAX_MESSAGES / 2) * EXPIRE_TIME
      EXPIRE_TIME =  3.days
      MAX_MESSAGES = 50
      # AI provider-specific limits are applied to requests/responses. To not
      # rely only on third-party limits and assure that cache usage can't be
      # exhausted by users by sending huge texts/responses, we apply also
      # safeguard limit on maximum size of cached response. 1 token ~= 4 chars
      # in English, limit is typically ~4100 -> so 20000 char limit should be
      # sufficient.
      MAX_TEXT_LIMIT = 20_000

      def initialize(user)
        @user = user
      end

      def add(message)
        cache_data(dump_message(message))
      end

      def messages(filters = {})
        with_redis do |redis|
          redis.xrange(key).filter_map do |_id, data|
            load_message(data) if matches_filters?(data, filters)
          end
        end
      end

      def last_conversation
        all = messages
        idx = all.rindex(&:conversation_reset?)
        return all unless idx
        return [] unless idx + 1 < all.size

        all[idx + 1..]
      end

      private

      attr_reader :user

      def cache_data(data)
        with_redis do |redis|
          redis.xadd(key, data, maxlen: MAX_MESSAGES)
          redis.expire(key, EXPIRE_TIME)
        end
      end

      def key
        "ai_chat:#{user.id}"
      end

      def with_redis(&block)
        Gitlab::Redis::Chat.with(&block) # rubocop: disable CodeReuse/ActiveRecord
      end

      def matches_filters?(data, filters)
        return false if filters[:roles]&.exclude?(data['role'])
        return false if filters[:request_ids]&.exclude?(data['request_id'])

        data
      end

      def dump_message(message)
        # Message is stored only partially. Some data might be missing after reloading from storage.
        result = message.to_h.slice(*%w[id request_id role content])

        result['errors'] = message.errors&.to_json
        result['extras'] = message.extras&.to_json
        result['timestamp'] = message.timestamp&.to_s
        result['content'] = result['content'][0, MAX_TEXT_LIMIT] if result['content']

        result.compact
      end

      def load_message(data)
        data['extras'] = ::Gitlab::Json.parse(data['extras']) if data['extras']
        data['errors'] = ::Gitlab::Json.parse(data['errors']) if data['errors']
        data['timestamp'] = Time.zone.parse(data['timestamp']) if data['timestamp']
        data['ai_action'] = 'chat'
        data['user'] = user

        ChatMessage.new(data)
      end
    end
  end
end
