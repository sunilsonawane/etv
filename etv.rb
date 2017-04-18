require 'open-uri'
require 'fileutils'
require 'flickraw'
require 'rmagick'

API_KEY = "API_KEY"
SECRET = "SECRET"

module Collage
  class PhotoService
    attr_accessor :photos, :photos_count

    def initialize
      self.photos_count       = 10
      self.photos             = []
      FlickRaw.api_key        = API_KEY
      FlickRaw.shared_secret  = SECRET
    end

    def search_photos(keywords)
      keywords_dup = keywords.compact.dup
      dictionary = Dictionary.new
      self.photos = []
      while photos.size < photos_count
        keywords_dup << dictionary.random_word if keywords_dup.empty?
        keyword = keywords_dup.shift
        photo   = fetch_photos(keyword)
        photos << photo if photo
      end
      photos
    end

    def fetch_photos(keyword)
      options = {
        text: keyword,
        sort: 'interestingness-desc',
        per_page: 1,
        page: 1,
        content_type: 1,
        media: :photos
      }
      flickr_photo = flickr.photos.search(options)
      return if flickr_photo.to_a.empty?

      photo_info  = flickr.photos.getInfo(photo_id: flickr_photo.first['id'])
      photo = photo_info.to_hash
      photo["url"] = FlickRaw.url_b(photo_info)
      photo
    end

    def download
      FileUtils.mkdir_p "/tmp/collage"
      Dir.chdir("/tmp/collage") do |dir|
        photos.each do |photo|
          file = open(photo["url"])
          file_name = photo["url"].split("/").last
          File.open(File.join(dir, file_name), 'wb') do |f|
            f.write(file.read)
          end
          photo["local_url"] = "#{dir}/#{file_name}"
        end
      end
    end

    def crop
      photos.each do |photo|
        img = Magick::Image.read(photo["local_url"])[0]
        img.crop!(0, 0, 200, 200)
        img.write photo["local_url"]
      end
    end

    def collage(collage_name)
      bg = Magick::Image.read('bg.png').first
      count =0
      start_x = 0
      start_y = 0

      photos.each do |photo|
        image = Magick::Image.read(photo["local_url"]).first
        bg.composite!(image, start_x, start_y, Magick::OverCompositeOp)
        count += 1
        start_x += 210
        if count == 5
          start_x = 0
          start_y = 210
        end 
      end

      bg.write("#{collage_name}.jpg")
      puts "Collage file #{collage_name}.jpg created successfully"
    end

  end
end

module Collage
  class Dictionary
    attr_accessor :dict_filename

    def initialize(dict_filename = nil)
      self.dict_filename = dict_filename || '/usr/share/dict/words'
    end

    def read_file_lines
      IO.readlines(dict_filename)
    end

    def random_word
      lines = read_file_lines
      number  = Random.new.rand(1..lines.count).to_i
      lines[number].chomp
    end
  end
end

## =============================================
=begin
  
  Installation steps:
  1) Install image magic library
    sudo apt-get install libmagickwand-dev

  2) Install required gems
    gem install rmagick
    gem install flickraw

  Execute program:
    Pass 10 keywords as parameter to ruby script to search photo for each keyword on flickr.
    If less than 10 keywords passed then library will pick remaining keywords random keywords from disctionary.
    Pass past parameter as a file_name to save collage

  ruby etv.rb flowers tree india tiger rose jasmin anemone my_collage

  Output:
  Image collage file with given name will get created in current directory.

=end
## ============================================

collage_name = ARGV.pop
keywords = ARGV
puts "Collage Name: #{collage_name}"
puts "Keywords: #{keywords}"
photo_service = Collage::PhotoService.new
photo_service.search_photos(keywords)
photo_service.download
photo_service.crop
photo_service.collage(collage_name)