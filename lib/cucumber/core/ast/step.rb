require 'cucumber/core/ast/describes_itself'
require 'cucumber/core/ast/location'

module Cucumber
  module Core
    module Ast
      class Step
        include HasLocation
        include DescribesItself

        attr_reader :keyword, :name, :comments, :exception, :multiline_arg
        attr_accessor :language

        def initialize(location, keyword, name, multiline_arg)
          @location, @keyword, @name, @multiline_arg = location, keyword, name, multiline_arg
          @comments = []
        end

        def to_sexp
          [:step, line, keyword, name, @multiline_arg.to_sexp]
        end

        def backtrace_line
          "#{location}:in `#{keyword}#{name}'"
        end

        def actual_keyword(previous_step_keyword = nil)
          if [language.and, language.but].flatten.uniq.include? keyword
            if previous_step_keyword.nil?
              language.given.reject{|kw| kw == '* '}[0]
            else
              previous_step_keyword
            end
          else
            keyword
          end
        end

        def inspect
          keyword_and_name = [keyword, name].join(": ")
          %{#<#{self.class} "#{keyword_and_name}" (#{location})>}
        end

        private

        def children
          [@multiline_arg]
        end

        def description_for_visitors
          :step
        end
      end

      class ExpandedOutlineStep < Step

        def initialize(outline_step, language, location, comments, keyword, name, multiline_arg)
          @outline_step, @language, @location, @comments, @keyword, @name, @multiline_arg = outline_step, language, location, comments, keyword, name, multiline_arg
        end

        alias :self_match_locations? :match_locations?

        def match_locations?(queried_locations)
          self_match_locations?(queried_locations) or @outline_step.match_locations?(queried_locations)
        end

        alias :step_backtrace_line :backtrace_line

        def backtrace_line
          "#{step_backtrace_line}\n" +
          "#{@outline_step.location}:in `#{@outline_step.keyword}#{@outline_step.name}'"
        end

      end
    end
  end
end
