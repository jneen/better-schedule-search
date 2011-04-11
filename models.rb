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
    load_results(build_url(query))
  end

  BOGUS_NEXT_URL = 'http://schedule.berkeley.edu/?PageID=srchfall.html'
  OSOC_BASE = 'http://osoc.berkeley.edu/OSOC/osoc'

  def build_url(query)
    out = ""
    out << OSOC_BASE + '?' << query.to_param
    out
  end

  def load_results(url)
    doc = Nokogiri::HTML(open(url))
    courses << doc

    next_url = see_next_results_url(doc)

    if next_url && next_url != BOGUS_NEXT_URL
      load_results(next_url)
    end
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
  rescue
    nil # probably bad
  end
end

class CourseList
  include ActiveModel::Serializers::JSON

  def tables
    @tables ||= []
  end

  def initialize(*pages)
    pages.each do |page|
      push(page)
    end
  end

  def push(doc)
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

  def as_json(*a)
    self.to_a
  end

  def encode_json(*a)
    as_json.to_json
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
  def encode_json(*a)
    as_json.to_json
  end

  include ActiveModel::Serializers::JSON

  class << self
    def attributes
      if superclass.respond_to? :attributes
        superclass.attributes + own_attributes
      else
        own_attributes
      end
    end

    def attribute(name, &blk)
      own_attributes << name.to_sym
      define_method(name) do
        info[name.to_sym] ||= instance_eval(&blk)
      end
    end

    def attribute?(name)
      attributes.include? name.to_sym
    end

  private
    def own_attributes
      @own_attributes ||= []
    end
  end

  attr_reader :root
  def initialize(root)
    @root = root
  end

  def info
    @info ||= {}
  end

  def as_json(*a)
    inflate!
    info
  end

  def clear
    info.clear
  end

  def inflate!
    clear

    self.class.attributes.each do |attr|
p :attr => attr, :klass => self.class
      result = send(attr)
      result.inflate! if result.respond_to? :inflate!
    end
  end
end

# common superclass for Course and Section
class CourseProto < Entity
  def rows
    @rows ||= root.css('tr')
  end

  attribute :desig do
    line(1, :raw => true).children[0].text
  end

  attribute :updated do
    line(4) =~ /UPDATED: (\d+\/\d+\/\d+)/
    # if it doesn't match or OSOC gives us an invalid date
    # just return nil
    Date.parse($1) + 2000.years if $1 rescue nil
  end

  attribute :ccn do
    line(5) =~ /^(\d+)/
    $1.to_i
  end

  attribute :restrictions do
    line(8)
  end

  attribute :note do
    line(9)[0..-5]
  end

  attribute :edd? do
    note.include? 'EARLY DROP DEADLINE'
  end

  attribute :bad? do
    restrictions == 'FULL' || enrollment.bad?
  end

  def time_and_location
    @time_and_location ||= begin
      l = line(2)
      l ? l.split(', ') : []
    end
  end

  attribute :time do
    time_and_location[0]
  end

  attribute :location do
    loc = time_and_location[1]
    loc && loc.titleize
  end

  attribute(:title) do
    line(1).gsub('(catalog description)', '').strip
  end

  attribute :instructor do
    line(3)
  end

  attribute :enrollment do
    EnrollmentInfo.new(line(10, :label => true), line(10))
  end

  attribute :infobears_url do
    if rows[11]
      line(11, :raw => true).css('a').attr('href').to_s
    end # else nil
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

class Course < CourseProto
  def inflate!
    super
    sections.each(&:inflate!)
  end

  def clear
    _sections = self.sections
    super
    info[:sections] = _sections
  end

  attribute :sections do
    []
  end

  attribute :catalog_url do
    line(1, :raw => true).children[1].css('a').attr('href').value
  end

  attribute :units do
    line(6).to_i
  end

  attribute :session do
    # TODO
  end

  attribute :final do
    Final.new(line(7))
  end

  attribute :ratemyprof_url do
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

end

class Section < CourseProto
end

class EnrollmentInfo < Entity
  attr_reader :label, :line
  def initialize(label, line)
    @label, @line = label, line
  end

  attribute :open? do
    fullness != 'Full'
  end

  attribute :bad? do
    fullness == 'Full'
  end

  attribute :limit do
    line =~ /Limit:(\d+)/
    $1.to_i unless $1.nil?
  end

  attribute :enrolled do
    line =~ /Enrolled:(\d+)/
    $1.to_i unless $1.nil?
  end

  attribute :available do
    limit - enrolled unless limit.nil? || enrolled.nil?
  end

  attribute :waitlist do
    line =~ /Waitlist:(\d+)/
    $1.to_i unless $1.nil?
  end

  attribute :as_of do
    label =~ /Enrollment on (\d+\/\d+\/\d+)/
    Date.parse($1) + 2000.years unless $1.nil?
  end

  attribute :fullness do
    if !enrolled.nil? && !limit.nil?
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
end

class Final < Entity
  attr_reader :line
  def initialize(line)
    @line = line
  end

  attribute :group do
    line =~ /^(\d+):/
    $1.to_i unless $1.nil?
  end

  attribute :date do
    line =~ /\d+: (.*)\302/
    Date.parse($1) if $1 rescue nil
  end

  attribute :time do
    line =~ /(\S+)\s*$/
    $1
  end
end

class Restrictions < Entity
end
