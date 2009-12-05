require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module LeftRecursionSpec
  describe "Simple direct left recursion" do
    testing_grammar %q{
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
    testing_grammar %q{
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

    it "fails all the time because of the priority of PEG rules" do
      parse('aaab').should be_nil
      parse('aaaab').should be_nil
      parse('aaaaab').should be_nil
      parse('aaaaaab').should be_nil
    end
  end

  describe "Direct left recursion backtracking (2)" do
    # compare BacktrackLR2 from http://www.tinlizzie.org/ometa-js/#LeftRecursionFiddling
    testing_grammar %q{
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
          "b" {
            def sexp
              "(b 'b)"
            end
          }
        end
      end
    }

    it "drops to the seed parse" do
      parse('acb').sexp.should == "(top (a.3 'ac) (b 'b))"
    end

    it "backtracks according to priority" do
      parse('acab').sexp.should == "(top (a.2 (a.3 'ac) 'a) (b 'b))"
      parse('acaab').sexp.should == "(top (a.1 (a.3 'ac) 'aa) (b 'b))"
      parse('acaaab').sexp.should == "(top (a.2 (a.1 (a.3 'ac) 'aa) 'a) (b 'b))"
    end
  end

  describe "Indirect left recursion (subtraction expressions)" do
    testing_grammar %q{
      grammar SubLR
        rule x
          expr
        end
        rule expr
          x "-" num {
            def value
              x.value - num.value
            end
          }
          / num
        end
        rule num
          [1-9] [0-9]* {
            def value
              text_value.to_i
            end
          }
          / "0" {
            def value
              0
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
    testing_grammar %q{
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
      parse('b').should be_nil
      parse('c').should be_nil
      parse('d').should be_nil
      parse('cb').should be_nil
      parse('cc').should be_nil
      parse('bddd').should be_nil
      parse('ccdd').should be_nil
      parse('cbc').should be_nil
      parse('cbbcbb').should be_nil
    end
  end

  describe "Indirect recursion with choices across multiple levels" do
    testing_grammar %q{
      grammar MultiDeepLR
        rule top
          a {
            def sexp
              "(top #{super})"
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
              "(b.2 #{c.sexp} 'b)"
            end
          }
          / "b" {
            def sexp
              "(b.3 'b)"
            end
          }
        end
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
      parse('ccba').sexp.should == "(top (a (b.2 (c.1 (c.2 'c) 'c) 'b) 'a))"
      parse('baba').sexp.should == "(top (a (b.1 (a (b.3 'b) 'a) 'b) 'a))"
    end
  end

  describe "Mixed left and right recursion" do
    testing_grammar %q{
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

    it "always fails due to greedy PEG semantics" do 
      parse('a').should be_nil
      parse('aa').should be_nil
      parse('aaa').should be_nil
    end
  end
  
  describe "Circular left recursion with no termination" do
    testing_grammar %q{
      grammar CircularLR
        rule a 
          b "a" / c "a"
        end
        rule b
          c "b" / a "b"
        end
        rule c
          a "c" / b "c"
        end
      end
    }

    it "should fail gracefully for any finite-length input (no infinite loops)" do
      parse('a').should be_nil
      parse('ba').should be_nil
      parse('cba').should be_nil
      parse('ababcacba').should be_nil
    end
  end


  describe "Circular left recursion with termination" do
    testing_grammar %q{
      grammar CircularLR2
        rule a 
          b "a" / c "a" 
        end
      
        rule b
          c "b" / a "b" 
        end
      
        rule c
          a "c" / b "c" / "c"
        end
      end
    }

    it "should fail for non-matching strings" do
      parse('a').should be_nil
      parse('ba').should be_nil
      parse('ababcacba').should be_nil
    end
  
    it "should fail for non-matching strings" do
      parse('cba').should_not be_nil
      parse('cabcbaba').should_not be_nil
      parse('cbcbcba').should_not be_nil
      parse('cacacacba').should_not be_nil
    end
  end


  describe "Mutual left-recursion" do
    testing_grammar %q{
      grammar MutualLR
        rule top
          b
        end
      
        rule a
          b "a" {
            def sexp
              "(a #{b.sexp})"
            end
          }
          / c "a" {
            def sexp
              "(a #{c.sexp})"
            end
          }
          / d "a" {
            def sexp
              "(a #{d.sexp})"
            end
          }
        end
      
        rule b
          a "b" {
            def sexp
              "(b #{a.sexp})"
            end
          }
          / c "b" {
            def sexp
              "(b #{c.sexp})"
            end
          }
          / "b" {
            def sexp
              "(b)"
            end
          }
        end
      
        rule c
          a "c" {
            def sexp
              "(c #{a.sexp})"
            end
          }
        end
      
        rule d
          "d" {
            def sexp
              "(d)"
            end
          }
        end
      end
    }
      
    it "properly parses matching strings" do
      parse('b').sexp.should      == "(b)"
      parse('dacb').sexp.should   == "(b (c (a (d))))"
      parse('bacacb').should      be_nil
      parse('bacb').sexp.should   == "(b (c (a (b))))"
      parse('dab').sexp.should    == "(b (a (d)))"
      parse('bacab').should       be_nil
      parse('bab').sexp.should    == "(b (a (b)))"
      
      parse('dacacb').should be_nil
      parse('dacbacb').sexp.should    == "(b (c (a (b (c (a (d)))))))"
      parse('dacbab').sexp.should     == "(b (a (b (c (a (d))))))"
      parse('dabacb').sexp.should     == "(b (c (a (b (a (d))))))"
      parse('dabab').sexp.should      == "(b (a (b (a (d)))))"
      parse('bacacb').should          be_nil
      parse('bacbacb').sexp.should    == "(b (c (a (b (c (a (b)))))))"
      parse('babacb').sexp.should     == "(b (c (a (b (a (b))))))"
      parse('bacbab').sexp.should     == "(b (a (b (c (a (b))))))"
      parse('babab').sexp.should      == "(b (a (b (a (b)))))"
      parse('bacacacb').should        be_nil
      parse('bacbacbacb').sexp.should == "(b (c (a (b (c (a (b (c (a (b))))))))))"
    end
  
    it "fails for strings not parsed by the grammar" do
      parse('a').should be_nil
      #parse('b').should be_nil
      parse('c').should be_nil
      parse('d').should be_nil
      parse('aa').should be_nil
      parse('ab').should be_nil
      parse('ac').should be_nil
      parse('ad').should be_nil
      parse('ba').should be_nil
      parse('bb').should be_nil
      parse('bc').should be_nil
      parse('bd').should be_nil
      parse('ca').should be_nil
      parse('cb').should be_nil
      parse('cc').should be_nil
      parse('cd').should be_nil
      parse('da').should be_nil
      parse('db').should be_nil
      parse('dc').should be_nil
      parse('dd').should be_nil
      parse('aaa').should be_nil
      parse('aab').should be_nil
      parse('aac').should be_nil
      parse('aad').should be_nil
      parse('aba').should be_nil
      parse('abb').should be_nil
      parse('abc').should be_nil
      parse('abd').should be_nil
      parse('aca').should be_nil
      parse('acb').should be_nil
      parse('acc').should be_nil
      parse('acd').should be_nil
      parse('ada').should be_nil
      parse('adb').should be_nil
      parse('adc').should be_nil
      parse('add').should be_nil
      parse('baa').should be_nil
      #parse('bab').should be_nil
      parse('bac').should be_nil
      parse('bad').should be_nil
      parse('bba').should be_nil
      parse('bbb').should be_nil
      parse('bbc').should be_nil
      parse('bbd').should be_nil
      parse('bca').should be_nil
      parse('bcb').should be_nil
      parse('bcc').should be_nil
      parse('bcd').should be_nil
      parse('bda').should be_nil
      parse('bdb').should be_nil
      parse('bdc').should be_nil
      parse('bdd').should be_nil
      parse('caa').should be_nil
      parse('cab').should be_nil
      parse('cac').should be_nil
      parse('cad').should be_nil
      parse('cba').should be_nil
      parse('cbb').should be_nil
      parse('cbc').should be_nil
      parse('cbd').should be_nil
      parse('cca').should be_nil
      parse('ccb').should be_nil
      parse('ccc').should be_nil
      parse('ccd').should be_nil
      parse('cda').should be_nil
      parse('cdb').should be_nil
      parse('cdc').should be_nil
      parse('cdd').should be_nil
      parse('daa').should be_nil
      #parse('dab').should be_nil
      parse('dac').should be_nil
      parse('dad').should be_nil
      parse('dba').should be_nil
      parse('dbb').should be_nil
      parse('dbc').should be_nil
      parse('dbd').should be_nil
      parse('dca').should be_nil
      parse('dcb').should be_nil
      parse('dcc').should be_nil
      parse('dcd').should be_nil
      parse('dda').should be_nil
      parse('ddb').should be_nil
      parse('ddc').should be_nil
      parse('ddd').should be_nil
    end
  end

end
