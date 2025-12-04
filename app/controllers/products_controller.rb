# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  before_action :set_product, only: %i[show edit update destroy]
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :check_admin, only: %i[new create edit update destroy]

  # GET /products
  def index
    @products = Product.all

    # 🔎 Search (title + description if present)
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @products = @products.where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?", search_term, search_term)
    end

    # 🎨 Filter by category
    if params[:category_id].present?
      @products = @products.where(category_id: params[:category_id])
    end

    # 🗂️ Filter by format
    if params[:format].present?
      format_term = "%#{params[:format].downcase}%"
      @products = @products.where("LOWER(file_format) LIKE ?", format_term)
    end

    # 🔃 Sorting
    case params[:sort]
    when "newest"
      @products = @products.order(created_at: :desc)
    when "price_low"
      @products = @products.order(price: :asc)
    when "price_high"
      @products = @products.order(price: :desc)
    end
  end

  # GET /products/1
  def show; end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit; end

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
      attachments = ActiveStorage::Attachment.find(params[:purge_images])
      attachments.each(&:purge)
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
    @product = Product.find(params[:id])
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

