#require 'rspec'
require File.dirname(__FILE__) + '/spec_helper'

require 'rack/test'

describe Searcher do
  include Rack::Test::Methods
  before :each do
    # TODO: stub, don't monkeypatch
    class Searcher
      def open(uri)
        File.read(File.dirname(__FILE__) + '/../test/computer_science.html')
      end
    end

    @searcher = Searcher.new('')
  end

  def app
    @app ||= Sinatra::Application
  end

  it "has courses" do
    @searcher.should respond_to :courses
    @searcher.courses.should be_a CourseList
    @searcher.courses.should respond_to :each
    CourseList.included_modules.should include Enumerable
  end

  describe "a course" do
    before :each do
      @course = @searcher.courses.first
    end

    it "has enrollment info" do
      @course.enrollment.limit.should == 268
      @course.enrollment.enrolled.should == 0
      @course.enrollment.waitlist.should == 0
      @course.enrollment.fullness.should == 'Empty'
      @course.enrollment.as_of.should == Date.parse('3/22/2011')
    end

    it "has final info" do
      @course.final.should be_a Final
      @course.final.group.should == 17
      @course.final.time.should == '8-11A'
      @course.final.date.should == Date.parse('12/16/2011')
    end

    it "has a catalog url" do
      @course.catalog_url.should == 'http://osoc.berkeley.edu/catalog/gcc_search_sends_request?p_dept_name=ELECTRICAL+ENGINEERING&p_dept_cd=EL+ENG&p_title=&p_number=20N'
    end
  end

  it "responds to get" do
    get '/search'
    last_response.should be_ok
    last_response.body.should_not be_empty
  end
end
