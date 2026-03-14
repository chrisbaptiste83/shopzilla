class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_from_token!

  private

  # Allow Bearer-token auth in addition to session auth for JSON/API requests.
  def authenticate_from_token!
    return if devise_controller?
    header = request.headers['Authorization']
    return unless header&.start_with?('Bearer ')
    token = header.split(' ', 2).last
    user  = User.find_by(auth_token: token)
    sign_in(user, store: false) if user
  end
end
