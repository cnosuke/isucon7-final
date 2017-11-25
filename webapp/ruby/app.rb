require 'erb'
require 'sinatra/base'
#require 'newrelic_rpm'
require './game'

class App < Sinatra::Base
  require_relative './periodic_profiler'
  #use StackProf::PeriodicProfiler,
  #  profile_interval_seconds: 1,
  #  sampling_interval_microseconds: 1000,
  #  result_directory: '/tmp'

  use Game

  configure do
    set :public_folder, File.expand_path('../../public', __FILE__)
  end

  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  get '/initialize' do
    if ENV['RACK_ENV'] == 'production' && Game.is_leader?
      Game::HOSTS[1..-1].each do |h|
        Thread.new do
          open("http://#{h}/initialize").read
        end
      end
    end

    Game.initialize!
    204
  end

  get '/room/' do
    content_type :json
    { 'host' => '', 'path' => '/ws' }.to_json
  end

  get '/room/:room_name' do
    return "localhost:9292" unless ENV['RACK_ENV'] == 'production'
    return 400 unless Game.is_leader? # リーダ以外は部屋を知らない

    room_name = ERB::Util.url_encode(params[:room_name])
    host = Game.get_or_create_host_by_room(room_name)
    path = "/ws/#{room_name}"

    content_type :json
    { 'host' => host, 'path' => path }.to_json
  end

  get '/' do
    send_file File.expand_path('index.html', settings.public_folder)
  end
end
