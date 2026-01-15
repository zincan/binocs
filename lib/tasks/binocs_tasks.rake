# frozen_string_literal: true

namespace :binocs do
  desc "Clear all Binocs request records"
  task clear: :environment do
    count = Binocs::Request.count
    Binocs::Request.delete_all
    puts "Cleared #{count} Binocs request records."
  end

  desc "Prune old Binocs request records"
  task prune: :environment do
    retention = Binocs.configuration.retention_period
    count = Binocs::Request.where("created_at < ?", retention.ago).delete_all
    puts "Pruned #{count} Binocs request records older than #{retention.inspect}."
  end

  desc "Show Binocs statistics"
  task stats: :environment do
    puts "Binocs Statistics"
    puts "-" * 40
    puts "Total requests: #{Binocs::Request.count}"
    puts "Requests today: #{Binocs::Request.today.count}"
    puts "Requests last hour: #{Binocs::Request.last_hour.count}"
    puts "Average duration: #{Binocs::Request.average_duration || 0}ms"
    puts "Error rate: #{Binocs::Request.error_rate}%"
    puts ""
    puts "Methods breakdown:"
    Binocs::Request.methods_breakdown.each do |method, count|
      puts "  #{method}: #{count}"
    end
    puts ""
    puts "Status breakdown:"
    Binocs::Request.status_breakdown.sort.each do |status, count|
      puts "  #{status}: #{count}"
    end
  end
end
