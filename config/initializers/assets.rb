# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.1"
Rails.application.config.assets.paths << Rails.root.join("node_modules")

# Ensure builds directory is checked before app/javascript for bundled assets
Rails.application.config.assets.paths.unshift(Rails.root.join("app/assets/builds"))

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
