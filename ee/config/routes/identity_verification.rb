# frozen_string_literal: true

scope :users, module: :users do
  resource :identity_verification, controller: :identity_verification, only: :show do
    get :verification_state
    post :verify_email_code
    post :resend_email_code
    post :send_phone_verification_code
    post :verify_phone_verification_code
    post :verify_arkose_labs_session
    patch :toggle_phone_exemption
    get :arkose_labs_challenge
    get :verify_credit_card
    get :success
  end
end
