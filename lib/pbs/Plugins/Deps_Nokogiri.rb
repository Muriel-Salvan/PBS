#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module PBS

  # Get the dependency description of Nokogiri
  #
  # Return::
  # * <em>RDI::Model::DependencyDescription</em>: The dependency description
  def self.getNokogiriDepDesc
    return RDI::Model::DependencyDescription.new('Nokogiri').addDescription( {
      :Testers => [
        {
          :Type => 'RubyRequires',
          :Content => [ 'nokogiri' ]
        }
      ],
      :Installers => [
        {
          :Type => 'Gem',
          :Content => 'nokogiri',
          :ContextModifiers => [
            {
              :Type => 'GemPath',
              :Content => '%INSTALLDIR%'
            }
          ]
        }
      ]
    } )
  end

end