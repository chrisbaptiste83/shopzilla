namespace :admin do
  desc "Create admin user for testing"
  task create_user: :environment do
    admin = AdminUser.find_or_create_by(email: 'admin@shopzilla.com') do |user|
      user.password = 'password123'
      user.password_confirmation = 'password123'
    end
    
    if admin.persisted?
      puts "Admin user created successfully!"
      puts "Email: admin@shopzilla.com"
      puts "Password: password123"
    else
      puts "Failed to create admin user: #{admin.errors.full_messages.join(', ')}"
    end
  end
end
