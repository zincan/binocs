# frozen_string_literal: true

require 'curses'
require 'rbconfig'
require_relative 'swagger/client'
require_relative 'swagger/path_matcher'
require_relative 'tui/colors'
require_relative 'tui/window'
require_relative 'tui/request_list'
require_relative 'tui/request_detail'
require_relative 'tui/help_screen'
require_relative 'tui/filter_menu'
require_relative 'tui/app'

module Binocs
  module TUI
  end
end
