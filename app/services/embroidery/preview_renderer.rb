require "open3"
require "digest"

module Embroidery
  class PreviewRenderer
    SCRIPT = Rails.root.join("bin", "render_embroidery_preview.py").freeze

    def initialize(pes_path:, output_path:, style: :isolated)
      @pes_path    = pes_path.to_s
      @output_path = output_path.to_s
      @style       = style.to_s
    end

    def call
      FileUtils.mkdir_p(File.dirname(@output_path))

      _stdout, stderr, status = Open3.capture3(
        "python3", SCRIPT.to_s, @pes_path, @output_path, "--style", @style
      )

      raise "render failed for #{@pes_path}: #{stderr.strip}" unless status.success?
      raise "renderer produced no output at #{@output_path}" unless File.exist?(@output_path)

      {
        filename:             File.basename(@output_path),
        source_relative_path: nil,
        byte_size:            File.size(@output_path),
        sha256:               Digest::SHA256.file(@output_path).hexdigest,
        proposed_s3_key:      nil,
        rendered:             true
      }
    end
  end
end
