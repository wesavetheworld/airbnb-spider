require 'yaml'
require 'csv'

f = open ('city_list.yaml')
city_list = YAML.load(f.read())
f.close

data_table = [["city","date","center_lat","center_lng","count"]]
hotel_list_table = [["city","date","hotel_id","user_id","name","price","lat","lng"]]

city_list.each do |city|
  Dir.glob("data/#{city}_data*.yaml").each do |file|
    date = /\d{8}-\d\d:\d\d:\d\d/.match(file).to_s
    f = open(file)
    data = YAML.load(f.read())
    
    data_table.push([city,date,data[city]["center_lat"],data[city]["center_lng"],data[city]["count"]])
  end

  Dir.glob("data/#{city}_hotel_list*.yaml").each do |file|
    date = /\d{8}-\d\d:\d\d:\d\d/.match(file).to_s
    f = open(file)
    data = YAML.load(f.read())
    
    data[city].each do |hotel|
      hotel_list_table.push([city,date,hotel["id"],hotel["user"],hotel["name"],hotel["price"],hotel["lat"],hotel["lng"]])
    end
  end

end

CSV.open("export/city_data.csv","w") do |csv|
  data_table.each do |x|
    csv << x
  end
end

CSV.open("export/hotel_list.csv","w") do |csv|
  hotel_list_table.each do |x|
    csv << x
  end
end