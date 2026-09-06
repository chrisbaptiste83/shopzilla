class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM_EMAIL", "support@gloriasembroideryshop.com")
  layout "mailer"
end
