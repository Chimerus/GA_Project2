# sticking all the requires here
require 'sinatra/base'
require 'pg'
require 'bcrypt'
require 'pry'
require 'redcarpet'
require 'uri'

module Forum
  class Server < Sinatra::Base
    # error message list
    ERRORS = {"1" => "Email already exists...."}
    # session handling, must be enabled! to secure login instead of cookies
    enable :sessions
    # to enable updating and destroying information
    set :method_override,true

    if ENV["RACK_ENV"] == "production"
      uri = URI.parse(ENV['DATABASE_URL'])
      PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    else
      @@db = PG.connect dbname: 'forum_dev'
    end

    # Methods 
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

    def user_exists?( email )
      users = @@db.exec_params "SELECT * FROM users WHERE email = $1", [email]
      return users.count > 0
    end

    get '/login' do
      @user_login = @@db.exec_params("SELECT * FROM users WHERE id = $1", [session['user_id']]).first
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
      session.clear
      erb :end
    end

    get '/' do
      @top_topics = @@db.exec_params('SELECT * FROM topics LEFT JOIN users ON user_id = users.id ORDER BY upvotes DESC LIMIT 3')
      erb :index
    end

    get '/signup' do
      @error = ERRORS[ params[:e] ]
      erb :signup
    end

    post '/signup' do
      name = params['name']
      password_digest = BCrypt::Password.create(params['password'])
      email = params['email']
      image = params['img_link']
      real_name = params['real_name']
      info = params['about']

      if user_exists? email
        redirect '/signup?e=1'
      else
        new_user = @@db.exec_params(<<-SQL, [ name, password_digest, email, image, real_name, info])
        INSERT INTO users (name, password_digest, email, img_link, real_name, about)
        VALUES ($1,$2,$3,$4,$5,$6) RETURNING id;
        SQL
      end

      # this user_id is just a var, but now they are tagged
      session['user_id'] = new_user.first['id'].to_i
      # session['logged_in'] = true
      redirect "/login"
    end

    get '/faq' do
      erb :faqs
    end

    # Topic and Post routes and creation
    # to the topic creation form
    get '/post_topic' do
      erb :post_topic
    end

    get '/topics' do
      # besides the topic information, need name and img link to display avatar. but for gravatar function, need email too.
      @topic_list = @@db.exec_params('SELECT topics.*, users.name, users.img_link, users.email FROM topics, users WHERE topics.user_id = users.id')
      @topic_type = "Full Topics"
      erb :topics
    end

    # see the topic and comments for a specific topic
    get '/topic_thread/:id' do
      @this_topic = params[:id]
      @topic_post = @@db.exec_params("SELECT topics.*, users.name, users.img_link, users.email FROM topics, users WHERE topics.id = #{@this_topic} AND topics.user_id = users.id")[0]
      @post_list = @@db.exec_params("SELECT posts.*, users.name, users.img_link, users.email FROM posts, users WHERE posts.topics_id = #{@this_topic} AND user_id = users.id")
      erb :topic_thread
    end

    # create a new topic
    post '/topics' do 
      title = params["title"]
      # new md stuff
      md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      markdown = md.render(params["content"])
      reviews = params["is_review"]
      upvotes = 0
      comments = 0
      op = session['user_id']
      @@db.exec_params(<<-SQL, [title, markdown, upvotes, comments, op, reviews])
      INSERT INTO topics (title, content, upvotes, responses, user_id, is_review)
      VALUES ($1,$2,$3,$4,$5,$6);
      SQL
      redirect '/topics'
    end 

    # editing
    put '/update_topic/:id' do
      mod_id = params[:id]
      md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      edit_topics = md.render(params["content"])
      @@db.exec_params(<<-SQL, [edit_topics, mod_id]) 
      UPDATE topics 
      SET content = $1, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $2;
      SQL
      redirect '/topics'
    end

    # the upvote modifier
    put '/update/:id' do
      @up_id = params[:id].to_i
      @@db.exec_params("UPDATE topics SET upvotes = upvotes + 1 WHERE id = #{@up_id}")
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
      @@db.exec_params("UPDATE topics SET responses = responses + 1 WHERE id = #{t_id}")
      redirect '/topics'
    end 

    # Editing a comment
    put '/update_comment/:id' do
      mod_id = params[:id]
      md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      edit_comments = md.render(params["content"])
      @@db.exec_params(<<-SQL, [edit_comments, mod_id]) 
      UPDATE posts 
      SET content = $1, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $2;
      SQL
      redirect '/users'
    end

    get '/reviews' do
      # basically a topics search only for topics tagged review
      @topic_type = "Reviews"
      @topic_list = @@db.exec_params('SELECT topics.*, users.name, users.img_link, users.email FROM topics, users WHERE topics.user_id = users.id AND is_review = TRUE')
      erb :topics
    end

    # where route things like wrong password, logout, and an easter egg
    get '/end' do
      erb :end
    end

    get '/users' do
      # temp = session['user_id']
      @user = @@db.exec_params("SELECT * FROM users WHERE id = $1", [session['user_id']]).first
      @user_topics = @@db.exec_params("SELECT * FROM topics WHERE user_id = $1",[session['user_id']])
      @user_comments = @@db.exec_params("SELECT * FROM posts WHERE user_id = $1",[session['user_id']])
      erb :users
    end

    get '/users/:id' do
      temp = params[:id]
      @user = @@db.exec_params("SELECT * FROM users WHERE id = $1", [temp]).first
      @user_topics = @@db.exec_params("SELECT * FROM topics WHERE user_id = $1",[temp])
      @user_comments = @@db.exec_params("SELECT * FROM posts WHERE user_id = $1",[temp])
      erb :users
    end

  end
end
      # binding.pry
