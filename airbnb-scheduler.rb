require 'rubygems'
require 'logger'
require 'rufus-scheduler'
require 'mixpanel-ruby'
require 'socket'

$host = Socket.gethostname
$tracker = Mixpanel::Tracker.new("4b8a200b7b7af5992a6db04e53e94f5d")
$logger = Logger.new("airbnb-scheduler.log","weekly")

scheduler = Rufus::Scheduler.new

scheduler.cron '40 12 * * * UTC ' do
  $logger.info ("Scheduler") { "Start City Spider" }
  puts "Start City Spider"

  $tracker.track($host, 'City Spider Schedule')  
  system("ruby airbnb-city-spider.rb")
  $tracker.track($host, 'City Spider Schedule Done')  

  $logger.info ("Scheduler") { "End City Spider" }
  puts "End City Spider"
end

scheduler.join
