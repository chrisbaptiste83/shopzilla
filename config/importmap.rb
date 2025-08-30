# Pin npm packages by running ./bin/importmap

# config/importmap.rb
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
