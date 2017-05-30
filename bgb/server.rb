# @file server.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require 'rubygems'
require 'sinatra'
require 'json'
require 'thread'
require_relative 'deployment'
require_relative 'environment'

# Configure Sinatra
set :port, 3000
set :bind, '0.0.0.0'
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == ['clearwater', 'se4rfv=2']
end

# Serves index.html for root, Sinatra serves public by default
get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/deployments' do
  Deployment.all.to_json
end

post '/deployments' do
  data = JSON.parse request.body.read
  env_name = data["environment"]
  env_size = data["size"]
  if env_name.empty? and env_size.empty?
    halt 400
  end
  environment = Environment.new(env_name)
  deployment = Deployment.new(env_name)
  deployment.to_json
end

get '/deployments/:deployment' do
  if d = Deployment.get(params[:deployment]) 
    d.to_json 
  else
    halt 404
  end
end
