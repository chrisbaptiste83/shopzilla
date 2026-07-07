class ErrorsController < ApplicationController
  skip_before_action :authenticate_from_token!

  def not_found
    render status: :not_found
  end

  def unprocessable
    render status: :unprocessable_entity
  end

  def server_error
    render status: :internal_server_error
  end
end
