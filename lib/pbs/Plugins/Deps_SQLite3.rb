#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Get the dependency description of SQLite3
  #
  # Return:
  # * <em>list<RDI::Model::DependencyDescription></em>: The dependencies descriptions
  def self.getSQLite3Dependencies
    lLibDepDesc = nil
    case $rUtilAnts_Platform_Info.os
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
    return [
      RDI::Model::DependencyDescription.new('Ruby-SQLite3').addDescription( {
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
    } ),
      RDI::Model::DependencyDescription.new('SQLite 3 Library').addDescription(lLibDepDesc)
    ]
  end

end