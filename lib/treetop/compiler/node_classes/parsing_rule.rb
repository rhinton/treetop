module Treetop
  module Compiler
    class ParsingRule < Runtime::SyntaxNode

      def compile(builder)
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
            generate_left_recursion_update(builder, result_var)
            builder.newline
            generate_cache_storage(builder, result_var)
          end
          builder << "@stack.pop"
          builder.newline
          builder << result_var
        end
      end
      
      def generate_cache_lookup(builder)
        builder.if_ "node_cache[:#{name}].has_key?(index)" do
          builder.assign 'cached', "node_cache[:#{name}][index]"
          #builder << '@index = cached.interval.end if cached'
          #builder << 'return cached'
          builder.if__ "cached.kind_of? LeftRecursion" do
            builder << 'cached.found(@stack.involved_recursions(cached))'
            builder << 'return nil'
          end
          builder.else_ do 
            builder << '@index = cached.interval.end if cached'
            builder << 'return cached'
          end
        end
      end
      
      def generate_cache_left_recursion(builder)
        builder.assign 'lrec', "@stack.push(:#{name})"
        builder.assign "node_cache[:#{name}][index]", 'lrec'
      end

      def generate_left_recursion_update(builder, result_var)
        builder.if_ 'lrec.active?' do
          builder << 'lrec.report_to_parents if lrec.seed_parse?'
          builder.if__ result_var do
            builder.if__ "#{result_var}.interval.end > node_cache[:#{name}][start_index].interval.end" do
              builder.assign 'lrec.state', ':grow_lr'
              builder.assign '@index', 'start_index'
              builder << 'lrec.uncache_involved_rules(node_cache, start_index)'
            end
            builder.else_ do
              builder.assign 'lrec.state', ':no_recursion'
              builder.assign result_var, "node_cache[:#{name}][start_index]"
              builder.assign '@index', "#{result_var}.interval.end"
              builder << 'lrec.restore_involved_rules(node_cache, start_index)'
            end
          end
          builder.else_ do
            builder.if_ '!lrec.seed_parse?' do
              builder.assign result_var, "node_cache[:#{name}][start_index]"
              builder.assign '@index', "#{result_var}.interval.end"
              builder << 'lrec.restore_involved_rules(node_cache, start_index)'
            end
            builder.assign 'lrec.state', ':no_recursion'
          end
        end
      end

      def generate_cache_storage(builder, result_var)
        builder.assign "node_cache[:#{name}][start_index]", result_var
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
