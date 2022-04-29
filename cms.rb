require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

root = File.expand_path('..', __FILE__)

get '/' do
  @files = Dir.glob(root + '/data/*').map do |path|
    File.basename(path)
  end

  erb :home
end

get '/:file' do |file|
  file_path = root + "/data/#{file}"

  if !File.exist?(file_path)
    session[:error] = "#{file} does not exist."
    redirect '/'
  else
    headers \
      "Content-Type" => "text/plain"
    body File.read(file_path)
  end
end