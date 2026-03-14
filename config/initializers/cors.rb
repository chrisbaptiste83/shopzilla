Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_URL", "http://localhost:5173"),
             "http://localhost:4173",
             "http://localhost:3001",
             /https:\/\/.*\.github\.io$/,
             /https:\/\/.*\.netlify\.app$/,
             /https:\/\/.*\.vercel\.app$/

    resource "/products*",
      headers: :any,
      methods: [:get, :options],
      credentials: false

    resource "/categories*",
      headers: :any,
      methods: [:get, :options],
      credentials: false

    resource "/orders*",
      headers: :any,
      methods: [:get, :post, :options],
      credentials: false

    resource "/users*",
      headers: :any,
      methods: [:get, :post, :delete, :options],
      credentials: false
  end
end
