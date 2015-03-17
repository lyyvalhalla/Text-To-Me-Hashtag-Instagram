#! /usr/bin/env ruby

require 'twilio-ruby'
require 'sinatra'
require 'instagram'

enable :sessions

CALLBACK_URL = "http://localhost:4567/oauth/callback"

Instagram.configure do |config|
  config.client_id = "50995b6b9ba245eeb3e566b007de30cd"
  config.client_secret = "196d7ffbc8f14ae49f5daaafd143a695"
end

helpers do
  def get_id_from_username(username)
    client = Instagram.client(:access_token => session[:access_token])
    search_result = client.user_search(username)
    if (search_result == nil or search_result[0].username != username)
      return nil
    else
      return search_result[0].id
    end
  end

  def get_user_recent_media(id)
    client = Instagram.client(:access_token => session[:access_token])
    recent_media = client.user_recent_media(id)
    logger.info "getting a random photo from #{recent_media.length} images"
    index = rand(recent_media.length)
    recent_media[index]
  end

  def get_tag_recent_media(tagname)
    client = Instagram.client(:access_token => session[:access_token])
    recent_media = client.tag_recent_media(tagname)
    logger.info "getting a random photo from #{recent_media.length} images"
    index = rand(recent_media.length)
    recent_media[index]
  end
end

get '/' do
  logger.info '/'
  redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end

get '/oauth/callback' do
  logger.info '/oauth/callback'
  response = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
  session[:access_token] = response.access_token
  session[:logged_in] = true
  redirect '/ready'
end

get '/ready' do 
  logger.info '/ready'
  'Service ready. Listening at +1-510-455-7111 for incoming messages.'
end

get '/msg' do
  body = params[:Body]
  logger.info "/msg received message body: #{body}"

  if (body[0] == '@')
    userid = get_id_from_username(body.split('@', 2)[1])
    if (userid == nil)
      text_response = "Cannot find username #{}. Please try again"
    else
      media_result = get_user_recent_media(userid)
      media_response = media_result.images.low_resolution.url
      text_response = media_result.caption.text
    end
  elsif (body[0] == '#')
    media_result = get_tag_recent_media(body.split('#', 2)[1])
    media_response = media_result.images.low_resolution.url
    text_response = media_result.caption.text
  else
    text_response = 'Wrong format. Please try again'
  end

  twiml = Twilio::TwiML::Response.new do |r|
    r.Message do |message| 
      if (text_response != nil)
        message.Body text_response
      end
      if (media_response != nil)
        message.Media media_response
      end
    end
  end
  twiml.text
end
