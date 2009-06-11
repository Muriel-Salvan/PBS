#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Types

    class Shell < ShortcutType

      TCCmd_ID = 1000

      # Create the window that edits content associated to this type
      #
      # Parameters:
      # * *iParent* (_Window_): The parent window
      # * *iContent* (_Object_): The content containing initial values
      # Return:
      # * _Panel_: The panel containing controls
      def createEditPanel(iParent, iContent)
        rResult = Wx::Panel.new(iParent)

        # Create all components
        lSTCmd = Wx::StaticText.new(rResult, -1, 'Shell command')
        lTCCmd = Wx::TextCtrl.new(rResult, :id => TCCmd_ID, :value => iContent)
        lTCCmd.min_size = [300, lTCCmd.min_size.height]

        # Put them in sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        rResult.sizer = lMainSizer
        lMainSizer.add_item([0,0], :proportion => 1)
        lMainSizer.add_item(lSTCmd, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
        lMainSizer.add_item(lTCCmd, :flag => Wx::GROW, :proportion => 0)
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
        rContent = iPanel.find_window_by_id(TCCmd_ID).value

        return rContent
      end

      # Get the default icon file name associated to this type
      #
      # Return:
      # * _String_: The icon file name, relative to PBS root dir
      def getIconFileName
        return 'Graphics/Run.png'
      end

      # Create an empty content.
      # This is used for putting default values in the NewShortcut dialog.
      #
      # Return:
      # * _Object_: The default content
      def createEmptyContent
        return 'echo "Hello World"'
      end

      # Get a simple summary of a given content created by this Type.
      # This could be used in tool tips for example.
      #
      # Parameters:
      # * *iContent* (_Object_): Content created by this type
      # Return:
      # * _String_: The content's summary
      def getContentSummary(iContent)
        return iContent
      end

    end

  end

end
