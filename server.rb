# sticking all the requires here
require 'sinatra/base'
require 'pg'
require 'bcrypt'
require 'pry'

module Forum
  class Server < Sinatra::Base
    # session handling, must be enabled! to secure login instead of cookies
    enable :sessions

    @@db = PG.connect dbname: 'forum_dev'

    def current_user
      @current_user ||= @@db.exec_params(<<-SQL, [session['user_id']]).first
        SELECT * FROM users  WHERE id = $1
      SQL
    end

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
          erb :index
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
      @top_posts = @@db.exec('SELECT * FROM topics LIMIT 3')
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
      erb :index
    end

    get '/topics' do
      @topic_list = @@db.exec('SELECT * FROM topics')
      # binding.pry
      erb :topics
    end

    get '/topic_thread' do
      erb :topic_thread
    end
    # Topic and Post routes and creation

    get '/post_topic' do
      erb :post_topic
    end

    post '/topics' do 
      title = params["title"]
      content = params["content"]
      op = session['user_id']
      upvotes = 0
      @@db.exec_params(<<-SQL, [params['title'], params['content'], upvotes, op])
      INSERT INTO topics (title, content, upvotes, user_id)
      VALUES ($1,$2,$3,$4);
      SQL
      redirect '/topics'
    end 

    get '/regular_post' do
      erb :regular_post
    end

    post '/regular_post' do 

    end 

    get '/end' do
      erb :end
    end
  end
end
