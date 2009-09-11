#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Windows/ResolveConflictDialog.rb'
require 'pbs/Windows/ContentMetadataPanel.rb'

module PBS

  # Dialog that edits a Shortcut
  class ResolveShortcutConflictDialog < ResolveConflictDialog

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iSC* (_Shortcut_): The Shortcut containing existing info
    # * *iContent* (_Object_): The content issuing a conflict
    # * *iMetadata* (<em>map<String,Object></em>): The Metadata issuing a conflict
    # * *iController* (_Controller_): The Controller
    def initialize(iParent, iSC, iContent, iMetadata, iController)
      @SC = iSC
      @Content = iContent
      @Metadata = iMetadata
      @Controller = iController
      super(iParent, 'Shortcut',
        :title => "Resolve Shortcut conflict (#{iSC.Type.pluginDescription[:PluginName]})",
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )
    end

    # Get existing panel
    #
    # Return:
    # * <em>Wx::Panel</em>: The panel containing existing data
    def getExistingPanel
      rPanel = ContentMetadataPanel.new(self, @SC.Type, @Controller)

      rPanel.setData(@SC.Content, @SC.Metadata)

      return rPanel
    end

    # Get conflicting panel
    #
    # Return:
    # * <em>Wx::Panel</em>: The panel containing conflicting data
    def getConflictingPanel
      rPanel = ContentMetadataPanel.new(self, @SC.Type, @Controller)
      
      rPanel.setData(@Content, @Metadata)

      return rPanel
    end

  end

end
