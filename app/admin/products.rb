ActiveAdmin.register Product do
  permit_params :title, :price, :description, :file_format, :is_available,
                :physical_product, :shippable, :dimensions, :stitch_count,
                :category_id, :new_category_name, :embroidery_file,
                images: [], purge_images: []

  # ── Index ──────────────────────────────────────────────────────────────────
  index do
    selectable_column
    id_column
    column :title
    column :price do |p| number_to_currency(p.price) end
    column :category
    column("Available") { |p| p.is_available ? "✓" : "—" }
    column("Images")    { |p| p.images.count }
    column :created_at
    actions
  end

  # ── Filters ────────────────────────────────────────────────────────────────
  filter :title
  filter :price
  filter :category, as: :select, collection: -> { Category.order(:name).pluck(:name, :id) }
  filter :is_available
  filter :created_at

  # ── Show ───────────────────────────────────────────────────────────────────
  show do
    attributes_table do
      row :title
      row :price
      row :category
      row :file_format
      row :dimensions
      row :stitch_count
      row :is_available
      row :physical_product
      row :shippable
      row(:description) { |p| p.description.to_s.html_safe }
      row(:embroidery_file) do |p|
        p.embroidery_file.attached? ? p.embroidery_file.filename.to_s : "—"
      end
      row(:images) do |p|
        if p.images.attached?
          p.images.map { |img|
            image_tag img.variant(resize_to_fill: [80, 80]),
                      style: "margin:2px;border-radius:6px;"
          }.join.html_safe
        else
          "—"
        end
      end
    end
    active_admin_comments
  end

  # ── Form ───────────────────────────────────────────────────────────────────
  form do |f|
    f.semantic_errors

    columns do
      column do
        # Product Details
        f.inputs "Product Details" do
          f.input :title,
                  hint: "A catchy name for your embroidery design (3–255 characters)"

          f.input :price,
                  as: :number,
                  input_html: { min: 0, step: 0.01 },
                  hint: "Price in dollars"

          f.input :description,
                  as: :text,
                  input_html: { rows: 6 },
                  hint: "Describe the design, usage tips, or any notes"

          f.input :file_format,
                  hint: "e.g. PES, DST, JEF — or leave blank"

          f.input :dimensions,
                  hint: "e.g. 4×4 inches or hoop size"

          f.input :stitch_count,
                  as: :number,
                  input_html: { min: 0, step: 1 },
                  hint: "Total stitch count (optional)"

          f.input :is_available,
                  label: "Available for purchase",
                  hint: "Uncheck to hide from the shop"

          f.input :physical_product,
                  label: "Physical product",
                  hint: "Check if this requires shipping"

          f.input :shippable,
                  hint: "Check if shippable"
        end

        # Category
        f.inputs "Category" do
          f.input :category,
                  as: :select,
                  collection: Category.order(:name).map { |c| [c.name, c.id] },
                  include_blank: "— Select existing category —",
                  hint: "Pick an existing category, or create one below"

          f.input :new_category_name,
                  as: :string,
                  label: "Or create a new category",
                  hint: "Type a name — it will be created automatically and selected"
        end
      end

      column do
        # Embroidery File
        f.inputs "Embroidery File" do
          f.input :embroidery_file,
                  as: :file,
                  hint: f.object.embroidery_file.attached? ?
                    "Currently attached: #{f.object.embroidery_file.filename}" :
                    "Upload a .pes, .dst, .jef or similar file"
        end

        # Product Images
        f.inputs "Product Images (max 2)" do
          f.input :images,
                  as: :file,
                  input_html: { multiple: true, accept: "image/*" },
                  label: "Upload images",
                  hint: "Hold Ctrl/Cmd to select multiple. Max 10 MB each."

          if f.object.images.attached?
            f.inputs "Current Images — check box to remove" do
              f.object.images.each do |image|
                li do
                  image_tag image.variant(resize_to_fill: [80, 80]),
                            style: "border-radius:8px;vertical-align:middle;margin-right:8px;"
                  span image.filename.to_s, style: "font-size:0.85rem;color:#555;"
                  check_box_tag "product[purge_images][]", image.id, false,
                                id: "purge_#{image.id}",
                                style: "margin-left:12px;vertical-align:middle;"
                  label_tag "purge_#{image.id}", "Remove",
                            style: "margin-left:4px;font-size:0.8rem;color:#c0392b;cursor:pointer;"
                end
              end
            end
          end
        end
      end
    end

    f.actions
  end

  # ── Controller hooks ───────────────────────────────────────────────────────
  controller do
    def create
      handle_category_and_purge
      super
    end

    def update
      handle_category_and_purge
      super
    end

    private

    def handle_category_and_purge
      new_name = params[:product]&.delete(:new_category_name)&.strip
      if new_name.present?
        cat = Category.find_or_create_by!(name: new_name)
        params[:product][:category_id] = cat.id
      end

      blob_ids = Array(params[:product]&.delete(:purge_images)).map(&:to_s).reject(&:blank?)
      if blob_ids.any? && params[:id].present?
        product = Product.find(params[:id])
        product.images.each do |img|
          img.purge if blob_ids.include?(img.id.to_s)
        end
      end
    end
  end
end
