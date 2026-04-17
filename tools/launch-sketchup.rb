# Launches SketchUp with the eval bridge for Claude Code integration.
# Usage: ruby tools/launch-sketchup.rb [version] [--debug]

version = '2026'
debug_mode = false

ARGV.each do |arg|
  case arg
  when '--debug' then debug_mode = true
  when /^\d{4}$/ then version = arg
  end
end

bridge_script = File.expand_path('sketchup-bridge.rb', __dir__)

extra_args = %(-RubyStartup "#{bridge_script}")
extra_args = %(-rdebug "ide port=7000" #{extra_args}) if debug_mode

if RUBY_PLATFORM.include?('darwin')
  app = "/Applications/SketchUp #{version}/SketchUp.app"
  command = %(open -a "#{app}" --args #{extra_args})
else
  program_files_64 = ENV['ProgramW6432'] || 'C:/Program Files'
  program_files_32 = ENV['ProgramFiles(x86)'] || 'C:/Program Files (x86)'

  relative = "SketchUp/SketchUp #{version}"
  relative = File.join(relative, 'SketchUp') if version.to_i >= 2025
  relative = File.join(relative, 'SketchUp.exe')

  path_64 = File.join(program_files_64, relative)
  path_32 = File.join(program_files_32, relative)
  sketchup = File.exist?(path_64) ? path_64 : path_32

  command = %("#{sketchup}" #{extra_args})
end

warn "Launching SketchUp #{version} with bridge..."
warn "  Debug mode: #{debug_mode}" if debug_mode
spawn(command)
