#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # The conflicts panel options
  class ConflictsPanel < Wx::Panel

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent window
    def initialize(iParent)
      super(iParent)

      # Create components
      lSBTags = Wx::StaticBox.new(self, Wx::ID_ANY, 'Tags')
      @RBTagsKey = Wx::RadioBox.new(self, Wx::ID_ANY, 'Tags conflict key based on',
        :choices => [
          'None',
          'Name only',
          'Description (Name + Icon)'
        ],
        :style => Wx::RA_SPECIFY_ROWS
      )
      @RBTagsAction = Wx::RadioBox.new(self, Wx::ID_ANY, 'Action to take in case of Tags conflict',
        :choices => [
          'Ask user',
          'Merge using existing values',
          'Merge using conflicting values',
          'Cancel single conflict',
          'Cancel whole operation'
        ],
        :style => Wx::RA_SPECIFY_ROWS
      )
      lSBShortcuts = Wx::StaticBox.new(self, Wx::ID_ANY, 'Shortcuts')
      @RBShortcutsKey = Wx::RadioBox.new(self, Wx::ID_ANY, 'Shortcuts conflict key based on',
        :choices => [
          'None',
          'Name only',
          'Description (Name + Icon)',
          'Content (URL)',
          'Description and Content'
        ],
        :style => Wx::RA_SPECIFY_ROWS
      )
      @RBShortcutsAction = Wx::RadioBox.new(self, Wx::ID_ANY, 'Action to take in case of Shortcuts conflict',
        :choices => [
          'Ask user',
          'Merge using existing values',
          'Merge using conflicting values',
          'Cancel single conflict',
          'Cancel whole operation'
        ],
        :style => Wx::RA_SPECIFY_ROWS
      )

      # Put everything in sizers
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      # Each static box has a sizer
      lTagsSizer = Wx::StaticBoxSizer.new(lSBTags, Wx::HORIZONTAL)
      lTagsSizer.add_item(@RBTagsKey, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lTagsSizer.add_item(@RBTagsAction, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lShortcutsSizer = Wx::StaticBoxSizer.new(lSBShortcuts, Wx::HORIZONTAL)
      lShortcutsSizer.add_item(@RBShortcutsKey, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lShortcutsSizer.add_item(@RBShortcutsAction, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lMainSizer.add_item(lTagsSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      lMainSizer.add_item(lShortcutsSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 1)
      self.sizer = lMainSizer
      lMainSizer.fit(self)
    end

    # Set current components based on options
    #
    # Parameters:
    # * *iOptions* (<em>map<Symbol,Object></em>): Options
    def setOptions(iOptions)
      # Set default values based on the current options
      @RBTagsKey.selection = iOptions[:tagsUnicity]
      @RBShortcutsKey.selection = iOptions[:shortcutsUnicity]
      @RBTagsAction.selection = iOptions[:tagsConflict]
      @RBShortcutsAction.selection = iOptions[:shortcutsConflict]
    end

    # Fill the options from the components
    #
    # Parameters:
    # * *oOptions* (<em>map<Symbol,Object></em>): The options to fill
    def fillOptions(oOptions)
      oOptions[:tagsUnicity] = @RBTagsKey.selection
      oOptions[:shortcutsUnicity] = @RBShortcutsKey.selection
      oOptions[:tagsConflict] = @RBTagsAction.selection
      oOptions[:shortcutsConflict] = @RBShortcutsAction.selection
    end

  end

end
