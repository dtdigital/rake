namespace :project do


desc "Set up an HTML5 Boilerplate project"
task :newflat => ["_:init"] do
  `rm -rf ./css`
  `rm -rf ./js`
  `git clone git@github.com:dtdigital/html5-boilerplate.git`
  `mv ./html5-boilerplate/* ./`
  `mv ./html5-boilerplate/.gitattributes ./.gitattributes`
  `mv ./html5-boilerplate/.gitignore ./.gitignore`
  `rm -rf ./img`
  `mv apple-touch-icon* ./images`
  `mv favicon.ico ./images`
  `touch css/application.css`
  `rm -rf html5-boilerplate`
  Rake::Task["_:gitinit"].invoke
end


desc "Set up a new Email Template Project"
task :newemail do
  print "Project Job Number: "
  if (project = $stdin.gets.chomp)

    path = File.join(Dir.getwd, project)
    ENV['PROJECT_ID'] = project

    `mkdir #{path}`
    Dir.chdir(path)
    `git clone git@github.com:dtdigital/Email-Boilerplate.git .`
    `mkdir images`
    Rake::Task["_:gitinit"].invoke
    Rake::Task["project:config_email"].invoke
    ENV['PROJECT_ID'] = nil
  end
end

desc "Create dt config file"
task :config_email, :id do |t, args|
  yaml = %Q{

id: "#{ENV['PROJECT_ID']}"

config:
  path_to_file_server: ""

# Add folders or files
# to package up
# relative to project root
folders:
  images: "images"
  index:  "email.html"

image_folder_to_upload_to_s3: "images" 

  }

  config = File.new("./dt.yaml", "w")
  config.write(yaml)
  config.close
end

desc "Compile coffeescript files"
task :coffeescript_compile do
  system %Q{coffee -c ./assets/coffee}
end

desc "Create dt config file"
task :config, :id do |t, args|
  yaml = %Q{

id: "#{ENV['PROJECT_ID']}"

config:
  path_to_file_server: ""

# Add folders or files
# to package up
# relative to project root
folders:
  css: "assets/css"
  images: "assets/images"
  js: "assets/js"
  coffee: "assets/coffee"
  index: "index.html"

  }

  config = File.new("./dt.yaml", "w")
  config.write(yaml)
  config.close
end

desc "Create new flat file project for OSX and assign some variables"
task :newproject do
  print "Project Job Number: "

  if (project = $stdin.gets.chomp)

    path = File.join(Dir.getwd, project)
    ENV['PROJECT_ID'] = project

    if Dir.exists? path
      puts "ERROR: Directory already exists, exiting...."
    else
      `mkdir #{path}`
      Dir.chdir(path)

      Rake::Task["project:config"].invoke
      Rake::Task["project:newflat"].invoke

      system %Q{mkdir "./assets"}
      system %Q{mv "./css" "./assets/css"}
      system %Q{mv "./images" "./assets/images"}
      system %Q{mv "./js" "./assets/js"}
      system %Q{mv "./coffee" "./assets/coffee"}

      Rake::Task["_:grab_flat_file_server"].invoke

      print "Do you want to open the Project up in Sublime: [yn] "
      case $stdin.gets.chomp
      when 'y'
        `subl .`
      when 'n'
        false
      end
      ENV['PROJECT_ID'] = nil
    end
  end
end

desc "Package up flat file project and place on fileserver"
task :package_project do
  require 'yaml'
  # #
  # TODO: Move the current directory contents into old
  # Copy over the new directory



  @localDirectory = Dir.getwd

  @date = Time.new
  @config = YAML.load_file("dt.yaml")
  @path_parent = @config["config"]["path_to_file_server"]

  @coffee = @config["folders"]["coffee"]

  if @coffee
    Rake::Task["project:coffeescript_compile"].invoke
  end

  def make_current_working_directory()
    _p = "#{@path_parent}/#{@date.strftime("%Y%m%d")}"
    system %Q{mkdir "#{_p}"}
    package_and_copy_current_directory(_p)
  end

  def package_and_copy_current_directory(_p)
    Dir.chdir(@localDirectory)
    folders = @config["folders"]
    assets_folder = @config["config"]["assets_folder_name"]

    # If hash then depend on whether assets folder is set or not 
    # as to whether it's prepended to the copy path
    if folders.class() == Hash
      if assets_folder
        if not Dir.exists? "./#{assets_folder}"
          print "ERROR: assets folder is set but does not exists \n"
        end
        # move and prepend assets folder before copying 
        # ie flat file server
        folders.each do |key, value|
          system %Q{cp -r "./#{assets_folder}/#{value}" "#{_p}"}
        end
      else
        # just copy as outlined
        folders.each do |key, value|
          system %Q{cp -r "./#{value}" "#{_p}"}
        end
      end
    else
      # * wildcard just move all the buggers over
      Dir['*'].each do |file|
        system %Q{cp -r "#{file.sub('.erb', '')}" "#{_p}"}
      end
    end
    # clean up by removing the dt.yaml file

    if File.exists? "#{_p}/dt.yaml"
      system %Q{rm "#{_p}/dt.yaml"}    
    end
  end

  if Dir.exists? "#{@path_parent}/#{@date.strftime("%Y%m%d")}"  
    if not Dir.exists? "#{@path_parent}/_old"
      system %Q{mkdir "#{@path_parent}/_old"}
    end

    Dir.chdir(@path_parent)
    Dir['*'].each do |file|
      if File.basename(file) != "_old"
        if /(20)\d{6}/.match(File.basename(file))
          if Dir.exists? "#{Dir.getwd}/_old/#{File.basename(file)}"
            # add in incrementing underscores
            Dir.chdir("./_old")
            increment = 0
            Dir['*'].each do |old_files|
              array = old_files.split("_")
              if File.basename(file).to_s == array[0].to_s
                increment += 1
              end
            end
            Dir.chdir("../")
            system %Q{mv "#{file.sub('.erb', '')}" "./_old/#{file.sub('.erb', '')}_#{increment}"}
          else
            system %Q{mv "#{file.sub('.erb', '')}" "./_old/#{file.sub('.erb', '')}"}
          end
        end
      end
    end
    make_current_working_directory()

  else 
    make_current_working_directory()
  end
end

end