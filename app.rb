require 'rubygems'
require 'bundler'
Bundler.require

require 'models'

helpers do
  def pluralize(str, count=1)
    if count == 1
      str
    else
      str.pluralize
    end
  end
end

get '/' do
end

get '/search' do
  @courses = Searcher.new(params).courses
  erubis :search
end
