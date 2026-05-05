require "fileutils"
require "json"

module Embroidery
  class SourceCleanup
    Result = Struct.new(
      :manifest_path,
      :source_root,
      :candidates,
      :summary,
      keyword_init: true
    ) do
      def to_h
        {
          manifest_path: manifest_path,
          source_root: source_root,
          summary: summary,
          candidates: candidates
        }
      end
    end

    def initialize(manifest_path:, dry_run: true, force: false)
      @manifest_path = Pathname.new(manifest_path).expand_path
      @dry_run = dry_run
      @force = force
    end

    def call
      raise ArgumentError, "manifest path does not exist: #{@manifest_path}" unless @manifest_path.file?
      raise ArgumentError, "refusing destructive cleanup without force confirmation" if !@dry_run && !@force

      manifest = JSON.parse(@manifest_path.read).deep_symbolize_keys
      source_root = Pathname.new(manifest.fetch(:source_root))
      packaged_products = Array(manifest[:packaged_products])

      candidates = packaged_products.map do |product|
        build_candidate(product, source_root)
      end

      candidates.each do |candidate|
        next unless candidate[:within_source_root]
        next unless candidate[:exists]
        next if @dry_run

        FileUtils.rm_rf(candidate[:source_path])
        candidate[:action] = "deleted"
      end

      Result.new(
        manifest_path: @manifest_path.to_s,
        source_root: source_root.to_s,
        candidates: candidates,
        summary: build_summary(candidates)
      )
    end

    private

    def build_candidate(product, source_root)
      path = Pathname.new(product.fetch(:source_path))
      exists = path.directory?
      within_source_root = path.to_s == source_root.to_s || path.to_s.start_with?("#{source_root}#{File::SEPARATOR}")

      {
        source_path: path.to_s,
        source_relative_path: product[:source_relative_path],
        proposed_s3_prefix: product[:proposed_s3_prefix],
        exists: exists,
        within_source_root: within_source_root,
        byte_size: exists ? directory_size(path) : 0,
        action: initial_action(exists, within_source_root)
      }
    end

    def directory_size(path)
      Dir.glob(path.join("**", "*").to_s).sum do |entry|
        File.file?(entry) ? File.size(entry) : 0
      end
    end

    def initial_action(exists, within_source_root)
      return "outside_source_root" unless within_source_root
      return "missing" unless exists

      @dry_run ? "would_delete" : "pending_delete"
    end

    def build_summary(candidates)
      {
        dry_run: @dry_run,
        candidate_count: candidates.size,
        existing_count: candidates.count { |candidate| candidate[:exists] },
        outside_source_root_count: candidates.count { |candidate| !candidate[:within_source_root] },
        missing_count: candidates.count { |candidate| !candidate[:exists] },
        deleted_count: candidates.count { |candidate| candidate[:action] == "deleted" },
        total_bytes: candidates.sum { |candidate| candidate[:byte_size] }
      }
    end
  end
end
