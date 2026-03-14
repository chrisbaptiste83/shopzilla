class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :html, :json

  def create
    build_resource(sign_up_params)

    resource.save
    yield resource if block_given?

    respond_to do |format|
      format.html do
        if resource.persisted?
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          clean_up_passwords resource
          set_minimum_password_length
          respond_with resource
        end
      end
      format.json do
        if resource.persisted?
          sign_in(resource_name, resource)
          render json: {
            token: resource.auth_token,
            user:  { id: resource.id, email: resource.email }
          }, status: :created
        else
          render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end
