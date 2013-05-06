# @file server.rb
#
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by post at
# Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK

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
