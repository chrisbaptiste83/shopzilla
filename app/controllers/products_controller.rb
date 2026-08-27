# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  ALLOWED_SORTS = %w[newest price_low price_high].freeze

  before_action :set_product, only: %i[show edit update destroy]
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :check_admin, only: %i[new create edit update destroy]

  # GET /products
  def index
    @products = Product
      .where(is_available: true)
      .includes(:category, images_attachments: :blob)
      .with_rich_text_description

    # 🔎 Search (title + description if present)
    if params[:search].present?
      search_term = "%#{Product.sanitize_sql_like(params[:search].downcase)}%"
      @products = @products
        .left_joins(:rich_text_description)
        .where("LOWER(products.title) LIKE :q OR LOWER(action_text_rich_texts.body) LIKE :q", q: search_term)
    end

    # 🎨 Filter by category
    if params[:category_id].present?
      @products = @products.where(category_id: params[:category_id])
    end

    # 🗂️ Filter by file_format (use :file_format param to avoid clash with Rails' :format)
    if params[:file_format].present?
      format_term = "%#{Product.sanitize_sql_like(params[:file_format].downcase)}%"
      @products = @products.where("LOWER(file_format) LIKE ?", format_term)
    end

    # 🧵 Filter by stitch count
    if params[:stitch_min].present?
      @products = @products.where("stitch_count >= ?", params[:stitch_min].to_i)
    end
    if params[:stitch_max].present?
      @products = @products.where("stitch_count <= ?", params[:stitch_max].to_i)
    end

    # 🔃 Sorting (Strict Whitelist Enforcement)
    sort_key = ALLOWED_SORTS.include?(params[:sort]) ? params[:sort] : nil
    case sort_key
    when "newest"
      @products = @products.order(created_at: :desc)
    when "price_low"
      @products = @products.order(price: :asc)
    when "price_high"
      @products = @products.order(price: :desc)
    else
      @products = @products.order(created_at: :desc) if @products.order_values.empty?
    end

    per_page = params[:per].to_i
    per_page = 24 if per_page <= 0
    per_page = 48 if per_page > 48
    @products = @products.page(params[:page]).per(per_page)
    @categories = Category.with_available_products
    @file_formats = Product.where(is_available: true).where.not(file_format: [ nil, "" ]).distinct.pluck(:file_format)
      .flat_map { |formats| formats.split(/\s*,\s*/) }.uniq.sort

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  # GET /products/1
  def show
    @related_products = @product.category.products
      .where(is_available: true)
      .where.not(id: @product.id)
      .includes(images_attachments: :blob)
      .limit(4)

    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  # GET /products/new — managed exclusively in the admin panel
  def new
    redirect_to new_admin_product_path
  end

  # GET /products/1/edit — managed exclusively in the admin panel
  def edit
    redirect_to edit_admin_product_path(@product)
  end

  # POST /products
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to product_url(@product), notice: "Product was successfully created." }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1
  def update
    # Purge selected images before updating the product
    if params[:purge_images].present?
      @product.images.where(id: params[:purge_images]).each(&:purge)
    end

    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to product_url(@product), notice: "Product was successfully updated." }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1
  def destroy
    @product.destroy!
    respond_to do |format|
      format.html { redirect_to products_url, notice: "Product was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_product
    @product = Product
      .includes(:category, { reviews: :user }, :rich_text_description, images_attachments: :blob, embroidery_file_attachment: :blob)
      .find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :title,
      :price,
      :description,
      :category_id,
      :new_category_name, # 🆕 allow new category name
      :file_format,
      :is_available,
      :dimensions,
      :stitch_count,
      :physical_product, # 🚚 allow physical product
      :embroidery_file,
      images: [],
      purge_images: [] # 🖼️ allow purging images
    )
  end

  def check_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
  end
end
