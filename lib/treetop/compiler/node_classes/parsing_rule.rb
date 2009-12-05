module Treetop
  module Compiler
    class ParsingRule < Runtime::SyntaxNode

      attr_reader :cache_name

      def compile(builder, context)
        @cache_name = "'#{context.join('::')}\##{name}'"
        compile_inline_module_declarations(builder)
        generate_method_definition(builder)
      end
      
      def compile_inline_module_declarations(builder)
        parsing_expression.inline_modules.each_with_index do |inline_module, i|
          inline_module.compile(i, builder, self)
          builder.newline
        end
      end
      
      def generate_method_definition(builder)
        builder.reset_addresses
        expression_address = builder.next_address
        result_var = "r#{expression_address}"
        
        builder.method_declaration(method_name) do
          builder.assign 'start_index', 'index'
          generate_cache_lookup(builder)
          generate_cache_left_recursion(builder)
          builder.newline
          builder.assign result_var, 'nil'
          builder.loop do
            parsing_expression.compile(expression_address, builder)
            builder.newline
            generate_cache_storage(builder, result_var)
          end
          builder << "@stack.pop"
          builder.newline
          builder << result_var
        end
      end
      
      def generate_cache_lookup(builder)
        builder.if_ "node_cache[:#{cache_name}].has_key?(index)" do
          builder.assign 'cached', "node_cache[:#{cache_name}][index]"
          #builder << '@index = cached.interval.end if cached'
          #builder << 'return cached'
          builder.if_ "cached.kind_of? LeftRecursion" do
            builder << 'cached.found(@stack.involved_recursions(cached))'
            builder << 'return nil'
          end
          builder.if_ "cached" do
            builder << 'cached = SyntaxNode.new(input, index...(index + 1)) if cached == true'
            builder << '@index = cached.interval.end'
          end
          builder << 'return cached'
        end
      end
      
      def generate_cache_left_recursion(builder)
        builder.assign 'lrec', "@stack.push(:#{cache_name})"
        builder.assign "node_cache[:#{cache_name}][index]", 'lrec'
      end

      def generate_cache_storage(builder, result_var)
        builder.if__ 'lrec.active?' do
          # any updates to cache and @index are performed in #left_recursion_update
          builder.assign result_var, "left_recursion_update(lrec, start_index, #{result_var})"
        end
        builder.else_ do
          builder.assign "node_cache[:#{cache_name}][start_index]", result_var
        end
        builder << 'break unless lrec.active?'
      end
      
      def method_name
        "_nt_#{name}"
      end
      
      def name
        nonterminal.text_value
      end
    end
  end
end
