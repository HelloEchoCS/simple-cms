require 'redcarpet'
require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'fileutils'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  @users = YAML.load_file(config_path + '/users.yml')
end

def config_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/config', __FILE__)
  else
    File.expand_path('../config', __FILE__)
  end
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, strikethrough: true)
  markdown.render(content)
end

def generate_response(file_path)
  @content = File.read(file_path)
  ext = File.extname(file_path)
  case ext
  when '.md'
    @content = render_markdown(@content)
    erb :view_file
  else
    headers['Content-Type'] = 'text/plain'
    @content
  end
end

def filename_validation(name)
  'A name is required.' if name.empty?
end

def valid_user?(username, password)

  @users.any? do |user, pass|
    user == username && BCrypt::Password.new(pass) == password
  end
end

def signed_in?
  session[:signed_in]
end

def no_signin_redirect
  unless signed_in?
    session[:error] = 'You must be signed in to do that.'
    redirect '/'
  end
end

get '/' do
  @files = Dir.glob(data_path + '/*').map do |path|
    File.basename(path)
  end

  erb :home
end

# Create a new document
get '/new' do
  no_signin_redirect
  erb :new
end

post '/new' do
  no_signin_redirect

  @file_name = params[:file_name].strip.to_s

  error = filename_validation(@file_name)
  if error
    session[:error] = error
    status 422
    erb :new
  else
    FileUtils.touch data_path + "/#{@file_name}"
    session[:success] = "#{@file_name} was created."
    redirect '/'
  end
end

get '/sign_in' do
  erb :sign_in
end

post '/sign_in' do
  if valid_user?(params[:username], params[:password])
    session[:signed_in] = true
    session[:user] = params[:username]
    session[:success] = 'Welcome!'
    redirect '/'
  else
    session[:error] = 'Invalid Credentials'
    status 422
    erb :sign_in
  end
end

post '/sign_out' do
  session[:signed_in] = false
  session[:user] = nil
  session[:success] = 'You have been signed out.'
  redirect '/'
end

# Open one file
get '/:file' do |file|
  file_path = data_path + "/#{file}"

  if !File.exist?(file_path)
    session[:error] = "#{file} does not exist."
    redirect '/'
  else
    generate_response(file_path)
  end
end

# Edit one file
get '/:file/edit' do |file|
  no_signin_redirect

  file_path = data_path + "/#{file}"
  @content = File.read(file_path)
  erb :edit
end

post '/:file' do |file|
  no_signin_redirect

  file_path = data_path + "/#{file}"
  File.write(file_path, params[:content])
  session[:success] = "#{file} has been updated."

  redirect '/'
end

post '/:file/delete' do |file|
  no_signin_redirect

  file_path = data_path + "/#{file}"
  File.delete(file_path)
  session[:success] = "#{file} has been deleted."

  redirect '/'
end
