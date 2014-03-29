# app/controllers/subscriptions_controller.rb
class SController < ApplicationController
  def show
    if subscription = current_user.subscription
      render json: subscription.as_json
    else
      render json: {}
    end
  end
end
