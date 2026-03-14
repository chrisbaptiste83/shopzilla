class Users::SessionsController < Devise::SessionsController
  respond_to :html, :json

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)

    respond_to do |format|
      format.html { respond_with resource, location: after_sign_in_path_for(resource) }
      format.json do
        resource.regenerate_auth_token if resource.auth_token.blank?
        render json: {
          token: resource.auth_token,
          user:  { id: resource.id, email: resource.email }
        }
      end
    end
  end

  def destroy
    respond_to do |format|
      format.html { super }
      format.json do
        current_user&.update_column(:auth_token, nil)
        sign_out(resource_name)
        head :no_content
      end
    end
  end
end
