
namespace :files do
	desc "Batch rename files based on a separator args [current_string, string_to_rename, separator]"
	task :rename_files_with_seperator, :current_string, :string_to_rename, :separator do |t, args|
		
		current_string = args.current_string || ""
		seperator = args.seperator || "-"
		string_to_rename = args.string_to_rename || ""

		Dir['*'].each do |file|

			file_array = File.basename(file).split(seperator) 

			next if file_array[0] != current_string

			if File.exist?("./#{string_to_rename}-#{file_array[1]}")
				system %Q{mv "./#{file.sub('.erb', '')}" "#{string_to_rename}-#{file_array[1]}"}
			else
				system %Q{mv "./#{file.sub('.erb', '')}" "#{string_to_rename}-#{file_array[1]}"}
			end

		end
	end


end