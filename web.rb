# frozen_string_literal: true

require "sinatra/base"
require "reviewbot/webhook_controller"

module ReviewBot
  class Web < Sinatra::Base

    get "/" do
      puts "Running"
    end

    get "/test" do
      file = File.read('sample_response2.json')
      body = JSON.parse(file)

      controller = WebhookController.new
      controller.handle_webhook_body(body) 
      true
    end

    post "/pullrequest" do
      body = JSON.parse(request.body.read)
      # puts body.to_json
      puts "Received pull request webhook"
      controller = WebhookController.new

      puts "Passing webhook body to WebhookController"
      controller.handle_webhook_body(body)

    end
  end
end
