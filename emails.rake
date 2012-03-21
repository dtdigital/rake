namespace :email do

desc "Compile non inline styles to inline styles for eDMs"
task :toinline do

  require 'net/http'
  require 'cgi'

  if File.exist?("email.html")
    email = File.open("email.html", "rb")
    email_content = email.read

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

    else
      res.value
      puts "ERROR: inline service returned #{res.value}"
    end
  else
    puts "ERROR: missing an email template named 'email.html'"
  end
end


desc "Upload Images to S3"
task :upload_images do
  puts "We Need to finsih this"
end
end