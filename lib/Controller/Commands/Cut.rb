#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  module Commands

    module Cut

      # Register this command
      #
      # Parameters:
      # * *iCommands* (<em>map<Integer,Hash></em>): The map of commands to complete
      def registerCmdCut(iCommands)
        iCommands[Wx::ID_CUT] = {
          :title => 'Cut',
          :help => 'Cut selection',
          :bitmap => Wx::Bitmap.new("#{$PBSRootDir}/Graphics/Cut.png"),
          :method => :cmdCut,
          :accelerator => [ Wx::MOD_CMD, 'x'[0] ]
        }
      end

      # Command that cuts an object into the clipboard
      #
      # Parameters:
      # * *iParams* (<em>map<Symbol,Object></em>): The parameters:
      # ** *objectID* (_Integer_): ID of the object to be copied
      # ** *object* (_Object_): Object to be copied
      def cmdCut(iParams)
        lObjectID = iParams[:objectID]
        lObject = iParams[:object]
        if ((lObjectID == ID_TAG) or
            (lObjectID == ID_SHORTCUT))
          lClipboardData = Tools::DataObjectTag.new
          lClipboardData.Data = Marshal.dump([lObjectID, lObject.getSerializedData])
          Wx::Clipboard.open do | ioClipboard |
            ioClipboard.data = lClipboardData
          end
          notifyObjectCut(lObjectID, lObject)
        else
          puts "!!! The selected item is neither a Shortcut nor a Tag, ID = #{lObjectID}). Bug ?"
        end
      end

    end

  end

end
