#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every useful method that Commands can use to access some data.
  # Data retrieved this way should NEVER be modified.
  # If you wish to modify data, use methods defined in the Actions module. Therefore your modifications will be protected with Undo methods, and you will not mess other Commands' Undo doing so.
  module Readers

    # The PBS root dir
    #   String
    attr_reader :PBSRootDir

    # The current opened file name
    #   String
    attr_reader :CurrentOpenedFileName

    # Is the current opened file modified ?
    #   Boolean
    attr_reader :CurrentOpenedFileModified

    # The Root tag
    #   Tag
    attr_reader :RootTag

    # The list of Shortcuts
    #   list< Shortcut >
    attr_reader :ShortcutsList

    # The current type of copy (Wx::ID_COPY or Wx::ID_CUT)
    #   Integer
    attr_reader :CopiedMode

    # The current ID of what we have copied
    #   Integer
    attr_reader :CopiedID

    # The current copied selection
    #   MultipleSelection
    attr_reader :CopiedSelection

    # The current type of drag (Wx::DRAG_COPY or Wx::DRAG_MOVE)
    #   Integer
    attr_reader :DragMode

    # The current dragged selection
    #   MultipleSelection
    attr_reader :DragSelection

    # Mode of Copy of the clipboard's content
    #   Integer
    attr_reader :Clipboard_CopyMode

    # ID of the clipboard's content
    #   Integer
    attr_reader :Clipboard_CopyID

    # Serialized selection in the clipboard
    #   MultipleSelection::Serialized
    attr_reader :Clipboard_SerializedSelection

    # Options
    #   map< Symbol, Object >
    attr_reader :Options

    # The Undo stack
    #   list< Controller::UndoableOperation >
    attr_reader :UndoStack

    # The Redo stack
    #   list< Controller::UndoableOperation >
    attr_reader :RedoStack

    # Get the icon associated to a Tag.
    # Even if it was set to nil, the default icon will be returned.
    # This method ensures a valid Wx::Bitmap object will be returned.
    #
    # Parameters::
    # * *iTag* (_Tag_): The Tag
    # Return::
    # * <em>Wx::Bitmap</em>: The icon
    def getTagIcon(iTag)
      rIcon = iTag.Icon

      if (rIcon == nil)
        rIcon = getGraphic('Tag.png')
      end

      return rIcon
    end

    # Get the icon associated to a Shortcut.
    # Even if it was set to nil, the default icon will be returned.
    # This method ensures a valid Wx::Bitmap object will be returned.
    #
    # Parameters::
    # * *iShortcut* (_Shortcut_): The Shortcut
    # Return::
    # * <em>Wx::Bitmap</em>: The icon
    def getShortcutIcon(iShortcut)
      rIcon = iShortcut.Metadata['icon']

      if (rIcon == nil)
        rIcon = getPluginBitmap(iShortcut.Type.pluginDescription)
      end

      return rIcon
    end

    # Get Import plugins descriptions
    #
    # Return::
    # * <em>map<String,map<Symbol,Object>></em>: The map of plugins description per plugin name
    def getImportPlugins
      return get_plugins_descriptions('Import')
    end

    # Get Export plugins descriptions
    #
    # Return::
    # * <em>map<String,map<Symbol,Object>></em>: The map of plugins description per plugin name
    def getExportPlugins
      return get_plugins_descriptions('Export')
    end

    # Get Types plugins descriptions
    #
    # Return::
    # * <em>map<String,map<Symbol,Object>></em>: The map of plugins description per plugin name
    def getTypesPlugins
      return get_plugins_descriptions('Type')
    end

    # Get Commands plugins descriptions
    #
    # Return::
    # * <em>map<String,map<Symbol,Object>></em>: The map of plugins description per plugin name
    def getCommandPlugins
      return get_plugins_descriptions('Command')
    end

    # Get ShortcutCommands plugins descriptions
    #
    # Return::
    # * <em>map<String,map<Symbol,Object>></em>: The map of plugins description per plugin name
    def getShortcutCommandsPlugins
      return get_plugins_descriptions('ShortcutCommand')
    end

    # Get Integration plugins descriptions
    #
    # Return::
    # * <em>map<String,map<Symbol,Object>></em>: The map of plugins description per plugin name
    def getIntegrationPlugins
      return get_plugins_descriptions('Integration')
    end

    # Get bitmap associated to a plugin.
    # If no bitmap was provided by the plugin itself, a default bitmap is returned.
    #
    # Parameters::
    # * *ioPluginDescription* (<em>map<Symbol,Object></em>): The plugin description
    # Return::
    # * <em>Wx::Bitmap</em>: The bitmap
    def getPluginBitmap(ioPluginDescription)
      if (ioPluginDescription[:Bitmap] == nil)
        # Load it
        ioPluginDescription[:Bitmap] = getGraphic(ioPluginDescription[:BitmapName])
      end
      return ioPluginDescription[:Bitmap]
    end

    # Get an access to a given Types plugin
    #
    # Parameters::
    # * *iPluginName* (_String_): Name of the plugin to access
    # * _CodeBlock_: The code called with the instantiated plugin:
    #   * *ioPlugin* (_Object_): The instantiated plugin
    def accessTypesPlugin(iPluginName)
      access_plugin_Protected('Type', iPluginName) do |ioPlugin|
        yield(ioPlugin)
      end
    end

    # Get an access to a given Integration plugin
    #
    # Parameters::
    # * *iPluginName* (_String_): Name of the plugin to access
    # * _CodeBlock_: The code called with the instantiated plugin:
    #   * *ioPlugin* (_Object_): The instantiated plugin
    def accessIntegrationPlugin(iPluginName)
      access_plugin_Protected('Integration', iPluginName) do |ioPlugin|
        yield(ioPlugin)
      end
    end

    # Get an access to a given Import plugin
    #
    # Parameters::
    # * *iPluginName* (_String_): Name of the plugin to access
    # * _CodeBlock_: The code called with the instantiated plugin:
    #   * *ioPlugin* (_Object_): The instantiated plugin
    def accessImportPlugin(iPluginName)
      access_plugin_Protected('Import', iPluginName) do |ioPlugin|
        yield(ioPlugin)
      end
    end

    # Get an access to a given Export plugin
    #
    # Parameters::
    # * *iPluginName* (_String_): Name of the plugin to access
    # * _CodeBlock_: The code called with the instantiated plugin:
    #   * *ioPlugin* (_Object_): The instantiated plugin
    def accessExportPlugin(iPluginName)
      access_plugin_Protected('Export', iPluginName) do |ioPlugin|
        yield(ioPlugin)
      end
    end

    # Get an access to a given ShortcutCommands plugin
    #
    # Parameters::
    # * *iPluginName* (_String_): Name of the plugin to access
    # * _CodeBlock_: The code called with the instantiated plugin:
    #   * *ioPlugin* (_Object_): The instantiated plugin
    def accessShortcutCommandsPlugin(iPluginName)
      access_plugin_Protected('ShortcutCommand', iPluginName) do |ioPlugin|
        yield(ioPlugin)
      end
    end

  end

end
