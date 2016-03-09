require "w_g/version"
require "w_g/method_decorator"
require "benchmark"

class WG

  include MethodDecorator

  #################
  # Configuration #
  #################

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
  #     Helpers    #
  ##################

  # Wraps a method with measure
  def self.measure_decorator(klass, method_name, options, tag, method_binding, method_args, method_block)
    measure(tag, *method_args) { default_decorator(klass, method_name, options, tag, method_binding, method_args, method_block) }
  end

  # Wraps a controller action with measure
  def self.filter(controller)
    return yield unless @measure_enabled
    tag = "#{controller.class.name}.#{controller.action_name}"

    start_time = (Time.current.to_f * 1000.0).to_i
    measure(tag) { yield }
    end_time = (Time.current.to_f * 1000.0).to_i

    # For debugging only
    # ap "***** watchful guerilla filter start  :: #{tag} -> #{start_time}"
    # ap "***** watchful guerilla filter end    :: #{tag} -> #{end_time}"
    # ap "***** watchful guerilla filter total  :: #{tag} -> #{fmt((end_time - start_time)/1000)}"
  end


  ##################
  # Initialization #
  ##################

  @decorators = []
  tracing
  profiling
  measuring
  reporting_threshold


  #############
  # Measuring #
  #############

  # Times a block and nested blocks
  # Prints results to log when top level block
  def self.measure(category = '*unspecified*', *identifiers)
    return yield unless @measure_enabled

    start_time = Time.current
    old_top = @top
    current = new(@top, start_time, category, identifiers)
    begin
      ap "--******--#{current.identifier}" if @trace_enabled
      @top = current
      if @root
        old_top.children << current
      else
        @measure_exception = nil
        @root = current
      end
      begin
        current.block_start_time = Time.current
        result = yield
      ensure
        current.block_end_time = Time.current
      end
      #skip on exception
      print_measured_results(current) if @root == current
    ensure
      @root = nil if @root == current
      @top = old_top
      current.end_time = Time.current
    end
    result
  end

  # Disables/Enables all nested measure blocks
  def self.measure_block state = true
    old_state = @measure_enabled
    toggle_measuring state
    result = yield
    toggle_measuring old_state
    result
  end

  # Sends measuring data to log
  # Traverses tree from root
  def self.print_measured_results(root)
    output = {}
    root.end_time = Time.current
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

      @category_times.sort_by{|k,v| v[0]}.reverse.each do |category, (s_time, o_time, count, errored)|
        if errored
          print_label output[:errors], category, s_time, o_time, count
        else
          print_label output[:blocks], category, s_time, o_time, count
        end
        increment_summary_category('', s_time, o_time, count)
        super_category = /(.*)(\.|\#)/.match(category.to_s).try(:[],1)
        increment_summary_category(super_category, s_time, o_time, count) if super_category
      end

      @super_category_times.sort_by{|k,v| v[0]}.reverse.each do |super_category, (s_time, o_time, count)|
        print_label(output[:totals], super_category, s_time, o_time, count) unless super_category.blank?
      end

      @long_calls.sort_by{|v| v[1]}.reverse.each do |(category, s_time)|
        output[:long_blocks] << "---- #{fmt(s_time)} >> #{category}"
      end
    }
    s_time, o_time, count = @super_category_times['']
    t_time = s_time + o_time + print_time
    print_label(output[:grand_totals], fmt(t_time), s_time, o_time + print_time, count)

    ap ""
    ap "WG Measuring Report"
    ap ""
    ap "-- Call Count -- Block Time (ms) -- Overhead Time (ms) -- Category"
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
    ap "ERROR BLOCKS (uncaught exceptions prevented complete measuring)"
    output[:errors].each { |s| ap s }
    ap ""
    ap "LONG BLOCKS"
    output[:long_blocks].each { |s| ap s }
  end

  def self.print_label(output, label, s_time, o_time, count = nil)
    output << "-- #{count.to_s.rjust(10,' ')} -- #{fmt(s_time,15)} -- #{fmt(o_time)} -- #{label}"
  end

  # Agregates measured blocks categories by supercategories
  def self.increment_summary_category(category, s_time, o_time, count = 1)
    category_time = (@super_category_times[category] ||= [0,0,0])
    category_time[0] += s_time
    category_time[1] += o_time
    category_time[2] += count
  end

  # Extracts and agregates measured blocks by category
  def self.increment_category_time(node)
    category_time = (@category_times[node.category] ||= [0,0,0,false])
    category_time[0] += node.self_time
    category_time[1] += node.overhead_time
    category_time[2] += 1
    category_time[3] ||= node.errored?

    @long_calls << [node.identifier, node.self_time] if node.self_time > @reporting_threshold
  end

  def self.fmt(value, length = 18)
    format("%.3f", value*1000).rjust(length,' ')
  end


  #############
  # Instances #
  #############

  attr_accessor :start_time,
    :block_start_time,
    :block_end_time,
    :end_time,
    :category,
    :identifiers,
    :children
  # :parent # for debugging only

  def initialize(parent, start_time, category, identifiers = [])
    #self.parent = parent
    self.start_time = start_time
    self.category = category
    self.identifiers = [] #identifiers
    self.children = []
  end

  def child_time
    @child_time ||= children.map(&:sumarize).sum
  end

  def block_time
    @block_time ||= block_end_time && block_start_time ?
      block_end_time - block_start_time :
      child_time
  end

  def total_time
    @total_time ||= end_time && start_time ?
      end_time - start_time :
      block_time
  end

  def self_time
    @self_time ||= block_time - child_time
  end

  def overhead_time
    @overhead_time ||= total_time - block_time
  end

  def errored?
    !(end_time && start_time)
  end

  def sumarize
    increment_category_time
    total_time
  end

  def increment_category_time
    self.class.increment_category_time self
  end

  def identifier
    @identifier ||= ([category] + identifiers).join(', ')
  end

  def fmt(value, length = 18)
    self.class.fmt(value, length)
  end

  # For debugging only

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
end
