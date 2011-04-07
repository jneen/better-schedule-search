require 'open-uri'
require 'active_support/core_ext'

$debug = Logger.new('tmp/debug.log')

# this is a gigantic pile of hack.
# Luckily Berkeley is probably not going to
# change this html any time soon.

class Searcher
  def courses
    @courses ||= CourseList.new
  end

  def initialize(query)
    load_results(query.dup)
  end

  BOGUS_NEXT_URL = 'http://schedule.berkeley.edu/?PageID=srchfall.html'
  OSOC_BASE = 'http://osoc.berkeley.edu/OSOC/osoc'

  def build_url(query)
    out = ""
    out << OSOC_BASE + '?' << query.to_query
    out
  end

  def load_results(query)
    courses << open('http://osoc.berkeley.edu/OSOC/osoc?y=0&p_term=FL&p_deptname=--+Choose+a+Department+Name+--&p_classif=--+Choose+a+Course+Classification+--&p_presuf=--+Choose+a+Course+Prefix/Suffix+--&p_dept=computer+science&x=0')
  end
private
  def see_next_results_url(doc)
    # oh god why
    doc.
      css('body').
      children.filter('table')[0].
      children[1].
      children[2].
      children[1].
      children[1].
      children[2].
      children[1].
      attr('href')
  rescue nil #probably bad.
  end
end

class CourseList
  def tables
    @tables ||= []
  end

  def initialize(*pages)
    pages.each do |page|
      push(page)
    end
  end

  def push(html)
    doc = Nokogiri::HTML(html)
    tables.concat doc.css('table')[1..-2]
  end
  alias << push

  include Enumerable
  def each(&blk)
    if courses.empty?
      yield_each(&blk)
    else
      courses.each(&blk)
    end
  end

private
  def yield_each
    while table = tables.shift
      course = Course.new(table)
      until tables.empty? || lecture?(tables.first)
        course.sections << Section.new(tables.shift)
      end
      courses << course
      yield course
    end
  end

  def courses
    @courses ||= []
  end

  def lecture?(table)
    # if OSOC colors the title blue, then it's a lecture.
    # LOL
    !!table.css('tr')[0].css('font')[-1].attr('color')
  end
end

class Entity
  def self.cache(name, &blk)
    define_method(name) do
      info[name.to_sym] ||= instance_eval(&blk)
    end
  end

  attr_reader :root
  def initialize(root)
    @root = root
  end

  def info
    @info ||= {}
  end

  def to_json
    info.to_json
  end
end

class Course < Entity
  def rows
    @rows ||= root.css('tr')
  end

  cache :sections do
    []
  end

  cache :desig do
    line(1, :raw => true).children[0].text
  end

  cache :catalog_url do
    line(1, :raw => true).children[1].css('a').attr('href').value
  end

  cache :status do
    EnrollmentInfo.new(line(4))
  end

  cache :ccn do
    line(5) =~ /^(\d+)/
    $1.to_i
  end

  cache :units do
    line(6).to_i
  end

  cache :session do
    # TODO
  end

  cache :final do
    Final.new(line(7))
  end

  cache :restrictions do
    line(8)
  end

  cache :note do
    line(9)[0..-5]
  end

  cache :edd? do
    note.include? 'EARLY DROP DEADLINE'
  end

  cache :bad? do
    restrictions == 'FULL' || enrollment.bad?
  end

  def time_and_location
    @time_and_location ||= begin
      l = line(2)
      l ? l.split(', ') : []
    end
  end

  cache :time do
    time_and_location[0]
  end

  cache :location do
    loc = time_and_location[1]
    loc && loc.titleize
  end

  cache(:title) { line(1) }

  cache :instructor do
    line(3)
  end

  cache :enrollment do
    EnrollmentInfo.new(line(10, :label => true), line(10))
  end

  cache :infobears_url do
    # sorry everybody
    if rows[11]
      line(11, :raw => true).css('a').attr('href').to_s
    end # else nil
  end

  cache :ratemyprof_url do
    instructor =~ /^(\w+)/
    if $1
      prof = $1
      desig =~ /^(\w+)/
      dept = $1
      "http://www.ratemyprofessors.com/SelectTeacher.jsp?" << {
        :sid => 1072, # berkeley's school id?
        :the_dept => dept,
        :letter => prof # NB: these params are stupidly named.
      }.to_param
    end
  end

  def css_classes
    c = []
    c << 'bad' if bad?
    c << 'edd' if edd?
    c
  end

#private
  def line(num, options={})
    childidx = options[:label] ? 0 : -1
    row = rows[num].children[childidx]

    return row if options[:raw]

    text = row.text.strip

    text unless text.empty?
  end
end

class Section < Course
end

class EnrollmentInfo < Entity
  attr_reader :label, :line
  def initialize(label, line)
    @label, @line = label, line
  end

  cache :open? do
    fullness != 'Full'
  end

  cache :bad? do
    fullness == 'Full'
  end

  cache :limit do
    line =~ /Limit:(\d+)/
    $1.to_i unless $1.nil?
  end

  cache :enrolled do
    line =~ /Enrolled:(\d+)/
    $1.to_i unless $1.nil?
  end

  cache :available do
    limit - enrolled unless limit.nil? || enrolled.nil?
  end

  cache :waitlist do
    line =~ /Waitlist:(\d+)/
    $1.to_i unless $1.nil?
  end

  cache :as_of do
    label =~ /Enrollment on (\d+\/\d+\/\d+)/
    Date.parse($1) + 2000.years unless $1.nil?
  end

  cache :fullness do
    case 8*(enrolled.to_f / limit)
    when 0...1
      'Empty'
    when 1...3
      '<big>&frac14;</big>Full'
    when 3...5
      '<big>&frac12;</big>Full'
    when 5...7
      '<big>&frac34;</big>Full'
    when 7...8
      'Nearly Full'
    else
      'Full'
    end
  end
end

class Final < Entity
  attr_reader :line
  def initialize(line)
    @line = line
  end

  cache :group do
    line =~ /^(\d+):/
    $1.to_i unless $1.nil?
  end

  cache :date do
    line =~ /\d+: (.*)\302/
    Date.parse($1) unless $1.nil?
  end

  cache :time do
    line =~ /(\S+)\s*$/
    $1
  end
end

class Restrictions < Entity
end
