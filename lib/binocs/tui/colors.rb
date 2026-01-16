# frozen_string_literal: true

module Binocs
  module TUI
    module Colors
      # Color pair constants
      NORMAL = 1
      HEADER = 2
      SELECTED = 3
      METHOD_GET = 4
      METHOD_POST = 5
      METHOD_PUT = 6
      METHOD_DELETE = 7
      STATUS_SUCCESS = 8
      STATUS_REDIRECT = 9
      STATUS_CLIENT_ERROR = 10
      STATUS_SERVER_ERROR = 11
      MUTED = 12
      ERROR = 13
      BORDER = 14
      TITLE = 15
      KEY_HINT = 16
      SEARCH = 17

      # Pill-style colors (with backgrounds)
      METHOD_GET_PILL = 18
      METHOD_POST_PILL = 19
      METHOD_PUT_PILL = 20
      METHOD_DELETE_PILL = 21
      STATUS_SUCCESS_PILL = 22
      STATUS_REDIRECT_PILL = 23
      STATUS_CLIENT_ERROR_PILL = 24
      STATUS_SERVER_ERROR_PILL = 25

      def self.init
        # Note: Curses.start_color and use_default_colors are called in App#setup_curses
        # Define color pairs (foreground, background)
        # -1 means default/transparent background
        # Colors adjusted for terminal compatibility (BLUE shows as teal in some themes)
        Curses.init_pair(NORMAL, Curses::COLOR_WHITE, -1)
        Curses.init_pair(HEADER, Curses::COLOR_YELLOW, -1)
        Curses.init_pair(SELECTED, Curses::COLOR_BLACK, Curses::COLOR_WHITE)
        Curses.init_pair(METHOD_GET, Curses::COLOR_BLUE, -1)     # teal in your theme
        Curses.init_pair(METHOD_POST, Curses::COLOR_YELLOW, -1)
        Curses.init_pair(METHOD_PUT, Curses::COLOR_MAGENTA, -1)
        Curses.init_pair(METHOD_DELETE, Curses::COLOR_RED, -1)
        Curses.init_pair(STATUS_SUCCESS, Curses::COLOR_BLUE, -1) # teal = success
        Curses.init_pair(STATUS_REDIRECT, Curses::COLOR_YELLOW, -1)
        Curses.init_pair(STATUS_CLIENT_ERROR, Curses::COLOR_MAGENTA, -1)
        Curses.init_pair(STATUS_SERVER_ERROR, Curses::COLOR_RED, -1)
        Curses.init_pair(MUTED, Curses::COLOR_WHITE, -1) # Will use dim attribute
        Curses.init_pair(ERROR, Curses::COLOR_RED, -1)
        Curses.init_pair(BORDER, Curses::COLOR_BLUE, -1)
        Curses.init_pair(TITLE, Curses::COLOR_YELLOW, -1)
        Curses.init_pair(KEY_HINT, Curses::COLOR_YELLOW, -1)
        Curses.init_pair(SEARCH, Curses::COLOR_BLACK, Curses::COLOR_YELLOW)

        # Pill-style pairs (text on colored background)
        # Using colors with best terminal compatibility
        Curses.init_pair(METHOD_GET_PILL, Curses::COLOR_WHITE, Curses::COLOR_BLUE)
        Curses.init_pair(METHOD_POST_PILL, Curses::COLOR_BLACK, Curses::COLOR_YELLOW)
        Curses.init_pair(METHOD_PUT_PILL, Curses::COLOR_WHITE, Curses::COLOR_MAGENTA)
        Curses.init_pair(METHOD_DELETE_PILL, Curses::COLOR_WHITE, Curses::COLOR_RED)
        Curses.init_pair(STATUS_SUCCESS_PILL, Curses::COLOR_WHITE, Curses::COLOR_BLUE)
        Curses.init_pair(STATUS_REDIRECT_PILL, Curses::COLOR_BLACK, Curses::COLOR_YELLOW)
        Curses.init_pair(STATUS_CLIENT_ERROR_PILL, Curses::COLOR_WHITE, Curses::COLOR_MAGENTA)
        Curses.init_pair(STATUS_SERVER_ERROR_PILL, Curses::COLOR_WHITE, Curses::COLOR_RED)
      end

      def self.method_color(method)
        case method.to_s.upcase
        when 'GET' then METHOD_GET
        when 'POST' then METHOD_POST
        when 'PUT', 'PATCH' then METHOD_PUT
        when 'DELETE' then METHOD_DELETE
        else NORMAL
        end
      end

      def self.status_color(status)
        return MUTED if status.nil?

        case status
        when 200..299 then STATUS_SUCCESS
        when 300..399 then STATUS_REDIRECT
        when 400..499 then STATUS_CLIENT_ERROR
        when 500..599 then STATUS_SERVER_ERROR
        else NORMAL
        end
      end

      def self.method_pill_color(method)
        case method.to_s.upcase
        when 'GET' then METHOD_GET_PILL
        when 'POST' then METHOD_POST_PILL
        when 'PUT', 'PATCH' then METHOD_PUT_PILL
        when 'DELETE' then METHOD_DELETE_PILL
        else NORMAL
        end
      end

      def self.status_pill_color(status)
        return MUTED if status.nil?

        case status
        when 200..299 then STATUS_SUCCESS_PILL
        when 300..399 then STATUS_REDIRECT_PILL
        when 400..499 then STATUS_CLIENT_ERROR_PILL
        when 500..599 then STATUS_SERVER_ERROR_PILL
        else NORMAL
        end
      end
    end
  end
end
