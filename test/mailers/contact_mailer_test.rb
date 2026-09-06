require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "message_notification delivers formatted contact inquiry" do
    email = ContactMailer.message_notification(
      name: "Jane Doe",
      email: "jane@example.com",
      subject: "Custom Embroidery Request",
      message: "Can you create a custom floral patch?"
    )

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "support@gloriasembroideryshop.com" ], email.to
    assert_equal [ "jane@example.com" ], email.reply_to
    assert_includes email.subject, "Custom Embroidery Request"
    assert_includes email.subject, "Jane Doe"
    assert_includes email.html_part.body.to_s, "Can you create a custom floral patch?"
    assert_includes email.text_part.body.to_s, "Can you create a custom floral patch?"
  end
end
