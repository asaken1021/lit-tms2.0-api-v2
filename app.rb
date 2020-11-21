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

refresh_privkey = OpenSSL::PKey::RSA.generate(2048)
refresh_pubkey = refresh_privkey.public_key

def bad_request
  status 400
  res_data = {
    error: 'Bad Request'
  }

  return json res_data.to_json
end

def unauthorized
  status 401
  res_data = {
    error: 'Unauthorized'
  }

  return json res_data.to_json
end

def forbidden
  status 403
  res_data = {
    error: 'Forbidden'
  }

  return json res_data.to_json
end

def not_found
  status 404
  res_data = {
    error: 'Not Found'
  }

  return json res_data.to_json
end

def token_check(req_token, pubkey)
  # binding.pry
  JWT.decode(req_token, pubkey, true, {algorithm: 'RS256'})
  return true
rescue => e
  return false
  # return unauthorized if e.class == JWT::ExpiredSignature || e.class ==JWT::VerificationError
  # return bad_request
end

options '*' do
  response.headers["Access-Control-Allow-Methods"] = "GET, PUT, POST, DELETE, OPTIONS"
  response.headers["Access-Control-Allow-Origin"] = "http://localhost:8080"
  response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token, X-Requested-With"
  response.headers["Access-Control-Allow-Credentials"] = "true"
end

before do
  response.headers["Access-Control-Allow-Origin"] = "http://localhost:8080"
  response.headers["Access-Control-Allow-Credentials"] = "true"

  # if params["token"] != nil ||
  # if token_check
  #   # Nothing to do
  # else
  #   return unauthorized
  # end
end

def update_project_progress(id = nil)
  project = Project.find_by(id: id)
  all_tasks = Task.where(project_id: id)
  completed_tasks = all_tasks.where(progress: 100)

  if all_tasks.count == 0
    project.progress = 0
  else
    project.progress = (completed_tasks.count.to_f / all_tasks.count.to_f * 100)
  end

  project.save
end

