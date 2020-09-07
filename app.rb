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
    req_data = nil
    res_data = nil

    before do
      request.body.rewind
      req_data = JSON.parse(request.body.string)
    end

    get '/users' do
      status 500
    end
    post '/users' do
      user = User.create(
        mail: req_data["mail"],
        name: req_data["name"],
        password: req_data["password"],
        password_confirmation: req_data["password_confirmation"],
        line_id: ""
      )
      if user.persisted?
        status 200
        session[:user] = user.id
        'OK'
      else
        if req_data["password"] != req_data["password_confirmation"]
          status 400
          'PASSWORD_MISMATCH'
        else
          'UNKNOWN_ERROR'
        end
      end
    end
    put '/users' do
      status 500
    end
  end
end