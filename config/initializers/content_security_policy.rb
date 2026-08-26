# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, "https://fonts.googleapis.com", :unsafe_inline
    policy.connect_src :self, :https, "https://api.stripe.com"
    policy.frame_src   :none
    policy.base_uri    :self
    policy.frame_ancestors :none
  end

  # Generate session nonces for permitted importmap and inline scripts.
  # Note: style-src removed from nonce directives to allow GSAP inline style animations
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
