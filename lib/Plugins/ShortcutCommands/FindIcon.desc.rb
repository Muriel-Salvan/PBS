#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module ShortcutCommands

    module Description

      class FindIcon

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
        # # Specific parameters to Shortcut Command plugins:
        # ** :shortcutTypes (<em>list<String></em>): A list of Shortcuts types that this command is applicable to. Can be nil to target all types.
        def pluginInfo
          return {
            :title => 'Find icon',
            :description => 'Find an appropriate icon for a Shortcut',
            :bitmapName => 'FindIcon.png',
            :shortcutTypes => nil
          }
        end

      end

    end

  end

end
