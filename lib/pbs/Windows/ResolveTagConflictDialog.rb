#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'pbs/Windows/ResolveConflictDialog'

module PBS

  # Dialog that resolves conflict on a Tag
  class ResolveTagConflictDialog < ResolveConflictDialog

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iTag* (_Tag_): The existing Tag
    # * *iName* (_String_): Tag name getting into conflict
    # * *iIcon* (<em>Wx::Bitmap</em>): Icon getting into conflict
    def initialize(iParent, iTag, iName, iIcon)
      @Tag = iTag
      @Name = iName
      @Icon = iIcon
      super(iParent, 'Tag',
        :title => 'Resolve conflicts between 2 Tags',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )
    end

    # Get existing panel
    #
    # Return:
    # * <em>Wx::Panel</em>: The panel containing existing data
    def getExistingPanel
      require 'pbs/Windows/TagMetadataPanel'
      rPanel = TagMetadataPanel.new(self)

      rPanel.setData(@Tag.Name, @Tag.Icon)
      
      return rPanel
    end

    # Get conflicting panel
    #
    # Return:
    # * <em>Wx::Panel</em>: The panel containing conflicting data
    def getConflictingPanel
      require 'pbs/Windows/TagMetadataPanel'
      rPanel = TagMetadataPanel.new(self)
      
      rPanel.setData(@Name, @Icon)

      return rPanel
    end

  end

end
