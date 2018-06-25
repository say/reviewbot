# frozen_string_literal: true

# require "reviewbot/github"
require "slack-ruby-bot"

module ReviewBot
  class WebhookController
    attr_reader :slack
    private :slack

    def initialize
      Slack.configure do |config|
        config.token = ENV['SLACK_API_TOKEN']
      end

      print("Initializing a WebhookController...")
      @slack = Slack::Web::Client.new
      print("Slack client initialized! 🚀")
    end

    def handle_webhook_body(body)
        action = body['action']
        number = body['number']
  
        # Pull Request
        pull_request = body['pull_request']
        url = pull_request['html_url']
        title = pull_request['title']
  
        # Maps assignee/reviewers to just their github handle
        assignees = pull_request['assignees'].map { |assignee| assignee['login'] }
        reviewers = pull_request['requested_reviewers'].map { |reviewer| reviewer['login'] }
        
        # Maps labels to just the text value
        labels = pull_request['labels'].map { |label| label['name'] }
  
        # Repo
        repo = pull_request['head']['repo']
        repo_name = repo['name']
        repo_full_name = repo['full_name']
  
        # Map github handles => User model objects
        assignee_users = assignees.map { |user| User.find_by(github_user: user) }.compact
        reviewer_users = reviewers.map { |user| User.find_by(github_user: user) }.compact
  
        puts "Found #{assignee_users.count} assignees, #{reviewer_users.count} reviewers"
  

        # TODO: Dry this 😬
        assignee_users.each { |user|
          puts "Checking if @#{user.slack_user} should be updated"
          slack_username = "@" + user.slack_user

          # Check if we are subscribed to this label
          break if (user.labels & labels).empty?
          
          # Check if we are subscribed to this repo (case insensitive)
          user_repos = user.repositories.map(&:downcase)
          break if !(user_repos.include? repo_name.downcase or user_repos.include? repo_full_name.downcase)
  
          puts "[#{slack_username}]: Sending message because of #{user.labels & labels} label(s)"

          status_color = pull_request['state'] == 'open' ? "#03b70b" : "#ff0000"
          formatted_pr = "##{number} - #{title}:\n#{url}"
          
          @slack.chat_postMessage(
            channel: slack_username,
            text: "Update", 
            attachments: [
              {
                thumb_url: "",
                fallback: "Ready for Review Pull Requests:\n\n#{formatted_pr}",
                title: "An assigned pull request was #{action}",
                title_link: url,
                text: formatted_pr,
                color: status_color
              }
            ],
            as_user: true)
        }


        reviewer_users.each { |user|
          puts "Checking if @#{user.slack_user} should be updated"
          slack_username = "@" + user.slack_user

          # Check if we are subscribed to this label
          break if (user.labels & labels).empty?

          # Don't send another message if we already sent one to an assignee
          break if assignee_users.include? user
          
          # Check if we are subscribed to this repo (case insensitive)
          user_repos = user.repositories.map(&:downcase)
          break if !(user_repos.include? repo_name.downcase or user_repos.include? repo_full_name.downcase)
  
          puts "[#{slack_username}]: Sending message because of #{user.labels & labels} label(s)"

          status_color = pull_request['state'] == 'open' ? "#03b70b" : "#ff0000"
          formatted_pr = "##{number} - #{title}:\n#{url}"
          
          @slack.chat_postMessage(
            channel: slack_username,
            text: "Update", 
            attachments: [
              {
                thumb_url: "",
                fallback: "Ready for Review Pull Requests:\n\n#{formatted_pr}",
                title: "A pull request that you are reviewing was #{action}",
                title_link: url,
                text: formatted_pr,
                color: status_color
              }
            ],
            as_user: true)
        }
   
    end

  end
end
