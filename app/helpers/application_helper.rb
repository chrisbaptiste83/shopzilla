module ApplicationHelper
  def in_wishlist?(product)
    return false unless user_signed_in?
    current_user.wishlist_items.exists?(product_id: product.id)
  end

  def wishlist_item_for(product)
    return nil unless user_signed_in?
    current_user.wishlist_items.find_by(product_id: product.id)
  end

  CATEGORY_IMAGE_MAP = [
    [ /animal/i,                   "categories/animals.jpg"       ],
    [ /cartoon|whimsy/i,           "categories/cartoons.jpg"      ],
    [ /letter|monogram/i,          "categories/monograms.jpg"     ],
    [ /holiday|christmas|seasonal/i, "categories/holiday.jpg"     ],
    [ /baby|nursery/i,             "categories/baby.jpg"          ],
    [ /floral.+nature|nature.+floral/i, "categories/floral_nature.jpg" ],
    [ /floral|flower|botanical/i,  "categories/floral.jpg"        ]
  ].freeze

  def category_banner_image(category)
    name = category.name.to_s
    matched = CATEGORY_IMAGE_MAP.find { |pattern, _| name.match?(pattern) }
    matched ? matched[1] : "categories/hero.jpg"
  end

  def imagekit_url(blob_or_attachment, transforms = {})
    endpoint = ENV.fetch("IMAGEKIT_URL_ENDPOINT", nil)
    return nil unless endpoint

    key = if blob_or_attachment.respond_to?(:blob)
      blob_or_attachment.blob.key
    elsif blob_or_attachment.respond_to?(:key)
      blob_or_attachment.key
    else
      blob_or_attachment.to_s
    end

    tr = transforms.map do |k, v|
      case k
      when :width   then "w-#{v}"
      when :height  then "h-#{v}"
      when :quality then "q-#{v}"
      when :format  then "f-#{v}"
      when :crop    then "c-#{v}"
      when :sharpen then "e-sharpen-#{v}"
      else "#{k}-#{v}"
      end
    end.join(",")

    url = "#{endpoint}/#{key}"
    tr.present? ? "#{url}?tr=#{tr}" : url
  end

  def turbo_native_app?
    request.user_agent.to_s.include?("Turbo Native") ||
      request.user_agent.to_s.include?("Hotwire Native")
  end
end
