require "yaml"
require "tmpdir"
require "tempfile"
require "digest"
require "base64"

namespace :embroidery do
  CATALOG_FILE   = Rails.root.join("db/seeds/catalog.yml")
  RENDER_SCRIPT  = Rails.root.join("scripts/render_pes.py")
  DEFAULT_SOURCE = File.expand_path("~/Desktop/Embroidery Files")

  # ── embroidery:import ────────────────────────────────────────────────────────
  # Reads db/seeds/catalog.yml, renders each PES file to a preview PNG,
  # then creates or updates the matching Product record and attaches both files.
  #
  # Usage:
  #   rails embroidery:import
  #   EMBROIDERY_SOURCE_DIR="/path/to/pes" rails embroidery:import
  #   FORCE=1 rails embroidery:import          # re-render + re-attach all images
  desc "Import products from db/seeds/catalog.yml"
  task import: :environment do
    source_dir = ENV.fetch("EMBROIDERY_SOURCE_DIR", DEFAULT_SOURCE)
    force      = ENV["FORCE"].present?
    trim_guides = ActiveModel::Type::Boolean.new.cast(ENV.fetch("TRIM_GUIDES", "true"))
    catalog    = YAML.load_file(CATALOG_FILE)

    puts "Source directory: #{source_dir}"
    puts "Force re-render:  #{force}"
    puts "Trim guide runs:  #{trim_guides}"
    puts

    seed_categories(catalog.fetch("categories", []))

    products = catalog.fetch("products", [])
    puts "Importing #{products.size} products...\n\n"

    results = { created: 0, updated: 0, skipped: 0, errors: [] }

    Dir.mktmpdir("embroidery_renders") do |tmpdir|
      products.each do |data|
        import_one(data, source_dir, tmpdir, force, trim_guides, results)
      end
    end

    puts "\n#{"=" * 50}"
    puts "Created:  #{results[:created]}"
    puts "Updated:  #{results[:updated]}"
    puts "Skipped:  #{results[:skipped]}"
    puts "Errors:   #{results[:errors].size}"
    results[:errors].each { |e| puts "  - #{e}" }
  end

  # ── embroidery:render ────────────────────────────────────────────────────────
  desc "Render a single PES file to PNG  (args: pes_path,out_path)"
  task :render, %i[pes_path out_path] => :environment do |_, args|
    abort "Usage: rails embroidery:render[/path/to/file.pes,/path/to/out.png]" if args[:pes_path].blank?
    out = args[:out_path] || args[:pes_path].sub(/\.pes$/i, ".png")
    render_args = [ "python3", RENDER_SCRIPT.to_s, args[:pes_path], out ]
    render_args << "--trim-guides" unless ENV["TRIM_GUIDES"] == "false"
    render_args += [ "--rotate", ENV.fetch("ROTATE", "0") ]
    system(*render_args)
    puts "Rendered → #{out}"
  end

  desc "Re-render a product's attached previews (PRODUCT_ID=28 ROTATE=3 DRY_RUN=true)"
  task rerender_previews: :environment do
    product_id = ENV.fetch("PRODUCT_ID")
    rotation = Float(ENV.fetch("ROTATE", "0"))
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    product = Product.find(product_id)

    abort "Product #{product.id} has no attached embroidery file" unless product.embroidery_file.attached?

    previews = product.images.filter_map do |image|
      style = image.blob.metadata["render_style"].presence ||
        image.filename.to_s.match(/(?:-|_)(dark|light|detail)\.png\z/i)&.captures&.first&.downcase
      [ image, style ] if %w[dark light detail].include?(style)
    end
    abort "Product #{product.id} has no recognizable preview images" if previews.empty?

    Tempfile.create([ "product-#{product.id}", ".pes" ]) do |pes_file|
      product.embroidery_file.blob.open do |source|
        IO.copy_stream(source, pes_file)
      end
      pes_file.flush

      Dir.mktmpdir("product_preview_renders") do |tmpdir|
        previews.each do |image, style|
          output_path = File.join(tmpdir, "#{style}.png")
          command = [
            "python3", RENDER_SCRIPT.to_s, pes_file.path, output_path,
            "--style", style, "--trim-guides", "--rotate", rotation.to_s
          ]
          raise "render failed for #{image.filename}" unless system(*command)

          checksum = Base64.strict_encode64(Digest::MD5.file(output_path).digest)
          byte_size = File.size(output_path)
          blob = image.blob

          if dry_run
            puts "Would update #{blob.filename} (#{style}, #{rotation} degrees)"
            next
          end

          blob.variant_records.find_each { |variant| variant.image.purge }
          File.open(output_path, "rb") do |rendered|
            blob.service.upload(
              blob.key,
              rendered,
              checksum: checksum,
              filename: blob.filename,
              content_type: blob.content_type
            )
          end
          blob.update!(
            byte_size: byte_size,
            checksum: checksum,
            metadata: blob.metadata.to_h.merge("render_rotation_degrees" => rotation)
          )
          puts "Updated #{blob.filename} (#{style}, #{rotation} degrees)"
        end
      end
    end
  end

  # ── embroidery:reimport ───────────────────────────────────────────────────────
  desc "Force re-render and re-attach all product images"
  task reimport: :environment do
    ENV["FORCE"] = "1"
    Rake::Task["embroidery:import"].invoke
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

  def seed_categories(names)
    names.each { |name| Category.find_or_create_by!(name: name) }
    puts "Categories ready: #{names.join(', ')}\n\n"
  end

  def import_one(data, source_dir, tmpdir, force, trim_guides, results)
    title    = data.fetch("title")
    cat_name = data.fetch("category")
    pes_name = data.fetch("pes_file")
    pes_path = File.join(source_dir, pes_name)

    unless File.exist?(pes_path)
      msg = "#{title}: PES file not found — #{pes_path}"
      puts "  SKIP  #{msg}"
      results[:errors] << msg
      return
    end

    category = Category.find_or_create_by!(name: cat_name)
    product  = Product.find_or_initialize_by(title: title)
    created  = product.new_record?

    product.category       = category
    product.price          = data["price"] || "19.99"
    product.stitch_count   = data["stitch_count"] if data["stitch_count"]
    product.file_format    = "PES"
    product.is_available   = true
    product.physical_product = false
    product.shippable      = false

    if product.description.blank? || product.description.body.blank?
      product.description = "<p>#{data['description'].to_s.strip.gsub("\n", ' ')}</p>"
    end

    product.save!

    # Attach embroidery file
    if force || !product.embroidery_file.attached?
      product.embroidery_file.attach(
        io: File.open(pes_path),
        filename: File.basename(pes_path),
        content_type: "application/octet-stream"
      )
    end

    # Render 3 preview images (dark, light, detail)
    if force || !product.images.attached?
      slug = title.parameterize
      renders = %w[dark light detail].filter_map do |style|
        path = File.join(tmpdir, "#{slug}-#{style}.png")
        render_args = [ "python3", RENDER_SCRIPT.to_s, pes_path, path, "--style", style ]
        render_args << "--trim-guides" if trim_guides
        ok   = system(*render_args)
        ok && File.exist?(path) ? { style: style, path: path } : nil
      end

      if renders.any?
        product.images.purge if force && product.images.attached?
        attachables = renders.map do |r|
          filename = "#{slug}-#{r[:style]}.png"
          {
            io: File.open(r[:path]),
            filename: filename,
            content_type: "image/png",
            metadata: Product.image_metadata_for(filename: filename, render_style: r[:style])
          }
        end
        product.images.attach(attachables)
        product.reload
        attached = product.images.count
        puts "  #{"CREATE" if created}#{"UPDATE" unless created}  #{title} (#{attached}/#{renders.size} images)"
      else
        msg = "#{title}: all renders failed"
        puts "  ERROR  #{msg}"
        results[:errors] << msg
      end
    else
      puts "  SKIP   #{title} (already has images — use FORCE=1 to re-render)"
      results[:skipped] += 1
      return
    end

    created ? results[:created] += 1 : results[:updated] += 1
  rescue StandardError => e
    msg = "#{title}: #{e.message}"
    puts "  ERROR  #{msg}"
    results[:errors] << msg
  end
end
