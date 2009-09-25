#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Integration

    class Main

      # Get the default options
      #
      # Return:
      # * _Object_: The default options (can be nil if none needed)
      def getDefaultOptions
        return nil
      end

      # Get the configuration panel
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iController* (_Controller_): The controller
      # Return:
      # * <em>Wx::Panel</em>: The configuration panel, or nil if none needed
      def getConfigPanel(iParent, iController)
        return nil
      end

      # Create a new instance of the integration plugin
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # Return:
      # * _Object_: The instance of this integration plugin
      def createNewInstance(iController)
        require 'pbs/Windows/MainFrame'
        rMainFrame = MainFrame.new(nil, iController)

        rMainFrame.show

        return rMainFrame
      end

      # Delete a previously created instance
      #
      # Parameters:
      # * *iController* (_Controller_): The model controller
      # * *ioInstance* (_Object_): The instance created via createNewInstance that we now have to delete
      def deleteInstance(iController, ioInstance)
        # Clean up everything that was registered before destruction
        ioInstance.unregisterAll
        ioInstance.destroy
      end

    end

  end

end
