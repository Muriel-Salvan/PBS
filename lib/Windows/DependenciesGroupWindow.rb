#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # The group of panels in a scrolled window
  class DependenciesGroupWindow < Wx::ScrolledWindow

    # Panel that proposes how to resolve a dependency
    class DependencyLoaderPanel < Wx::Panel

      include Tools

      # Icons used to identify status
      ICON_OK = Tools::loadBitmap('ValidOK.png')
      ICON_KO = Tools::loadBitmap('ValidKO.png')
      ICON_DOWNLOAD = Tools::loadBitmap('Download.png')

      # Constructor
      # The notifier control window must have a notifyInstallDecisionChanged method implemented
      #
      # Parameters:
      # * *iParent* (<em>Wx::Window</em>): The parent window
      # * *iDepName* (_String_): The name for this dependency
      # * *iInstallCommand* (_String_): The gem install command for this dependency (or nil if installation is impossible)
      # * *iPluginsList* (<em>list<[PluginType,PluginName]></em>): List of plugins dependent on this dependency
      # * *iNotifierControl* (_Object_): The notifier control that will be notified upon changes
      # * *iInstallChoices* (<em>list<[String,String]></em>): Possible directories (at least 1) to install to ( [ name, path ] ), or nil of installation is impossible
      # * *iDepHandler* (_Object_): The object that can handle the dependency operations (test if valid, install...)
      # * *iInstallPrefix* (_String_): The install prefix that will be added in front of the command for display only
      def initialize(iParent, iDepName, iInstallCommand, iPluginsList, iNotifierControl, iInstallChoices, iDepHandler, iInstallPrefix)
        super(iParent)

        @DepName = iDepName
        @DepHandler = iDepHandler
        @InstallCommand = iInstallCommand
        # Installation directory (corresponding to default choice of @RBInstallIn
        # String
        if (iInstallChoices == nil)
          @InstallDir = nil
        else
          @InstallDir = iInstallChoices[0][1]
        end
        # Directory where the dependency has been found
        # String
        @ValidDirectory = nil
        # The control to be notified upon changes
        @NotifierControl = iNotifierControl

        # Create components
        lSBMain = Wx::StaticBox.new(self, Wx::ID_ANY, iDepName)
        # Put bold
        lFont = lSBMain.font
        lFont.weight = Wx::FONTWEIGHT_BOLD
        lSBMain.font = lFont
        @SBStatus = Wx::StaticBitmap.new(self, Wx::ID_ANY, ICON_KO)
        @RBIgnore = Wx::RadioButton.new(self, Wx::ID_ANY, 'Ignore', :style => Wx::RB_GROUP)
        lRBDirectory = Wx::RadioButton.new(self, Wx::ID_ANY, 'Specify directory')
        if (iInstallCommand == nil)
          @RBInstall = nil
          @RBInstallIn = nil
        else
          @RBInstall = Wx::RadioButton.new(self, Wx::ID_ANY, "Install (#{iInstallPrefix}#{iInstallCommand})")
          lStrChoices = []
          iInstallChoices.each do |iInstallChoiceInfo|
            iInstallName, iInstallDir = iInstallChoiceInfo
            lStrChoices << "#{iInstallName} (#{iInstallDir})"
          end
          @RBInstallIn = Wx::RadioBox.new(self, Wx::ID_ANY, 'Install in',
            :choices => lStrChoices + [
              "Temporary directory (#{Dir.tmpdir})",
              'Other directory'
            ],
            :style => Wx::RA_SPECIFY_ROWS
          )
        end
        # list< String >
        lStrPluginsList = []
        iPluginsList.each do |iPluginKey|
          iPluginType, iPluginName = iPluginKey
          lStrPluginsList << "#{iPluginType}/#{iPluginName}"
        end
        lSTUsed = Wx::StaticText.new(self, Wx::ID_ANY, "Used by #{lStrPluginsList.sort.join(', ')}")

        # Put them into sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)

        lSBSizer = Wx::StaticBoxSizer.new(lSBMain, Wx::VERTICAL)

        lFirstLineSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        lFirstLineSizer.add_item(@SBStatus, :border => 8, :flag => Wx::ALIGN_CENTER|Wx::ALL, :proportion => 0)
        lFirstLineSizer.add_item(@RBIgnore, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        lFirstLineSizer.add_item(lRBDirectory, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        if (@RBInstall != nil)
          lFirstLineSizer.add_item(@RBInstall, :flag => Wx::ALIGN_CENTER, :proportion => 0)
        end

        lSBSizer.add_item(lFirstLineSizer, :flag => Wx::GROW, :proportion => 0)
        if (@RBInstallIn != nil)
          lSBSizer.add_item(@RBInstallIn, :flag => Wx::GROW, :proportion => 0)
        end
        lSBSizer.add_item(lSTUsed, :flag => Wx::GROW, :proportion => 0)

        lMainSizer.add_item(lSBSizer, :flag => Wx::GROW, :proportion => 1)

        self.sizer = lMainSizer
        self.fit

        # Set events
        # Click on "Ignore"
        evt_radiobutton(@RBIgnore) do |iEvent|
          # Choose to ignore the missing dependency
          setIgnore
        end
        # Click on "Choose a directory"
        evt_radiobutton(lRBDirectory) do |iEvent|
          # Choose a directory
          showModal(Wx::DirDialog, self,
            :message => "Open directory containing #{iDepName} library"
          ) do |iModalResult, iDialog|
            case iModalResult
            when Wx::ID_OK
              @ValidDirectory = nil
              # Test if this directory resolves the dependency
              lSuccess, lException = iDepHandler.testDirectory(iDepName, iDialog.path)
              if (lSuccess)
                # It's ok, we have a valid directory
                @ValidDirectory = iDialog.path
                @SBStatus.bitmap = ICON_OK
                if (@RBInstallIn != nil)
                  @RBInstallIn.show(false)
                  self.fit
                end
                @NotifierControl.notifyInstallDecisionChanged
                parent.fitComponents
              else
                logErr "Adding directory #{iDialog.path} does not help in using #{iDepName}: #{lException}"
                setIgnore
              end
            else
              setIgnore
            end
          end
        end
        if (@RBInstall != nil)
          # Click on "Install"
          evt_radiobutton(@RBInstall) do |iEvent|
            # Choose to install the missing dependency
            @ValidDirectory = nil
            @SBStatus.bitmap = ICON_DOWNLOAD
            @RBInstallIn.show(true)
            self.fit
            @NotifierControl.notifyInstallDecisionChanged
            parent.fitComponents
          end
          # Choose installation
          evt_radiobox(@RBInstallIn) do |iEvent|
            # Change the installation destination
            # The last item is always "Specify a directory to install"
            # The before the last item is always "Temporary directory"
            # All other items are the list given as input
            case @RBInstallIn.selection
            when @RBInstallIn.count - 1
              # The last one
              # Specify a directory to install to
              showModal(Wx::DirDialog, self,
                :message => "Install #{iDepName} library in directory"
              ) do |iModalResult, iDialog|
                case iModalResult
                when Wx::ID_OK
                  # Change install directory to iDialog.path
                  @InstallDir = iDialog.path
                else
                  @RBInstallIn.selection = 0
                  @InstallDir = iInstallChoices[0][1]
                end
              end
            when @RBInstallIn.count - 2
              # The before the last one
              @InstallDir = "#{Dir.tmpdir}/PBS_Dep_#{self.object_id}"
            else
              # Others
              @InstallDir = iInstallChoices[@RBInstallIn.selection][1]
            end
          end
        end

        # First state
        setIgnore(true)

      end

      # Set the panel to ignore decision
      #
      # Parameters:
      # * *iInitializing* (_Boolean_): Are we initializing ? In this case, we won't notify. [optional = false]
      def setIgnore(iInitializing = false)
        @ValidDirectory = nil
        @SBStatus.bitmap = ICON_KO
        @RBIgnore.value = true
        if (@RBInstallIn != nil)
          @RBInstallIn.show(false)
          self.fit
        end
        if (!iInitializing)
          @NotifierControl.notifyInstallDecisionChanged
        end
        parent.fitComponents
      end

      # Is this panel marked to be installed ?
      #
      # Return:
      # * _Boolean_: Is this panel marked to be installed ?
      def install?
        if (@RBInstall == nil)
          return false
        else
          return @RBInstall.value
        end

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
      # A standard directory is a directory where PBS will search for plugins by default (no need to remember such a directory in options).
      #
      # Return:
      # * _Boolean_: Does the installation location a standard directory ?
      def installDirStandard?
        if (@RBInstallIn == nil)
          return true
        else
          # Only the last item is non standard (choose an install directory)
          # The temporary directory will not be remembered (same behaviour as standard dirs)
          # All other choices are considered standard
          return (@RBInstallIn.selection != @RBInstallIn.count - 1)
        end
      end

      # Install the dependency
      #
      # Parameters:
      # * *ioProgressDialog* (<em>Wx::ProgressDialog</em>): The progress dialog to update (can be nil)
      # Return:
      # * _Boolean_: Success ?
      def performInstall(ioProgressDialog)
        logInfo "Installing dependency #{@DepName} in #{@InstallDir} (#{@InstallCommand})"
        rSuccess = @DepHandler.install(@DepName, @InstallDir, @InstallCommand, ioProgressDialog)
        if (rSuccess)
          logInfo 'Installation done successfully.'
        else
          logErr "Installing dependency \"#{@InstallCommand}\" ended in error. Please try to install it manually."
        end

        return rSuccess
      end

      # Get the real directories to add to the options after having performed an install
      #
      # Return:
      # * <em>list<String></em>: The directories to add
      def getDirectoriesToAdd
        return @DepHandler.getDirectoriesToAddAfterInstall(@DepName, @InstallDir, @InstallCommand)
      end

    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent window
    # * *iDepsList* (<em>map<String,[String,list<[String,String]>]></em>): The map of dependencies, along with their install command and the list of plugins ( [ type, name ] ) depending on this dependency
    # * *iNotifierControl* (_Object_): The notifier control that will be notified upon changes
    # * *iInstallChoices* (<em>list<[String,String]></em>): Possible directories (at least 1) to install to ( [ name, path ] ), or nil of installation is impossible
    # * *iDepHandler* (_Object_): The object that can handle the dependency operations (test if valid, install...)
    # * *iInstallPrefix* (_String_): The install prefix that will be added in front of the command for display only
    def initialize(iParent, iDepsList, iNotifierControl, iInstallChoices, iDepHandler, iInstallPrefix)
      super(iParent,
        :style => Wx::VSCROLL
      )

      # Mapping of dependency name to panel
      # map< String, DependencyLoaderPanel >
      @DepToPanels = {}
      # List of external directories needed to resolve some dependencies.
      # These are the directories that might be searched next time PBS is launched on this computer.
      # list< String >
      @ExternalDirectories = []

      @ScrollSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      # Create the panels
      # list< DependencyLoaderPanel >
      iDepsList.each do |iDepName, iDepInfo|
        iInstallCommand, iPluginsList = iDepInfo
        lDepPanel = nil
        if (iInstallChoices == nil)
          lDepPanel = DependencyLoaderPanel.new(
            self,
            iDepName,
            nil,
            iPluginsList,
            iNotifierControl,
            nil,
            iDepHandler,
            iInstallPrefix
          )
        else
          lDepPanel = DependencyLoaderPanel.new(
            self,
            iDepName,
            iInstallCommand,
            iPluginsList,
            iNotifierControl,
            iInstallChoices,
            iDepHandler,
            iInstallPrefix
          )
        end
        @DepToPanels[iDepName] = lDepPanel
        # Put in the sizer
        @ScrollSizer.add_item(lDepPanel, :border => 8, :flag => Wx::GROW|Wx::BOTTOM, :proportion => 0)
      end
      self.sizer = @ScrollSizer

      # Resize everything
      self.fit
      self.fit_inside
      
      # Add the size of scrollbars to the window's size, for them to not appear if not needed
      self.size = [
        self.size.width + Wx::SystemSettings.get_metric(Wx::SYS_VTHUMB_Y),
        self.size.height + Wx::SystemSettings.get_metric(Wx::SYS_HTHUMB_X)
      ]

      # Set the initial size for sizers to behave correctly
      self.initial_size = self.size

      # Set scrollbars
      set_scrollbars(1, 1, size.width, size.height)

    end

    # Return the number of dependencies to ignore and to install
    #
    # Return:
    # * _Integer_: Number of dependencies to ignore
    # * _Integer_: Number of dependencies to install
    def getIgnoreInstallCounters
      rNbrIgnore = 0
      rNbrInstall = 0

      @DepToPanels.each do |iDepName, iDepPanel|
        if (iDepPanel.install?)
          rNbrInstall += 1
        elsif (iDepPanel.ignore?)
          rNbrIgnore += 1
        end
      end

      return rNbrIgnore, rNbrInstall
    end

    # Return if a given dependency is marked to be installed
    #
    # Parameters:
    # * *iDepName* (_String_): The dependency name
    # Return:
    # * _Boolean_: Is it meant to be installed ?
    def depInstall?(iDepName)
      return @DepToPanels[iDepName].install?
    end

    # Return if a given dependency is marked to be ignored
    #
    # Parameters:
    # * *iDepName* (_String_): The dependency name
    # Return:
    # * _Boolean_: Is it meant to be ignored ?
    def depIgnore?(iDepName)
      return @DepToPanels[iDepName].ignore?
    end

    # Place the components correctly inside the sizers
    def fitComponents
      @ScrollSizer.fit_inside(self)
    end

    # Perform the install of the dependencies
    #
    # Parameters:
    # * *ioProgressDialog* (<em>Wx::ProgressDialog</em>): The progress dialog to update (can be nil)
    # * *iIdxInitialCount* (_Integer_): Initial progress count of the progress dialog
    # Return:
    # * <em>list<String></em>: List of additional directories resolving the dependencies
    # * <em>list<String></em>: List of dependencies that should be resolved
    def performApply(ioProgressDialog, iIdxInitialCount)
      rAdditionalDirs = []
      rResolvedDeps = []

      lIdxCount = iIdxInitialCount
      @DepToPanels.each do |iDepName, iDepPanel|
        if (iDepPanel.install?)
          if ((ioProgressDialog != nil) and
              (!ioProgressDialog.update(lIdxCount, "Installing #{iDepName} ...")))
            break
          end
          if (iDepPanel.performInstall(ioProgressDialog))
            # We installed it successfully
            rResolvedDeps << iDepName
            # Add the directory if it is not a standard one
            if (!iDepPanel.installDirStandard?)
              # Retrieve the installed directory
              rAdditionalDirs += iDepPanel.getDirectoriesToAdd
            end
          end
          lIdxCount += 1
        elsif (!iDepPanel.ignore?)
          # We have a valid directory
          rAdditionalDirs << iDepPanel.getValidDirectory
          rResolvedDeps << iDepName
        end
      end

      return rAdditionalDirs, rResolvedDeps
    end

  end

end
