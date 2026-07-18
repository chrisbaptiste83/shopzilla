# frozen_string_literal: true

class StripeTerminalService
  MIN_AMOUNT_CENTS = 50
  MAX_AMOUNT_CENTS = 1_000_000
  CURRENCY = "usd"

  class Error < StandardError; end
  class ValidationError < Error; end
  class OwnershipError < Error; end

  def self.connection_token
    Stripe::Terminal::ConnectionToken.create
  end

  def self.create_payment_intent(user:, amount_cents:, product_ids: [])
    new.create_payment_intent(user: user, amount_cents: amount_cents, product_ids: product_ids)
  end

  def self.capture!(user:, payment_intent_id:)
    new.capture!(user: user, payment_intent_id: payment_intent_id)
  end

  def create_payment_intent(user:, amount_cents:, product_ids: [])
    cents = normalize_amount_cents!(amount_cents)
    ids = Array(product_ids).map { |id| id.to_s.strip }.reject(&:blank?).first(50)

    Stripe::PaymentIntent.create(
      amount: cents,
      currency: CURRENCY,
      payment_method_types: [ "card_present" ],
      capture_method: "manual",
      metadata: {
        user_id: user.id.to_s,
        product_ids: ids.join(","),
        tap_to_pay: "true"
      }
    )
  end

  def capture!(user:, payment_intent_id:)
    id = payment_intent_id.to_s.strip
    raise ValidationError, "payment_intent_id is required" if id.blank?

    intent = Stripe::PaymentIntent.retrieve(id)
    owner = intent.metadata["user_id"].to_s
    raise OwnershipError, "payment intent is not owned by this user" unless owner == user.id.to_s

    Stripe::PaymentIntent.capture(id)
  end

  private

  def normalize_amount_cents!(value)
    cents =
      case value
      when Integer then value
      when String
        raise ValidationError, "amount_cents must be an integer" unless value.match?(/\A-?\d+\z/)
        value.to_i
      else
        raise ValidationError, "amount_cents must be an integer (cents), not a float dollar amount"
      end

    if cents < MIN_AMOUNT_CENTS || cents > MAX_AMOUNT_CENTS
      raise ValidationError, "amount_cents must be between #{MIN_AMOUNT_CENTS} and #{MAX_AMOUNT_CENTS}"
    end
    cents
  end
end
