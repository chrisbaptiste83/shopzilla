class HomeController < ApplicationController
  def index
    @featured_categories = Category.with_available_products.limit(6)
    @featured_products = Product.where(is_available: true)
                                 .with_attached_images
                                 .order(created_at: :desc)
                                 .limit(3)
  end

  def about
  end

  def contact
    if request.post?
      name = params[:name].to_s.strip
      email = params[:email].to_s.strip
      subject = params[:subject].to_s.strip
      message = params[:message].to_s.strip

      if name.blank? || email.blank? || message.blank?
        flash.now[:alert] = "Please provide your name, email address, and a message."
        render :contact, status: :unprocessable_entity
        return
      end

      ContactMailer.message_notification(
        name: name,
        email: email,
        subject: subject,
        message: message
      ).deliver_later

      redirect_to contact_path, notice: "Thank you for reaching out! We received your message and will respond within 24–48 hours."
    end
  end
end
