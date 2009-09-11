#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Dialog that chooses an icon
  class ChooseIconDialog < Wx::Dialog

    COLOUR_BTNFACE = Wx::SystemSettings::get_colour(Wx::SYS_COLOUR_BTNFACE)
    COLOUR_BTNSHADOW = Wx::SystemSettings::get_colour(Wx::SYS_COLOUR_BTNSHADOW)

    MAX_ICON_WIDTH = 64
    MAX_ICON_HEIGHT = 64

    # Class representing the content of the grid
    class IconsGrid < Wx::GridTableBase

      # Constructor
      #
      # Parameters:
      # * *iGrid* (<em>Wx::Grid</em>): The grid that will use this GridTableBase
      # * *iBitmapsList* (<em>list<Wx::Bitmap></em>): The list of bitmaps to represent
      def initialize(iGrid, iBitmapsList)
        super()
        @Grid = iGrid
        @BitmapsList = iBitmapsList
      end

      # Return the number of columns
      #
      # Return:
      # * _Integer_: Number of columns
      def get_number_cols
        # Depends on the total number of bitmaps to display and the number of rows
        return (@BitmapsList.size/get_number_rows) + 1
      end

      # Return the number of rows
      #
      # Return:
      # * _Integer_: Number of rows
      def get_number_rows
        # Depends on the height of the grid, and the space allocated to each row
        rNbrRows = @Grid.size.height/@Grid.default_row_size

        if (rNbrRows < 1)
          rNbrRows = 1
        end

        return rNbrRows
      end

      # Return the type name of the cell
      #
      # Parameters:
      # * *iRow* (_Integer_): The row number
      # * *iCol* (_Integer_): The column number
      # Return:
      # * _String_: Data type name
      def get_type_name(iRow, iCol)
        return 'Wx::Bitmap'
      end

      # Returns if a given cell is empty
      #
      # Parameters:
      # * *iRow* (_Integer_): The row number
      # * *iCol* (_Integer_): The column number
      # Return:
      # * _Boolean_: Is the cell empty ?
      def is_empty_cell(iRow, iCol)
        return true
      end

      # Return the attribute of a given cell.
      # I don't really get why this is useful yet. However it asks for it.
      #
      # Parameters:
      # * *iRow* (_Integer_): The row number
      # * *iCol* (_Integer_): The column number
      # * *iAttrKind* (_Integer_): The kind of attribute to return
      # Return:
      # * <em>Wx::GridCellAttr</em>: The corresponding attribute
      def get_attr(iRow, iCol, iAttrKind)
        return Wx::GridCellAttr.new(
          COLOUR_BTNFACE,
          COLOUR_BTNFACE,
          @Grid.font,
          Wx::ALIGN_CENTER,
          Wx::ALIGN_CENTER
        )
      end

    end

    # Class that renders icons in a grid
    # We have to inherit from the StringRenderer, as inheriting from the normal renderer does not work: we can't instantiate the class afterwards (Allocator undefined). Bug ?
    class IconsGridRenderer < Wx::GridCellStringRenderer

      # Constructor
      #
      # Parameters:
      # * *iGrid* (<em>Wx::Grid</em>): The grid using this renderer
      # * *iBitmapsList* (<em>list<Wx::Bitmap></em>): The list of bitmaps to represent
      def initialize(iGrid, iBitmapsList)
        super()
        @Grid = iGrid
        @BitmapsList = iBitmapsList
      end

      # Draw the icon
      #
      # Parameters:
      # * *iGrid* (<em>Wx::Grid</em>): The grid that is rendering the item
      # * *iAttr* (<em>Wx::GridCellAttr</em>): The grid cell attribute
      # * *ioDC* (<em>Wx::DC</em>): The device context used to draw
      # * *iRect* (<em>Wx::Rect</em>): The bounding rectangle to draw
      # * *iRow* (_Integer_): The row number
      # * *iCol* (_Integer_): The column number
      # * *iIsSelected* (_Boolean_): Is the cell selected ?
      def draw(iGrid, iAttr, ioDC, iRect, iRow, iCol, iIsSelected)
        # Don't call the inherited draw, as no get_value method has been defined in the corresponding GridTableBase object.
        if ((@Grid.grid_cursor_col == iCol) and
            (@Grid.grid_cursor_row == iRow))
          ioDC.brush = Wx::Brush.new(COLOUR_BTNSHADOW)
          ioDC.pen = Wx::Pen.new(COLOUR_BTNSHADOW)
        else
          ioDC.brush = Wx::Brush.new(COLOUR_BTNFACE)
          ioDC.pen = Wx::Pen.new(COLOUR_BTNFACE)
        end
        ioDC.draw_rectangle(iRect.x, iRect.y, iRect.width, iRect.height)
        # First compute the index of the bitmap represented
        lIdxBitmap = iCol*@Grid.number_rows + iRow
        if (lIdxBitmap < @BitmapsList.size)
          lBitmap = @BitmapsList[lIdxBitmap]
          ioDC.draw_bitmap(
            lBitmap,
            iRect.x + (iRect.width-lBitmap.width)/2,
            iRect.y + (iRect.height-lBitmap.height)/2,
            true
          )
        end
      end

    end

    # Create a Bitmap from a file.
    # This method resizes eventually the bitmap to fit the maximal size.
    #
    # Parameters:
    # * *iFileName* (_String_): The file name
    # Return:
    # * <em>Wx::Bitmap</em>: The Bitmap, or nil if error
    def createBitmapFromFile(iFileName)
      rBitmap, lError = getBitmapFromURL(iFileName)

      if (rBitmap == nil)
        logErr "Error while getting bitmap from #{iFileName}: #{lError}"
      else
        lNewWidth = rBitmap.width
        if (rBitmap.width > MAX_ICON_WIDTH)
          lNewWidth = MAX_ICON_WIDTH
        end
        lNewHeight = rBitmap.height
        if (rBitmap.height > MAX_ICON_HEIGHT)
          lNewHeight = MAX_ICON_HEIGHT
        end
        if ((rBitmap.width > lNewWidth) or
            (rBitmap.height > lNewHeight))
          # We have to resize the bitmap to lNewWidth/lNewHeight
          rBitmap = Wx::Bitmap.from_image(rBitmap.convert_to_image.scale(lNewWidth, lNewHeight))
        end
      end

      return rBitmap
    end

    # Create the buttons panel
    #
    # Parameters:
    # * *iParent* (_Window_): The parent window
    # Return:
    # * _Panel_: The panel containing controls
    def createButtonsPanel(iParent)
      rResult = Wx::Panel.new(iParent)

      # Create buttons
      lBAdd = Wx::Button.new(rResult, Wx::ID_ANY, 'Add ...')
      lBOK = Wx::Button.new(rResult, Wx::ID_OK, 'OK')
      lBCancel = Wx::Button.new(rResult, Wx::ID_CANCEL, 'Cancel')

      # Put them in sizers
      lMainSizer = Wx::StdDialogButtonSizer.new
      rResult.sizer = lMainSizer
      lMainSizer.add_button(lBAdd)
      lMainSizer.add_button(lBOK)
      lMainSizer.add_button(lBCancel)
      lMainSizer.realize

      # Event for the add button
      evt_button(lBAdd) do |iEvent|
        # Open a file to add icons in the list
        showModal(Wx::FileDialog, self,
          :message => 'Open image',
          :style => Wx::FD_OPEN|Wx::FD_FILE_MUST_EXIST,
          :wildcard => 'All files (*)|*'
        ) do |iModalResult, iDialog|
          case iModalResult
          when Wx::ID_OK
            begin
              lBitmap = createBitmapFromFile(iDialog.path)
              if (lBitmap != nil)
                @BitmapsList << lBitmap
                notifyBitmapsListChanged
              else
                logErr "Error while reading file #{iDialog.path}: #{$!}. Ignoring this file."
              end
            rescue
              logErr "Error while reading file #{iDialog.path}: #{$!}. Ignoring this file."
            end
          end
        end
      end

      return rResult
    end

    # Get the selected icon.
    # If it is the same as the previously set one, it returns nil
    #
    # Return:
    # * <em>Wx::Bitmap</em>: The bitmap
    def getSelectedBitmap
      if ((@GIcons.grid_cursor_row == 0) and
          (@GIcons.grid_cursor_col == 0))
        return nil
      else
        return getBitmapAtPos(@GIcons.grid_cursor_row, @GIcons.grid_cursor_col)
      end
    end

    # Get the bitmap at a given Row/Col position
    #
    # Parameters:
    # * *iRow* (_Integer_): The row number
    # * *iCol* (_Integer_): The column number
    # Return:
    # * <em>Wx::Bitmap</em>: The selected bitmap, or nil if none
    def getBitmapAtPos(iRow, iCol)
      rBitmap = nil

      lIdxBitmap = @GIcons.number_rows*iCol + iRow
      if (lIdxBitmap < @BitmapsList.size)
        rBitmap = @BitmapsList[lIdxBitmap]
      end

      return rBitmap
    end

    # Refresh the Grid after a change of size
    def refreshGrid
      # Get which index was selected
      lIdxOldSelection = @GIcons.grid_cursor_col*@GIcons.number_rows+@GIcons.grid_cursor_row
      # Don't try to reuse the old IconsGrid (even if it has not changed), as it will result in a SegFault. Bug ?
      @GIcons.table = IconsGrid.new(@GIcons, @BitmapsList)
      # Reselect the same index
      lRow = lIdxOldSelection % @GIcons.number_rows
      lCol = lIdxOldSelection/@GIcons.number_rows
      @GIcons.set_grid_cursor(lRow, lCol)
    end

    # Notify that the bitmaps list has changed
    def notifyBitmapsListChanged
      # Compute maximal width/height
      lMaxHeight = 0
      lMaxWidth = 0
      @BitmapsList.each do |iBitmap|
        if (lMaxHeight < iBitmap.height)
          lMaxHeight = iBitmap.height
        end
        if (lMaxWidth < iBitmap.width)
          lMaxWidth = iBitmap.width
        end
      end
      # We set the row and column sizes
      @GIcons.set_default_col_size(lMaxWidth + 4, true)
      @GIcons.set_default_row_size(lMaxHeight + 4, true)
      refreshGrid
    end

    # Constructor
    #
    # Parameters:
    # * *iParent* (<em>Wx::Window</em>): The parent
    # * *iIcon* (<em>Wx::Bitmap</em>): The initial icon
    def initialize(iParent, iIcon)
      super(iParent,
        :title => 'Choose icon',
        :style => Wx::DEFAULT_DIALOG_STYLE|Wx::RESIZE_BORDER|Wx::MAXIMIZE_BOX
      )

      # Create the bitmaps list that store icons to display
      # Always add the default one first
      # TODO: For performance reasons, keep this list in a class variable: this will avoid reading files several times, and it will also reuse previously added icons. However we still have to add the current icon at first place (and replace previous first place by doing it).
      @BitmapsList = [iIcon]
      # Parse all files in the Graphics dir to add some others
      Dir.glob("#{$PBS_GraphicsDir}/*") do |iFileName|
        begin
          @BitmapsList << createBitmapFromFile(iFileName)
        rescue Exception
          # Happens if a file not understandeable by Wx::Bitmap appears in the directory. Nothing serious.
          logErr "Error while reading file #{iFileName}: #{$!}. Ignoring this file."
        end
      end

      # First create all the panels that will fit in this dialog
      @GIcons = Wx::Grid.new(self)
      # We set the bitmap data renderer instead of the default text one
      @GIcons.register_data_type('Wx::Bitmap', IconsGridRenderer.new(@GIcons, @BitmapsList), nil)
      # We select the first icon, as it will is the current one
      @GIcons.set_grid_cursor(0, 0)
      # We noyify the bitmaps list has changed, to set the row and column sizes
      notifyBitmapsListChanged
      # We set everything read-only
      @GIcons.disable_cell_edit_control
      @GIcons.disable_drag_col_move
      @GIcons.disable_drag_col_size
      @GIcons.disable_drag_grid_size
      @GIcons.disable_drag_row_size
      @GIcons.enable_editing(false)
      @GIcons.enable_grid_lines(false)
      # We hide the labels
      @GIcons.col_label_size = 0
      @GIcons.row_label_size = 0
      # We set the background color
      @GIcons.default_cell_background_colour = COLOUR_BTNFACE
      # Force a single selection
      lDeselecting = false
      @GIcons.evt_grid_cell_left_click do |iEvent|
        lBitmap = getBitmapAtPos(iEvent.row, iEvent.col)
        if (lBitmap == nil)
          iEvent.veto
        else
          @GIcons.clear_selection
          @GIcons.set_grid_cursor(iEvent.row, iEvent.col)
          @GIcons.refresh
        end
      end
      @GIcons.evt_grid_range_select do |iEvent|
        if (!lDeselecting)
          lDeselecting = true
          @GIcons.clear_selection
          lDeselecting = false
        end
      end

      # The underlying buttons
      lButtonsPanel = createButtonsPanel(self)

      # Then put everything in place using sizers
      # Create the main sizer
      lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
      self.sizer = lMainSizer
      lMainSizer.add_item(@GIcons, :flag => Wx::GROW, :proportion => 1)
      lMainSizer.add_item(lButtonsPanel, :flag => Wx::GROW|Wx::ALL, :border => 8, :proportion => 0)

      # On resize, we have to reorganize the bitmaps
      evt_size do |iEvent|
        iEvent.skip
        refreshGrid
      end

      # Fit the window correctly
      fit
      if (size.width > 600)
        self.size = [600,400]
        refreshGrid
      end

    end

  end

end
