

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
    doc = Nokogiri::HTML(File.open("email_compiled.html")) 
    xml = %Q{
      <?xml version="1.0"?>
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
    else
      res.value
      puts "ERROR: inline service returned #{res.value}"
    end

end


desc "Test Email general wrapper"
task :test do 
  Rake::Task["email:upload_images"].invoke
  Rake::Task["email:toinline"].invoke
  Rake::Task["email:replace_img_src"].invoke
  Rake::Task["email:litmus_upload"].invoke
  ENV['PROJECT_ID'] = nil
  ENV['S3_ID'] = nil
end

desc "Replace img tag src to S3 location"
task :replace_img_src do
  require 'nokogiri'
  loc = "http://"+ENV['S3_ID']+"/"+ENV['S3_BUCKET_ID']+"/"+ENV['PROJECT_ID']
  doc = Nokogiri::HTML(File.open("email_compiled.html"))
  puts "== Replacing img src to S3"
  doc.xpath("//img").each do |img|
        src = img['src']
        src = src.gsub!(/(^images)/, loc)
        img['src'] = src
  end
  system %Q{rm "email_compiled.html"}
  file = File.new("email_compiled.html", "w")
  file.write(doc)
  file.close
  puts "== Done"

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