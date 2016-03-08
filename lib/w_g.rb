require "w_g/version"
require "benchmark"

class WG

  #################
  # Configuration #
  #################

  def self.configure
    yield(self)
    ActiveRecord::Base.register_filters
  end


  def self.tracing(state = false)
    @trace_enabled = !!state
  end

  def self.profiling(state = false)
    @profile_enabled = !!state
  end

  def self.measuring(state = false)
    @measure_enabled = !!state
  end

  def self.reporting_threshold(milliseconds = 20)
    @reporting_threshold = milliseconds / 1000.0
  end


  ##################
  # Initialization #
  ##################


  #set everything to defaults
  tracing
  profiling
  measuring
  reporting_threshold


  #############
  # Profiling #
  #############

  def self.profile(printer = :graph, profile_name = 'profile', profile_options = {})
    return yield unless @profile_enabled
    profile = nil
    result = nil
    begin
      @profile_active = true
      RubyProf.start
      result = yield
    ensure
      profile = RubyProf.stop
      @profile_active = false
    end

    case printer
    when :graph
        RubyProf::GraphPrinter.new(profile).print(
          File.open("#{Rails.root}/tmp/#{profile_name}-graph.html", 'w+'),
          {print_file:true, min_percent: 1}.merge(profile_options)
        )
    when :flat
        RubyProf::FlatPrinter.new(profile).print(
          File.open("#{Rails.root}/tmp/#{profile_name}-flat.html", 'w+')
        )
    end

    result
  end

  def self.pause
    RubyProf.pause if @profile_enabled && @profile_active
  end

  def self.resume
    RubyProf.resume if @profile_enabled && @profile_active
  end

  #############
  # Measuring #
  #############

  def self.print_measured_results(root)
    output = {}
    print_time = Benchmark.realtime {
      output.merge!({
        errors: [],
        blocks: [],
        totals: [],
        grand_totals: [],
        long_blocks: []
      })
      @super_category_times = {}
      @category_times = {}
      @long_calls = []
      root.sumarize

      @category_times.sort_by{|k,v| v[0]}.reverse.each do |category, (s_time, o_time, errored)|
        if errored
          print_label output[:errors], category, s_time, o_time
        else
          print_label output[:blocks], category, s_time, o_time
        end
        increment_summary_category('', s_time, o_time)
        super_category = /\((.*)\)\:/.match(category.to_s).try(:[],1)
        increment_summary_category(super_category, s_time, o_time) if super_category
      end

      @super_category_times.sort_by{|k,v| v[0]}.reverse.each do |super_category, (s_time, o_time)|
        print_label(output[:totals], super_category, s_time, o_time) unless super_category.blank?
      end

      @long_calls.sort_by{|v| v[1]}.reverse.each do |(category, s_time)|
        output[:long_blocks] << "---- #{fmt(s_time)} >> #{category}"
      end
    }
    s_time, o_time = @super_category_times['']
    t_time = s_time + o_time + print_time
    print_label(output[:grand_totals], fmt(t_time), s_time, o_time + print_time)

    ap ""
    ap "WG Measuring Report"
    ap ""
    ap "----    Block Time (ms) -- Overhead Time (ms) -- Category"
    ap ""
    ap "GRAND TOTALS"
    output[:grand_totals].each { |s| ap s }
    ap ""
    ap "CATEGORY TOTALS"
    output[:totals].each { |s| ap s }
    ap ""
    ap "BLOCKS"
    output[:blocks].each { |s| ap s }
    ap ""
    ap "ERROR BLOCKS"
    ap "(uncaught exceptions prevented inspection)"
    output[:errors].each { |s| ap s }
    ap ""
    ap "LONG BLOCKS"
    output[:long_blocks].each { |s| ap s }
  end

  def self.print_label(output, label, s_time, o_time)
    output << "---- #{fmt(s_time)} -- #{fmt(o_time)} -- #{label}"
  end

  def self.increment_summary_category(category, s_time, o_time)
    category_time = (@super_category_times[category] ||= [0,0])
    category_time[0] += s_time
    category_time[1] += o_time
  end

  def self.increment_category_time(node)
    category_time = (@category_times[node.category] ||= [0,0,false])
    category_time[0] += node.self_time
    category_time[1] += node.overhead_time - node.total_time
    category_time[2] ||= !node.complete

    @long_calls << [node.identifier, node.self_time] if node.self_time > @reporting_threshold
  end

  def self.measure_block state = true
    old_state = @measure_enabled
    toggle_measuring state
    result = yield
    toggle_measuring old_state
    result
  end

  def self.measure(category = '*unspecified*', *identifiers)
    return yield unless @measure_enabled
    result = nil
    current = nil
    overhead_time = Benchmark.realtime {
      ap "--******--#{category}:: #{identifiers}" if @trace_enabled
      old_top = @top
      current = @top = new(@top, category, identifiers)
      begin
        if @root
          old_top.children << current
        else
          @measure_exception = nil
          @root = current
        end
        current.total_time = Benchmark.realtime { result = yield }
      ensure
        @root = nil if @root == current
        @top = old_top
      end
    }
    current.overhead_time = overhead_time
    current.complete = true

    print_measured_results(current) unless @root
    result
  end

  def self.fmt(value)
    format("%.3f", value*1000).rjust(18,' ')
  end

  def fmt(value)
    format("%.3f", value*1000).rjust(18,' ')
  end


  attr_accessor :complete, :total_time, :child_time, :self_time, :overhead_time, :children, :category, :identifiers
  # for debugging
  # attr_accessor :parent

  def initialize(parent, category, identifiers = [])
    #self.parent = parent
    self.identifiers = identifiers
    self.category = category
    self.children = []
    self.overhead_time = 0
    self.total_time = 0
    self.child_time = 0
    self.self_time = 0
    self.complete = false
  end

  # for debugging

  # def trace
  #   trace_root
  #   trace_children
  # end

  # def trace_children(level = 0)
  #   ap [level, overhead_time * 1000, total_time * 1000, self_time * 1000, child_time * 1000]
  #   children.each { |c|
  #     c.trace_children(level + 1)
  #   }
  #   nil
  # end

  # def trace_root
  #   if parent
  #     level = parent.trace_root + 1
  #     ap [level, overhead_time * 1000, total_time * 1000]
  #     level
  #   else
  #     ap [0, overhead_time * 1000, total_time * 1000]
  #     0
  #   end
  # end

  def sumarize
    self.child_time = children.map(&:sumarize).sum
    self.overhead_time = self.total_time = child_time unless complete
    self.self_time = total_time - child_time
    increment_category_time
    overhead_time
  end

  def increment_category_time
    self.class.increment_category_time self
  end

  def identifier
    @identifier ||= ([category] + identifiers).join(', ')
  end

  def self.filter(controller)
    return yield unless @measure_enabled
    tag = "#{controller.class.name}.#{controller.action_name}"

    start_time = (Time.current.to_f * 1000.0).to_i
    measure("(controller): #{tag}") { yield }
    end_time = (Time.current.to_f * 1000.0).to_i

    ap "***** watchful guerilla filter start  :: #{tag} -> #{start_time}"
    ap "***** watchful guerilla filter end    :: #{tag} -> #{end_time}"
    ap "***** watchful guerilla filter total  :: #{tag} -> #{fmt((end_time - start_time)/1000)}"
  end

end
