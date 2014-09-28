require 'nokogiri'
require 'open-uri'
require 'tumblr_client'
load 'habs_config.rb'

class UnsuitableURLError < StandardError; end 

Tumblr.configure do |config|
  config.consumer_key = CONSUMER_KEY
  config.consumer_secret = CONSUMER_SECRET
  config.oauth_token = OAUTH_TOKEN
  config.oauth_token_secret = OAUTH_TOKEN_SECRET
end

def get_photo_link(base_url)
  current_url = base_url.dup
  5.times do
    #Walk the directory tree randomly until photos folder is found
    #Should be <5 levels
    current_page = Nokogiri::HTML(open(current_url))
    dir_links = current_page.css('a').drop(5).map { |link| link['href'] }
    if dir_links.include? 'photos/'
      current_url << 'photos/'
      break
    elsif dir_links.include? 'data/' || dir_links.empty?
      raise UnsuitableURLError, "Couldn't find photos directory for #{current_url}"
    else
      current_url << dir_links.sample
    end
    sleep(10) #Don't exceed the LOC's specified limits for automated pageloads
  end
  sleep(10)
  photo_page = Nokogiri::HTML(open(current_url))
  high_res_jpgs = photo_page.css('a').map { |a| a['href'] }.
                  select { |a| /pv\.jpg$/ =~ a }
  if high_res_jpgs.empty?
    raise UnsuitableURLError, "No suitable images in #{current_url}"
  else
    photo_link = current_url + high_res_jpgs.sample
    if File.exist?(PHOTO_LOG)
      used_photos = IO.readlines(PHOTO_LOG).map { |line| line.chomp }
      if used_photos.include? photo_link
        raise UnsuitableURLError, "Used #{photo_link} already"
      end
    end
    photo_link
  end
end

def get_metadata(photo_url)
  data_url_fields = /\/(\w*)\/(\w*)\/(\d*)pv\.jpg$/.match(photo_url)
  data_url = "http://www.loc.gov/pictures/collection/hh/item/" \
             "#{data_url_fields[1]}.#{data_url_fields[2]}.#{data_url_fields[3]}p/"
  data_page = Nokogiri::HTML(open(data_url))
  data_title = data_page.title.gsub(/[\t\r\n]/, '').strip
  until ("a".."z").include?(data_title.downcase[0]) || data_title.empty?
    data_title.slice!(0)
  end
  tags = data_page.css('div#bib ul li ul li')[0].text.
         gsub(/[\t\r\n]/, "").strip.split(" -- ").join(", ")
  { :photo_url => photo_url, :data_url => data_url,
    :data_title => data_title, :tags => tags }
end

def post_to_tumblr(post_fields)
  client = Tumblr::Client.new
  client.photo(BLOG_URL, {
    :source => post_fields[:photo_url],
    :caption => "<a href='#{post_fields[:data_url]}'>#{post_fields[:data_title]}</a>",
    :tags => post_fields[:tags]
  })
end

def main
  #Format is not 100% consistent; this may take multiple tries
  retries = 5
  begin
    photo_link = get_photo_link(BASE_URL)
    metadata = get_metadata(photo_link)
    response = post_to_tumblr(metadata)
    puts "#{Time.now}: #{response} #{photo_link}"
    if response["id"]
      File.open(PHOTO_LOG, 'a') { |file| file.puts photo_link }
    end
  rescue OpenURI::HTTPError, UnsuitableURLError => err
    STDERR.puts "#{Time.now}: #{err.message}"
    if retries > 0 && err.message != "403 Forbidden"
      retries -= 1
      sleep(10)
      retry
    end
  rescue => err
    STDERR.puts "#{Time.now}: with #{photo_link}, #{metadata}, #{response}:"
    STDERR.puts err.message
    STDERR.puts err.backtrace
  end
end

main
