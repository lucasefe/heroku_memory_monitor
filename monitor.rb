#!/usr/bin/env ruby

require 'heroku-api'
require 'open-uri'

STDOUT.sync = true
app_name = 'credible-chefsfeed'

puts "[monitor] Starting to monitor #{app_name}"

begin
  API_KEY = ENV['HEROKU_API_KEY']
  raise "Provide HEROKU_API_KEY" if API_KEY.nil?
  MAX_DYNO_SIZE=500
  CODE = "R14"

  heroku = Heroku::API.new(api_key: API_KEY)

  # make sure this range will cover your web dynos.
  dynos = (1..20).to_a
  dyno_types = %w(web worker)

  previous_timestamps = Hash.new(0)
  restarts = Hash.new

  while true
    begin
      puts "[monitor] Fetching log"
      response = open(heroku.get_logs(app_name, 'num' => '1000').body).readlines.reverse.select{|l| l.include?(CODE) }
    rescue => ex
      puts "[monitor] Unable to fetch log (#{ex.message})"
    end

    if response
      dyno_types.each do |type|
        dynos.each do |i|
          dyno_name = "#{type}.#{i}"
          restarts[dyno_name] ||= Time.now
          dyno_response = response.detect{|l| l.include? "[#{dyno_name}]" }
          if dyno_response
      if (Time.now - restarts[dyno_name]) > 600
              restarts[dyno_name] = Time.now
              puts "[monitor] RESTARTING #{dyno_name} based on #{CODE}"
              puts heroku.post_ps_restart(app_name, "ps" => dyno_name)
      else
          puts "[monitor] grace period for #{dyno_name}"
            end
    end
        end
      end
    else
      puts "[monitor] No activity..."
    end
    sleep 10
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

