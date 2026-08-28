require "open3"
require "digest"
require "mini_magick"

module Embroidery
  class PreviewRenderer
    SCRIPT = Rails.root.join("scripts", "render_pes.py").freeze

    def initialize(pes_path:, output_path:, style: :isolated, rotation: 0, trim_guides: true)
      @pes_path    = pes_path.to_s
      @output_path = output_path.to_s
      @style       = style.to_s == "isolated" ? "light" : style.to_s
      @rotation    = rotation.to_f
      @trim_guides = trim_guides
    end

    def call
      FileUtils.mkdir_p(File.dirname(@output_path))

      command = [
        "python3", SCRIPT.to_s, @pes_path, @output_path,
        "--style", @style, "--rotate", @rotation.to_s
      ]
      command << "--trim-guides" if @trim_guides
      _stdout, stderr, status = Open3.capture3(*command)

      raise "render failed for #{@pes_path}: #{stderr.strip}" unless status.success?
      validate_output!

      {
        filename:             File.basename(@output_path),
        source_relative_path: nil,
        byte_size:            File.size(@output_path),
        sha256:               Digest::SHA256.file(@output_path).hexdigest,
        proposed_s3_key:      nil,
        rendered:             true
      }
    end

    private

    def validate_output!
      unless File.file?(@output_path) && File.size(@output_path).positive?
        raise "renderer produced no output at #{@output_path}"
      end

      image = MiniMagick::Image.open(@output_path)
      image.validate!
      raise "renderer produced a non-PNG image at #{@output_path}" unless image.type == "PNG"
    rescue MiniMagick::Error, MiniMagick::Invalid => e
      raise "renderer produced an invalid PNG at #{@output_path}: #{e.message}"
    end
  end
end
