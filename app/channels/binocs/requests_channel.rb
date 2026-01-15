# frozen_string_literal: true

module Binocs
  class RequestsChannel < ApplicationCable::Channel
    def subscribed
      stream_from "binocs_requests"
    end

    def unsubscribed
      # Cleanup when channel is unsubscribed
    end
  end
end
