ActiveAdmin.register Category do
  permit_params :name

  # Index page
  index do
    selectable_column
    id_column
    column :name
    column :created_at
    actions
  end

  # Filters
  filter :name
  filter :created_at

  # Form
  form do |f|
    f.inputs "Category Details" do
      f.input :name
    end
    f.actions
  end
end

