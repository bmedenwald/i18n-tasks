# coding: utf-8
require 'ostruct'
require 'set'
module I18n::Tasks
  class CommandsBase
    include ::I18n::Tasks::Logging

    def initialize(i18n = nil)
      @i18n = i18n
    end

    def locales_opt(locales)
      return i18n.locales if locales == ['all'] || locales == 'all'
      if locales.present?
        locales = Array(locales).map { |v| v.strip.split(/\s*[\+,:]\s*/).compact.presence if v.is_a?(String) }.flatten
        locales = locales.map(&:presence).compact.map { |v| v == 'base' ? base_locale : v }
        locales
      else
        i18n.locales
      end
    end

    VALID_LOCALE_RE = /\A\w[\w\-_\.]*\z/i
    def parse_locales!(opt)
      opt[:locales] = locales_opt(opt[:arguments].presence || opt[:locales]).tap do |locales|
        locales.each do |locale|
          raise CommandError.new("Invalid locale: #{locale}") if VALID_LOCALE_RE !~ locale
        end
        log_verbose "locales for the command are #{locales.inspect}"
      end
    end


    VALID_TREE_FORMATS = %w(terminal-table yaml json keys inspect)

    def print_locale_tree(tree, opt, version = :show_tree)
      format = opt[:format] || VALID_TREE_FORMATS.first
      raise CommandError.new("unknown format: #{format}. Valid formats are: #{VALID_TREE_FORMATS * ', '}.") unless VALID_TREE_FORMATS.include?(format)
      case format
        when 'terminal-table'
          terminal_report.send(version, tree)
        when 'inspect'
          puts tree.inspect
        when 'keys'
          puts tree.key_names(root: true)
        when *i18n.data.adapter_names.map(&:to_s)
          puts i18n.data.adapter_dump tree, i18n.data.adapter_by_name(format)
      end
    end

    protected

    def terminal_report
      @terminal_report ||= I18n::Tasks::Reports::Terminal.new(i18n)
    end

    def spreadsheet_report
      @spreadsheet_report ||= I18n::Tasks::Reports::Spreadsheet.new(i18n)
    end

    class << self
      def cmds
        @cmds ||= {}.with_indifferent_access
      end

      def cmd(name, &block)
        cmds[name] = OpenStruct.new(@next_def)
        @next_def  = {}
        define_method name do |*args|
          begin
            coloring_was             = Term::ANSIColor.coloring?
            Term::ANSIColor.coloring = ENV['I18N_TASKS_COLOR'] || STDOUT.isatty
            instance_exec *args, &block
          rescue CommandError => e
            log_error e.message
            exit 78
          ensure
            Term::ANSIColor.coloring = coloring_was
          end
        end
      end

      def desc(text)
        next_def[:desc] = text
      end

      def opts(&block)
        next_def[:opts] = block
      end

      private
      def next_def
        @next_def ||= {}
      end
    end

    def desc(name)
      self.class.cmds.try(:[], name).try(:desc)
    end

    def i18n
      @i18n ||= I18n::Tasks::BaseTask.new
    end

    delegate :base_locale, :t, to: :i18n
  end
end
