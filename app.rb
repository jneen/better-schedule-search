require 'rubygems'
require 'bundler'
Bundler.require

require 'models'

get '/search' do
  @courses = Searcher.new(params).courses
  erubis :search
end
