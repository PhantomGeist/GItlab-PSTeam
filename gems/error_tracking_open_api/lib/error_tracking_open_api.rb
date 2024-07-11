=begin
#Error Tracking REST API

#This schema describes the API endpoints for the error tracking feature

The version of the OpenAPI document: 0.0.1

Generated by: https://openapi-generator.tech
OpenAPI Generator version: 6.0.0

=end

# Common files
require 'error_tracking_open_api/api_client'
require 'error_tracking_open_api/api_error'
require 'error_tracking_open_api/version'
require 'error_tracking_open_api/configuration'

# Models
require 'error_tracking_open_api/models/error'
require 'error_tracking_open_api/models/error_event'
require 'error_tracking_open_api/models/error_stats'
require 'error_tracking_open_api/models/error_update_payload'
require 'error_tracking_open_api/models/error_v2'
require 'error_tracking_open_api/models/message_event'
require 'error_tracking_open_api/models/project'
require 'error_tracking_open_api/models/stats_object'
require 'error_tracking_open_api/models/stats_object_group_inner'

# APIs
require 'error_tracking_open_api/api/errors_api'
require 'error_tracking_open_api/api/errors_v2_api'
require 'error_tracking_open_api/api/events_api'
require 'error_tracking_open_api/api/messages_api'
require 'error_tracking_open_api/api/projects_api'

module ErrorTrackingOpenAPI
  class << self
    # Customize default settings for the SDK using block.
    #   ErrorTrackingOpenAPI.configure do |config|
    #     config.username = "xxx"
    #     config.password = "xxx"
    #   end
    # If no block given, return the default Configuration object.
    def configure
      if block_given?
        yield(Configuration.default)
      else
        Configuration.default
      end
    end
  end
end
