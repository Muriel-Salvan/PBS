#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Temp directory is used to eventually copy the database file if it is in use.
require 'tmpdir'

module PBS

  # Module defining some handy methods for use with SQLite3
  module Tools_SQLite3

    # This class encapsulates a SQLite3 DB.
    # Its added value is to try copying database files in temporary files before opening them in the case they are already in use by another application (useful to open FireFox db for example with FireFox opened).
    class SQLite3DB
      
      # Underlying Sqlite3 database object
      #   SQLite3::Database
      attr_reader :DB
      
      # Constructor
      #
      # Parameters:
      # * *iFileName* (_String_): File containing the db
      def initialize(iFileName)
        @TmpFileName = nil
        @DB = SQLite3::Database.new(iFileName)
        begin
          # Issue a single select to test if the database is in use
          @DB.execute("SELECT * FROM sqlite_master LIMIT 1")
        rescue SQLite3::BusyException
          # The database is in use.
          # Try copying the file in another place.
          @TmpFileName = "#{Dir.tmpdir}/DB_#{self.object_id}.sqlite"
          FileUtils::cp(iFileName, @TmpFileName)
          # Try again
          @DB.close
          @DB = SQLite3::Database.new(@TmpFileName)
        end
      end
      
      # Finalize the DB object.
      def final
        @DB.close
        # Remove eventually temporary file
        if (@TmpFileName != nil)
          File.unlink(@TmpFileName)
        end
      end
      
    end

    # Open a SQLite3 DB and calls some code on it
    # If the DB is in use, it copies into a temporary file before opening it.
    # It also ensures the DB is closed at the end,
    #
    # Parameters:
    # * *iFileName* (_String_): File containing the db
    # * *CodeBlock*: The code called with the db opened:
    # ** *ioDB* (<em>SQLite3::Database</em>): The DB object
    def openSQLite3DB(iFileName)
      lDB = SQLite3DB.new(iFileName)
      yield(lDB.DB)
      lDB.final
    end

  end

end