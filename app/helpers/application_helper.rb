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
    [ /floral|flower|botanical/i,  "categories/floral.jpg"        ],
  ].freeze

  def category_banner_image(category)
    name = category.name.to_s
    matched = CATEGORY_IMAGE_MAP.find { |pattern, _| name.match?(pattern) }
    matched ? matched[1] : "categories/hero.jpg"
  end
end
