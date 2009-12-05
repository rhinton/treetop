module Treetop
  module Runtime
    class CompiledParser
      include Treetop::Runtime
      
      attr_reader :input, :index, :max_terminal_failure_index
      attr_writer :root
      attr_accessor :consume_all_input
      alias :consume_all_input? :consume_all_input
      
      def initialize
        self.consume_all_input = true
      end

      def parse(input, options = {})
        prepare_to_parse(input)
        @index = options[:index] if options[:index]
        result = send("_nt_#{root}")
        return nil if (consume_all_input? && index != input.size)
        return SyntaxNode.new(input, index...(index + 1)) if result == true
        return result
      end

      def failure_index
        max_terminal_failure_index
      end

      def failure_line
        @terminal_failures && input.line_of(failure_index)
      end

      def failure_column
        @terminal_failures && input.column_of(failure_index)
      end

      def failure_reason
        return nil unless (tf = terminal_failures) && tf.size > 0
        "Expected " +
          (tf.size == 1 ?
           tf[0].expected_string :
                 "one of #{tf.map{|f| f.expected_string}.uniq*', '}"
          ) +
                " at line #{failure_line}, column #{failure_column} (byte #{failure_index+1})" +
                " after #{input[index...failure_index]}"
      end
      
      def terminal_failures
        @terminal_failures.map! {|tf_ary| TerminalParseFailure.new(*tf_ary) }
      end


      protected
      
      attr_reader :node_cache, :input_length
      attr_writer :index
              
      def prepare_to_parse(input)
        @input = input
        @input_length = input.length
        reset_index
        @node_cache = Hash.new {|hash, key| hash[key] = Hash.new}
        @regexps = {}
        @terminal_failures = []
        @max_terminal_failure_index = 0
        @stack = @stack || CallStack.new
        @stack.reset
      end
      
      def reset_index
        @index = 0
      end
      
      def parse_anything(node_class = SyntaxNode, inline_module = nil)
        if index < input.length
          result = instantiate_node(node_class,input, index...(index + 1))
          result.extend(inline_module) if inline_module
          @index += 1
          result
        else
          terminal_parse_failure("any character")
        end
      end
    
      def instantiate_node(node_type,*args)
        if node_type.respond_to? :new 
          node_type.new(*args)
        else
          SyntaxNode.new(*args).extend(node_type)
        end
      end
    
      def has_terminal?(terminal, regex, index)
        if regex
          rx = @regexps[terminal] ||= Regexp.new(terminal)
          input.index(rx, index) == index
        else
          input[index, terminal.size] == terminal
        end
      end
    
      def terminal_parse_failure(expected_string)
        return nil if index < max_terminal_failure_index
        if index > max_terminal_failure_index
          @max_terminal_failure_index = index
          @terminal_failures = []
        end
        @terminal_failures << [index, expected_string]
        return nil
      end

      def left_recursion_update(lrec, start_index, result)
        # assume left recursion is active
        lrec.report_to_parents if lrec.seed_parse?
        if result
          # growing left recursion produced a successful parse
          if result.interval.end > node_cache[lrec.rule][start_index].interval.end
            # new parse achieves progress in stream: continue growing
            lrec.state = :grow_lr
            @index = start_index
            lrec.uncache_involved_rules(node_cache, start_index)
            node_cache[lrec.rule][start_index] = result
          else
            # new parse is no better than previous parse: return previous
            # result and terminate left recursion
            lrec.state = :no_recursion
            result = node_cache[lrec.rule][start_index]
            @index = result.interval.end
            lrec.restore_involved_rules(node_cache, start_index)
          end
        else
          if lrec.seed_parse?
            # seed parse failed: store total failure in cache and preempt recursion
            node_cache[lrec.rule][start_index] = nil
          else
            # growing the last parse failed: return previus (successful) result
            # from cache and terminate left recursion
            result = node_cache[lrec.rule][start_index]
            @index = result.interval.end
            lrec.restore_involved_rules(node_cache, start_index)
          end
          lrec.state = :no_recursion
        end

        return result
      end

    end
  end
end
