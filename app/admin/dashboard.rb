# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Sales Overview" do
          div class: "dashboard-stats" do
            div class: "stat-item" do
              h3 "Total Revenue"
              h2 number_to_currency(Payment.where(status: "completed").sum(:amount))
            end
            div class: "stat-item" do
              h3 "Orders This Month"
              h2 Order.where(created_at: 1.month.ago..Time.current).count
            end
            div class: "stat-item" do
              h3 "Total Products"
              h2 Product.count
            end
          end
        end

        panel "Recent Orders" do
          table_for Order.includes(:user, :payment).limit(10).order(created_at: :desc) do
            column "Order", :id do |order|
              link_to "##{order.id}", admin_order_path(order)
            end
            column "Customer", :user
            column "Total" do |order|
              number_to_currency(order.total)
            end
            column "Status", :status
            column "Date", :created_at do |order|
              order.created_at.strftime("%m/%d/%Y")
            end
          end
        end
      end

      column do
        panel "Payment Status" do
          div do
            h4 "Completed: #{Payment.where(status: 'completed').count}"
            h4 "Pending: #{Payment.where(status: 'pending').count}"
            h4 "Failed: #{Payment.where(status: 'failed').count}"
          end
        end

        panel "Download Activity" do
          table_for DownloadAccess.includes(:user, :product).limit(10).order(created_at: :desc) do
            column "User", :user
            column "Product", :product
            column "Downloads", :download_count
            column "Expires", :expires_at do |access|
              access.expires_at.strftime("%m/%d/%Y %H:%M")
            end
          end
        end
      end
    end
  end # content
end
