#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Description

      class OpenMerge

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
        # # Specific parameters to Command plugins:
        # ** :commandID (_Integer_): The command ID
        # ** :accelerator (<em>[Integer,Integer]</em>): The accelerator (modifier and key)
        # ** :parameters (<em>list<Symbol></em>): The list of symbols that GUIs have to provide to the execute method
        def pluginInfo
          return {
            :title => 'Open and Merge',
            :description => 'Open a PBS file and merge it with existing',
            :bitmapName => 'OpenMerge.png',
            :commandID => ID_OPEN_MERGE,
            :parameters => [
              :parentWindow
            ]
          }
        end

      end

    end

  end

end