require 'rubygems'
require 'logger'
require 'rufus-scheduler'

$logger = Logger.new("airbnb-scheduler.log","weekly")

scheduler = Rufus::Scheduler.new

scheduler.cron '5 0 * * *' do
  $logger.info ("Scheduler") { "Start City Spider" }
  puts "Start City Spider"
  
  system("ruby airbnb-city-spider.rb")

  $logger.info ("Scheduler") { "End City Spider" }
  puts "End City Spider"
end

scheduler.join
