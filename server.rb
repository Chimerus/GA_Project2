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
    set :method_override,true

    @@db = PG.connect dbname: 'forum_dev'

    def current_user
      @current_user ||= @@db.exec_params(<<-SQL, [session['user_id']]).first
        SELECT * FROM users  WHERE id = $1
      SQL
    end

    # def markdown(text)
    #   options = [:hard_wrap, :filter_html, :autolink, :no_intraemphasis, :fenced_code, :gh_blockcode]
    #   Redcarpet.new(text, *options).to_html
    # end

    get '/login' do
      erb :login
    end

    post '/login' do
      name_test = params['name']
      password = params['password']

      returning_user = @@db.exec_params(<<-SQL, [name_test])
        SELECT * FROM users WHERE name = $1
      SQL
      # binding.pry
      if returning_user.any?
        checky = BCrypt::Password.new(returning_user[0]['password_digest'])
        # check the bcrypt password against the PLAINTEXT password
        if checky == password
          # this user_id is just a var, but now they are tagged?
          session['user_id'] = returning_user.first['id'].to_i
          session['logged_in'] = true
          # binding.pry
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
      password_digest = BCrypt::Password.create(params['password'])
      new_user = @@db.exec_params(<<-SQL, [params['name'], params['email'], password_digest])
      INSERT INTO users (name, email, password_digest)
      VALUES ($1,$2,$3) RETURNING id;
      SQL
      # this user_id is just a var, but now they are tagged?
      session['user_id'] = new_user.first['id'].to_i
      redirect '/'
    end

    get '/topics' do
      # @topic_list = @@db.exec('SELECT * FROM topics LEFT JOIN users ON user_id = users.id')
      @topic_list = @@db.exec('SELECT topics.*, users.name FROM topics, users WHERE topics.user_id = users.id')

      erb :topics
    end

    get '/topic_thread/:id' do
      @this_topic = params[:id]
      @topic_post = @@db.exec("SELECT topics.*, users.name FROM topics, users WHERE topics.id = #{@this_topic}")[0]
      @post_list = @@db.exec("SELECT posts.*, users.name FROM posts, users WHERE posts.topics_id = #{@this_topic} AND user_id = users.id")
      erb :topic_thread
    end
    # Topic and Post routes and creation

    get '/post_topic' do
      erb :post_topic
    end

    post '/topics' do 
      # new md stuff
      md = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      markdown = md.render(params["content"])
      # end
      title = params["title"]
      # content = params["content"]
      op = session['user_id']
      upvotes = 0
      @@db.exec_params(<<-SQL, [title, markdown, upvotes, op])
      INSERT INTO topics (title, content, upvotes, user_id)
      VALUES ($1,$2,$3,$4);
      SQL
      redirect '/topics'
    end 

    get '/regular_post/:id' do
      @topic_id = params[:id]
      erb :regular_post
    end

    put '/update/:id' do
      @up_id = params[:id].to_i
      @@db.exec("UPDATE topics SET upvotes = upvotes + 1 WHERE id = #{@up_id}")
      # binding.pry
      redirect '/topics'
    end

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
      redirect '/topics'
    end 

    get '/end' do
      erb :end
    end
  end
end
