# Discussion
#
# The implementation of left recursion is based on the paper, "Packrat Parsers
# Can Support Left Recursion" by Alessandro Warth, James R. Douglass, and Todd
# Millstein.  There are a few differences, though.  Their LR type seemed
# superfluous in this implementation.  Specifically, the seed is available as
# the current result, the rule is available to the current parsing method, the
# head is otherwise available when necessary, and the next pointer is
# unnecessary since the stack is implemented as an array.

require 'set'
module Treetop
  module Runtime
    # Instances of the LeftRecursion class are stored on the call stack and the
    # memo cache to provide the context necessary for parsing left-rercursive
    # rules.
    class LeftRecursion
      attr_reader :stack_pos
      attr_accessor :rule
      attr_accessor :state
      attr_reader :involved_rules
      attr_reader :parent_recursions

      INTERVAL = (-1...-1)

      def initialize(stack_pos, rule=nil)
        @stack_pos = stack_pos
        @rule = rule
        @state = :no_recursion
        @involved_rules = Set.new
        @indirect_results_cache = {}
        @parent_recursions = []
      end

      def set(rule)
        @rule = rule
        #assert(@state == :no_recursion)
        #assert(@involved_rules.empty?)
        #assert(@indirect_results_cache.empty?)
        #assert(@parent_recursions.empty?)
      end

      def interval
        INTERVAL
      end

      # This method is called when a left recursive loop is discovered.  The
      # argument is an Enumerable containing the LeftRecursion instances on the
      # call stack up to (but not including) the left-recursive rule.
      def found(involved_recursions)
        # involved = stack.involved_recursions(self)
        # @involved_rules.merge(involved.map{|r| r.rule})
        #involved.each do |lrec|
        involved_recursions.each do |lrec|
          @involved_rules.add(lrec.rule)
          lrec.parent_recursions.push(self)
        end
        @state = :seed_parse
      end

      # Report the involved set of a child recursion to any parent recursions.
      # In particular, when two or more rules are mutually recursive, this
      # method reports the involved set of the "child" recursion to the
      # "parent" recursion.
      def report_to_parents
        @parent_recursions.each do |lrec|
          lrec.involved_rules.merge(@involved_rules)
        end
        @parent_recursions.clear
      end

      # Return a true value when this left recursion object is marked as
      # working on a seed parse or growing a left recursive rule.
      def active?
        (@state == :seed_parse) || (@state == :grow_lr)
      end

      # Return a true value when this left recursion object is executing a seed
      # parse.
      def seed_parse?
        @state == :seed_parse
      end
  
      # Remove the cached parse results for nodes involved indirectly in left
      # recursion.  These results are saved and restored when we are done growing
      # the seed parse.
      def uncache_involved_rules(node_cache, pos)
        @involved_rules.each do |rule|
          # when growing seed parses, some of the original rules may not be
          # reactivated -- so only update our cache for rules that are parsed
          if node_cache[rule].has_key?(pos)
            @indirect_results_cache[rule] = node_cache[rule][pos]
            node_cache[rule].delete(pos)
          end
        end
      end
  
      # Restore the cached parse results for nodes involved indirectly in left
      # recursion (see #uncache_involved_rules).
      def restore_involved_rules(node_cache, pos)
        @involved_rules.each do |rule|
          node_cache[rule][pos] = @indirect_results_cache[rule] || node_cache[rule][pos]
        end
        @indirect_results_cache.clear
        @involved_rules.clear
      end
    end


  
    # The CallStack class implements a call stack based on a Ruby
    # (dynamically-sized) array.  By storing the call stack in an array, we (A)
    # have O(1) random access, and (B) reuse LeftRecursion objects to minimize
    # instantiations.  Note that the random access is actually used for
    # creating the list of involved rules when recursion is detected
    # (CallStack#involved_recursions).
    class CallStack
      # Initial size of call stack: a value of 4 allows us to parse grammars
      # with rules up to four levels deep without increasing the call stack
      # size.
      INITIAL_SIZE = 32
      attr_reader :curr_idx
  
      def initialize
        @curr_idx = -1
        @stack = Array.new(INITIAL_SIZE) {|ii| LeftRecursion.new(ii)}
      end

      # Reset call stack state preparatory for a new parse.  This should only
      # be necessary if the last parse failed in an unexpected way
      # (e.g. throwing an exception).
      def reset
        @curr_idx = -1
      end
  
      # Push a LeftRecursion object on the call stack corresponding to a new
      # invocation of rule +rule+ at index +start+.  Returns the new instance.
      def push(rule)
        @curr_idx += 1
        if @curr_idx >= @stack.size
          @stack.push(LeftRecursion.new(@curr_idx, rule))
        else
          @stack[@curr_idx].set(rule)
        end
        @stack[@curr_idx]
      end
  
      # Pop the current LeftRecursion object off the stack.  Returns the instance
      # removed.
      def pop
        result = @stack[@curr_idx]
        @curr_idx -= 1
        result
      end
  
      # Return a Set containing the LeftRecursion objects involved in a
      # recursion (i.e. up the call stack) up to the given LeftRecursion
      # object.  The resulting set does not include the head object.
      def involved_recursions(head)
        @stack[(head.stack_pos+1)..@curr_idx]
      end
  
      ## Return a Set containing the rules involved in a recursion (i.e. up the
      ## call stack) up to the given LeftRecursion object.  The resulting set does
      ## not include the head object.
      #def involved_rules(head)
      #  rset = Set.new
      #  idx = @curr_idx
      #  while !@stack[idx].equal? head
      #    rset.add(@stack[idx].rule)
      #    idx -= 1
      #  end
      #  rset
      #end

      def inspect
        str = ""
        @curr_idx.times do |idx|
          str << "\n#{idx}:  #{@stack[idx].inspect}"
        end
      end

    end  # CallStack class

  end  # Runtime module
end  # Treetop module
