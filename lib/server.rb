#!/usr/bin/env ruby

require 'sinatra/base'
require 'sass/plugin/rack'
require 'rack/contrib'
require 'hamlit'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'sinatra/activerecord'
require 'sinatra/strong-params'
require 'bcrypt'

require_relative 'user_model'
require_relative 'data_fragment_model'

module Textbookr
  class Server < Sinatra::Base
    ###########################################################################
    # Configuration                                                           #
    ###########################################################################
  
    # Load extensions.
    register Sinatra::ActiveRecordExtension
    register Sinatra::StrongParams
    # Configure the application using user settings from config.rb.
    configure do
      set :environment, :development # TODO: Move to config/app.rb!
      set :root, Config.root_path
      set :haml, {escape_html: false, format: :html5}
      set :bind, '0.0.0.0' # TODO: Move to config/app.rb!
      set :sessions, true
      # Internationalisation
      # http://recipes.sinatrarb.com/p/development/i18n
      # A locale is only considered 'available' if the
      # corresponding file in locales/*.yml contains at
      # least one string!
      I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
      I18n.load_path = Dir[Config.root_path+'locales'+'*.yml']
      I18n.backend.load_translations
      # use Rack::Locale # TODO: Fix this so that it does not inject region as well!
      # CSS compiler
      Sass::Plugin.options[:style] = :expanded
      Sass::Plugin.options[:cache_location] = (Config.cache_path+'sass').to_s
      Sass::Plugin.options[:template_location] = (Config.sass_path).to_s
      Sass::Plugin.options[:css_location] = (Config.css_path).to_s
      use Sass::Plugin::Rack
    end
    
    ###########################################################################
    # Helper Methods                                                          #
    ###########################################################################

    helpers do
      # Just some convenience (nicer to type current_user in views, etc.)
      def current_user
        User.find(session[:user_id]) if session[:user_id]
      end

      def locale
        I18n.locale
      end
    end
    
    ###########################################################################
    # Routes                                                                  #
    ###########################################################################

    # Prepending the rest of the route with the locale code.
    before '/:locale/?*' do
      I18n.locale = params[:locale]
      request.path_info = '/'+params[:splat].first
    end

    # Landing page showing the list of available L1s.
    get '/' do
      @locales = I18n.available_locales
      haml :language_list
    end

    # Handling logging in and logging out.
    get '/login' do
      @user = User.new
      haml :login_form
    end
    post '/login' do
      # TODO: What about strong params?
      if @user = User.find_by_email(params[:user_email])
        if @user.authenticate(params[:user_password])
          session[:user_id] = @user.id
          redirect to(params[:referer] || '/')
        end
      end
      # TODO: How about an error message?
      redirect back
    end
    get '/logout' do
      current_user && session[:user_id] = nil
      redirect back
    end

    # Displaying the contents themselves.
    get '/*' do |path|
      if fragment = DataFragment.find_by_path(path)
        @contents = fragment.html
      else
        cefr_level, chapter_name, heading = path.split("/")
        params[:cefr_level]   = cefr_level   || 'a1'
        params[:chapter_name] = chapter_name || 'intro'
        params[:heading]      = heading      || '1'
        content_file_name = "#{params[:cefr_level]}-#{params[:chapter_name]}.html"
        content_file = Config.cache_path+'chapters'+locale.to_s+content_file_name
        @contents = begin
          File.read(content_file)
        rescue
          I18n.t(:no_contents)
        end
      end
      toc_file = Config.cache_path+'tocs'+"#{locale}.html"
      @toc = begin
        File.read(toc_file)
      rescue
        I18n.t(:no_toc)
      end
      haml :contents
    end

    # Save modified contents
    post '/*' do |path|
      # TODO: Make pretty.
      if fragment = DataFragment.find_by_path(path)
        fragment.update_attribute(:html, params[:data_fragment_html])
      else
        DataFragment.create(path: path, html: params[:data_fragment_html])
      end      
      # TODO: Some sort of message?
      redirect back
    end
  end
end
