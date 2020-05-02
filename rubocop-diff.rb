#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'

@options = {
  base: 'master',
  merge_base: nil,
  repo: Pathname.new('.'),
  tip: 'HEAD'
}

def parse_args
  require 'optparse'

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

def git_diff
  require 'rugged'

  repo = Rugged::Repository.discover(@options[:repo])
  @options[:repo] = Pathname.new(repo.workdir)

  tip_commit = repo.rev_parse(@options[:tip])

  base_ref = if @options[:merge_base]
               base = repo.rev_parse(@options[:merge_base])
               repo.merge_base(base, tip_commit)
             else
               @options[:base]
             end

  base_commit = repo.rev_parse(base_ref)

  diff = base_commit.diff(tip_commit)

  # Detect renamed files
  diff.find_similar!
end

def lines_changed_by_file(diff)
  require 'set'

  diff.patches.map do |patch|
    path = patch.delta.new_file[:path]
    next unless path.end_with? '.rb'

    lines = patch.hunks.map do |hunk|
      hunk.lines.filter(&:addition?).map(&:new_lineno)
    end.flatten

    next if lines.empty?

    [@options[:repo] / path, Set.new(lines)]
  end.compact.to_h
end

def setup_rubocop
  require 'rubocop'

  config_store = RuboCop::ConfigStore.new
  config_store.options_config = @options[:repo] / '.rubocop.yml'
  runner = RuboCop::Runner.new({}, config_store)
  class << runner
    public :file_offenses
  end

  formatter = RuboCop::Formatter::ProgressFormatter.new($stdout)

  [runner, formatter]
end

def print_offenses(changes)
  exit_code = 0
  runner, formatter = setup_rubocop

  formatter.started(changes.keys)

  changes.each do |path, lines|
    path = path.to_s
    offenses = runner.file_offenses(path)
    offenses = offenses.filter { |offense| lines.include? offense.location.line }
    formatter.file_finished(path, offenses)
    exit_code = 1 unless offenses.empty?
  end

  formatter.finished(changes.keys)

  exit_code
end

def main
  parse_args
  exit print_offenses(lines_changed_by_file(git_diff))
end

main
