# sticking all the requires here
require 'sinatra/base'
require 'pg'
require 'bcrypt'
require 'pry'
require 'redcarpet'

module Forum
  class Server < Sinatra::Base
    # session handling, must be enabled! to secure login instead of cookies
    enable :sessions
    # to enable updating and destroying information
    set :method_override,true

    @@db = PG.connect dbname: 'forum_dev'
    # who is currently logged in
    def current_user
      @current_user ||= @@db.exec_params(<<-SQL, [session['user_id']]).first
        SELECT * FROM users  WHERE id = $1
      SQL
    end
    # Makes Gravatar work
    def avatar_url(user)
        gravatar_id = Digest::MD5.hexdigest(user['email'].downcase)
        "http://gravatar.com/avatar/#{gravatar_id}.png?s=75&d=identicon"
    end

    # def markdown(text)
    #   options = [:hard_wrap, :filter_html, :autolink, :no_intraemphasis, :fenced_code, :gh_blockcode]
    #   Redcarpet.new(text, *options).to_html
    # end

    get '/login' do
      erb :login
    end

    post '/login' do
      email_test = params['email']
      password = params['password']
      returning_user = @@db.exec_params(<<-SQL, [email_test])
        SELECT * FROM users WHERE email = $1
      SQL
      if returning_user.any?
        checky = BCrypt::Password.new(returning_user[0]['password_digest'])
        # check the bcrypt password against the PLAINTEXT password
        if checky == password
          # this user_id is just a var, but now they are tagged?
          session['user_id'] = returning_user.first['id'].to_i
          # how I check that they are "logged in" to enable/disable features, explicit true for clarity
          session['logged_in'] = true
          redirect '/'
        else
          # sends to ending page if password incorrect, notifies
          @password = true
          erb :end
        end
      else
        session['the_sell'] = "That user does not exist! Would you like to join?"
        redirect '/signup'
      end
    end

    get '/logout' do
      session[:user_id] = nil
      session['logged_in'] = false
      @logout = true
      erb :end
    end

    get '/' do
      @top_topics = @@db.exec('SELECT * FROM topics LEFT JOIN users ON user_id = users.id ORDER BY upvotes DESC LIMIT 3')
      erb :index
    end

    get '/signup' do
      erb :signup
    end

    post '/signup' do
      name = params['name']
      password_digest = BCrypt::Password.create(params['password'])
      email = params['email']
      image = params['img_link']
      real_name = params['real_name']
      info = params['about']
      new_user = @@db.exec_params(<<-SQL, [ name, password_digest, email, image, real_name, info])
      INSERT INTO users (name, password_digest, email, img_link, real_name, about)
      VALUES ($1,$2,$3,$4,$5,$6) RETURNING id;
      SQL
      # this user_id is just a var, but now they are tagged
      session['user_id'] = new_user.first['id'].to_i
      # session['logged_in'] = true
      redirect '/'
    end

    get '/topics' do
      # besides the topic information only need the name from users, so only taking that from users
      @topic_list = @@db.exec('SELECT topics.*, users.name FROM topics, users WHERE topics.user_id = users.id')
      erb :topics
    end

    # see the topic and comments for a specific topic
    get '/topic_thread/:id' do
      @this_topic = params[:id]
      @topic_post = @@db.exec("SELECT topics.*, users.name FROM topics, users WHERE topics.id = #{@this_topic}")[0]
      @post_list = @@db.exec("SELECT posts.*, users.name FROM posts, users WHERE posts.topics_id = #{@this_topic} AND user_id = users.id")
      erb :topic_thread
    end

    # Topic and Post routes and creation
    # to the topic creation form
    get '/post_topic' do
      erb :post_topic
    end

    # create a new topic
    post '/topics' do 
      title = params["title"]
      # new md stuff
      md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      markdown = md.render(params["content"])
      upvotes = 0
      comments = 0
      op = session['user_id']
      @@db.exec_params(<<-SQL, [title, markdown, upvotes, comments, op])
      INSERT INTO topics (title, content, upvotes, responses, user_id)
      VALUES ($1,$2,$3,$4,$5);
      SQL
      redirect '/topics'
    end 

    # the upvote modifier
    put '/update/:id' do
      @up_id = params[:id].to_i
      @@db.exec("UPDATE topics SET upvotes = upvotes + 1 WHERE id = #{@up_id}")
      # binding.pry
      redirect '/topics'
    end

    get '/regular_post/:id' do
      @topic_id = params[:id]
      erb :regular_post
    end

    # Posting a comment to a topic
    post '/regular_post' do 
      md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      markdown = md.render(params["content"])
      # @content = params["content"]
      t_id = params["topics_id"]
      op = session['user_id']
      @@db.exec_params(<<-SQL,[ markdown, op, t_id ])
      INSERT INTO posts (content, user_id, topics_id)
      VALUES ($1,$2,$3);
      SQL
      # and update the topic with response number
      @@db.exec("UPDATE topics SET responses = responses + 1 WHERE id = #{t_id}")
      redirect '/topics'
    end 
    # where route things like wrong password, logout, and an easter egg
    get '/end' do
      erb :end
    end

    get '/user' do
      # temp = session['user_id']
      @user = @@db.exec_params("SELECT * FROM users WHERE id = $1", [session['user_id']]).first
      @user_topics = @@db.exec_params("SELECT * FROM topics WHERE user_id = $1",[session['user_id']])
      @user_comments = @@db.exec_params("SELECT * FROM posts WHERE user_id = $1",[session['user_id']])
      erb :user
    end

    get '/user/:id' do
      temp = params[:id]
      @user = @@db.exec_params("SELECT * FROM users WHERE id = $1", [temp]).first
      @user_topics = @@db.exec_params("SELECT * FROM topics WHERE user_id = $1",[temp])
      @user_comments = @@db.exec_params("SELECT * FROM posts WHERE user_id = $1",[temp])
      erb :user
    end
    # do I put the more specific before or after in rb?
  end
end
      # binding.pry
