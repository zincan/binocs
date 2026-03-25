# frozen_string_literal: true

module Binocs
  class RequestsController < ApplicationController
    before_action :set_request, only: [:show, :destroy, :lifecycle, :raw]

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

    def sequence
      @client_identifiers = Request.client_identifiers
      @selected_client = params[:client].presence || @client_identifiers.first
      @requests = Request.by_client(@selected_client).for_sequence.limit(200)
    end

    def heatmap
      @endpoints = Request
        .group(:method, :path)
        .select(
          "method",
          "path",
          "COUNT(*) as hit_count",
          "AVG(duration_ms) as avg_duration",
          "MAX(duration_ms) as max_duration",
          "SUM(CASE WHEN status_code >= 500 THEN 1 ELSE 0 END) as error_count",
          "SUM(CASE WHEN status_code >= 400 AND status_code < 500 THEN 1 ELSE 0 END) as client_error_count"
        )
        .order(Arel.sql("COUNT(*) DESC"))

      # Try to match endpoints to swagger spec paths for grouping
      @swagger_spec = Binocs::Swagger::Client.fetch_spec rescue nil
      @endpoint_groups = build_endpoint_groups(@endpoints, @swagger_spec)

      @total_requests = Request.count
      @max_hits = @endpoints.map(&:hit_count).max || 1
      @max_avg_duration = @endpoints.map { |e| e.avg_duration.to_f }.max || 1
      @view_mode = params[:view] || "frequency"
    end

    def analytics
      @total_requests = Request.count
      @today_requests = Request.today.count
      @avg_duration = Request.average_duration
      @error_rate = Request.error_rate

      # Hourly traffic for the last 24 hours
      @hourly_traffic = Request
        .where("created_at >= ?", 24.hours.ago)
        .group_by_hour
        .count

      # Status code distribution
      @status_distribution = Request.status_breakdown

      # Method distribution
      @method_distribution = Request.methods_breakdown

      # Top endpoints by volume
      @top_endpoints = Request
        .group(:method, :path)
        .select("method, path, COUNT(*) as hit_count, AVG(duration_ms) as avg_duration")
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(15)

      # Slowest endpoints (avg)
      @slowest_endpoints = Request
        .group(:method, :path)
        .select("method, path, COUNT(*) as hit_count, AVG(duration_ms) as avg_duration, MAX(duration_ms) as max_duration")
        .having("COUNT(*) >= 2")
        .order(Arel.sql("AVG(duration_ms) DESC"))
        .limit(10)

      # Error hotspots
      @error_endpoints = Request
        .where("status_code >= 400")
        .group(:method, :path, :status_code)
        .select("method, path, status_code, COUNT(*) as error_count")
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)

      # Response time distribution (buckets)
      @duration_buckets = build_duration_buckets
    end

    def lifecycle
      logs = Array(@request.logs)

      # Extract the controller log entry (the summary line from ActiveSupport::Notifications)
      controller_log = logs.find { |l| l["type"] == "controller" }

      # Timing breakdown
      total_duration = @request.duration_ms.to_f
      controller_duration = controller_log&.dig("duration").to_f
      view_runtime = controller_log&.dig("view_runtime").to_f
      db_runtime = controller_log&.dig("db_runtime").to_f

      middleware_time = [total_duration - controller_duration, 0].max
      other_time = [controller_duration - view_runtime - db_runtime, 0].max

      @lifecycle = {
        total_duration: total_duration,
        controller_duration: controller_duration,
        middleware_time: middleware_time,
        view_runtime: view_runtime,
        db_runtime: db_runtime,
        other_time: other_time
      }

      # SQL queries from logs
      @sql_queries = logs.select { |l| l["type"] == "sql" }

      # Render entries from logs
      @render_entries = logs.select { |l| l["type"] == "render" }

      # Halted filter (if any before_action halted the chain)
      @halted_filter = logs.find { |l| l["type"] == "halted" }

      # Redirect info
      @redirect = logs.find { |l| l["type"] == "redirect" }

      # Exception info (from logs or request model)
      @exception_log = logs.find { |l| l["type"] == "exception" }

      # Generic log entries
      @log_entries = logs.select { |l| l["type"] == "log" }

      # Middleware stack from the host Rails app
      @middleware_stack = begin
        Rails.application.middleware.map do |middleware|
          name = middleware.klass.is_a?(String) ? middleware.klass : middleware.klass.name
          name
        end.compact
      rescue
        []
      end
    end

    def raw
      @section = params[:section].presence || "full"
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

    def build_endpoint_groups(endpoints, spec)
      groups = {}

      endpoints.each do |ep|
        tag = find_swagger_tag(ep.method, ep.path, spec) || derive_tag_from_path(ep.path)
        groups[tag] ||= []
        groups[tag] << ep
      end

      # Sort groups by total hits descending
      groups.sort_by { |_tag, eps| -eps.sum(&:hit_count) }.to_h
    end

    def find_swagger_tag(method, path, spec)
      return nil unless spec && spec["paths"]

      spec["paths"].each do |spec_path, path_item|
        next unless path_item.is_a?(Hash)

        pattern = spec_path.gsub(/\{[^}]+\}/, "[^/]+")
        next unless path.match?(/\A#{pattern}\z/)

        operation = path_item[method.downcase]
        next unless operation

        return operation["tags"]&.first
      end

      nil
    end

    def derive_tag_from_path(path)
      # /v1/companies/123/invitations -> "Companies"
      # /api/users -> "Users"
      segments = path.split("/").reject(&:blank?)
      # Skip version prefixes
      segments.shift if segments.first&.match?(/\Av\d+\z/)
      segments.shift if segments.first&.match?(/\Aapi\z/i)
      # Take first meaningful segment
      segment = segments.first || "Other"
      segment.titleize.pluralize
    end

    def build_duration_buckets
      buckets = {
        "< 10ms" => Request.where("duration_ms < 10").count,
        "10-50ms" => Request.where("duration_ms >= 10 AND duration_ms < 50").count,
        "50-100ms" => Request.where("duration_ms >= 50 AND duration_ms < 100").count,
        "100-250ms" => Request.where("duration_ms >= 100 AND duration_ms < 250").count,
        "250-500ms" => Request.where("duration_ms >= 250 AND duration_ms < 500").count,
        "500ms-1s" => Request.where("duration_ms >= 500 AND duration_ms < 1000").count,
        "1-3s" => Request.where("duration_ms >= 1000 AND duration_ms < 3000").count,
        "> 3s" => Request.where("duration_ms >= 3000").count
      }
      buckets.reject { |_, v| v.zero? }
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
