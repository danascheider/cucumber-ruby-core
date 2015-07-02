require 'cucumber/core/ast/names'
require 'cucumber/core/ast/location'
require 'cucumber/core/ast/describes_itself'

module Cucumber
  module Core
    module Ast
      class Background
        include Names
        include HasLocation
        include DescribesItself

        def initialize(location, keyword, name, description, raw_steps)
          @location = location
          @keyword = keyword
          @name = name
          @description = description
          @raw_steps = raw_steps
          @comments = []
        end

        attr_reader :description, :raw_steps
        private     :raw_steps

        attr_reader :comments, :keyword, :location

        def children
          raw_steps
        end

        def language(language)
          children.each { |step| step.language = language }
        end

        private

        def description_for_visitors
          :background
        end

      end
    end
  end
end
