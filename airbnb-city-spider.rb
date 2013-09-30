require 'rubygems'
require 'logger'
require 'nokogiri'
require 'net/http'
require 'json'
require 'yaml'
require 'mixpanel-ruby'
require 'socket'

$host = Socket.gethostname
$tracker = Mixpanel::Tracker.new("4b8a200b7b7af5992a6db04e53e94f5d")
$logger = Logger.new("airbnb-city.log","weekly")

module AirBnb
  def self.url_name(address)
    address.downcase.gsub(/-/,'~').gsub(/ /,'-').gsub(/,/,'--')
  end
  
  def self.http(url)
    begin
      uri = URI(url)
      result = {}
      $tracker.track($host, 'HTTP Request')  
      Net::HTTP.start(uri.host,uri.port,:use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri
        request["Cookie"] = "_user_attributes=#{URI::escape('{"curr":"usd"}')}"
        request["User-Agent"] = "Mozilla/5.0 (compatible; DataBnb-Bot)"
        response = http.request request 
      
        result["request"] = request.each do |x| end
        result["response"] = response.each do |x| end
        result["body"] = response.body
      end
      $tracker.track($host, 'HTTP Request Done')  
      sleep(2);
    rescue StandardError => e
      $logger.info ("HTTPBot") { e.to_s }
      puts "error: #{e.to_s}"
      raise e
    end  
    
    $logger.info ("HTTPBot") { "url: #{url}" }    
    $logger.info ("HTTPBot") { "request: #{result["request"]}" }    
    $logger.info ("HTTPBot") { "response: #{result["response"]}" }    
    return result
  end
end

class Spider
end

class CitySpider < Spider
  attr_accessor :city_list, :city_data, :hotel_list, :thread_pool
  
  def initialize()
    @city_list = [];
    @hotel_list = {};
    @city_data = {};
    @thread_pool = [];
  end
  
  def thread_traverse_range(city,price_min,price_max,count)
    while true do
      4.times do |x|
        if @thread_pool[x]==nil or @thread_pool[x].alive?()==false then
          @thread_pool[x] = Thread.new do 
            puts "start new traverse_range thread - slot #{x}, city=#{city}, price_min=#{price_min}, price_max=#{price_max}, count=#{count}"
            traverse_range(x,city,price_min,price_max,count)
          end      
          return    
        end
      end
      sleep(1);
    end
  end
        
  def traverse_range(id,city,price_min,price_max,count)
    page = 1
    read_count = 0
    city_hotel_list = []
    
    while read_count < count do
      $tracker.track($host, 'City Spider Traverse Page')  
      url = "https://www.airbnb.com/search/search_results?location=#{AirBnb::url_name(city)}"
      url = url + "&price_min=#{price_min}" if price_min
      url = url + "&price_max=#{price_max}" if price_max
      url = url + "&page=#{page}"
      
      res = AirBnb::http(url)
      html = JSON.parse(res["body"])["results"]      
      doc = Nokogiri.HTML(html)
    
      $logger.info ("CitySpider") { "traverse_range##{id} - page=#{page}, page_size=#{doc.search("div.listing").size}" }    
      puts "traverse_range##{id} - page=#{page}, page_size=#{doc.search("div.listing").size}"
      
      break if doc.search("div.listing").size==0
            
      doc.search("div.listing").each do |elem|
        read_count = read_count+1
        city_hotel_list.push({"city"=>city,
          "lat"=>elem.attribute("data-lat").to_s,
          "lng"=>elem.attribute("data-lng").to_s,
          "name"=>elem.attribute("data-name").to_s,
          "url"=>elem.attribute("data-url").to_s,
          "user"=>elem.attribute("data-user").to_s,
          "id"=>elem.attribute("data-id").to_s,
          "price"=>elem.search("div.listing-price a div h2").text.to_s
        })
      end
      
      page=page+1
    end
    
    $logger.info ("CitySpider") { "traverse_range##{id} - count=#{city_hotel_list.size}" }    
    puts "traverse_range##{id} - count=#{city_hotel_list.size}"
    
    @hotel_list[city]=[] if @hotel_list[city]==nil 
    @hotel_list[city]+= city_hotel_list
  end
  
  def fetch_city_price(city,price_min,price_max)
     $logger.info ("CitySpider") { "fetch_city_price - city=#{city}, price_min=#{price_min}, price_max=#{price_max}"}
     puts "fetch_city_price - city=#{city}, price_min=#{price_min}, price_max=#{price_max}"

     url = "https://www.airbnb.com/search/search_results?location=#{AirBnb::url_name(city)}"
     url = url + "&price_min=#{price_min}" if price_min
     url = url + "&price_max=#{price_max}" if price_max
     
     res = AirBnb::http(url)     
     data = JSON.parse(res["body"])
 
     if not city_data[city] then
       city_data[city] = {"center_lat"=>data["center_lat"],"center_lng"=>data["center_lng"]}
     end
 
     if (data["visible_results_count"]<1000 or price_min==price_max) then
        $logger.info ("CitySpider") {"traverse_range - city=#{city}, price_min=#{price_min}, price_max=#{price_max}, count=#{data["visible_results_count"]}"}
        puts "thread_traverse_range - city=#{city}, price_min=#{price_min}, price_max=#{price_max}, count=#{data["visible_results_count"]}"
        thread_traverse_range(city,price_min,price_max,data["visible_results_count"])
     else
       mid = (price_max + price_min)/2

       fetch_city_price(city,price_min,mid)
       fetch_city_price(city,mid+1,price_max)
     end
  end
  
  def fetch_city(city)
    $logger.info ("CitySpider") { "fetch_city - city=#{city}"}
    puts "fetch_city - city=#{city}"
    
    fetch_city_price(city,0,100)
    fetch_city_price(city,100,1000)
    fetch_city_price(city,1000,10000) 
    
    @thread_pool.each do |x| 
      x.join if x 
    end
          
    @hotel_list[city].uniq! if @hotel_list[city]
    @city_data[city]["count"] = @hotel_list[city].size if @hotel_list[city]
  end
  
  def init
    f = open ('city_list.yaml')
    @city_list = YAML.load(f.read())
    f.close
  end
  
  def run_city(city)
    @hotel_list = {}
    @city_data = {}
    fetch_city(city)
    
    f = open("data/#{city}_data-#{Time.now.utc.strftime("%Y%m%d-%H:%M:%S")}.yaml","w")
    f.write (@city_data.to_yaml)
    f.close

    f = open("data/#{city}_hotel_list-#{Time.now.utc.strftime("%Y%m%d-%H:%M:%S")}.yaml","w")
    f.write (@hotel_list.to_yaml)
    f.close
  end

  def run
    @city_list.each do |city|
      run_city(city)
    end
  end  
end

def run_city_spider
  begin
    thread_pool = []

    cs = CitySpider.new
    cs.init
    cs.city_list.each do |x|

      start_flag = false
      while not start_flag do
        2.times do |i|
          if thread_pool[i]==nil or thread_pool[i].alive?()==false then        
            thread_pool[i]=Thread.new do 
              $tracker.track($host, 'City Spider Run City')  
              tcs = CitySpider.new
              tcs.city_list = [x]
              tcs.run
            end
            start_flag = true
            break
          end
        end

      end
    end

    thread_pool.each do |x| 
      x.join if x 
    end  
  rescue StandardError => e
    $logger.error ("Error") { e.to_s }
    puts "Error - #{e.to_s}"

    raise e
  end
end

time = Time.now
$logger.info ("CitySpider") {"Start"}
puts "CitySpider - Start"

run_city_spider

$logger.info ("CitySpider") {"End"}
puts "CitySpider - End"
$logger.info ("CitySpider") {"Time: #{Time.now-time}"}
puts "CitySpider - Time: #{Time.now-time}"

