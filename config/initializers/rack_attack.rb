class Rack::Attack
  # General request rate limit (exclude assets)
  throttle("req/ip", limit: 200, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # Login: 5 attempts per minute per email
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip
    end
  end

  # Login: also throttle by IP to catch credential stuffing
  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # Password reset: prevent email enumeration / inbox spam
  throttle("password_reset/ip", limit: 5, period: 10.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # Cart add: prevent session bloat
  throttle("cart/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/cart") && req.post?
  end

  # Checkout: prevent Stripe session spam
  throttle("checkout/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/checkout") && req.post?
  end

  # Stripe webhook: prevent replay hammering
  throttle("webhooks/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks")
  end

  # Downloads: prevent bulk scraping of signed URLs
  throttle("downloads/ip", limit: 20, period: 10.minutes) do |req|
    req.ip if req.path.start_with?("/downloads")
  end

  # Return 429 JSON for API clients, HTML for browsers
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    retry_after = match_data ? (match_data[:period] - (Time.now.to_i % match_data[:period])) : 60

    if req.env["HTTP_ACCEPT"]&.include?("application/json")
      [ 429, { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
        [ { error: "Too many requests. Please try again later." }.to_json ] ]
    else
      [ 429, { "Content-Type" => "text/html", "Retry-After" => retry_after.to_s },
        [ "<h1>Too Many Requests</h1><p>Please try again in a moment.</p>" ] ]
    end
  end
end
