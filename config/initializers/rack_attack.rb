class Rack::Attack
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" and req.post?:
        req.params.get("user", {}).get("email", "").lower().strip()
  end
end