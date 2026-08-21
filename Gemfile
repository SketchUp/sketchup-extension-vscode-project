source 'https://rubygems.org'

# Not used directly. On Windows, `net/http` pulls in `resolv`, which reads DNS
# settings via `win32/registry`, which requires `fiddle`. Ruby 3.4 warns that
# `fiddle` stops being a default gem in Ruby 4.0 and asks you to declare it,
# even though `win32-registry` already declares it in its own gemspec. Declaring
# it here silences the warning, which would otherwise be printed by any
# bundled tool that touches the network (e.g. `bundle exec rubocop`).
gem 'fiddle'

group :development do
  gem 'minitest'                 # Helps solargraph with code insight when you write unit tests.
  gem 'sketchup-api-stubs'       # VSCode SketchUp Ruby API insight
  gem 'skippy', '~> 0.5.3.a'     # Aid with common SketchUp extension tasks.
  gem 'solargraph'               # VSCode Ruby IDE support (Better at SU API stubs than LSP)
end

group :documentation do
  gem 'commonmarker', '~> 0.23'  # Allows YARD to use Markdown for code comments.
  gem 'yard', '~> 0.9'           # Generates Ruby documentation.
end

group :analysis do
  gem 'rubocop', '>= 1.85', '< 2.0'  # Static analysis of Ruby Code.
  gem 'rubocop-sketchup', '~> 2.1.1' # Static analysis for the SketchUp Ruby API.
end
