require 'rubygems'
require 'bundler'
Bundler.require

require 'models'

get '/' do
end

get '/search' do
  @courses = Searcher.new(request.params).courses
end
