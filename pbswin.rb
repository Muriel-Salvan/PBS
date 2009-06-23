#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  class Launcher_mswin32

    # This method sends a message (platform dependent) to the user, without the use of wxruby
    #
    # Parameters:
    # * *iMsg* (_String_): The message to display
    def sendMsg(iMsg)
      system("msg \"#{ENV['USERNAME']}\" /W #{iMsg}")
    end

  end

end

require 'launcher.rb'
PBS::Launcher.new.launch(File.dirname(__FILE__), PBS::Launcher_mswin32.new)
