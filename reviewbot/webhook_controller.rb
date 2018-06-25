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

      puts "Initializing a WebhookController..."
      @slack = Slack::Web::Client.new
      puts "Slack client initialized! 🚀"
    end

    def handle_webhook_body(body)
        ignored_actions = ["unlabeled"]

        action = body['action']
        number = body['number']

        return nil if ignored_actions.include? action
  
        # Pull Request
        pull_request = body['pull_request']
        url = pull_request['html_url']
        title = pull_request['title']
  
        # Maps assignee/reviewers to just their github handle
        assignees = pull_request['assignees'].map { |assignee| assignee['login'] }
        reviewers = pull_request['requested_reviewers'].map { |reviewer| reviewer['login'] }
        color = pull_request['state'] == 'open' ? "#03b70b" : "#ff0000"

        # Maps labels to just the text value
        labels = pull_request['labels'].map { |label| label['name'] }
  
        # Repo
        repo = pull_request['head']['repo']
        repo_name = repo['name']
        repo_full_name = repo['full_name']

        # Map github handles => User model objects
        assignee_users = assignees.map { |user| User.find_by(github_user: user) }.compact
        reviewer_users = (reviewers - assignees).map { |user| User.find_by(github_user: user) }.compact

        formatted_pr = "##{number} - #{title}:\n#{url}"
        assignees = check_if_updates_needed(assignee_users, labels, repo_name, repo_full_name)
        puts "Assignees: #{assignees}"

        assignees.each { |user|
          send_message(user.slack_user, number, title, url, formatted_pr, color, action)
        } if assignees
 
        puts "Reviewers: #{reviewers}"
        reviewers = check_if_updates_needed(reviewer_users, labels, repo_name, repo_full_name)
        reviewers.each { |user|
          send_message(user.slack_user, number, title, url, formatted_pr, color, action)
        } if reviewers
        nil
    end
    
    private

    def check_if_updates_needed(users, labels, repo, full_repo)
      puts "Checking #{users} against #{repo} with #{labels}"
      filtered = users.select do |user|
        puts "Checking if @#{user.slack_user} should be updated"
        # Check if we are subscribed to this repo (case insensitive)
        user_repos = user.repositories.map(&:downcase)
        (user.labels & labels) && (user_repos.include? repo.downcase or user_repos.include? full_repo.downcase)
      end
      puts "Filtered: #{filtered}"

      return filtered
    end

    def send_message(slack_user, number, title, url, text, color, action)
      puts "[#{slack_user}]: Sending message '#{text}' because of #{action}"

      @slack.chat_postMessage(
        channel: "@" + slack_user,
        text: "##{number} was just #{action}", 
        attachments: [
          {
            thumb_url: "",
            fallback: "Ready for Review Pull Requests:\n\n#{text}",
            title: title,
            title_link: url,
            text: text,
            color: color
          }
        ],
        as_user: true)
    end

  end
end
