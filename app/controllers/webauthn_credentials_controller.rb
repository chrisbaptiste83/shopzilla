# frozen_string_literal: true

class WebauthnCredentialsController < ApplicationController
  before_action :authenticate_user!

  def create
    create_options = WebAuthn::Credential.options_for_create(
      user: {
        id: current_user.webauthn_id,
        name: current_user.email
      },
      exclude: current_user.webauthn_credentials.pluck(:external_id)
    )

    session[:current_challenge] = create_options.challenge
    render json: create_options
  end

  def callback
    credential_params = params.require(:credential)
    webauthn_credential = WebAuthn::Credential.from_create(credential_params)

    begin
      raise WebAuthn::Error, "missing challenge" if session[:current_challenge].blank?

      webauthn_credential.verify(session[:current_challenge])

      credential = current_user.webauthn_credentials.build(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count
      )

      if credential.save
        render json: { status: "ok", id: credential.id }
      else
        render json: { error: credential.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue WebAuthn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    ensure
      session.delete(:current_challenge)
    end
  end

  def destroy
    current_user.webauthn_credentials.find(params[:id]).destroy!
    redirect_back fallback_location: root_path, notice: "Passkey deleted."
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: root_path, alert: "Passkey not found."
  end
end
