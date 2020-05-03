# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'rugged'
require 'set'

module RuboCop
  module Diff
    # A class to execute the program when launched via the command line
    class CLI
      DEFAULT_OPTIONS = {
        base: 'master',
        merge_base: nil,
        repo: Pathname.new('.'),
        tip: 'HEAD'
      }.freeze

      def initialize(**options)
        parse_args(**options)
        @repo = Rugged::Repository.discover(@options[:repo])
      end

      def run
        print_offenses
      end

      private

      def print_offenses
        success = true
        changes = lines_changed_per_file
        runner = create_runner
        formatter = create_formatter

        formatter.started(changes.keys)

        changes.each do |path, lines|
          path = path.to_s
          offenses = runner.file_offenses(path)
          offenses = offenses.filter { |offense| lines.include? offense.location.line }
          formatter.file_finished(path, offenses)
          success = false unless offenses.empty?
        end

        formatter.finished(changes.keys)

        success
      end

      def lines_changed_per_file
        git_diff.patches.map do |patch|
          path = patch.delta.new_file[:path]
          next unless path.end_with? '.rb' # TODO: will skip ruby files that don't end in `.rb`

          lines = patch.hunks.map do |hunk|
            hunk.lines.filter(&:addition?).map(&:new_lineno)
          end.flatten

          next if lines.empty?

          [workdir / path, Set.new(lines)]
        end.compact.to_h
      end

      def git_diff
        base_commit.diff(tip_commit).find_similar!
      end

      def base_commit
        base_ref = if @options[:merge_base]
                     base = @repo.rev_parse(@options[:merge_base])
                     @repo.merge_base(base, tip_commit)
                   else
                     @options[:base]
                   end

        @repo.rev_parse(base_ref)
      end

      def tip_commit
        @repo.rev_parse(@options[:tip])
      end

      def create_runner
        require 'rubocop'

        config_store = RuboCop::ConfigStore.new
        config_store.options_config = workdir / '.rubocop.yml'
        runner = RuboCop::Runner.new({}, config_store)

        class << runner
          public :file_offenses
        end

        runner
      end

      def create_formatter
        require 'rubocop'

        RuboCop::Formatter::ProgressFormatter.new($stdout)
      end

      def workdir
        Pathname.new(@repo.workdir)
      end

      def parse_args(**options)
        @options = DEFAULT_OPTIONS.merge(options)

        OptionParser.new do |opts|
          opts.on('-bBASE', '--base=BASE') do |base|
            @options[:base] = base
          end

          opts.on('-mMERGE_BASE', '--merge-base=MERGE_BASE') do |merge_base|
            @options[:merge_base] = merge_base
          end

          opts.on('-rREPOSITORY', '--repository=REPOSITORY') do |repo|
            @options[:repo] = Pathname.new(repo)
          end

          opts.on('-tTIP', '--tip=TIP') do |tip|
            @options[:tip] = tip
          end
        end.parse!
      end
    end
  end
end
