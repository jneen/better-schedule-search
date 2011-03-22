class Searcher
end

class Entity
  def info
    @info ||= {}
  end

  def to_json
    info.to_json
  end

  def method_missing(m, *a, &b)
    if m.to_s.end_with?(?=)
  end
end

class Course < Entity
end

class Section < Entity
end

class EnrollmentInfo < Entity
end
