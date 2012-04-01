require_relative '../../spec_helper'
require 'tailor/rulers/indentation_ruler'
require 'ripper'

describe Tailor::Rulers::IndentationSpacesRuler do
  let!(:spaces) { 5 }

  subject do
    Tailor::Rulers::IndentationSpacesRuler.new(spaces)
  end

  describe "#initialize" do
    it "sets @proper to an Hash with :this_line and :next_line keys = 0" do
      proper_indentation = subject.instance_variable_get(:@proper)
      proper_indentation.should be_a Hash
      proper_indentation[:this_line].should be_zero
      proper_indentation[:next_line].should be_zero
    end
  end

  describe "#should_be_at" do
    it "returns @proper[:this_line]" do
      subject.instance_variable_set(:@proper, { this_line: 321 })
      subject.should_be_at.should == 321
    end
  end

  describe "#next_should_be_at" do
    it "returns @proper[:next_line]" do
      subject.instance_variable_set(:@proper, { next_line: 123 })
      subject.next_should_be_at.should == 123
    end
  end

  describe "#decrease_this_line" do
    let!(:spaces) { 27 }

    context "#started? is true" do
      before { subject.stub(:started?).and_return true }

      context "@proper[:this_line] gets decremented < 0" do
        it "sets @proper[:this_line] to 0" do
          subject.instance_variable_set(:@proper, {
            this_line: 0, next_line: 0
          })

          subject.decrease_this_line
          proper_indentation = subject.instance_variable_get(:@proper)
          proper_indentation[:this_line].should == 0
        end
      end

      context "@proper[:this_line] NOT decremented < 0" do
        it "decrements @proper[:this_line] by @config[:spaces]" do
          subject.instance_variable_set(:@proper, {
            this_line: 28, next_line: 28
          })
          subject.decrease_this_line

          proper_indentation = subject.instance_variable_get(:@proper)
          proper_indentation[:this_line].should == 1
        end
      end
    end

    context "#started? is false" do
      before { subject.stub(:started?).and_return false }

      it "does not decrement @proper[:this_line]" do
        subject.instance_variable_set(:@proper, {
          this_line: 28, next_line: 28
        })
        subject.decrease_this_line

        proper_indentation = subject.instance_variable_get(:@proper)
        proper_indentation[:this_line].should == 28
      end
    end
  end

  describe "#increase_next_line" do
    context "#started? is true" do
      before { subject.stub(:started?).and_return true }

      it "increases @proper[:next_line] by @config[:spaces]" do
        expect { subject.increase_next_line }.to change{subject.next_should_be_at}.
          by(spaces)
      end
    end

    context "#started? is false" do
      before { subject.stub(:started?).and_return false }

      it "does not increases @proper[:next_line]" do
        expect { subject.increase_next_line }.to_not change{subject.next_should_be_at}.
          by(spaces)
      end
    end
  end

  describe "#decrease_next_line" do
    let!(:spaces) { 27 }

    context "#started? is true" do
      before { subject.stub(:started?).and_return true }

      it "decrements @proper[:next_line] by @config[:spaces]" do
        expect { subject.decrease_next_line }.to change{subject.next_should_be_at}.
          by(-spaces)
      end
    end

    context "#started? is false" do
      before { subject.stub(:started?).and_return false }

      it "decrements @proper[:next_line] by @config[:spaces]" do
        expect { subject.decrease_next_line }.to_not change{subject.next_should_be_at}.
          by(-spaces)
      end
    end
  end

  describe "#set_up_line_transition" do
    pending
  end

  describe "#single_line_indent_statement?" do
    context "@indent_keyword_line is nil and lineno is 1" do
      before do
        subject.instance_variable_set(:@indent_keyword_line, nil)
        subject.stub(:lineno).and_return 1
      end

      specify { subject.single_line_indent_statement?.should be_false }
    end

    context "@indent_keyword_line is 1 and lineno is 1" do
      before do
        subject.instance_variable_set(:@indent_keyword_line, 1)
        subject.stub(:lineno).and_return 1
      end

      specify { subject.single_line_indent_statement?.should be_true }
    end

    context "@indent_keyword_line is 2 and lineno is 1" do
      before do
        subject.instance_variable_set(:@indent_keyword_line, 2)
        subject.stub(:lineno).and_return 1
      end

      specify { subject.single_line_indent_statement?.should be_false }
    end

    context "@indent_keyword_line is 1 and lineno is 2" do
      before do
        subject.instance_variable_set(:@indent_keyword_line, 1)
        subject.stub(:lineno).and_return 2
      end

      specify { subject.single_line_indent_statement?.should be_false }
    end
    end
  
  describe "#transition_lines" do
    context "#started? is true" do
      before { subject.stub(:started?).and_return true }

      it "sets @proper[:this_line] to @proper[:next_line]" do
      subject.instance_variable_set(:@proper, { next_line: 33 })

      expect { subject.transition_lines }.to change{subject.should_be_at}.
        from(subject.should_be_at).to(subject.next_should_be_at)
      end
    end

    context "#started? is true" do
      before { subject.stub(:started?).and_return false }

      it "sets @proper[:this_line] to @proper[:next_line]" do
        subject.instance_variable_set(:@proper, { next_line: 33 })

        expect { subject.transition_lines }.to_not change{subject.should_be_at}.
          from(subject.should_be_at).to(subject.next_should_be_at)
      end
    end
  end

  describe "#start" do
    it "sets @started to true" do
      subject.instance_variable_set(:@started, false)
      subject.start
      subject.instance_variable_get(:@started).should be_true
    end
  end

  describe "#stop" do
    it "sets @started to false" do
      subject.instance_variable_set(:@started, true)
      subject.stop
      subject.instance_variable_get(:@started).should be_false
    end
  end

  describe "#started?" do
    context "@started is true" do
      before { subject.instance_variable_set(:@started, true) }
      specify { subject.started?.should be_true }
    end

    context "@started is false" do
      before { subject.instance_variable_set(:@started, false) }
      specify { subject.started?.should be_false }
    end
  end

  describe "#update_actual_indentation" do
    context "when indented 0" do
      let(:file_text) { "puts 'something'" }

      it "sets @actual_indentation to 0" do
        subject.update_actual_indentation(Ripper.lex(file_text))
        subject.instance_variable_get(:@actual_indentation).should be_zero
      end
    end

    context "when indented 1" do
      let(:file_text) { " puts 'something'" }

      it "returns 1" do
        subject.update_actual_indentation(Ripper.lex(file_text))
        subject.instance_variable_get(:@actual_indentation).should == 1
      end
    end

    context "when end of a multi-line string" do
      let(:lexed_output) do
        [[[2, 11], :on_tstring_end, "}"], [[2, 12], :on_nl, "\n"]]
      end

      it "returns @actual_indentation from the first line" do
        subject.instance_variable_set(:@actual_indentation, 123)
        subject.update_actual_indentation(lexed_output)
        subject.instance_variable_get(:@actual_indentation).should == 123
      end
    end
  end

  describe "#end_of_multi-line_string?" do
    context "lexed output is from the end of a multi-line % statement" do
      let(:lexed_output) do
        [[[2, 11], :on_tstring_end, "}"], [[2, 12], :on_nl, "\n"]]
      end

      it "returns true" do
        subject.end_of_multi_line_string?(lexed_output).should be_true
      end
    end

    context "lexed output is not from the end of a multi-line % statement" do
      let(:lexed_output) do
        [[[2, 11], :on_comma, ","], [[2, 12], :on_nl, "\n"]]
      end

      it "returns true" do
        subject.end_of_multi_line_string?(lexed_output).should be_false
      end
    end

    context "lexed output contains start AND end of a multi-line % statement" do
      let(:lexed_output) do
        [
          [[1, 0], :on_tstring_beg, "%Q{"],
          [[1, 3], :on_tstring_content, "this is a t string! suckaaaaaa!"],
          [[1, 32], :on_tstring_end, "}"]
        ]
      end

      it "returns true" do
        subject.end_of_multi_line_string?(lexed_output).should be_false
      end
    end
  end

  describe "#valid_line?" do
    pending
  end

  describe "#comma_update" do
    context "column is the last in the line" do
      let(:lexed_line) do
        l = double "LexedLine"
        l.stub(:line_ends_with_comma?).and_return true
        l.stub(:length).and_return 1
        l
      end
      
      it "sets @last_comma_statement_line to lineno" do
        subject.comma_update(lexed_line, 100, 1)
        subject.instance_variable_get(:@last_comma_statement_line).
          should == 100
      end
    end

    context "column is NOT the last in the line" do
      it "does not set @last_comma_statement_line to lineno" do
        subject.comma_update("text,", 100, 1)
        subject.instance_variable_get(:@last_comma_statement_line).
          should be_nil
      end
    end
  end
  
  describe "#comment_update" do
    pending
    context "token does not contain a trailing newline" do
      
    end
    
    context "token contains a trailing newline" do
      context "lexed_line is spaces then a comment" do
        
      end
      
      context "lexed_line is no spaces and a comment" do
        
      end
      
      context "lexed_line ends with an operator" do
        
      end
      
      context "lexed_line ends with a comma" do
        
      end
    end
  end

  describe "#embexpr_beg_update" do
    it "sets @embexpr_beg to true" do
      subject.instance_variable_set(:@embexpr_beg, false)
      subject.embexpr_beg_update
      subject.instance_variable_get(:@embexpr_beg).should be_true
    end
  end


  describe "#embexpr_end_update" do
    it "sets @embexpr_beg to false" do
      subject.instance_variable_set(:@embexpr_beg, true)
      subject.embexpr_end_update
      subject.instance_variable_get(:@embexpr_beg).should be_false
    end
  end

  describe "#ignored_nl_update" do
    pending
  end

  describe "#kw_update" do
    pending
  end

  describe "#lbrace_update" do
    pending
  end

  describe "#lbracket_update" do
    pending
  end

  describe "#lparen_update" do
    pending
  end

  describe "#nl_update" do
    pending
  end

  describe "#period_update" do
    pending
  end

  describe "#rbrace_update" do
    pending
  end

  describe "#rbracket_update" do
    pending
  end

  describe "#rparen_update" do
    pending
  end

  describe "#tstring_beg_update" do
    it "calls #stop" do
      subject.should_receive(:stop)
      subject.tstring_beg_update 1
    end
    
    it "adds the lineno to @tstring_nesting" do
      subject.tstring_beg_update 1
      subject.instance_variable_get(:@tstring_nesting).should == [1]
    end
  end

  describe "#tstring_end_update" do
    it "calls #start" do
      subject.should_receive(:start)
      subject.tstring_end_update
    end

    it "removes the lineno to @tstring_nesting" do
      subject.instance_variable_set(:@tstring_nesting, [1])
      subject.tstring_end_update
      subject.instance_variable_get(:@tstring_nesting).should be_empty
    end
  end

  describe "#single_line_indent_statement?" do
    pending
  end

  describe "#multi_line_braces?" do
    pending
  end

  describe "#multi_line_brackets?" do
    pending
  end

  describe "#multi_line_parens?" do
    pending
  end

  describe "#in_tstring?" do
    pending
  end

  describe "#r_event_with_content?" do
    context ":on_rparen" do
      context "line is '  )'" do
        let(:current_line) do
          l = double "LexedLine"
          l.stub(:first_non_space_element).and_return [[1, 2], :on_rparen, ")"]

          l
        end

        before do
          subject.stub(:lineno).and_return 1
          subject.stub(:column).and_return 2
        end

        it "returns true" do
          subject.r_event_without_content?(current_line).should be_true
        end
      end

      context "line is '  })'" do
        let(:current_line) do
          l = double "LexedLine"
          l.stub(:first_non_space_element).and_return [[1, 2], :on_rbrace, "}"]

          l
        end

        before do
          subject.stub(:lineno).and_return 1
          subject.stub(:column).and_return 3
        end

        it "returns false" do
          subject.r_event_without_content?(current_line).should be_false
        end
      end

      context "line is '  def some_method'" do
        let(:current_line) do
          l = double "LexedLine"
          l.stub(:first_non_space_element).and_return [[1, 0], :on_kw, "def"]

          l
        end

        before do
          subject.stub(:lineno).and_return 1
          subject.stub(:column).and_return 3
        end

        it "returns false" do
          subject.r_event_without_content?(current_line).should be_false
        end
      end
    end
  end
end