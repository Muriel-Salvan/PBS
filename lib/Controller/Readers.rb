#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # This module defines every useful method that Commands can use to access some data.
  # Data retrieved this way should NEVER be modified.
  # If you wish to modify data, use methods defined in the Actions module. Therefore your modifications will be protected with Undo methods, and you will not mess other Commands' Undo doing so.
  module Readers

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

    # Types plugins
    #   map< String, Object >
    attr_reader :TypesPlugins

    # Import plugins
    #   map< String, Object >
    attr_reader :ImportPlugins

    # Export plugins
    #   map< String, Object >
    attr_reader :ExportPlugins

    # Integration plugins
    #   map< String, Object >
    attr_reader :IntegrationPlugins

    # The current type of copy (Wx::ID_COPY or Wx::ID_CUT)
    #   Integer
    attr_reader :CopiedMode

    # The current copied selection
    #   MultipleSelection
    attr_reader :CopiedSelection

    # The current type of drag (Wx::DRAG_COPY or Wx::DRAG_MOVE)
    #   Integer
    attr_reader :DragMode

    # The current dragged selection
    #   MultipleSelection
    attr_reader :DragSelection

    # Find a Shortcut based on its unique ID
    #
    # Parameters:
    # * *iSCID* (_Integer_): The Shortcut's unique id
    # * *iHasToExist* (_Boolean_): Has the Shortcut to exist ? [optional = true]
    # Return:
    # * _Shortcut_: The retrieved Shortcut, or nil if none found
    def findShortcut(iSCID, iHasToExist = true)
      rShortcut = nil

      @ShortcutsList.each do |iSC|
        if (iSC.getUniqueID == iSCID)
          rShortcut = iSC
          break
        end
      end
      if ((rShortcut == nil) and
          (iHasToExist))
        puts "!!! Unable to retrieve Shortcut with internal ID #{iSCID}. Bug ?"
      end

      return rShortcut
    end

    # Find a Tag based on its unique ID
    #
    # Parameters:
    # * *iTagID* (<em>list<String></em>): The Tag's unique id
    # Return:
    # * _Tag_: The retrieved Tag, or nil if none found
    def findTag(iTagID)
      return @RootTag.searchTag(iTagID)
    end

  end

end
