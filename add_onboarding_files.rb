require 'xcodeproj'

project_path = 'TanyaLe.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'TanyaLe' }

# Find or create the Onboarding group inside Prototypes
prototypes_group = project.main_group.find_subpath(File.join('TanyaLeApp', 'Views', 'Prototypes'), true)
onboarding_group = prototypes_group.find_subpath('Onboarding', true)
onboarding_group.set_source_tree('<group>')

# Add the files to the group
files = [
  'SandboxMakerOnboardingView.swift',
  'OnboardingPageOne.swift',
  'OnboardingPageTwo.swift',
  'OnboardingPageThree.swift'
]

files.each do |file_name|
  unless onboarding_group.files.find { |f| f.path == file_name }
    file_ref = onboarding_group.new_file(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_name} to project"
  else
    puts "#{file_name} already in project"
  end
end

project.save
