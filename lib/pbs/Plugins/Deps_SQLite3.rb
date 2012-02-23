#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Get the dependency description of SQLite3
  #
  # Return::
  # * <em>list<RDI::Model::DependencyDescription></em>: The dependencies descriptions
  def self.getSQLite3Dependencies
    rDeps = [ RDI::Model::DependencyDescription.new('Ruby-SQLite3').add_description( {
        :Testers => [
          {
            :Type => 'RubyRequires',
            :Content => [ 'sqlite3' ]
          }
        ],
        :Installers => [
          {
            :Type => 'Gem',
            :Content => 'sqlite3-ruby --version 1.2.3',
            :ContextModifiers => [
              {
                :Type => 'GemPath',
                :Content => '%INSTALLDIR%'
              }
            ]
          }
        ]
      } )
      ]

    lLibDepDesc = nil
    case os
    when OS_WINDOWS
      lLibDepDesc = {
        :Testers => [
          {
            :Type => 'DynamicLibraries',
            :Content => [ 'sqlite3.dll' ]
          }
        ],
        :Installers => [
          {
            :Type => 'Download',
            :Content => 'http://www.sqlite.org/sqlitedll-3_6_15.zip',
            :ContextModifiers => [
              {
                :Type => 'LibraryPath',
                :Content => '%INSTALLDIR%'
              }
            ]
          }
        ]
      }
    # TODO: Specify for other OS
    end
    if (lLibDepDesc != nil)
      rDeps << RDI::Model::DependencyDescription.new('SQLite 3 Library').add_description(lLibDepDesc)
    end

    return rDeps
  end

end