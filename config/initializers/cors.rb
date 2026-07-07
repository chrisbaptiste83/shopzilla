TRUSTED_ORIGINS = [
  ENV.fetch("FRONTEND_URL", "http://localhost:5173"),
  "http://localhost:4173",
  "http://localhost:3001"
].freeze

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Public read-only endpoints — broad origin support is fine
  allow do
    origins(*TRUSTED_ORIGINS,
            /https:\/\/.*\.github\.io$/,
            /https:\/\/.*\.netlify\.app$/,
            /https:\/\/.*\.vercel\.app$/)

    resource "/products*",
      headers: :any,
      methods: [ :get, :options ],
      credentials: false

    resource "/categories*",
      headers: :any,
      methods: [ :get, :options ],
      credentials: false
  end

  # Write endpoints — only explicit trusted origins
  allow do
    origins(*TRUSTED_ORIGINS)

    resource "/orders*",
      headers: :any,
      methods: [ :get, :post, :options ],
      credentials: false

    resource "/users*",
      headers: :any,
      methods: [ :get, :post, :delete, :options ],
      credentials: false
  end
end
