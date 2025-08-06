ActiveAdmin.register Product do
  permit_params :title, :price, :description, :category, :file_format, :is_available, :dimensions, :embroidery_file, images: []

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

  filter :title
  filter :category
  filter :is_available
  filter :created_at

  form do |f|
    f.inputs "Product Details" do
      f.input :title
      f.input :price
      f.input :description
      f.input :category
      f.input :file_format
      f.input :is_available
      f.input :dimensions
    end
    f.inputs "Media Uploads" do
      f.input :embroidery_file, as: :file
      f.input :images, as: :file, input_html: { multiple: true }
    end
    f.actions
  end

  show do
    attributes_table do
      row :title
      row :price
      row :description
      row :category
      row :file_format
      row :is_available
      row :dimensions
      row :created_at
      row :updated_at
      row :embroidery_file do |product|
        if product.embroidery_file.attached?
          link_to product.embroidery_file.filename, rails_blob_path(product.embroidery_file, disposition: "attachment")
        else
          "No file attached"
        end
      end
      row :images do |product|
        if product.images.attached?
          product.images.each do |image|
            div do
              image_tag image, style: "max-width: 200px; max-height: 200px; margin: 5px;"
            end
          end
        else
          "No images attached"
        end
      end
    end
    active_admin_comments
  end
end
