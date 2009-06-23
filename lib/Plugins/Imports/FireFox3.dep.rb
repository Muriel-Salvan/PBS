#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Imports

    # Get dependencies needed for this plugin
    #
    # Return:
    # * <em>map<String,String></em>: The map of requires and their corresponding gem install command line
    def self.getFireFox3Deps
      return {
        'sqlite3' => 'sqlite3-ruby --version 1.2.3'
      }
    end

  end

end
