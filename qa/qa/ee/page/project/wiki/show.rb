# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Wiki
          module Show
            extend QA::Page::PageConcern

            def wait_for_repository_replication(max_wait: Runtime::Geo.max_file_replication_time)
              QA::Runtime::Logger.debug(%(#{self.class.name} - wait_for_repository_replication))
              wait_until_geo_max_replication_time(max_wait: max_wait) do
                has_no_text?(/No repository|The wiki for this project is empty/)
              end
            end

            def wait_for_repository_replication_with(text, max_wait: Runtime::Geo.max_file_replication_time)
              QA::Runtime::Logger.debug(%(#{self.class.name} - wait_for_repository_replication_with_text "#{text}"))
              wait_until_geo_max_replication_time(max_wait: max_wait) do
                page.has_text?(text)
              end
            end

            def wait_until_geo_max_replication_time(max_wait: Runtime::Geo.max_file_replication_time, &block)
              wait_until(max_duration: max_wait, &block)
            end
          end
        end
      end
    end
  end
end
