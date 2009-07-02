#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # About Dialog
  class AboutDialog < Wx::Dialog

    ABOUT_ICON = Tools::loadBitmap('Icon72.png')

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    def initialize(iParent)
      super(iParent,
        :title => 'About PBS',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # Create components
      lTCMessage = Wx::TextCtrl.new(self, Wx::ID_ANY, '',
        :style => Wx::TE_MULTILINE|Wx::TE_READONLY|Wx::TE_RICH|Wx::TE_RICH2|Wx::TE_AUTO_URL
      )
      lTCMessage.append_text("PBS: Portable Bookmarks and Shortcuts

Planning, Development, Testing, Documentation:
Muriel Salvan - http://murielsalvan.users.sourceforge.net

This software is provided Free and Open Source - http://www.opensource.org -, under the BSD license - http://www.freebsd.org/copyright/license.html -.

Changelog:

v 0.0.1.20090430
* Initial release
")
      lTCMessage.set_selection(0, 0)
      evt_text_url(lTCMessage) do |iEvent|
        if (iEvent.mouse_event.button(Wx::MOUSE_BTN_LEFT))
          IO.popen("start #{iEvent.url}")
        end
      end
      lSBIcon = Wx::StaticBitmap.new(self, Wx::ID_ANY, ABOUT_ICON)
      lSTTitle = Wx::StaticText.new(self, Wx::ID_ANY, "PBS\nPortable\nBookmarks\nand\nShortcuts",
        :style => Wx::ALIGN_CENTRE
      )
      lSTVersion = Wx::StaticText.new(self, Wx::ID_ANY, "v #{$PBS_VERSION}")
      lSTVersionTags = Wx::StaticText.new(self, Wx::ID_ANY, $PBS_VERSION_TAGS.join(', '))
      lBClose = Wx::Button.new(self, Wx::ID_OK, 'Close')
      lHCPBSURL = Wx::HyperlinkCtrl.new(self, Wx::ID_ANY, 'PBS home page', 'http://pbstool.sourceforge.net',
        :style => Wx::NO_BORDER|Wx::HL_ALIGN_CENTRE|Wx::HL_CONTEXTMENU
      )
      lHCDonationsURL = Wx::HyperlinkCtrl.new(self, Wx::ID_ANY, 'Donate to PBS', 'http://sourceforge.net/donate/index.php?group_id=261341',
        :style => Wx::NO_BORDER|Wx::HL_ALIGN_CENTRE|Wx::HL_CONTEXTMENU
      )

      # Put everything in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)

      lTopSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)

      lTitleSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lTitleSizer.add_item(lSBIcon, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lTitleSizer.add_item([0,16], :proportion => 0)
      lTitleSizer.add_item(lSTTitle, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lTitleSizer.add_item([0,16], :proportion => 0)
      lTitleSizer.add_item(lSTVersion, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lTitleSizer.add_item(lSTVersionTags, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

      lTopSizer.add_item(lTitleSizer,
        :border => 4,
        :flag => Wx::ALIGN_CENTRE|Wx::ALL,
        :proportion => 0
      )
      lTopSizer.add_item(lTCMessage, :flag => Wx::GROW, :proportion => 1)

      lBottomSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)

      lURLSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lURLSizer.add_item(lHCPBSURL, :flag => Wx::ALIGN_LEFT, :proportion => 0)
      lURLSizer.add_item(lHCDonationsURL, :flag => Wx::ALIGN_LEFT, :proportion => 0)

      lBottomSizer.add_item(lURLSizer, :flag => Wx::ALIGN_CENTRE, :proportion => 1)
      lBottomSizer.add_item(lBClose, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

      lMainSizer.add_item(lTopSizer, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(lBottomSizer,
        :border => 4,
        :flag => Wx::GROW|Wx::ALL,
        :proportion => 0
      )

      self.sizer = lMainSizer

      # Events
      evt_button(lBClose) do |iEvent|
        self.end_modal(Wx::ID_OK)
      end

    end

  end

end
