#!/usr/bin/env python3
"""
Send Gloria's AWS & Stripe Migration Guide with proper RFC-compliant MIME attachment.
Uses Gmail SMTP with TLS/SSL, ensuring Content-Disposition: attachment for all email clients.
"""

import os
import smtplib
import ssl
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

# Paths
ACCOUNTS_FILE = Path.home() / ".config/secrets/gmail-accounts.tsv"
PDF_PATH = Path("/Users/christopherbaptiste/Documents/shopzilla-contributor-studio-plan/Gloria-AWS-Stripe-Migration-and-Learning-Guide-2026-09-05.pdf")

RECIPIENT = "gloala456710@gmail.com"
CC_RECIPIENT = "chrisbaptiste667@gmail.com"
SUBJECT = "Your Embroidery Shop Migration & Cybersecurity Hands-On Guide 🧵✨"

# 1. Read credentials
if not ACCOUNTS_FILE.exists():
    raise FileNotFoundError(f"Accounts file not found: {ACCOUNTS_FILE}")

sender_email = None
app_password = None

for line in ACCOUNTS_FILE.read_text().splitlines():
    line = line.split("#")[0].strip()
    if not line:
        continue
    parts = line.split()
    if len(parts) >= 2 and parts[0] == "chrisbaptiste667@gmail.com":
        sender_email = parts[0]
        app_password = parts[1]
        break

if not sender_email or not app_password:
    raise ValueError("Could not find credentials for chrisbaptiste667@gmail.com")

if not PDF_PATH.exists():
    raise FileNotFoundError(f"PDF attachment not found: {PDF_PATH}")

# 2. Build MIME message
msg = MIMEMultipart("mixed")
msg["From"] = f"Christopher Baptiste <{sender_email}>"
msg["To"] = RECIPIENT
msg["Cc"] = CC_RECIPIENT
msg["Subject"] = SUBJECT

body_text = """Hey Gloria,

I put together a complete hands-on guide for you to take full ownership of your embroidery store (gloriasembroideryshop.com) and set up everything under your own name.

Since you're studying cybersecurity, I didn't just write a setup manual—I designed this as a real-world learning lab where you get to practice the exact core security principles you'll see in the field:

1. AWS Cloud Security & IAM:
   Setting up your own production AWS account (glorias-embroidery-prod), locking down the root account with hardware/app MFA, creating a least-privilege IAM administrator, and provisioning encrypted S3 asset storage with strict bucket policies.

2. Stripe Payments & Merchant Setup:
   Registering your merchant account so all store earnings go directly to your bank account, and understanding how webhook signatures (HMAC-SHA256) protect against replay attacks.

3. Customer Inquiries & Order Notifications:
   Connecting your email so all customer questions from the contact form and instant alerts for every new sale arrive directly in your inbox.

4. Tailscale Peer-to-Peer Catalog Curation:
   Connecting your laptop to our private, WireGuard-encrypted mesh network to review, curate, and approve designs from our collection of 11,800+ embroidery files without exposing anything to the public internet.

I've already staged the first test batch of 10 floral designs and built all the automation and verification scripts so we can step through it together smoothly.

The full 28-page guide is attached as a PDF (Gloria-AWS-Stripe-Migration-and-Learning-Guide-2026-09-05.pdf). Take a look whenever you're ready, and we'll dive in together!

Love,
Chris
"""

body_html = f"""<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #2d3748;">
  <p>Hey Gloria,</p>
  <p>I put together a complete hands-on guide for you to take full ownership of your embroidery store (<a href="https://gloriasembroideryshop.com" style="color: #6366f1; text-decoration: underline;">gloriasembroideryshop.com</a>) and set up everything under your own name.</p>
  <p>Since you're studying cybersecurity, I didn't just write a setup manual—I designed this as a real-world learning lab where you get to practice the exact core security principles you'll see in the field:</p>
  <ol style="padding-left: 20px;">
    <li style="margin-bottom: 12px;"><strong>AWS Cloud Security &amp; IAM:</strong><br>Setting up your own production AWS account (<code>glorias-embroidery-prod</code>), locking down the root account with hardware/app MFA, creating a least-privilege IAM administrator, and provisioning encrypted S3 asset storage with strict bucket policies.</li>
    <li style="margin-bottom: 12px;"><strong>Stripe Payments &amp; Merchant Setup:</strong><br>Registering your merchant account so all store earnings go directly to your bank account, and understanding how webhook signatures (HMAC-SHA256) protect against replay attacks.</li>
    <li style="margin-bottom: 12px;"><strong>Customer Inquiries &amp; Order Notifications:</strong><br>Connecting your email so all customer questions from the contact form and instant alerts for every new sale arrive directly in your inbox.</li>
    <li style="margin-bottom: 12px;"><strong>Tailscale Peer-to-Peer Catalog Curation:</strong><br>Connecting your laptop to our private, WireGuard-encrypted mesh network to review, curate, and approve designs from our collection of 11,800+ embroidery files without exposing anything to the public internet.</li>
  </ol>
  <p>I've already staged the first test batch of 10 floral designs and built all the automation and verification scripts so we can step through it together smoothly.</p>
  <p>The full 28-page guide is attached as a PDF (<strong>{PDF_PATH.name}</strong>). Take a look whenever you're ready, and we'll dive in together!</p>
  <p>Love,<br><strong>Chris</strong></p>
</body>
</html>"""

# Alternative part for text & html
alt_part = MIMEMultipart("alternative")
alt_part.attach(MIMEText(body_text, "plain", "utf-8"))
alt_part.attach(MIMEText(body_html, "html", "utf-8"))
msg.attach(alt_part)

# 3. Attach PDF as a proper application/pdf attachment
with open(PDF_PATH, "rb") as f:
    pdf_attachment = MIMEBase("application", "pdf")
    pdf_attachment.set_payload(f.read())

encoders.encode_base64(pdf_attachment)
pdf_attachment.add_header(
    "Content-Disposition",
    "attachment",
    filename=PDF_PATH.name
)
msg.attach(pdf_attachment)

# 4. Transmit via Gmail SMTP SSL
print(f"Connecting to smtp.gmail.com:465 via SSL...")
context = ssl.create_default_context()
with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
    server.login(sender_email, app_password)
    recipients = [RECIPIENT, CC_RECIPIENT]
    server.sendmail(sender_email, recipients, msg.as_string())

print(f"SUCCESS: Email sent to {RECIPIENT} (and cc'd {CC_RECIPIENT}) with attachment {PDF_PATH.name} ({PDF_PATH.stat().st_size} bytes)")
