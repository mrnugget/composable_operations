require 'spec_helper'

describe "An operation with two before and two after filters =>" do

  let(:test_operation) do
    Class.new(ComposableOperations::Operation) do

      processes :flow_control

      attr_accessor :trace

      def initialize(input = [], options = {})
        super
        self.trace = [:initialize]
      end

      before do
        trace << :outer_before
        fail "Fail in outer before" if flow_control.include?(:fail_in_outer_before)
        halt "Halt in outer before" if flow_control.include?(:halt_in_outer_before)
      end

      before do
        trace << :inner_before
        fail "Fail in inner before" if flow_control.include?(:fail_in_inner_before)
        halt "Halt in inner before" if flow_control.include?(:halt_in_inner_before)
      end

      after do
        trace << :inner_after
        fail "Fail in inner after" if flow_control.include?(:fail_in_inner_after)
        halt "Halt in inner after" if flow_control.include?(:halt_in_inner_after)
      end

      after do
        trace << :outer_after
        fail "Fail in outer after" if flow_control.include?(:fail_in_outer_after)
        halt "Halt in outer after" if flow_control.include?(:halt_in_outer_after)
      end

      def execute
        trace << :execute_start
        fail "Fail in execute" if flow_control.include?(:fail_in_execute)
        halt "Halt in execute" if flow_control.include?(:halt_in_execute)
        trace << :execute_stop
        :final_result
      end
    end
  end

  context "when run and everything works as expected =>" do
    subject       { test_operation.new }
    before(:each) { subject.perform }

    it ("should run 'initialize' first")                    { subject.trace[0].should eq(:initialize)    }
    it ("should run 'outer before' after 'initialize'")     { subject.trace[1].should eq(:outer_before)  }
    it ("should run 'inner before' after 'outer before'")   { subject.trace[2].should eq(:inner_before)  }
    it ("should start 'execute' after 'inner before'")      { subject.trace[3].should eq(:execute_start) }
    it ("should stop 'execute' after it started 'execute'") { subject.trace[4].should eq(:execute_stop)  }
    it ("should run 'inner after' after 'execute'")         { subject.trace[5].should eq(:inner_after)   }
    it ("should run 'outer after' after 'inner after'")     { subject.trace[6].should eq(:outer_after)   }
    it ("should return :final_result as result")            { subject.result.should eq(:final_result) }
    it { should     be_succeeded }
    it { should_not be_failed    }
    it { should_not be_halted    }
  end


  # Now: TEST ALL! the possible code flows systematically

  test_vectors = [
    {
      :context => "no complications =>",
      :input   => [],
      :output  => :final_result,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :execute_stop, :inner_after, :outer_after],
      :state   => :succeeded
    }, {
      :context => "failing in outer_before filter =>",
      :input   => [:fail_in_outer_before],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_after, :outer_after],
      :state   => :failed
    }, {
      :context => "failing in inner_before filter =>",
      :input   => [:fail_in_inner_before],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :inner_after, :outer_after],
      :state   => :failed
    }, {
      :context => "failing in execute =>",
      :input   => [:fail_in_execute],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :inner_after, :outer_after],
      :state   => :failed
    }, {
      :context => "failing in inner_after filter =>",
      :input   => [:fail_in_inner_after],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :execute_stop, :inner_after, :outer_after],
      :state   => :failed
    }, {
      :context => "failing in outer_after filter =>",
      :input   => [:fail_in_outer_after],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :execute_stop, :inner_after, :outer_after],
      :state   => :failed
    }, {
      :context => "halting in outer_before filter =>",
      :input   => [:halt_in_outer_before],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_after, :outer_after],
      :state   => :halted
    }, {
      :context => "halting in inner_before filter =>",
      :input   => [:halt_in_inner_before],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :inner_after, :outer_after],
      :state   => :halted
    }, {
      :context => "halting in execute =>",
      :input   => [:halt_in_execute],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :inner_after, :outer_after],
      :state   => :halted
    }, {
      :context => "halting in inner_after filter =>",
      :input   => [:halt_in_inner_after],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :execute_stop, :inner_after, :outer_after],
      :state   => :halted
    }, {
      :context => "halting in outer_after filter =>",
      :input   => [:halt_in_outer_after],
      :output  => nil,
      :trace   => [:initialize, :outer_before, :inner_before, :execute_start, :execute_stop, :inner_after, :outer_after],
      :state   => :halted
    }
  ]

  context "when initialized with input that leads to =>" do
    subject { test_operation.new(input) }
    before(:each) { subject.perform }

    test_vectors.each do |tv|
      context tv[:context] do
        let(:input) { tv[:input] }
        let(:trace) { subject.trace }

        it("then its trace should be #{tv[:trace].inspect}") { subject.trace.should eq(tv[:trace]) }
        it("then its result should be #{tv[:output].inspect}") { subject.result.should eq(tv[:output]) }
        it("then its succeeded? method should return #{(tv[:state] == :succeeded).inspect}") { subject.succeeded?.should eq(tv[:state] == :succeeded) }
        it("then its failed? method should return #{(tv[:state] == :failed).inspect}") { subject.failed?.should    eq(tv[:state] == :failed)    }
        it("then its halted? method should return #{(tv[:state] == :halted).inspect}") { subject.halted?.should    eq(tv[:state] == :halted)    }
      end
    end
  end

  context "when halt and fail are used together" do
    subject { test_operation.new([:halt_in_execute, :fail_in_inner_after]) }
    it "should raise on calling operation.perform" do
      expect { subject.perform }.to raise_error
    end
  end

  context "when fail and halt are used together" do
    subject { test_operation.new([:fail_in_execute, :halt_in_inner_after]) }
    it "should raise on calling operation.perform" do
      expect { subject.perform }.to raise_error
    end
  end

  context "when halt is used twice" do
    subject { test_operation.new([:halt_in_execute, :halt_in_inner_after]) }
    it "should raise on calling operation.perform" do
      expect { subject.perform }.to raise_error
    end
  end

  context "when fail is used twice" do
    subject { test_operation.new([:fail_in_execute, :fail_in_inner_after]) }
    it "should raise on calling operation.perform" do
      expect { subject.perform }.to raise_error
    end
  end

end
