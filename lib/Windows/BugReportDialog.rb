#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # About Dialog
  class BugReportDialog < Wx::Dialog

    include Tools

    BUG_ICON = Tools::loadBitmap('Bug.png')

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iMsg* (_String_): The bug message
    def initialize(iParent, iMsg)
      super(iParent,
        :title => 'Bug',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # Create components
      lSTMessage = Wx::StaticText.new(
        self,
        Wx::ID_ANY,
        "A bug has just occurred.
Normally you should never see this message, but PBS is not perfect.
We are sorry for the inconvenience caused.
If you want to help improving PBS, please inform us of this bug:
take the time to open a ticket at PBS bug tracker, or click the \"Send report\" button below.
We will always try our best to correct bugs.
Thanks.",
        :style => Wx::ALIGN_CENTRE
      )
      lTCMessage = Wx::TextCtrl.new(self, Wx::ID_ANY, '',
        :style => Wx::TE_MULTILINE|Wx::TE_READONLY|Wx::TE_RICH|Wx::TE_RICH2|Wx::TE_AUTO_URL
      )
      lTCMessage.append_text(iMsg)
      lTCMessage.set_selection(0, 0)
      lSBIcon = Wx::StaticBitmap.new(self, Wx::ID_ANY, BUG_ICON)
      lBClose = Wx::Button.new(self, Wx::ID_OK, 'Close')
      lBSend = Wx::Button.new(self, Wx::ID_ANY, 'Send Bug report')
      lHCTrackerURL = Wx::HyperlinkCtrl.new(self, Wx::ID_ANY, 'PBS Bug tracker', 'http://sourceforge.net/tracker/?group_id=261341&atid=1141657',
        :style => Wx::NO_BORDER|Wx::HL_ALIGN_CENTRE|Wx::HL_CONTEXTMENU
      )

      # Put everything in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)

      lTopSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lTopSizer.add_item(lSBIcon,
        :border => 4,
        :flag => Wx::ALIGN_CENTRE|Wx::ALL,
        :proportion => 0
      )

      lTopRightSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      lTopRightSizer.add_item(lSTMessage, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lTopRightSizer.add_item(lTCMessage, :flag => Wx::GROW, :proportion => 1)

      lTopSizer.add_item(lTopRightSizer, :flag => Wx::GROW, :proportion => 1)

      lBottomSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      lBottomSizer.add_item(lHCTrackerURL, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lBottomSizer.add_item([8,0], :proportion => 1)
      lBottomSizer.add_item(lBSend, :flag => Wx::ALIGN_CENTRE, :proportion => 0)
      lBottomSizer.add_item(lBClose, :flag => Wx::ALIGN_CENTRE, :proportion => 0)

      lMainSizer.add_item(lTopSizer, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(lBottomSizer,
        :border => 4,
        :flag => Wx::GROW|Wx::ALL,
        :proportion => 0
      )

      self.sizer = lMainSizer

      self.fit

      # Events
      evt_button(lBClose) do |iEvent|
        self.end_modal(Wx::ID_OK)
      end
      evt_button(lBSend) do |iEvent|
        # TODO: Implement it
        showModal(Wx::MessageDialog, self,
          'This is not implemented yet. Sorry. Please use the link to the bug tracker and copy/paste the content of this bug in it. Thanks.',
          :style => Wx::ID_OK
        ) do |iModalResult, iDialog|
          # Nothing to do
        end
      end

    end

  end

end
