namespace :_ do


desc "Create git repository"
task :gitinit do
  `git init . && git add . && git commit -m "Initial Commit."`
end

desc "Initialize project structure"
task :init do
  `mkdir coffee css images js`
  `touch coffee/application.coffee`
  `touch css/application.css`
end

desc "Grab flat file server from git and bundle install it"
task :grab_flat_file_server do
  `git clone git@github.com:dtdigital/flat_file_sinatra_server.git`
  Dir.chdir("./flat_file_sinatra_server")
  Dir['*'].each do |file|
    system %Q{mv "#{file.sub('.erb', '')}" "../"}
  end
  Dir.chdir("../")
  `rm -rf flat_file_sinatra_server`
  `bundle install`
end

end