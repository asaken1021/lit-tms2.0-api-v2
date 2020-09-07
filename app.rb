require 'bundler/setup'
Bundler.require
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'sinatra/namespace'
require './models'
require 'webrick/https'
require 'openssl'
require 'open-uri'
require 'socket'
require 'net/http'
require 'json'
require 'securerandom'
require 'rmagick'

enable :sessions

before do
  response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
  response.headers["Access-Control-Allow-Origin"] = "http://localhost:8080"
  response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token, X-Requested-With"
  response.headers["Access-Control-Allow-Credentials"] = "true"
end

helpers do
  def current_user
    User.find_by(id: session[:user])
  end
end

get '/' do
  'Test'
end

namespace '/api' do
  namespace '/v2' do

  end
end