# frozen_string_literal: true

module Ai
  module Project
    class Conversations
      def initialize(project, user)
        @project = project
        @user = user
      end

      def ci_config_chat_enabled?
        @project.licensed_feature_available?(:ai_config_chat) &&
          Feature.enabled?(:ai_ci_config_generator, @user) &&
          (Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops))
      end

      def ci_config_messages
        return Ci::Editor::AiConversation::Message.none unless @user.can?(:create_pipeline, @project)

        Ci::Editor::AiConversation::Message.belonging_to(@project, @user).asc
      end
    end
  end
end
