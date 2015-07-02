require 'cucumber/core/ast/names'
require 'cucumber/core/ast/location'
require 'cucumber/core/ast/describes_itself'

module Cucumber
  module Core
    module Ast
      class ScenarioOutline
        include Names
        include HasLocation
        include DescribesItself

        MissingExamples = Class.new(StandardError)

        attr_reader :comments, :tags, :keyword,
                    :steps, :examples_tables, :line
        private :line

        def initialize(location, tags, keyword, name, description, steps, examples)
          @location          = location
          @tags              = tags
          @keyword           = keyword
          @name              = name
          @description       = description
          @steps             = steps
          @examples_tables   = examples
          @comments = []
        end

        def language(language)
          children.each { |child| child.language(language) }
        end

        private

        def children
          @steps + @examples_tables
        end

        def description_for_visitors
          :scenario_outline
        end

      end

    end
  end
end