namespace '/api' do
  namespace '/dev' do
    req_data = nil

    before do
      request.body.rewind

      if request.body.string == ""
        req_data = JSON.parse("{}")
      else
        req_data = JSON.parse(request.body.string)
      end
    end

    get '/token' do
      payload = {
        data: "Hello, World!",
        exp: Time.now.to_i + 15
      }
      token = JWT.encode(payload, privkey, 'RS256')
      res_data = {
        token: token
      }

      json res_data.to_json
    end

    post '/token' do
      token = req_data["token"]
      begin
        data = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })[0]
      rescue => e
        if e.class == JWT::ExpiredSignature || e.class == JWT::VerificationError
          status 401
          'Unauthorized'
        end
      end
      status 200
      'OK'
    end

    post '/decode' do
      token = req_data["token"]
      begin
        data = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })
      rescue => e
        if e.class == JWT::ExpiredSignature || e.class == JWT::VerificationError
          status 401
          return 'Unauthorized. ' + e.message
        end
      end

      json data
    end
  end

  namespace '/v2' do
    req_data = nil

    before do
      request.body.rewind

      if request.body.string == ""
        req_data = JSON.parse("{}")
      else
        req_data = JSON.parse(request.body.string)
      end

      if @env["REQUEST_METHOD"] != "OPTIONS"
        if params["token"] != nil
          return halt unauthorized if !token_check(params["token"], pubkey)
        elsif req_data["token"] != nil
          return halt unauthorized if !token_check(req_data["token"], pubkey)
        end
      end
    end

    post '/users' do
      user = User.create(
        mail: req_data["mail"],
        name: req_data["name"],
        password: req_data["password"],
        password_confirmation: req_data["password_confirmation"],
        line_id: ""
      )
      return bad_request if !user.persisted?

      status 200
      payload = {
        id: user.id,
        exp: Time.now.to_i + 86400
      }
      refresh_payload = {
        id: user.id,
        exp: Time.now.to_i + (60 * 60)
      }
      token = JWT.encode(payload, privkey, 'RS256')
      refresh_token = JWT.encode(refresh_payload, refresh_privkey, 'RS256')
      res_data = {
        name: user.name,
        id: user.id,
        token: token,
        refresh_token: refresh_token
      }

      json res_data.to_json
    end

    get '/users/:id' do
      return bad_request if params[:id] == nil

      user = User.find_by(id: params[:id])
      return not_found if user == nil

      status 200
      res_data = {
        user: user
      }

      json res_data.to_json
    end

    put '/users/:id' do
      status 501
    end

    post '/session' do
      user = User.find_by(mail: req_data["mail"])
      return bad_request if user == nil
      return bad_request if !user.authenticate(req_data["password"])

      status 200
      payload = {
        id: user.id,
        exp: Time.now.to_i + 10
      }
      refresh_payload = {
        id: user.id,
        exp: Time.now.to_i + (60 * 60)
      }
      token = JWT.encode(payload, privkey, 'RS256')
      refresh_token = JWT.encode(refresh_payload, refresh_privkey, 'RS256')
      res_data = {
        name: user.name,
        id: user.id,
        token: token,
        refresh_token: refresh_token
      }

      json res_data.to_json
    end

    put '/session' do
      refresh_token = req_data["refresh_token"]
      return bad_request if refresh_token == nil

      user_id = JWT.decode(refresh_token, refresh_pubkey, true, { algorithm: 'RS256' })[0]["id"]
      return bad_request if user_id == nil

      user = User.find_by(id: user_id)
      return unauthorized if user == nil

      payload = {
        id: user.id,
        exp: Time.now.to_i + 10
      }
      refresh_payload = {
        id: user.id,
        exp: Time.now.to_i + (60 * 60)
      }
      token = JWT.encode(payload, privkey, 'RS256')
      refresh_token = JWT.encode(refresh_payload, refresh_privkey, 'RS256')
      res_data = {
        name: user.name,
        id: user.id,
        token: token,
        refresh_token: refresh_token
      }

      json res_data.to_json
    end

    delete '/session' do
      status 501
    end

    get '/projects' do
      token = params["token"]
      return bad_request if token == nil

      user_id = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })[0]["id"]
      return bad_request if user_id == nil

      user = User.find_by(id: user_id)
      return unauthorized if user == nil

      projects = Project.where(user_id: user.id)
      return not_found if projects == nil

      status 200
      res_data = {
        projects: projects
      }

      json res_data.to_json
    end

    post '/projects' do
      token = req_data["token"]
      return bad_request if token == nil

      user_id = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })[0]["id"]
      return bad_request if user_id == nil

      user = User.find_by(id: user_id)
      return unauthorized if user == nil

      project = Project.create(
        name: req_data["name"],
        progress: 0,
        user_id: user_id
      )
      return bad_request if project == nil

      status 200
      res_data = {
        project: project
      }

      json res_data.to_json
    end

    get '/projects/:id' do
      return bad_request if params[:id] == nil

      project = Project.find_by(id: params[:id])
      return not_found if project == nil

      status 200
      res_data = {
        project: project
      }

      json res_data.to_json
    end

    put '/projects/:id' do
      status 501
    end

    get '/phases' do
      return bad_request if params["project_id"] == nil

      phases = Phase.where(project_id: params["project_id"])
      return not_found if phases == nil

      status 200
      res_data = {
        phases: phases
      }

      json res_data.to_json
    end

    post '/phases' do
      token = req_data["token"]
      return bad_request if token == nil

      user_id = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })[0]["id"]
      return unauthorized if user_id == nil

      return bad_request if req_data["project_id"] == nil

      project = Project.find_by(id: req_data["project_id"])
      return not_found if project == nil
      return forbidden if user_id != project.user_id

      deadline_date = req_data["deadline"].split('-')
      return bad_request if deadline_date == nil
      return bad_request if !Date.valid_date?(deadline_date[0].to_i, deadline_date[1].to_i, deadline_date[2].to_i)
      return bad_request if req_data["name"] == nil

      phase = Phase.create(
        name: req_data["name"],
        deadline: req_data["deadline"],
        project_id: project.id
      )
      status 200
      res_data = {
        phase: phase
      }

      json res_data.to_json
    end

    put '/phases/:id' do
      status 501
    end

    get '/tasks' do
      return bad_request if params["project_id"] == nil

      tasks = Task.where(project_id: params["project_id"])
      return not_found if tasks == nil

      status 200
      res_data = {
        tasks: tasks
      }

      json res_data.to_json
    end

    post '/tasks' do
      token = req_data["token"]
      return bad_request if token == nil

      user_id = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })[0]["id"]
      return unauthorized if user_id == nil

      return bad_request if req_data["project_id"] == nil
      return bad_request if req_data["phase_id"] == nil

      project = Project.find_by(id: req_data["project_id"])
      phase = Phase.find_by(id: req_data["phase_id"])
      return not_found if project == nil
      return not_found if phase == nil
      return forbidden if user_id != project.user_id
      return bad_request if project.id != phase.project_id

      task = Task.create(
        name: req_data["name"],
        memo: req_data["memo"],
        progress: 0,
        phase_id: phase.id,
        project_id: project.id
      )
      return bad_request if task == nil

      update_project_progress(project.id)

      status 200
      res_data = {
        task: task
      }

      json res_data.to_json
    end

    put '/tasks/:id' do
      token = req_data["token"]
      return bad_request if token == nil

      user_id = JWT.decode(token, pubkey, true, { algorithm: 'RS256' })[0]["id"]
      return unauthorized if user_id == nil

      return bad_request if params[:id] == nil

      task = Task.find_by(id: params[:id])
      return not_found if task == nil

      project = Project.find_by(id: task.project_id)

      return forbidden if user_id != project.user_id

      task.progress = req_data["task_progress"]
      task.save

      update_project_progress(project.id)

      status 200
      res_data = {
        task: task
      }

      json res_data.to_json
    end
  end
end