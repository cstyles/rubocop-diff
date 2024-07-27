# frozen_string_literal: true

module RuboCop
  module Diff
    # A class to handle command line arguments
    class Args
      DEFAULT_OPTIONS = {
        base: 'main',
        merge_base: nil,
        repo: Pathname.new('.'),
        tip: 'HEAD'
      }.freeze

      def self.parse(**options)
        options = DEFAULT_OPTIONS.merge(options)

        OptionParser.new do |opts|
          opts.on('-bBASE', '--base=BASE') do |base|
            options[:base] = base
          end

          opts.on('-mMERGE_BASE', '--merge-base=MERGE_BASE') do |merge_base|
            options[:merge_base] = merge_base
          end

          opts.on('-rREPOSITORY', '--repository=REPOSITORY') do |repo|
            options[:repo] = Pathname.new(repo)
          end

          opts.on('-tTIP', '--tip=TIP') do |tip|
            options[:tip] = tip
          end
        end.parse!

        options
      end
    end
  end
end
