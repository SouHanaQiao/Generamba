require 'fileutils'

require 'generamba/helpers/xcodeproj_helper.rb'

module Generamba

	# Responsible for creating the whole code module using information from the CLI
	class ModuleGenerator

		def generate_module(name, code_module, template)
			# Setting up Xcode objects
			project = XcodeprojHelper.obtain_project(code_module.xcodeproj_path)

			# Configuring file paths
			FileUtils.mkdir_p code_module.module_file_path

			if code_module.test_file_path != nil
				FileUtils.mkdir_p code_module.test_file_path
			end

			# Creating code files
			puts('Creating code files...')
			process_files_if_needed(template.code_files,
									name,
									code_module,
									template,
									project,
									code_module.project_targets,
									code_module.module_group_path,
									code_module.module_file_path)

			# Creating test files
			included_tests = code_module.test_targets && code_module.test_group_path && code_module.test_file_path

			if included_tests
				puts('Creating test files...')
				process_files_if_needed(template.test_files,
										name,
										code_module,
										template,
										project,
										code_module.test_targets,
										code_module.test_group_path,
										code_module.test_file_path)
			end

			# Saving the current changes in the Xcode project
			project.save

			puts 'Module successfully created!'
			puts "Name: #{name}".green
			puts "Module file path: #{code_module.module_file_path}".green
			puts "Module group path: #{code_module.module_group_path}".green
			puts !code_module.test_file_path ? '' : "Test file path: #{code_module.test_file_path}".green
			puts !code_module.test_group_path ? '' : "Test group path: #{code_module.test_group_path}".green
		end

		def process_files_if_needed(files, name, code_module, template, project, targets, group_path, dir_path)
			# It's possible that current project doesn't test targets configured, so it doesn't need to generate tests.
			# The same is for files property - a template can have only test or project files
			if targets.count == 0 || files == nil || files.count == 0 || dir_path == nil || group_path == nil
				return
			end

			XcodeprojHelper.clear_group(project, targets, group_path)
			files.each do |file|
				unless file[TEMPLATE_FILE_PATH_KEY]
					directory_name = file[TEMPLATE_NAME_KEY].gsub(/^\/|\/$/, '')
					file_group = dir_path.join(directory_name)

					FileUtils.mkdir_p file_group
					XcodeprojHelper.add_group_to_project(project, file_group)

					next
				end

				file_group = File.dirname(file[TEMPLATE_NAME_KEY])

				# Generating the content of the code file and it's name
				file_name, file_content = ContentGenerator.create_file(file, code_module, template)
				file_path = dir_path.join(file_group).join(file_name)

				# Creating the file in the filesystem
				FileUtils.mkdir_p File.dirname(file_path)
				File.open(file_path, 'w+') do |f|
					f.write(file_content)
				end

				file_is_resource = file[TEMPLATE_FILE_IS_RESOURCE_KEY]

				# Creating the file in the Xcode project
				XcodeprojHelper.add_file_to_project_and_targets(project, targets, group_path.join(file_group), file_path, file_is_resource)
			end
		end
	end
end