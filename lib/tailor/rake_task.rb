require 'rake'
require 'rake/tasklib'
require_relative 'critic'
require_relative 'configuration'
require_relative 'logger'
require_relative 'reporter'
require_relative 'cli/options'

begin
  # Support Rake > 0.8.7
  require 'rake/dsl_definition'
rescue LoadError
end

class Tailor

  # This class lets you define Rake tasks to drive tailor.  Specifying options
  # is similar to specifying options in a configuration file.
  #
  # @example Use Tailor CLI Options
  #   Tailor::RakeTask.new do |task|
  #     task.tailor_opts = %w(--no-color --max-line-length=100)
  #   end
  #
  # @example A task specifically for features
  #   Tailor::RakeTask.new(:tailor_features) do |task|
  #     task.file_set 'features/**/*.rb', :features do |style|
  #       style.max_line_length 100, level: :warn
  #       style.trailing_newlines 2
  #     end
  #   end
  #
  # @example Use and override a configuration file
  #   Tailor::RakeTask.new do |task|
  #     task.config_file = 'hardcore_stylin.rb'
  #     task.file_set 'lib/**/*.rb' do |style|
  #       style.indentation_spaces 2, level: :warn
  #     end
  #   end
  class RakeTask < ::Rake::TaskLib
    include ::Rake::DSL if defined? ::Rake::DSL

    # Use a specific configuration file.  If you have a .tailor file, your
    # RakeTask will automatically use that.
    #
    # @return [String] The path to the configuration file.
    attr_accessor :config_file

    # Specify any extra options (CLI options).  These will override any options
    # set in your config file.
    attr_accessor :tailor_opts

    attr_accessor :formatters

    # @param [String] name The task name.
    # @param [String] desc Description of the task.
    def initialize(name = "tailor", desc = "Check style")
      Tailor::Logger.log = false

      @name, @desc = name, desc
      @tailor_opts = []
      @file_sets = []
      @recursive_file_sets = []

      yield self if block_given?

      define_task
    end

    # Add a file set to critique, just like you would in a config file.
    #
    # @param [String] file_expression
    # @param [Symbol] label
    def file_set(file_expression, label=:default, &block)
      @file_sets << [file_expression, label, block]
    end

    # Add a recursive file set to critique, just like you would in a config
    # file.
    #
    # @param [String] file_expression
    # @param [Symbol] label
    def recursive_file_set(file_expression, label=:default, &block)
      @recursive_file_sets << [file_expression, label, block]
    end

    private

    def define_task
      desc @desc
      task @name do
        if config_file
          @tailor_opts.concat %W(--config-file=#{config_file})
        end

        configuration = create_config
        @reporter = Tailor::Reporter.new(configuration.formatters)

        create_file_sets_for configuration
        create_recursive_file_sets_for configuration
        check_default_file_set_in configuration

        critic = Tailor::Critic.new

        critic.critique(configuration.file_sets) do |problems_for_file, label|
          @reporter.file_report(problems_for_file, label)
        end

        @reporter.summary_report(critic.problems)

        critic.problem_count > 0
      end
    end

    # @return [Tailor::Configuration]
    def create_config
      configuration = Tailor::Configuration.new([],
        Tailor::CLI::Options.parse!(@tailor_opts))
      configuration.load!
      configuration.formatters(formatters) if formatters

      configuration
    end

    # @param [Tailor::Configuration] config
    def create_recursive_file_sets_for config
      unless @recursive_file_sets.empty?
        @recursive_file_sets.each do |fs|
          config.recursive_file_set(fs[0], fs[1], &fs[2])
        end
      end
    end

    # @param [Tailor::Configuration] config
    def create_file_sets_for config
      unless @file_sets.empty?
        @file_sets.each { |fs| config.file_set(fs[0], fs[1], &fs[2]) }
      end
    end

    # @param [Tailor::Configuration] config
    def check_default_file_set_in config
      if @file_sets.none? { |fs| fs[1] == :default }
        config.file_sets.delete(:default)
      end
    end
  end
end
