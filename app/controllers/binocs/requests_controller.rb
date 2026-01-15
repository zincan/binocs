# frozen_string_literal: true

module Binocs
  class RequestsController < ApplicationController
    before_action :set_request, only: [:show, :destroy]

    def index
      @requests = Request.recent
      @requests = apply_filters(@requests)
      @requests = @requests.page(params[:page]).per(50) if @requests.respond_to?(:page)
      @requests = @requests.limit(50) unless @requests.respond_to?(:page)

      @stats = {
        total: Request.count,
        today: Request.today.count,
        avg_duration: Request.average_duration,
        error_rate: Request.error_rate
      }

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def destroy
      @request.destroy

      respond_to do |format|
        format.html { redirect_to requests_path, notice: "Request deleted." }
        format.turbo_stream { render turbo_stream: turbo_stream.remove(@request) }
      end
    end

    def clear
      Request.delete_all

      respond_to do |format|
        format.html { redirect_to requests_path, notice: "All requests cleared." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("requests-list", partial: "binocs/requests/empty_list") }
      end
    end

    private

    def set_request
      @request = Request.find_by!(uuid: params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to requests_path, alert: "Request not found."
    end

    def apply_filters(scope)
      scope = scope.by_method(params[:method]) if params[:method].present?
      scope = scope.by_status_range(params[:status]) if params[:status].present?
      scope = scope.search(params[:search]) if params[:search].present?
      scope = scope.by_controller(params[:controller_name]) if params[:controller_name].present?
      scope = scope.with_exception if params[:has_exception] == "1"
      scope = scope.slow(params[:slow_threshold].to_i) if params[:slow_threshold].present?
      scope
    end
  end
end
