require 'open-uri'

class Hash
  def to_query_params
    map do |k,v|
      "#{URI.encode(k.to_s)}=#{URI.encode(v.to_s)}"
    end.join('&')
  end
end

class Searcher
  def course_els
    @course_els ||= []
  end

  def courses
    course_els.map { |c| Course.new(c) }
  end

  def initialize(query)
    load_results(query.dup)
  end

  BOGUS_NEXT_URL = 'http://schedule.berkeley.edu/?PageID=srchfall.html'
  OSOC_BASE = 'http://osoc.berkeley.edu/OSOC/osoc'

  def build_url(query)
    out = ""
    out << OSOC_BASE + '?' << query.to_query_params
    out
  end

  def load_results(query)
    doc = Nokogiri::HTML(open(build_url(query)))
    course_els.concat doc.css('table')[1..-2].css('tr')

    next_url = see_next_results_url(doc)

    if next_url && next_url != BOGUS_NEXT_URL
      query['p_start_row'] ||= 0
      query['p_start_row'] += 100

      load_results(query)
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
  rescue nil #probably bad.
  end
end

class Entity
  def self.cache(name, &blk)
    define_method(name) do
      info[name.to_sym] ||= blk.call
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

  def method_missing(m, *a, &b)
    info.has_key?(m) ? info[m] : super
  end
end

class Course < Entity
  cache :instructor do
  end
end

class Section < Course
end

class EnrollmentInfo < Entity
end
