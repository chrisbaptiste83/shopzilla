ActiveAdmin.register Product do
  permit_params :title, :price, :description, :file_format, :is_available, :dimensions, :category_id, :embroidery_file

  # Index page
  index do
    selectable_column
    id_column
    column :title
    column :price
    column :category
    column :is_available
    column :created_at
    actions
  end

  # Filters
  filter :title
  filter :price
  filter :category, as: :select, collection: Category.all
  filter :is_available
  filter :created_at

  # Form
  form do |f|
    f.inputs "Product Details" do
      f.input :title
      f.input :price

      # Rich text workaround: use text_area (rich text still works in the front-end show)
      f.input :description

      f.input :file_format
      f.input :is_available
      f.input :dimensions
      f.input :category, as: :select, collection: Category.all, include_blank: "Select a category"
      f.input :category, as: :string, input_html: { placeholder: "Or type a new category" }

      # ActiveStorage file input
      f.input :embroidery_file, as: :file, hint: f.object.embroidery_file.attached? ? 
        "Current file: #{f.object.embroidery_file.filename}" : "Upload embroidery file"
    end
    f.actions
  end
end

