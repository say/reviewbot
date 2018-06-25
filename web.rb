# frozen_string_literal: true

require "sinatra/base"
require "slack-ruby-bot"

module ReviewBot
  class Web < Sinatra::Base

    def format_pull_requests(pull_requests)
      pull_requests.map do |pull_request|
        number = pull_request.number
        title = pull_request.title
        url = pull_request.html_url
        "##{number} - #{title}:\n#{url}"
      end.join("\n\n")
    end

    get "/" do
      puts "Hello"


    end

    post "/pullrequest" do
      body = JSON.parse(request.body.read)

      pull_request = body['pull_request']
      action = body['action']

      repo_name = pull_request['head']['repo']['name']
      repo_full_name = pull_request['head']['repo']['full_name']
      pr_title = pull_request['title']
      pr_number = pull_request['number']


      assignees = pull_request['assignees'].map { |assignee| assignee['login'] }
      reviewers = pull_request['requested_reviewers'].map { |reviewer| reviewer['login'] }
      labels = pull_request['labels'].map { |label| label['name'] }

      Slack.configure do |config|
        config.token = ENV['SLACK_API_TOKEN']
      end

      user_assignees = assignees.map { |assignee| User.find_by(github_user: assignee) }.compact

      if user_assignees.empty?
        return
      end

      puts "Found assignees: #{user_assignees}"

      @github = GitHub.new

      octokit_pr = @github.pull_request(repo_full_name, pr_number)
      formatted_prs = format_pull_requests([octokit_pr])

      user_assignees.each { |user|
        puts "Checking if @#{user.slack_user} should be updated"

        # Check if we have any labels in common        
        break if (user.labels & labels).empty?
        
        user_repos = user.repositories.map(&:downcase)
        break if !(user_repos.include? repo_name.downcase or user_repos.include? repo_full_name.downcase)

        puts "We have something for @#{user.slack_user}: #{user.labels & labels}}"

        client = Slack::Web::Client.new

        slack_username = "@" + user.slack_user
        client.chat_postMessage(
          channel: slack_username, 
          text: "Update  #{'https://github.com/' + repo_full_name}", 
          attachments: [
            {
              fallback: "Ready for Review Pull Requests:\n\n#{formatted_prs}",
              title: "[#{action}] #{pr_title} -- ##{pr_number}",
              pretext: "A pull request that you are an 'assignee' of was updated:",
              text: formatted_prs,
              color: "#03b70b"
            }
          ],
          as_user: true)

      }
 
    end
  end
end
