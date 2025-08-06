ActiveAdmin.setup do |config|
  # == Site Title
  #
  # Set the title that is displayed on the main layout for each Active Admin page.
  #
  config.site_title = "Shopzilla Admin"

  # Set the link URL for the title. For example, to take users to your main site.
  # Defaults to no link.
  #
  config.site_title_link = "/"

  # Set an optional image to be displayed for the header instead of a string (overrides :site_title)
  # Note: Aim for an image that's 21px high so it fits in the header.
  #
  # config.site_title_image = "logo.png"

  # == Load Paths
  #
  # By default, Active Admin files go inside app/admin/.
  # You can change this directory or load more directories if needed.
  #
  # config.load_paths = [File.join(Rails.root, 'app', 'admin')]

  # == Default Namespace
  #
  # Set the default namespace for administration resources.
  # Default:
  config.default_namespace = :admin

  # == User Authentication
  #
  # Active Admin calls an authentication method in a before filter to ensure a logged-in user.
  # Use Devise's authenticate_user! for our existing User model.
  config.authentication_method = :authenticate_user!

  # == User Authorization
  #
  # Active Admin can call an authorization method to ensure the user has proper rights.
  # We're defining a custom before_action to check if the user is an admin.
  # (Not using CanCan or Pundit for simplicity; using a custom check instead.)
  config.before_action :check_admin

  # == Current User
  #
  # Active Admin associates actions with the current user performing them.
  # Use Devise's current_user method.
  config.current_user_method = :current_user

  # == Logging Out
  #
  # Configure the logout link path and method.
  config.logout_link_path = :destroy_user_session_path
  config.logout_link_method = :delete

  # == Root
  #
  # Set the action to call for the root path. Defaults to 'dashboard#index'.
  # config.root_to = 'dashboard#index'

  # == Admin Comments
  #
  # Disable comments if not needed.
  config.comments = false
  config.comments_menu = false

  # == Batch Actions
  #
  # Enable batch actions for resources.
  config.batch_actions = true

  # == Controller Filters
  #
  # You can add before, after, and around filters to all Active Admin resources.
  # (Already set before_action for admin check above.)
  # config.before_action :do_something_awesome

  # == Attribute Filters
  #
  # Exclude sensitive model attributes from display, forms, or export.
  config.filter_attributes = [:encrypted_password, :password, :password_confirmation]

  # == Localize Date/Time Format
  #
  # Set the localize format for dates and times.
  config.localize_format = :long

  # == Setting a Favicon
  #
  # config.favicon = 'favicon.ico'

  # == Meta Tags
  #
  # Add additional meta tags to the head element of Active Admin pages.
  # config.meta_tags = { author: 'Shopzilla Team' }

  # == Removing Breadcrumbs
  #
  # Breadcrumbs are enabled by default. Disable globally if not needed.
  # config.breadcrumb = false

  # == Create Another Checkbox
  #
  # Disabled by default. Enable globally if needed.
  # config.create_another = true

  # == Register Stylesheets & JavaScripts
  #
  # Load custom stylesheets or JavaScript for Active Admin.
  # config.register_stylesheet 'my_stylesheet.css'
  # config.register_javascript 'my_javascript.js'

  # == CSV Options
  #
  # Customize CSV export options.
  # config.csv_options = { col_sep: ';' }
  # config.csv_options = { force_quotes: true }

  # == Menu System
  #
  # Customize navigation menu if needed.
  # Example:
  # config.namespace :admin do |admin|
  #   admin.build_menu :utility_navigation do |menu|
  #     menu.add label: "Shopzilla Home", url: root_path, html_options: { target: :blank }
  #     admin.add_logout_button_to_menu menu
  #   end
  # end

  # == Download Links
  #
  # Customize download links for resource listing pages (e.g., CSV, XML).
  # config.namespace :admin do |admin|
  #   admin.download_links = [:csv, :xml, :json]
  # end

  # == Pagination
  #
  # Control pagination settings.
  config.default_per_page = 30
  config.max_per_page = 10_000

  # == Filters
  #
  # Enable or disable filters sidebar on index pages.
  config.filters = true
end

# Define check_admin method for ActiveAdmin to restrict access to admin users
def check_admin
  unless current_user&.admin?
    flash[:alert] = "You are not authorized to access the admin dashboard."
    redirect_to root_path
  end
end
