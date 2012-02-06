require 'net/http'
require 'net/https'
require 'json'

class NotifierHook < Redmine::Hook::ViewListener
  @@subdomain = nil
  @@token     = nil
  @@room_id   = nil

  def self.load_options
    options = YAML::load( File.open(File.join(Rails.root, 'config', 'campfire.yml')) )
    @@subdomain = options[Rails.env]['subdomain']
    @@token = options[Rails.env]['token']
    @@room_id = options[Rails.env]['room_id']
  end

  def controller_issues_new_after_save(context = { })
    @project = context[:project]
    @issue = context[:issue]
    @user = @issue.author
    speak "#{@user.firstname} created issue “#{@issue.subject}”. Comment: “#{truncate_words(@issue.description)}” http://#{Setting.host_name}/issues/#{@issue.id}"
  end
  
  def controller_issues_edit_after_save(context = { })
    @project = context[:project]
    @issue = context[:issue]
    @journal = context[:journal]
    @user = @journal.user
    speak "#{@user.firstname} edited issue “#{@issue.subject}”. Comment: “#{truncate_words(@journal.notes)}”. http://#{Setting.host_name}/issues/#{@issue.id}"
  end

  def controller_messages_new_after_save(context = { })
    @project = context[:project]
    @message = context[:message]
    @user = @message.author
    speak "#{@user.firstname} wrote a new message “#{@message.subject}” on #{@project.name}: “#{truncate_words(@message.content)}”. http://#{Setting.host_name}/boards/#{@message.board.id}/topics/#{@message.root.id}#message-#{@message.id}"
  end
  
  def controller_messages_reply_after_save(context = { })
    @project = context[:project]
    @message = context[:message]
    @user = @message.author
    speak "#{@user.firstname} replied a message “#{@message.subject}” on #{@project.name}: “#{truncate_words(@message.content)}”. http://#{Setting.host_name}/boards/#{@message.board.id}/topics/#{@message.root.id}#message-#{@message.id}"
  end
  
  def controller_wiki_edit_after_save(context = { })
    @project = context[:project]
    @page = context[:page]
    @user = @page.content.author
    speak "#{@user.firstname} edited the wiki “#{@page.pretty_title}” on #{@project.name}. http://#{Setting.host_name}/projects/#{@project.identifier}/wiki/#{@page.title}"
  end

private
  def speak(message)
    NotifierHook.load_options unless @@subdomain && @@token && @@room_id
    begin
      path = "/room/#{@@room_id}/speak.json"
      headers = {
        'Content-Type' => 'application/json'
      }
      json = JSON.generate({ :message => message })

      http = Net::HTTP.new("#{@@subdomain}.campfirenow.com", 443)
      http.use_ssl = true

      request = Net::HTTP::Post.new(path, headers)
      request.basic_auth(@@token, "X")
      request.body = json

      http.request(request)
    rescue => e
      RAILS_DEFAULT_LOGGER.error "Error during Campfire notification: #{e.message}"
    end
  end

  def truncate_words(text, length = 20, end_string = '…')
    return if text == nil
    words = text.split()
    words[0..(length-1)].join(' ') + (words.length > length ? end_string : '')
  end
end
