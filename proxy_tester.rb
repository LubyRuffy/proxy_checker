#!/usr/bin/env ruby
require 'open-uri'
require 'timeout'
require 'hirb'
require 'colorize'
require 'progress_bar'
require 'nokogiri'
require 'json'


extend Hirb::Console

def count_status_type(arr, status)
  arr.select { |p| p[:status].include?(status) }.size
end

real_ip = open("http://wtfismyip.com/text").read

threads = []
test_results = []
proxies = []

if ARGV[0]
	# URL of proxies :
	# ruby proxy_tester.rb http://www.free-proxy-list.net/
	text = open(ARGV[0]).read
	doc = Nokogiri::HTML(text)
	ip_port_regex = %r{((?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]))[: \t]*(\d{2,5})}
	doc.text.scan(ip_port_regex).each {|item|
		proxies << "#{item[0]}:#{item[1]}"
	}
else
	#format: each line like 1.1.1.1:8080
	IO.foreach("proxy_list.txt") { |line| proxies << line.strip }
end

proxies.uniq!
exit unless proxies.size>0
bar = ProgressBar.new(proxies.size, :bar, :percentage, :rate, :elapsed, :eta)

puts "TESTING PROXIES..."

100.times do

  threads << Thread.new do

    proxy = proxies.pop

    while proxy
      begin
        Timeout::timeout(5) do
          start_time    = Time.now
          response_ip   = open("http://wtfismyip.com/text", proxy: "http://#{proxy}").read
          response_time = Time.now.to_f - start_time.to_f

          response_headers = open("http://wtfismyip.com/headers", proxy: "http://#{proxy}").read

          external_ip_change = real_ip != response_ip
          hide_real_ip = !response_headers.include?(real_ip)
          hide_proxy_info = !response_headers.include?("proxy")

          status = "transparent".colorize(:light_blue)
          status = "ip not changed".colorize(:red) and next if !external_ip_change
          status = "anonymous".colorize(:yellow) if hide_real_ip
          status = "elite".colorize(:light_green) if hide_proxy_info
          
          country = JSON.parse(open("http://ip.taobao.com/service/getIpInfo.php?ip=#{proxy.split(':')[0]}").read)['data']['country_id']
          

          test_results << { proxy: proxy, status: status, response_time: response_time.round(2), country: country}
        end
      rescue => e
        #test_results << { proxy: proxy, status: e.class.to_s.colorize(:light_black) }
      end
      bar.increment!
      proxy = proxies.pop
    end
  end
end

threads.map(&:join)

table test_results.sort { |a,b| a[:response_time].to_f <=> b[:response_time].to_f }, fields: [:proxy, :status, :response_time, :country]

status_counts = [
  { type: "elite".colorize(:light_green),      count: count_status_type(test_results, "elite") },
  { type: "anonymous".colorize(:yellow),       count: count_status_type(test_results, "anonymous") },
  { type: "transparent".colorize(:light_blue), count: count_status_type(test_results, "transparent") }
]

table status_counts, fields: [:type, :count]