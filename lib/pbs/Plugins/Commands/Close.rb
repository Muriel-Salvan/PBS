#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    class Close

      # Command that exits PBS
      #
      # Parameters:
      # * *ioController* (_Controller_): The data model controller
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *instancesToClose* (<em>list<Object></em>): The list of instances to find and close
      def execute(ioController, iParams)
        lInstancesToClose = iParams[:instancesToClose]
        # Disable the selected Integration plugin instances from the Options and refresh
        lOldOptions = ioController.Options.clone
        # Parse all plugins, and mark them to be shut down if wanted, unless none remains (in this case, we exit)
        lSomeActive = false
        ioController.Options[:intPluginsOptions]. each do |iPluginID, ioInstancesInfo|
          ioInstancesInfo.each do |ioInstanceInfo|
            iTagID, iEnabled, iOptions, iInstantiatedInfo = ioInstanceInfo
            iInstance, iTag = iInstantiatedInfo
            if (iEnabled)
              if (lInstancesToClose.include?(iInstance))
                # Shutdown this one
                ioInstanceInfo[1] = false
              else
                lSomeActive = true
              end
            end
          end
        end
        # Refresh
        ioController.notifyOptionsChanged(lOldOptions)
        # Exit if no one is remaining
        if (!lSomeActive)
          ioController.executeCommand(Wx::ID_EXIT, :parentWindow => nil)
        end
      end

    end

  end

end
