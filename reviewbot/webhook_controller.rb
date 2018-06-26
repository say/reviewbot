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

      # Do not fire events for these actions
      ignored_actions = ["unlabeled"]

      action = body['action']
      number = body['number']
      
      author_icon = body['sender']['avatar_url']        
      author_name = body['sender']['login']
      author_link = body['sender']['html_url']

      icon_map = {
        "commented" => "https://png.icons8.com/ultraviolet/75/000000/comments.png",
        "labeled" => "https://png.icons8.com/ultraviolet/75/000000/details-popup.png",
        "unlabeled" => "https://png.icons8.com/ultraviolet/75/000000/do-not-disturb.png",
        "closed" => "https://png.icons8.com/ultraviolet/75/000000/toggle-off.png",
        "opened" => "https://png.icons8.com/ultraviolet/75/000000/toggle-on.png",
        "reopened" => "https://png.icons8.com/ultraviolet/75/000000/work.png",
        "edited" => "https://png.icons8.com/ultraviolet/75/000000/save-as.png",
        "submitted" => author_icon
      }

      action_icon_url = ""#icon_map[action]

      return nil if ignored_actions.include? action

      # Pull Request
      pull_request = body['pull_request']

      return nil if pull_request.nil?

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
        send_message(user.slack_user, number, title, url, formatted_pr, color, action, action_icon_url, author_name, author_icon, author_link)
      } if assignees

      puts "Reviewers: #{reviewers}"
      reviewers = check_if_updates_needed(reviewer_users, labels, repo_name, repo_full_name)
      reviewers.each { |user|
        send_message(user.slack_user, number, title, url, formatted_pr, color, action, action_icon_url, author_name, author_icon, author_link)
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
        (user.labels & labels).count > 0 && (user_repos.include? repo.downcase or user_repos.include? full_repo.downcase)
      end
      puts "Filtered: #{filtered}"

      return filtered
    end

    def send_message(slack_user, number, title, url, text, color, action, action_icon_url, author_name, author_icon, author_link)
      puts "[#{slack_user}]: Sending message '#{text}' because of #{action}"

      @slack.chat_postMessage(
        channel: "@" + slack_user,
        text: "Pull request ##{number} was just *#{action} by #{author_name}*",
        attachments: [
          {
            thumb_url: action_icon_url,
            fallback: "Ready for Review Pull Requests:\n\n#{text}",
            title: title,
            title_link: url,
            text: text,
            color: color,
            author_name: author_name,
            author_icon: author_icon,
            author_link: author_link,
            footer: "Github Webhook",
            footer_icon: "https://assets-cdn.github.com/images/modules/logos_page/Octocat.png",
            ts: Time.now.to_i
          }
        ],
        as_user: true)
    end

  end
end
