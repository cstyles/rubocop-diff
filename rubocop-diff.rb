#!/usr/bin/env ruby
# frozen_string_literal: true

@options = {
  base: 'master',
  repo: Pathname.new('.'),
  tip: 'HEAD'
}

def parse_args
  require 'optparse'

  OptionParser.new do |opts|
    opts.on('-bBASE', '--base=BASE') do |base|
      @options[:base] = base
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

  repo = Rugged::Repository.new(@options[:repo])
  base_commit = repo.rev_parse(@options[:base])
  tip_commit = repo.rev_parse(@options[:tip])

  diff = base_commit.diff(tip_commit)

  # Detect renamed files
  diff.find_similar!
end

def get_changes(diff)
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
  runner, formatter = setup_rubocop

  formatter.started(changes.keys)

  changes.each do |path, lines|
    path = path.to_s
    offenses = runner.file_offenses(path)
    offenses = offenses.filter { |offense| lines.include? offense.location.line }
    formatter.file_finished(path, offenses)
  end

  formatter.finished(changes.keys)
end

def main
  parse_args
  diff = git_diff
  changes = get_changes(diff)
  print_offenses(changes)
end

main
