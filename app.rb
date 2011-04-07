require 'rubygems'
require 'bundler'
Bundler.require

require 'models'

get '/' do
end

get '/search' do
  @courses = Searcher.new(request).courses
  erubis :search
end
