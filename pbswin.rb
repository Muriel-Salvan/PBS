
# Here is the behaviour:
# 1. Ensure we have wxRuby
# 2. Get the dependencies needed by the plugins:
# 2.1. If at least 1 dependency is missing:
# 2.1.1. Ensure we have RubyGems
# 2.1.2. Download each missing dependency

# Global paths
# Root dir used as a based for images directories, plugins to be required...
$PBS_RootDir = File.dirname(__FILE__)
$PBS_LibDir = "#{$PBS_RootDir}/lib"
$PBS_GraphicsDir = "#{$PBS_LibDir}/Graphics"
$PBS_ExtDir = "#{File.dirname(__FILE__)}/ext/#{RUBY_PLATFORM}"
$PBS_ExtGemsDir = "#{$PBS_ExtDir}/gems"

# Add the main library directory to the load path
$LOAD_PATH << $PBS_LibDir

# Setup RubyGems environment to install gems
def setupRubyGems
  # Check if RubyGems is up and running
  begin
    require 'rubygems'
  rescue Exception
    # RubyGems is not installed: try to use the Ruby interpreter shipping RubyGems
    # Protect this call: use it only if we are not already allinoneruby
    if (defined?(ALLINONERUBY))
      puts "!!! BUG !!!: RubyGems is not accessible although it has been invoked in the RubyGems wrapper: #{$!}."
      $stdin.gets
      exit 1
    else
      system("#{File.dirname(__FILE__)}/rubywithgems #{$0} #{ARGV.join(' ')}")
      exit 0
    end
  end
  lGemLocalRepository = "#{File.dirname(__FILE__)}/ext/#{RUBY_PLATFORM}"
  # Set RubyGems environment
  ENV['GEM_HOME'] = lGemLocalRepository
  if (ENV['GEM_PATH'] == nil)
    ENV['GEM_PATH'] = lGemLocalRepository
  else
    ENV['GEM_PATH'] += ":#{lGemLocalRepository}"
  end
  Gem.clear_paths
end

# Try to get WxRuby up and running
begin
  require 'wx'
rescue Exception
  # Check if we have the interpreter with WxRuby
  lRubyWxInterpreter = "#{File.dirname(__FILE__)}/bin/#{RUBY_PLATFORM}/rubywithwx"
  if (File.exists?(lRubyWxInterpreter))
    system("#{lRubyWxInterpreter} #{$0} #{ARGV.join(' ')}")
    exit 0
  else
    # We want to download the interpreter with Ruby and WxRuby, or maybe ensure RubyGems and download wxruby gem
    # TODO
    exit 1
  end
end

# Launch everything
require 'pbs'
PBS::run
