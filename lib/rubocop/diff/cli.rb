# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'rugged'
require 'set'

require_relative './args'

module RuboCop
  module Diff
    # A class to execute the program when launched via the command line
    class CLI
      def initialize(**options)
        @options = Args.parse(**options)
      end

      def run
        setup_git
        print_offenses
      end

      private

      def setup_git
        @repo = Rugged::Repository.discover(@options[:repo])
        @workdir = Pathname.new(@repo.workdir)
        @tip_commit = @repo.rev_parse(@options[:tip])

        base_ref = if @options[:merge_base]
                     base = @repo.rev_parse(@options[:merge_base])
                     @repo.merge_base(base, @tip_commit)
                   else
                     @options[:base]
                   end

        @base_commit = @repo.rev_parse(base_ref)
      end

      def print_offenses
        success = true
        changes = filter_changes(lines_changed_per_file)
        formatter.started(changes.keys)

        changes.each do |path, lines|
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

          lines = patch.hunks.map do |hunk|
            hunk.lines.filter(&:addition?).map(&:new_lineno)
          end.flatten

          next if lines.empty?

          [(@workdir / path).to_s, Set.new(lines)]
        end.compact.to_h
      end

      def git_diff
        @base_commit.diff(@tip_commit).find_similar!
      end

      # Filters changed files down to files that should actually be linted.
      # This will remove non-Ruby files and ensure we respect RuboCop's
      # `Include` and `Exclude` options.
      def filter_changes(changes)
        included_files = target_finder.find changes.keys, :only_recognized_file_types
        changes.filter { |path, _lines| included_files.include? path }
      end

      def runner
        @runner ||=
          begin
            require 'rubocop'
            runner = RuboCop::Runner.new({}, config_store)

            class << runner
              public :file_offenses
            end

            runner
          end
      end

      def formatter
        require 'rubocop'

        @formatter ||= RuboCop::Formatter::ProgressFormatter.new($stdout)
      end

      def target_finder
        require 'rubocop'

        RuboCop::TargetFinder.new(config_store, { force_exclusion: true })
      end

      def config_store
        @config_store ||=
          begin
            config_store = RuboCop::ConfigStore.new
            config_file_name = @workdir / '.rubocop.yml'
            config_store.options_config = config_file_name.to_s

            config_store
          end
      end
    end
  end
end
