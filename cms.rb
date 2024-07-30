require 'pry'
require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

root = File.expand_path("..", __FILE__)

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

def markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)

  case File.extname(path)
  when ".txt"
        headers["Content-Type"] = "text/plain"
        content
  when ".md"
    erb markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def signed_in?
  session.key?(:username)
end

def require_signed_in
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# Home page, lists all files
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |file| File.basename(file) }

  erb :index
end

# Go to create a new document
get "/new_doc" do
  require_signed_in

  erb :new_doc
end

# Sign In
get "/sign_in" do
  erb :sign_in
end

# submit sign in credentials
post "/sign_in" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:message] = "Welcome!"
    session[:username] = "admin"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :sign_in
  end
end

# Sign Out
post "/sign_out" do
  session[:message] = "You have been signed out."
  session.delete(:username)

  redirect "/"
end

# View a single file
get "/:file" do
  file_path = File.join(data_path, params[:file])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:file]} does not exist."
    redirect "/"
  end
end

# Edit document text
get "/:file/edit" do
  require_signed_in

  file_path = File.join(data_path, params[:file])

  @file_name = params[:file]
  @file_content = File.read(file_path)

  erb :edit
end

# Submit a new document form
post "/create_doc" do
  require_signed_in

  doc_name = params[:new_doc_name]

  if doc_name.strip.size > 0
    file_path = File.join(data_path, doc_name)
    File.write(file_path, "")
    session[:message] = "#{doc_name} has been created"
    redirect "/"
  else
    session[:message] = "A name is required"
    status 422
    erb :new_doc
  end
end

# delete a document
post "/:file/delete" do
  require_signed_in

  File.delete(data_path + '/' + params[:file])
  session[:message] = "#{params[:file]} has been deleted"

  redirect "/" 
end

# Post changes to edited document
post "/:file" do
  require_signed_in

  file_path = File.join(data_path, params[:file])
  File.write(file_path, params[:content])
  session[:message] = "The #{params[:file]} file has been updated successfully"

  redirect "/"
end
