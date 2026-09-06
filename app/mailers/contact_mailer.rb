# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  def message_notification(name:, email:, subject:, message:)
    @name = name
    @email = email
    @subject = subject.presence || "General Inquiry"
    @message = message

    recipient = ENV.fetch("MERCHANT_SUPPORT_EMAIL", "support@gloriasembroideryshop.com")

    mail(
      to: recipient,
      reply_to: @email,
      subject: "[Gloria's Embroidery Contact] #{@subject} from #{@name}"
    )
  end
end
