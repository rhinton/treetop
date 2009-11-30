require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module LeftRecursionSpec
  describe "Simple direct left recursion" do
    testing_grammar %{
      grammar LRDirect
        rule lr
          lr "l" / "l"
        end
      end
    }

    it "parses matching input" do
      parse('l').should_not be_nil
      parse('lll').should_not be_nil
    end

    it "fails if it does not parse all input" do
      parse('llr').should be_nil
    end
  end

  describe "Direct left recursion backtracking" do
    # compare BacktrackLR1 from http://www.tinlizzie.org/ometa-js/#LeftRecursionFiddling
    testing_grammar %{
      grammar BacktrackLR1 
        rule top
          a b {
            def sexp
              "(top #{a.sexp} #{b.sexp})"
            end
          }
        end
        rule a
          a "aa" {
            def sexp
              "(a.1 #{a.sexp} 'aa)"
            end
          }
          / a "a" {
            def sexp
              "(a.2 #{a.sexp} 'a)"
            end
          }
          / "aa" {
            def sexp
              "(a.3 'aa)"
            end
          }
        end
        rule b
          "ab" {
            def sexp
              "(b 'ab)"
            end
          }
        end
      end
    }

    it "drops to the seed parse" do
      parse('aaab').sexp.should == "(top (a.3 'aa) (b 'ab))"
    end

    it "backtracks when necessary to complete the parse" do
      parse('aaaab').sexp.should == "(top (a.2 (a.3 'aa) 'a) (b 'ab))"
    end

    it "follows the (earliest) highest-priority left-recursive path" do
      parse('aaaaab').sexp.should == "(top (a.1 (a.3 'aa) 'aa) (b 'ab))"
      parse('aaaaaab').sexp.should == "(top (a.1 (a.2 (a.3 'aa) 'a) 'aa) (b 'ab))"
    end
  end

  describe "Direct left recursion backtracking (2)" do
    # compare BacktrackLR2 from http://www.tinlizzie.org/ometa-js/#LeftRecursionFiddling
    testing_grammar %{
      grammar BacktrackLR2
        rule top
          a b {
            def sexp
              "(top #{a.sexp} #{b.sexp})"
            end
          }
        end
        rule a
          a "aa" {
            def sexp
              "(a.1 #{a.sexp} 'aa)"
            end
          }
          / a "a" {
            def sexp
              "(a.2 #{a.sexp} 'a)"
            end
          }
          / "ac" {
            def sexp
              "(a.3 'ac)"
            end
          }
        end
        rule b
          "ab" {
            def sexp
              "(b 'ab)"
            end
          }
        end
      end
    }

    it "drops to the seed parse" do
      parse('acab').sexp.should == "(top (a.3 'ac) (b 'ab))"
    end

    it "backtracks according to priority" do
      parse('acaab').sexp.should == "(top (a.2 (a.3 'ac) 'a) (b 'ab))"
      parse('acaaab').sexp.should == "(top (a.1 (a.3 'ac) 'aa) (b 'ab))"
      parse('acaaaab').sexp.should == "(top (a.1 (a.2 (a.3 'ac) 'a) 'aa) (b 'ab))"
    end
  end

  describe "Indirect left recursion (subtraction expressions)" do
    testing_grammar %{
      grammar SubLR
        rule x
          expr {
            def value
              expr.value
            end
          }
        end
        rule expr
          x "-" num {
            def value
              x.value - num.value
            end
          }
          / num {
            def value
              num.value
            end
          }
        end
        rule num
          ([1-9]* [0-9]) {
            def value
              text_value.to_i
            end
          }
        end
      end
    }

    it "parses matching input" do
      parse('0').should_not be_nil
      parse('12').should_not be_nil
      parse('3-0-5').should_not be_nil
    end

    it "produces correct binary results" do
      parse('0').value.should == 0
      parse('12').value.should == 12
      parse('3-1').value.should == 2
      parse('3-6').value.should == -3
    end

    it "produces correct higher-order results (left-associative parse tree)" do
      parse('3-1-2').value.should == 0
    end
  end

  describe "Indirect recursion across multiple choices" do
    testing_grammar %{
      grammar MultiChoiceLR
        rule top
          ad {
            def sexp
              "(top #{super})"
            end
          }
        end
        rule a
          ab / ac / ad
        end
        rule ab
          a "b" {
            def sexp
              "(ab.1 #{a.sexp} 'b)"
            end
          }
          / "b" {
            def sexp
              "(ab.2 'b)"
            end
          }
        end
        rule ac
          a "c" {
            def sexp
              "(ac.1 #{a.sexp} 'c)"
            end
          }
          / a "cb" {
            # this choice should never occur due to precendence of rule ab
            def sexp
              "(ac.2 #{a.sexp} 'cb)"
            end
          }
          / "c" {
            def sexp
              "(ac.3 'c)"
            end
          }
        end
        rule ad
          a "d" {
            def sexp
              "(ad #{a.sexp} 'd)"
            end
          }
        end
      end
    }

    it "parses correctly" do
      parse('bd').sexp.should == "(top (ad (ab.2 'b) 'd))"
      parse('cd').sexp.should == "(top (ad (ac.3 'c) 'd))"
      parse('cbd').sexp.should == "(top (ad (ab.1 (ac.3 'c) 'b) 'd))"
      parse('cbcd').sexp.should == "(top (ad (ac.1 (ab.1 (ac.3 'c) 'b) 'c) 'd))"
      parse('cbbcbbd').sexp.should == "(top (ad (ab.1 (ab.1 (ac.1 (ab.1 (ab.1 (ac.3 'c) 'b) 'b) 'c) 'b) 'b) 'd))"
    end

    it "rejects some strings not in the grammar" do
      parse('b').sexp.should_be_nil
      parse('c').sexp.should_be_nil
      parse('d').sexp.should_be_nil
      parse('cb').sexp.should_be_nil
      parse('cc').sexp.should_be_nil
      parse('bddd').sexp.should_be_nil
      parse('ccdd').sexp.should_be_nil
      parse('cbc').sexp.should_be_nil
      parse('cbbcbb').sexp.should_be_nil
    end
  end

  describe "Indirect recursion with choices across multiple levels" do
    test_grammar %{
      grammar MultiDeepLR
        rule top
          a {
            def sexp
              "(top #{a.sexp})"
            end
          }
        end
        rule a
          b "a" {
            def sexp
              "(a #{b.sexp} 'a)"
            end
          }
        end
        rule b
          a "b" {
            def sexp
              "(b.1 #{a.sexp} 'b)"
            end
          }
          / c "b" {
            def sexp
              "(b.2 #{c.sexp}) 'b)"
            end
          }
          / "b" {
            def sexp
              "(b.3 'b)"
            end
          }
        rule c
          c "c" {
            def sexp
              "(c.1 #{c.sexp} 'c)"
            end
          }
          / "c" {
            def sexp
              "(c.2 'c)"
            end
          }
        end
      end
    }

    it "parses correctly" do
      parse('ba').sexp.should == "(top (a (b.3 'b) 'a))"
      parse('cba').sexp.should == "(top (a (b.2 (c.2 'c) 'b) 'a))"
      parse('ccba').sexp.should == "(top (a (b.2 (c.1 (c.2 'c)) 'b) 'a))"
      parse('baba').sexp.should == "(top (a (b.1 (a (b.3 'b) 'a) 'b) 'a))"
    end
  end

  describe "Mixed left and right recursion" do
    test_grammar %{
      grammar MixedLeftRight
        rule top
          l r {
            def sexp
              "(top #{l.sexp} #{r.sexp})"
            end
          }
        end
        rule l
          l "a" {
            def sexp
              "(l #{l.sexp} 'a)"
            end
          }
          / "a" {
            def sexp
              "(l 'a)"
            end
          }
        end
        rule r 
          "a" r {
            def sexp
              "(r 'a #{r.sexp})"
            end
          }
          / "a" {
            def sexp
              "(r 'a)"
            end
          }
        end
      end
    }

    it "parses correctly with left-recursion dominant" do
      parse('a').sexp.should_be_nil
      parse('aa').sexp.should == "(top (l 'a) (r 'a))"
      parse('aaa').sexp.should == "(top (l (l 'a) 'a) (r 'a))"
    end
  end
  
end
