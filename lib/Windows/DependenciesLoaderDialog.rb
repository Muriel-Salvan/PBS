#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Dialog that downloads missing dependencies
  class DependenciesLoaderDialog < Wx::Dialog

    include Tools

    # Panel that proposes how to resolve a dependency
    class DependencyPanel < Wx::Panel

      include Tools

      # Icons used to identofy status
      ICON_OK = Wx::Bitmap.new("#{$PBS_GraphicsDir}/ValidOK.png")
      ICON_KO = Wx::Bitmap.new("#{$PBS_GraphicsDir}/ValidKO.png")
      ICON_DOWNLOAD = Wx::Bitmap.new("#{$PBS_GraphicsDir}/Download.png")

      # Constructor
      # The notifier control window must have a notifyInstallDecisionChanged method implemented
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iRequireName* (_String_): The require name for this dependency
      # * *iInstallCommand* (_String_): The gem install command for this dependency
      # * *iPluginsInfo* (<em>list<[PluginType,PluginName,PluginsMap,Params]></em>): Information about plugins dependent on this dependency
      # * *iNotifierControl* (_Object_): The notifier control that will be notified upon changes
      def initialize(iParent, iRequireName, iInstallCommand, iPluginsInfo, iNotifierControl)
        super(iParent)

        # Installation directory (corresponding to default choice of @RBInstallIn
        @InstallDir = $PBS_ExtGemsDir
        # Directory where the dependency has been found
        @ValidDirectory = nil
        # The control to be notified upon changes
        @NotifierControl = iNotifierControl

        # Create components
        lSBMain = Wx::StaticBox.new(self, Wx::ID_ANY, iRequireName)
        # Put bold
        lFont = lSBMain.font
        lFont.weight = Wx::FONTWEIGHT_BOLD
        lSBMain.font = lFont
        @SBStatus = Wx::StaticBitmap.new(self, Wx::ID_ANY, ICON_KO)
        @RBIgnore = Wx::RadioButton.new(self, Wx::ID_ANY, 'Ignore', :style => Wx::RB_GROUP)
        lRBDirectory = Wx::RadioButton.new(self, Wx::ID_ANY, 'Specify directory')
        @RBInstall = Wx::RadioButton.new(self, Wx::ID_ANY, "Install (gem install #{iInstallCommand})")
        @RBInstallIn = Wx::RadioBox.new(self, Wx::ID_ANY, 'Install in',
          :choices => [
            "PBS directory (#{$PBS_ExtGemsDir})",
            "Current host gems (#{Gem.dir})",
            "Current user gems (#{Gem.user_dir})",
            "Temporary directory (#{Dir.tmpdir})",
            'Other directory'
          ],
          :style => Wx::RA_SPECIFY_ROWS
        )
        # list< String >
        lPluginsList = []
        iPluginsInfo.each do |iPluginInfo|
          iPluginType, iPluginName, iPluginsMap, iParams = iPluginInfo
          lPluginsList << "#{iPluginType}/#{iPluginName}"
        end
        lSTUsed = Wx::StaticText.new(self, Wx::ID_ANY, "Used by #{lPluginsList.sort.join(', ')}")

        # Put them into sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)

        lSBSizer = Wx::StaticBoxSizer.new(lSBMain, Wx::VERTICAL)

        lFirstLineSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lFirstLineSizer.add_item(@SBStatus, :border => 8, :flag => Wx::ALIGN_CENTER|Wx::ALL, :proportion => 0)
        lFirstLineSizer.add_item(@RBIgnore, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lFirstLineSizer.add_item(lRBDirectory, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lFirstLineSizer.add_item(@RBInstall, :flag => Wx::ALIGN_CENTER, :proportion => 0)

        lSBSizer.add_item(lFirstLineSizer, :flag => Wx::GROW, :proportion => 0)
        lSBSizer.add_item(@RBInstallIn, :flag => Wx::GROW, :proportion => 0)
        lSBSizer.add_item(lSTUsed, :flag => Wx::GROW, :proportion => 0)

        lMainSizer.add_item(lSBSizer, :flag => Wx::GROW, :proportion => 1)
        
        self.sizer = lMainSizer
        self.fit

        # Set events
        evt_radiobutton(@RBIgnore) do |iEvent|
          # Choose to ignore the missing dependency
          setIgnore
        end
        evt_radiobutton(lRBDirectory) do |iEvent|
          # Choose a directory
          showModal(Wx::DirDialog, self,
            :message => "Open directory containing #{iRequireName} library"
          ) do |iModalResult, iDialog|
            case iModalResult
            when Wx::ID_OK
              # Test using the directory provided directly
              lOldLoadPath = $LOAD_PATH.clone
              @ValidDirectory = nil
              $LOAD_PATH << iDialog.path
              begin
                require iRequireName
                @ValidDirectory = iDialog.path
              rescue Exception
                # Test if there is a lib directory
                if (File.exists?("#{iDialog.path}/lib"))
                  $LOAD_PATH.replace(lOldLoadPath + ["#{iDialog.path}/lib"])
                  begin
                    require iRequireName
                    @ValidDirectory = iDialog.path
                  rescue Exception
                    logErr "Adding directory #{iDialog.path}[/lib] does not help in using #{iRequireName}: #{$!}"
                  end
                end
              end
              # Revert changes made for testing
              $LOAD_PATH.replace(lOldLoadPath)
              if (@ValidDirectory == nil)
                setIgnore
              else
                # It's ok, we have a valid directory
                @SBStatus.bitmap = ICON_OK
                @RBInstallIn.show(false)
                self.fit
                @NotifierControl.notifyInstallDecisionChanged
              end
            else
              setIgnore
            end
          end
        end
        evt_radiobutton(@RBInstall) do |iEvent|
          # Choose to install the missing dependency
          @ValidDirectory = nil
          @SBStatus.bitmap = ICON_DOWNLOAD
          @RBInstallIn.show(true)
          self.fit
          @NotifierControl.notifyInstallDecisionChanged
        end
        evt_radiobox(@RBInstallIn) do |iEvent|
          # Change the installation destination
          case @RBInstallIn.selection
          when 0
            @InstallDir = $PBS_ExtGemsDir
          when 1
            @InstallDir = Gem.dir
          when 2
            @InstallDir = Gem.user_dir
          when 3
            @InstallDir = "#{Dir.tmpdir}/PBS_GEMS_#{self.object_id}"
          when 4
            # Specify a directory to install to
            showModal(Wx::DirDialog, self,
              :message => "Install #{iRequireName} library in directory"
            ) do |iModalResult, iDialog|
              case iModalResult
              when Wx::ID_OK
                # Change install directory to iDialog.path
                @InstallDir = iDialog.path
              else
                @RBInstallIn.selection = 1
                @InstallDir = $PBS_ExtGemsDir
              end
            end
          else
            logBug "Unknown selection of installation directory: #{@RBInstallIn.selection}"
          end
        end

        # First state
        setIgnore

      end

      # Set the panel to ignore decision
      def setIgnore
        @ValidDirectory = nil
        @SBStatus.bitmap = ICON_KO
        @RBIgnore.value = true
        @RBInstallIn.show(false)
        self.fit
        @NotifierControl.notifyInstallDecisionChanged
      end

      # Is this panel marked to be installed ?
      #
      # Return:
      # * _Boolean_: Is this panel marked to be installed ?
      def install?
        return @RBInstall.value
      end

      # Is this panel marked to be ignored ?
      #
      # Return:
      # * _Boolean_: Is this panel marked to be ignored ?
      def ignore?
        return @RBIgnore.value
      end

      # Get the installation directory
      #
      # Return:
      # * _String_: Installation directory
      def installLocation
        return @InstallDir
      end

      # Get the valid directory where the dependency was found.
      #
      # Return:
      # * _String_: Directory containing the library, or nil if none specified
      def getValidDirectory
        return @ValidDirectory
      end

      # Does the installation location a standard directory ?
      # A standard directory is a directory where PBS will search for plugins by default.
      #
      # Return:
      # * _Boolean_: Does the installation location a standard directory ?
      def installDirStandard?
        return (@RBInstallIn.selection != 4)
      end

    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iMissingDeps* (<em>map<String,[String,list<[String,String,map<String,map<Symbol,Object>>,list<Object>]>]></em>): The map of missing dependencies
    def initialize(iParent, iMissingDeps)
      super(iParent,
        :title => 'Dependencies downloader',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # Mapping of require name to panel
      # map< String, DependencyPanel >
      @RequireToPanels = {}
      # List of requires that become loadable after this dialog's completion
      # list< String >
      @LoadableRequires = []
      # List of external directories needed to load new paths.
      # These are the directories that might be searched next time PBS is launched on this computer.
      # list< String >
      @ExternalDirectories = []

      # Create components
      @BApply = Wx::Button.new(self, Wx::ID_ANY, 'Apply')
      lFirstSentence = nil
      if (iMissingDeps.size == 1)
        lFirstSentence = 'A dependency for plugins is missing.'
      else
        lFirstSentence = "#{iMissingDeps.size} dependencies for plugins are missing."
      end
      lSTMessage = Wx::StaticText.new(self, Wx::ID_ANY, "#{lFirstSentence}\nPlease indicate what action to take for each one of them before continuing.",
        :style => Wx::ALIGN_CENTRE
      )
      lFont = lSTMessage.font
      lFont.weight = Wx::FONTWEIGHT_BOLD
      lSTMessage.font = lFont
      # The window that will contain each panel corresponding to missing dependencies
      @MainPanel = Wx::ScrolledWindow.new(self,
        :style => Wx::VSCROLL
      )
      @ScrollSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      # list< DependencyPanel >
      lDepsPanels = []
      # Create each panel
      iMissingDeps.each do |iRequireName, iRequireInfo|
        iGemInstallCommand, iPluginsInfo = iRequireInfo
        lDepPanel = DependencyPanel.new(@MainPanel, iRequireName, iGemInstallCommand, iPluginsInfo, self)
        lDepsPanels << lDepPanel
        @RequireToPanels[iRequireName] = lDepPanel
        @ScrollSizer.add_item(lDepPanel, :border => 8, :flag => Wx::GROW|Wx::BOTTOM, :proportion => 0)
      end
      @MainPanel.sizer = @ScrollSizer

      # Put everything in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lMainSizer.add_item(lSTMessage, :border => 8, :flag => Wx::ALIGN_CENTER|Wx::ALL, :proportion => 0)
      lMainSizer.add_item(@MainPanel, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(@BApply, :border => 8, :flag => Wx::ALIGN_RIGHT|Wx::ALL, :proportion => 0)
      self.sizer = lMainSizer

      # Resize everything
      self.fit
      # Add the size of scrollbars to the window's size, for them to not appear if not needed
      self.size = [
        self.size.width + Wx::SystemSettings.get_metric(Wx::SYS_VTHUMB_Y),
        self.size.height + Wx::SystemSettings.get_metric(Wx::SYS_HTHUMB_X)
      ]
      # Set scrollbars
      @MainPanel.set_scrollbars(1, 1, @MainPanel.size.width, @MainPanel.size.height)

      # Events
      evt_button(@BApply) do |iEvent|
        # Gather the list to install in a map, with the corresponding paths to install to
        # map< String, String >
        lRequiresToInstall = {}
        @RequireToPanels.each do |iRequireName, iDepPanel|
          if (iDepPanel.install?)
            lRequiresToInstall[iRequireName] = iDepPanel.installLocation
          end
        end
        if (!lRequiresToInstall.empty?)
          # Create the progress dialog
          lProgressDialog = Wx::ProgressDialog.new(
            "Gems installation",
            "Installing gems",
            lRequiresToInstall.size,
            self,
            Wx::PD_CAN_ABORT|Wx::PD_APP_MODAL
          )
          lIdxCount = 0
          # Install everybody
          lRequiresToInstall.each do |iRequireName, iInstallDir|
            lGemInstallCommand, lPluginsInfo = iMissingDeps[iRequireName]
            if (!lProgressDialog.update(lIdxCount, "Installing gem for requirement #{iRequireName} ..."))
              break
            end
            logInfo "Installing Gem for dependency #{iRequireName}: #{lGemInstallCommand}"
            lSuccess = installGem(iInstallDir, lGemInstallCommand, lProgressDialog)
            if (lSuccess)
              logInfo 'Installation done successfully.'
              @LoadableRequires << iRequireName
              # Add the directory if it is not a standard one
              if (!@RequireToPanels[iRequireName].installDirStandard?)
                # Retrieve the installed gem directory
                lGemName = lGemInstallCommand.split[0]
                lFound = false
                Dir.glob("#{iInstallDir}/gems/#{lGemName}*").each do |iDir|
                  if (File.exists?("#{iDir}/lib"))
                    @ExternalDirectories << "#{iDir}/lib"
                    lFound = true
                  end
                end
                if (!lFound)
                  logErr "Unable to find the installed directory #{iInstallDir}/gems/#{lGemName}*. It is possible that #{iRequireName} dependency will not be installed correctly."
                end
              end
            else
              logErr "Installing Gem \"#{lGemInstallCommand}\" ended in error. Please try to install it manually."
            end
            lIdxCount += 1
          end
          lProgressDialog.destroy
        end
        self.end_modal(Wx::ID_OK)
      end

      notifyInstallDecisionChanged

    end

    # Install a Gem
    # Only this method should have a dependency on RubyGems.
    # It calls the internal API of RubyGems: do not invoke gem binary, as it has to work also in an embedded binary (RubyGems statically compiled in Ruby) for packaging.
    #
    # Parameters:
    # * *iInstallDir* (_String_): The directory to install the Gem to.
    # * *iInstallCmd* (_String_): The gem install parameters
    # * *iProgressDialog* (<em>Wx::ProgressDialog</em>): The progress dialog to update eventually
    # Return:
    # * _Boolean_: Success ?
    def installGem(iInstallDir, iInstallCmd, iProgressDialog)
      rSuccess = true

      # Add options to the command
      lCmd = "#{iInstallCmd} --no-rdoc --no-ri --no-test"
      # this require is left here, as we don't want to need it if we don't call this method.
      require 'rubygems/commands/install_command'
      # Create the RubyGems command
      lRubyGemsInstallCmd = Gem::Commands::InstallCommand.new
      lRubyGemsInstallCmd.handle_options(lCmd.split)
      begin
        lRubyGemsInstallCmd.execute
      rescue Gem::SystemExitException
        # For RubyGems, this is normal behaviour: success results in an exception thrown with exit_code 0.
        if ($!.exit_code != 0)
          logBug "RubyGems returned error code #{$!.exit_code} while installing #{iInstallCmd}."
          rSuccess = false
        end
      rescue Exception
        logBug "RubyGems returned an exception while installing #{iInstallCmd}: #{$!}\nException stack:\n#{caller.join("\n")}"
        rSuccess = false
      end

      return rSuccess
    end

    # Notify that an install decision of one of the dependencies has changed
    def notifyInstallDecisionChanged
      # Get the number of dependencies to ignore, and the number to install
      lNbrToBeInstalled = 0
      lNbrToBeIgnored = 0
      @LoadableRequires = []
      @ExternalDirectories = []
      @RequireToPanels.each do |iRequireName, iDepPanel|
        if (iDepPanel.install?)
          lNbrToBeInstalled += 1
        elsif (iDepPanel.ignore?)
          lNbrToBeIgnored += 1
        else
          # We found a directory where this require is installed
          @LoadableRequires << iRequireName
          @ExternalDirectories << iDepPanel.getValidDirectory
        end
      end
      @BApply.label = "Apply (#{lNbrToBeInstalled} to be installed, #{lNbrToBeIgnored} to be ignored)"
      # Place the components correctly inside the sizer
      @ScrollSizer.fit_inside(@MainPanel)
    end

    # Return dependencies that should be loadable after this dialog execution
    #
    # Return:
    # * <em>list<String></em>: List of requires that should get ok
    def getLoadableDependencies
      return @LoadableRequires
    end

    # Return the list of directories that should be added to initial search paths for libraries
    #
    # Return:
    # * <em>list<String></em>: List of directories to add
    def getExternalDirectories
      return @ExternalDirectories
    end

  end

end
