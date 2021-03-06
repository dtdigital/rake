require 'rubygems'
require 'httparty'
require 'json'

class Campfire
  include HTTParty

  base_uri   'https://dtdigital3.campfirenow.com'
  basic_auth  ENV["BETSY_CAMPFIRE_API"], 'x'
  headers    'Content-Type' => 'application/json'

  def self.rooms
    Campfire.get('/rooms.json')["rooms"]
  end

  def self.room(room_id)
    Room.new(room_id)
  end

  def self.user(id)
    Campfire.get("/users/#{id}.json")["user"]
  end
end

class Room
  attr_reader :room_id

  def initialize(room_id)
    @room_id = room_id
  end

  def join
    post 'join'
  end

  def leave
    post 'leave'
  end

  def lock
    post 'lock'
  end

  def unlock
    post 'unlock'
  end

  def message(message)
    send_message message
  end

  def paste(paste)
    send_message paste, 'PasteMessage'
  end

  def play_sound(sound)
    send_message sound, 'SoundMessage'
  end

  def transcript
    get('transcript')['messages']
  end

  private

  def send_message(message, type = 'Textmessage')
    post 'speak', :body => {:message => {:body => message, :type => type}}.to_json
  end

  def get(action, options = {})
    Campfire.get room_url_for(action), options
  end

  def post(action, options = {})
    Campfire.post room_url_for(action), options
  end

  def room_url_for(action)
    "/room/#{room_id}/#{action}.json"
  end
end

namespace :email do

desc "Compile non inline styles to inline styles for eDMs"
task :toinline do

  require 'net/http'
  require 'cgi'

  if File.exist?("email.html")
    email = File.open("email.html", "rb")
    email_content = email.read
    puts "== Converting email to inline styles"
    #uses the http://inlinestyler.torchboxapps.com web service
    uri = URI('http://inlinestyler.torchboxapps.com/styler/convert/')
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data('source' => email_content, 'returnraw' => true)

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      html = CGI.unescapeHTML(res.body)
      if File.exist?("email_compiled.html")
        system %Q{rm "email_compiled.html"}
      end
      
      file = File.new("email_compiled.html", "w")
      file.write(html)
      file.close
      puts "== Done"
    else
      res.value
      puts "ERROR: inline service returned #{res.value}"
    end
  else
    puts "ERROR: missing an email template named 'email.html'"
  end
end

