# frozen_string_literal: true

require "sinatra/base"
require "reviewbot/webhook_controller"

module ReviewBot
  class Web < Sinatra::Base

    get "/" do
      puts "Running"
    end

    post "/pullrequest" do
      body = JSON.parse(request.body.read)

      print("Received pull request webhook")
      controller = WebhookController.new

      print("Passing webhook body to WebhookController")
      controller.handle_webhook_body(body)

    end
  end
end
