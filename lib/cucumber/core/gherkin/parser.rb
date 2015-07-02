require 'gherkin/parser'
require 'gherkin/token_scanner'
require 'gherkin/token_matcher'
require 'gherkin/ast_builder'
require 'gherkin/errors'
require 'cucumber/core/ast'

module Cucumber
  module Core
    module Gherkin
      ParseError = Class.new(StandardError)

      class Parser
        attr_reader :receiver
        private     :receiver

        def initialize(receiver)
          @receiver = receiver
        end

        def document(document)
          parser  = ::Gherkin::Parser.new
          scanner = ::Gherkin::TokenScanner.new(document.body)
          builder = AstTransformer.new(document.uri)

          if document.body.strip.empty?
            return receiver.feature Ast::NullFeature.new
          end

          begin
            result = parser.parse(scanner, builder, ::Gherkin::TokenMatcher.new)

            receiver.feature result
          rescue *PARSER_ERRORS => e
            raise Core::Gherkin::ParseError.new("#{document.uri}: #{e.message}")
          end
        end

        def done
          receiver.done
          self
        end

        private

        PARSER_ERRORS = ::Gherkin::ParserError

        class AstTransformer < ::Gherkin::AstBuilder
          attr_reader :uri
          private :uri

          def initialize(uri)
            super()
            @uri = uri
          end

          def create_ast_value(data)
            data = super

            if data[:type] == :Step && current_node.rule_type == :ScenarioOutline
              data[:type] = :OutlineStep
            end

            attributes = attributes_from(data)
            case data[:type]
            when :Feature
              Ast::Feature.new(
                attributes[:language],
                attributes[:location],
                attributes[:background] ||= Ast::EmptyBackground.new,
                attributes[:comments],
                attributes[:tags],
                attributes[:keyword],
                attributes[:name],
                attributes[:description] ||= "",
                attributes[:scenario_definitions]
                )
            when :Background
              Ast::Background.new(
                attributes[:location],
                attributes[:keyword],
                attributes[:name],
                attributes[:description] ||= "",
                attributes[:steps]
                )
            when :Scenario
              Ast::Scenario.new(
                attributes[:location],
                attributes[:tags],
                attributes[:keyword],
                attributes[:name],
                attributes[:description] ||= "",
                attributes[:steps]
                )
            when :ScenarioOutline
              Ast::ScenarioOutline.new(
                attributes[:location],
                attributes[:tags],
                attributes[:keyword],
                attributes[:name],
                attributes[:description] ||= "",
                attributes[:steps],
                attributes[:examples]
                )
            when :Examples
              Ast::Examples.new(
                attributes[:location],
                attributes[:tags],
                attributes[:keyword],
                attributes[:name],
                attributes[:description] ||= "",
                attributes[:header],
                attributes[:example_rows]
                )
            when :Step
              Ast::Step.new(
                attributes[:location],
                attributes[:keyword],
                attributes[:text],
                attributes[:argument] ||= Ast::EmptyMultilineArgument.new
                )
            when :OutlineStep
              Ast::OutlineStep.new(
                attributes[:location],
                attributes[:keyword],
                attributes[:text],
                attributes[:argument] ||= Ast::EmptyMultilineArgument.new
                )
            when :DataTable
              Ast::DataTable.new(
                attributes[:rows],
                attributes[:location]
                )
            when :DocString
              Ast::DocString.new(
                attributes[:content],
                attributes[:content_type],
                attributes[:location]
                )
            else
              raise
            end
          rescue => e
            raise e.class, "Unable to create AST node: '#{data[:type]} from #{data}' #{e.message}", e.backtrace
          end

          def attributes_from(data)
            result = data.dup
            result.delete(:type)
            if result.key?(:location)
              result[:location] = Ast::Location.new(uri, result[:location][:line])
            end

            if result.key?(:tags)
              result[:tags] = result[:tags].map { |tag| Ast::Tag.new(Ast::Location.new(uri, tag[:location][:line]), tag[:name]) }
            end

            if result.key?(:comments)
              result[:comments] = result[:comments].map { |comment| Ast::Comment.new(Ast::Location.new(uri, comment[:location][:line]), comment[:text]) }
            end

            if result.key?(:rows)
              result[:rows] = result[:rows].map { |r| r[:cells].map { |c| c[:value] } }
            end

            if result.key?(:tableHeader)
              header_attrs = result.delete(:tableHeader)
              header_attrs.delete(:type)
              header_attrs[:cells] = header_attrs[:cells].map { |c| c[:value] }
              result[:header] = Ast::ExamplesTable::Header.new(header_attrs[:cells], Ast::Location.new(uri, header_attrs[:location][:line]))
            end

            if result.key?(:tableBody)
              body_attrs = result.delete(:tableBody)
              result[:example_rows] = body_attrs.each.with_index.map do |row,index|
                cells = row[:cells].map { |c| c[:value] }
                header = result[:header]
                header.build_row(cells, index + 1, Ast::Location.new(uri, row[:location][:line]))
              end
            end
            rubify_keys(result)
          end

          def rubify_keys(hash)
            hash.keys.each do |key|
              if key.downcase != key
                hash[underscore(key).to_sym] = hash.delete(key)
              end
            end
            return hash
          end

          def underscore(string)
            string.to_s.gsub(/::/, '/').
              gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
              gsub(/([a-z\d])([A-Z])/,'\1_\2').
              tr("-", "_").
              downcase
          end

        end
      end
    end
  end
end
