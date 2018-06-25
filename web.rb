# frozen_string_literal: true

require "sinatra/base"

module ReviewBot
  class Web < Sinatra::Base
    get "/" do
      "ReviewBot"
    end

    post "/pullrequest" do
      body = JSON.parse(request.body.read)

      pull_request = body['pull_request']
      action = body['action']

      repo_name = pull_request['head']['repo']['name']
      repo_full_name = pull_request['head']['repo']['name'] 


      assignees = pull_request['assignees'].map { |assignee| assignee['login'] }
      reviewers = pull_request['requested_reviewers'].map { |reviewer| reviewer['login'] }
      labels = pull_request['labels'].map { |label| label['name'] }

      puts "#{repo_full_name} was #{action}:\nAssignees: #{assignees}\nReviewers: #{reviewers}\nLabels: #{labels}"
 
    end
  end
end
