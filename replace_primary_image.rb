require 'fileutils'

Dir.glob('app/views/**/*.erb').each do |file|
  content = File.read(file)
  new_content = content.gsub('.images.first', '.primary_image')
  if content != new_content
    File.write(file, new_content)
    puts "Updated #{file}"
  end
end
