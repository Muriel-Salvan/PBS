#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Imports

    module Description

      class GoogleChrome

        # Give the description of this plugin
        #
        # Return:
        # * <em>map<Symbol,Object></em>: Information on the plugin: the following symbols can be provided:
        # ** :title (_String_): Name of the plugin
        # ** :description (_String_): Quick description
        # ** :bitmapName (_String_): Sub-path to the icon (from the Graphics/ directory)
        # ** :gemsDependencies (<em>map<String,String></em>): List of require names to satisfy, with their corresponding gem install command
        # ** :libsDependencies (<em>map<String,String></em>): List of library names to satisfy, with their corresponding URL to download from
        # ** :enabled (_Boolean_): Is this plugin enabled ?
        def pluginInfo
          lLibDependencies = nil
          case $PBS_Platform.os
          when OS_WINDOWS
            lLibDependencies = {
              'sqlite3.dll' => 'http://www.sqlite.org/sqlitedll-3_6_15.zip'
            }
          # TODO: Specify for other OS
          end
          return {
            :title => 'Google Chrome',
            :description => 'Import Shortcuts from current Google Chrome profile',
            :bitmapName => 'GoogleChrome.png',
            :gemsDependencies => {
              'sqlite3' => 'sqlite3-ruby --version 1.2.3'
            },
            :libsDependencies => lLibDependencies,
            :enabled => ($PBS_Platform.os == OS_WINDOWS)
          }
        end

      end

    end

  end

end
