# frozen_string_literal: true

namespace :remote_development do
  resources :workspaces, path: 'workspaces(/*vueroute)' do
    resources :workspaces, only: [:index, :new], controller: :workspaces, action: :index
  end
end
