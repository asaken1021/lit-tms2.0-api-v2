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
require 'jwt'

privkey = OpenSSL::PKey::RSA.generate(2048)
pubkey = privkey.public_key

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

    before do
      request.body.rewind
      req_data = JSON.parse(request.body.string)
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
        payload = {
          id: user.id
        }
        token = JWT.encode(payload, privkey, 'RS256')
        res_data = {
          token: token
        }
      else
        if req_data["password"] != req_data["password_confirmation"]
          status 400
          res_data = {
            error: 'Bad Request: PASSWORD_MISMATCH'
          }
        else
          status 400
          res_data = {
            error: 'Bad Request: UNKNOWN_ERROR'
          }
        end
      end

      json res_data.to_json
    end

    get '/users/:id' do
      if params[:id] != nil
        user = User.find_by(id: params[:id])
        if user != nil
          status 200
          res_data = {
            user: user
          }
        else
          status 404
          res_data = {
            error: 'Not Found'
          }
        end
      else
        status 400
        res_data = {
          error: 'Bad Request'
        }
      end
      json res_data.to_json
    end

    put '/users/:id' do
      status 501
    end

    post '/session' do
      user = User.find_by(mail: req_data["mail"])
      if user && user.authenticate(req_data["password"])
        status 200
        payload = {
          id: user.id
        }
        token = JWT.encode(payload, privkey, 'RS256')
        res_data = {
          token: token
        }
      else
        status 400
        res_data = {
          error: 'Bad Request'
        }
      end

      json res_data.to_json
    end

    delete '/session' do
      status 501
    end

    get '/projects' do
      if req_data["user_id"] != nil
        if User.find_by(id: req_data["user_id"]) != nil
          status 200
          projects = Project.find_by(user_id: req_data["user_id"])
          res_data = {
            projects: projects
          }
        else
          status 404
          res_data = {
            error: 'Not Found'
          }
        end
      else
        status 400
        res_data = {
          error: 'Bad Request'
        }
      end

      json res_data.to_json
    end

    post '/projects' do
      token = req_data["token"]
      if token != nil
        binding.pry
        user_id = JWT.decode(token, pubkey, false, { algorithm: 'RS256' })[0]["id"]
        if user_id != nil
          user = User.find_by(id: user_id)
          if user != nil
            project = Project.create(
              name: req_data["name"],
              progress: 0,
              user_id: user_id
            )
            if project != nil
              status 200
              res_data = {
                project: project
              }
            else
              status 400
              res_data = {
                error: 'Bad Request'
              }
            end
          else
            status 401
            res_data = {
              error: 'Unauthorized'
            }
          end
        else
          status 400
          res_data = {
            error: 'Bad Request'
          }
        end
      else
        status 400
        res_data = {
          error: 'Bad Request'
        }
      end

      json res_data.to_json
    end

    get '/projects/:id' do
      project = Project.find_by(id: params[:id])
      if project != nil
        status 200
        res_data = {
          project: project
        }
      else
        if params[:id] == nil
          status 400
          res_data = {
            error: 'Bad Request'
          }
        else
          status 404
          res_data = {
            error: 'Not Found'
          }
        end
      end

      json res_data.to_json
    end

    put '/projects/:id' do
      status 501
    end

    get '/phases' do
      status 501
    end

    post '/phases' do
      status 501
    end

    get '/tasks' do
      status 501
    end

    post '/tasks' do
      status 501
    end
  end
end