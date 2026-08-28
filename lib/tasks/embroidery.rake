require "yaml"
require "tmpdir"
require "tempfile"
require "digest"
require "base64"

namespace :embroidery do
  CATALOG_FILE   = Rails.root.join("db/seeds/catalog.yml")
  RENDER_SCRIPT  = Rails.root.join("scripts/render_pes.py")
  DEFAULT_SOURCE = File.expand_path("~/Desktop/Embroidery Files")
  PREVIEW_STYLES = %w[dark light detail].freeze

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
    abort "Import failed for #{results[:errors].size} product(s)" if results[:errors].any?
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

    rerender_product_previews(product, rotation: rotation, dry_run: dry_run)
  end

  desc "Apply preview rotations declared in db/seeds/catalog.yml (DRY_RUN=true by default)"
  task apply_catalog_preview_rotations: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    products = YAML.load_file(CATALOG_FILE).fetch("products", [])
                   .select { |data| Float(data.fetch("preview_rotation_degrees", 0)) != 0 }

    products.each do |data|
      product = Product.find_by(title: data.fetch("title"))
      unless product
        warn "Skipping #{data.fetch('title')}: product not found"
        next
      end

      rerender_product_previews(
        product,
        rotation: Float(data.fetch("preview_rotation_degrees")),
        dry_run: dry_run
      )
    end
  end

  # ── embroidery:reimport ───────────────────────────────────────────────────────
  desc "Force re-render and re-attach all product images"
  task reimport: :environment do
    ENV["FORCE"] = "1"
    Rake::Task["embroidery:import"].invoke
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

  def rerender_product_previews(product, rotation:, dry_run:)
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
          Embroidery::PreviewRenderer.new(
            pes_path: pes_file.path,
            output_path: output_path,
            style: style,
            rotation: rotation
          ).call

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

  def seed_categories(names)
    names.each { |name| Category.find_or_create_by!(name: name) }
    puts "Categories ready: #{names.join(', ')}\n\n"
  end

  def import_one(data, source_dir, tmpdir, force, trim_guides, results)
    title    = data.fetch("title")
    cat_name = data.fetch("category")
    pes_name = data.fetch("pes_file")
    pes_path = File.join(source_dir, pes_name)
    preview_rotation = Float(data.fetch("preview_rotation_degrees", 0))

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
      begin
        slug = title.parameterize
        renders = PREVIEW_STYLES.map do |style|
          path = File.join(tmpdir, "#{slug}-#{style}.png")
          Embroidery::PreviewRenderer.new(
            pes_path: pes_path,
            output_path: path,
            style: style,
            rotation: preview_rotation,
            trim_guides: trim_guides
          ).call
          { style: style, path: path }
        end

        replacement_blobs = renders.map do |render|
          filename = "#{slug}-#{render[:style]}.png"
          metadata = Product.image_metadata_for(filename: filename, render_style: render[:style])
          metadata["render_rotation_degrees"] = preview_rotation unless preview_rotation.zero?

          File.open(render[:path], "rb") do |io|
            ActiveStorage::Blob.create_and_upload!(
              io: io,
              filename: filename,
              content_type: "image/png",
              metadata: metadata
            )
          end
        end

        old_attachments = force ? product.images.attachments.to_a : []
        product.with_lock do
          product.images.attach(replacement_blobs)
          old_attachments.each(&:destroy!)
        end

        product.reload
        attached = product.images.count
        puts "  #{"CREATE" if created}#{"UPDATE" unless created}  #{title} (#{attached}/#{renders.size} images)"
      rescue StandardError
        replacement_blobs&.each do |blob|
          blob.purge unless blob.attachments.exists?
        rescue StandardError
          nil
        end
        raise
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
