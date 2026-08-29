require "test_helper"
require "base64"
require "tmpdir"
require "yaml"

class Embroidery::PreviewRendererTest < ActiveSupport::TestCase
  PNG_BYTES = Base64.strict_decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  ).freeze
  SUCCESS = Struct.new(:success?).new(true)

  setup do
    @tmpdir = Dir.mktmpdir("preview_renderer_test", Rails.root.join("tmp"))
    @output_path = File.join(@tmpdir, "preview.png")
  end

  teardown do
    FileUtils.rm_rf(@tmpdir)
  end

  test "maps isolated to light and passes rotation without trim guides" do
    command = nil
    output_path = @output_path
    capture = lambda do |*args|
      command = args
      File.binwrite(output_path, PNG_BYTES)
      [ "", "", SUCCESS ]
    end

    with_stubbed_capture3(capture) do
      result = Embroidery::PreviewRenderer.new(
        pes_path: "/tmp/design.pes",
        output_path: @output_path,
        style: :isolated,
        rotation: -3.5,
        trim_guides: false
      ).call

      assert result[:rendered]
    end

    assert_equal [
      "python3", Embroidery::PreviewRenderer::SCRIPT.to_s,
      "/tmp/design.pes", @output_path,
      "--style", "light", "--rotate", "-3.5"
    ], command
  end

  test "includes trim guide flag when enabled" do
    command = nil
    output_path = @output_path
    with_stubbed_capture3(lambda { |*args|
      command = args
      File.binwrite(output_path, PNG_BYTES)
      [ "", "", SUCCESS ]
    }) do
      Embroidery::PreviewRenderer.new(
        pes_path: "/tmp/design.pes",
        output_path: @output_path
      ).call
    end
    assert_includes command, "--trim-guides"
  end

  test "catalog quarter-turns known sideways previews to the left" do
    products = YAML.load_file(Rails.root.join("db/seeds/catalog.yml")).fetch("products")
    rotations = products.to_h do |product|
      [ product.fetch("title"), product.fetch("preview_rotation_degrees", 0) ]
    end

    %w[Mushroom\ Border Easter\ Eeyore Halloween\ Pumpkin\ Mouse].each do |title|
      assert_equal(-90, rotations.fetch(title), "expected #{title} to rotate 90 degrees left")
    end
  end

  test "rejects an empty renderer output" do
    output_path = @output_path
    with_stubbed_capture3(lambda { |*|
      File.binwrite(output_path, "")
      [ "", "", SUCCESS ]
    }) do
      error = assert_raises(RuntimeError) do
        Embroidery::PreviewRenderer.new(
          pes_path: "/tmp/design.pes",
          output_path: @output_path
        ).call
      end
      assert_match(/produced no output/, error.message)
    end
  end

  test "rejects corrupt PNG output" do
    output_path = @output_path
    with_stubbed_capture3(lambda { |*|
      File.binwrite(output_path, "not an image")
      [ "", "", SUCCESS ]
    }) do
      error = assert_raises(RuntimeError) do
        Embroidery::PreviewRenderer.new(
          pes_path: "/tmp/design.pes",
          output_path: @output_path
        ).call
      end
      assert_match(/invalid PNG/, error.message)
    end
  end

  private

  def with_stubbed_capture3(replacement)
    original = Open3.method(:capture3)
    Open3.define_singleton_method(:capture3) do |*args, **kwargs|
      if args.first == "python3"
        replacement.call(*args)
      else
        original.call(*args, **kwargs)
      end
    end
    yield
  ensure
    Open3.define_singleton_method(:capture3, original)
  end
end
