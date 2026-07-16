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
    webauthn_credential = WebAuthn::Credential.from_create(params[:credential])

    begin
      webauthn_credential.verify(session[:current_challenge])

      credential = current_user.webauthn_credentials.build(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count
      )

      if credential.save
        render json: { status: "ok" }
      else
        render json: { error: "Failed to save credential" }, status: :unprocessable_entity
      end
    rescue WebAuthn::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    ensure
      session.delete(:current_challenge)
    end
  end

  def destroy
    current_user.webauthn_credentials.find(params[:id]).destroy
    redirect_to profile_path, notice: "Passkey deleted."
  end
end
