#!/usr/bin/env ruby

require 'heroku-api'
require 'open-uri'

STDOUT.sync = true

APP_NAME = ENV['HEROKU_APP_NAME']
API_KEY  = ENV['HEROKU_API_KEY']
MEMORY_CODE = "R14"

raise "Provide HEROKU_API_KEY" if API_KEY.nil?

puts "[monitor] Starting to monitor #{APP_NAME}"

begin

  heroku = Heroku::API.new(api_key: API_KEY)
  previous_timestamps = Hash.new(0)
  restarts = Hash.new

  while true
    begin
      response = open(heroku.get_logs(APP_NAME, 'num' => '1000').body).readlines.reverse.select{|l| l.include?(MEMORY_CODE) }
    rescue => ex
      puts "[monitor] Unable to fetch log (#{ex.message})"
    end

    if response
      response.each do |dyno_response|
        dyno_match= dyno_response.match(/(web|worker)\.(\d*)/)
        dyno_name = "#{dyno_match[1]}.#{dyno_match[2]}"
        restarts[dyno_name] ||= Time.now

        if dyno_response && (Time.now.to_i - restarts[dyno_name].to_i) > 300
          puts "[monitor] RESTARTING #{dyno_name} based on #{MEMORY_CODE} at #{Time.now}"
          puts "[monitor] Log: #{dyno_response}"
          restarts[dyno_name] = Time.now
          puts heroku.post_ps_restart(APP_NAME, "ps" => dyno_name)
        else
          puts "[monitor] Grace period for #{dyno_name}"
        end
      end
    else
      puts "[monitor] No activity..."
    end
    sleep 20
  end
rescue SignalException => ex
  # SIGTERM is normal, we don't need an email about it
  raise ex unless ex.signm == 'SIGTERM'
rescue Exception => ex
  puts("MONITOR ERROR")
  puts(ex.class.to_s)
  puts(ex.message)
  puts(ex.backtrace.join("\n"))
end

