require 'erb'
require 'sinatra/base'
#require 'newrelic_rpm'
require './game'
require 'pry'
require 'open-uri'

class App < Sinatra::Base
  use Game

  configure do
    set :public_folder, File.expand_path('../../public', __FILE__)
  end

  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  get '/initialize' do
    Game.initialize!

    if ENV['RACK_ENV'] == 'production'
      Game::HOSTS[1..-1].each do |h|
        Thread.new do
          open("http://#{h}/initialize").read
        end
      end
    end

    204
  end

  # これ使って無いわ
  get '/room/' do
    content_type :json
    { 'host' => '', 'path' => '/ws' }.to_json
  end

  get '/pry' do
    binding.pry
    'ok'
  end

  get '/room/:room_name' do
    room_name = ERB::Util.url_encode(params[:room_name])

    unless ENV['RACK_ENV'] == 'production'
      host = "localhost:9292"
    else
      host = Game.get_or_create_host_by_room(room_name)
    end

    path = "/ws/#{room_name}"

    content_type :json
    { 'host' => host, 'path' => path }.to_json
  end

  get '/' do
    send_file File.expand_path('index.html', settings.public_folder)
  end
end
