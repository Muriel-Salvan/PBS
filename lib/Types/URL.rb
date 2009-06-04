#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Types

    class URL < ShortcutType

      TCURL_ID = 1000

      # Create the window that edits content associated to this type
      #
      # Parameters:
      # * *iParent* (_Window_): The parent window
      # * *iSC* (_Shortcut_): The Shortcut containing initial values
      # Return:
      # * _Panel_: The panel containing controls
      def createEditPanel(iParent, iSC)
        rResult = Wx::Panel.new(iParent)

        # Create all components
        lSTURL = Wx::StaticText.new(rResult, -1, 'URL')
        lTCURL = Wx::TextCtrl.new(rResult, :id => TCURL_ID, :value => iSC.Content)
        lTCURL.min_size = [300, lTCURL.min_size.height]

        # Put them in sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        rResult.sizer = lMainSizer
        lMainSizer.add_item([0,0], :proportion => 1)
        lMainSizer.add_item(lSTURL, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item(lTCURL, :flag => Wx::GROW, :proportion => 0)
        lMainSizer.add_item([0,0], :proportion => 1)

        return rResult
      end

      # Get the content from the controls given from a panel created through this same plugin
      #
      # Parameters:
      # * *iPanel* (<em>Wx::Panel</em>): The panel containing values
      # Return:
      # * _Object_: The corresponding content, which will be associated to a shortcut
      def createContentFromPanel(iPanel)
        rContent = iPanel.find_window_by_id(TCURL_ID).value

        return rContent
      end

      # Get the default icon file name associated to this type
      #
      # Return:
      # * _String_: The icon file name, relative to PBS root dir
      def getIconFileName
        return 'Graphics/Bookmark.png'
      end

      # Create an empty content.
      # This is used for putting default values in the NewShortcut dialog.
      #
      # Return:
      # * _Object_: The default content
      def createEmptyContent
        return 'http://www.google.com'
      end

    end

  end

end