desc "Upload compiled email source to Litmus as a test"
task :litmus_upload do
    require 'net/http'
    require 'nokogiri'

    puts "== Starting Litmus test"

    company = "soi"
    doc = Nokogiri::HTML(File.open("____email_compiled.html")) 
    File.delete("____email_compiled.html")
    xml = %Q{
      <test_set>
        <applications type="array">
          <application>
            <code>hotmail</code>
          </application>
          <application>
            <code>gmail</code>
          </application>
          <application>
            <code>notes8</code>
          </application>
          <application>
            <code>ol2010</code>
          </application>
          <application>
            <code>ol2007</code>
          </application>
          <application>
            <code>gmailnew</code>
          </application>
          <application>
            <code>ffhotmail</code>
          </application>
          <application>
            <code>ipad3</code>
          </application>
          <application>
            <code>iphone3</code>
          </application>
          <application>
            <code>ol2000</code>
          </application>
          <application>
            <code>ol2002</code>
          </application>
          <application>
            <code>ol2003</code>
          </application>
          <application>
            <code>yahoo</code>
          </application>
        </applications>
        <save_defaults>false</save_defaults>
        <use_defaults>false</use_defaults>
        <email_source>
           <body><![CDATA[#{doc}]]></body>
           <subject>#{ENV['PROJECT_ID']}</subject>
        </email_source>
      </test_set>
    }

    uri = URI("https://soi.litmus.com/emails.xml")
    req = Net::HTTP::Post.new(uri.path)
    req.basic_auth 'soi', 'Password1'
    req.content_type = 'application/xml'
    req.body = xml

    #puts req.body

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(req)
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      response = res.body
      xml = Nokogiri::XML(response)
      puts "== Test uploaded successfully to Litmus https://soi.litmus.com/tests/"+xml.xpath("//id").first.content
      room = Campfire.room(490376)
      room.message "Litmus test for job number #{ENV['PROJECT_ID']} has been successfully uploaded: https://soi.litmus.com/tests/"+xml.xpath("//id").first.content
    else
      res.value
      puts "ERROR: inline service returned #{res.value}"
    end
    


end


desc "Test Email general wrapper"
task :test, :toinline do |t, args|

  toinline = args.toinline || false
  if toinline
    ENV['toinline'] = toinline
  end

  Rake::Task["email:upload_images"].invoke
  
  if toinline
    Rake::Task["email:toinline"].invoke
  end

  Rake::Task["email:replace_img_src"].invoke
  Rake::Task["email:litmus_upload"].invoke
  ENV['PROJECT_ID'] = nil
  ENV['S3_ID'] = nil
end

desc "Replace img tag src to S3 location"
task :replace_img_src do
  require 'nokogiri'
  require 'yaml'

  @config = YAML.load_file("dt.yaml")
  @images = @config['folders']['images']
  if @images == nil
    uts "ERROR: images folder name not set"
  end

  loc = "http://"+ENV['S3_ID']+"/"+ENV['S3_BUCKET_ID']+"/"+ENV['PROJECT_ID']
 
  if ENV['toinline']
    doc = Nokogiri::HTML(File.open("email_compiled.html"))
  else
    doc = Nokogiri::HTML(File.open("email.html"))
  end
  
  puts "== Replacing img src to S3"
  doc.xpath("//img").each do |img|
        src = img['src']
        src = src.gsub!(/(^#{@images})/, loc)
        img['src'] = src
  end

  file = File.new("____email_compiled.html", "w")
  file.write(doc)
  file.close
  puts "== Done"
end

desc "Add blank targets to all anchor tags in email template"
task :add_target_blank do
  require 'nokogiri'
  doc = Nokogiri::HTML(File.open("email.html"))
  puts "== Adding target='_blank' to anchor tags"
  doc.xpath("//a").each do |anchor|
    target = anchor['target']
    if target == nil
      anchor['target'] = "_blank"
    end
  end
  system %Q{rm "email.html"}
  file = File.new("email.html", "w")
  file.write(doc)
   file.close
end

desc "Upload Images to S3"
task :upload_images, :env, :branch do |t, args|
  require 'aws/s3'
  require 'digest/md5'
  require 'mime/types'
  require 'yaml'

  @config = YAML.load_file("dt.yaml")

  if @config == nil
    puts "ERROR: no config file"
    break
  end

  @id = @config["id"]

  ENV['PROJECT_ID'] = @id

  @folder_to_upload = @config["image_folder_to_upload_to_s3"]

## These are some constants to keep track of my S3 credentials and 
## bucket name. Nothing fancy here.    

AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
AWS_BUCKET = "dtdigitaledms"

ENV['S3_BUCKET_ID'] = AWS_BUCKET

## Use the `s3` gem to connect my bucket
    puts "== Uploading assets to S3/Cloudfront"
    AWS::S3::DEFAULT_HOST.replace "s3-ap-southeast-1.amazonaws.com"
    ENV['S3_ID'] = "s3-ap-southeast-1.amazonaws.com"
    service = AWS::S3::Base.establish_connection!(
      :access_key_id => AWS_ACCESS_KEY_ID,
      :secret_access_key => AWS_SECRET_ACCESS_KEY)

    bucket = AWS::S3::Bucket.find(AWS_BUCKET)
    
  
## Needed to show progress
    STDOUT.sync = true

## Find all files (recursively) in ./public and process them.
    Dir.glob("#{@folder_to_upload}/**/*").each do |file|

## Only upload files, we're not interested in directories
      if File.file?(file)

## Slash 'public/' from the filename for use on S3
        remote_file = file.gsub("#{@folder_to_upload}/", "")
## Try to find the remote_file, an error is thrown when no
## such file can be found, that's okay.  
        begin
          obj = bucket.objects.find_first(remote_file)
        rescue
          obj = nil
        end

        #puts obj

## If the object does not exist, or if the MD5 Hash / etag of the 
## file has changed, upload it.
        if !obj || (obj.etag != Digest::MD5.hexdigest(File.read(file)))
            #print "U"

## Simply create a new object, write the content and set the proper 
## mime-type. `obj.save` will upload and store the file to S3.
            AWS::S3::S3Object.store("#{@id}/"+remote_file, open("#{@folder_to_upload}/"+remote_file), AWS_BUCKET, :access => :public_read)
            puts "*UPLOADED: "+remote_file
        else
          print "."
        end
      end
    end
    STDOUT.sync = false # Done with progress output.

    puts "== Done"
  end
end