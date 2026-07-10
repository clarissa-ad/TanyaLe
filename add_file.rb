require 'xcodeproj'

project_path = 'TanyaLe.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'TanyaLe' }

# Find the group
group = project.main_group.find_subpath(File.join('TanyaLeApp', 'Views', 'Prototypes'), true)
group.set_source_tree('<group>')

# Add the file to the group
file_path = 'TanyaLeApp/Views/Prototypes/SandboxMakerOnboardingView.swift'
unless group.files.find { |f| f.path == 'SandboxMakerOnboardingView.swift' }
  file_ref = group.new_file('SandboxMakerOnboardingView.swift')
  # Add the file to the target
  target.add_file_references([file_ref])
  project.save
  puts "Added SandboxMakerOnboardingView.swift to project"
else
  puts "File already in project"
end
