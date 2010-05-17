# encoding: utf-8
#--
# (c) Copyright 2008, 2010 Mikael Lammentausta
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require "rexml/document"

module Caterpillar
  # Formulates generic JSR286 portlet XML
  class Portlet
    class << self

    # Rails-portlet Java class
    def portlet_class
      'com.celamanzi.liferay.portlets.rails286.Rails286Portlet'
    end

    # Rails-portlet Java class for 0.10.0+
    def portlet_filter_class
      'com.celamanzi.liferay.portlets.rails286.Rails286PortletFilter'
    end

    # Creates <portlet-app> XML document for portlet-ext.xml.
    #
    # @param portlets is an Array of Hashes
    # @returns String
    def xml(portlets)
      # create a new XML document
      doc = REXML::Document.new
      doc << REXML::XMLDecl.new('1.0', 'utf-8') 
      app = REXML::Element.new('portlet-app', doc)
      app.attributes['version'] = '2.0'
      app.attributes['xmlns'] = 'http://java.sun.com/xml/ns/portlet/portlet-app_2_0.xsd'
      app.attributes['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
      app.attributes['xsi:schemaLocation'] = 'http://java.sun.com/xml/ns/portlet/portlet-app_2_0.xsd'

      # create session values, common for all portlets
      session = 
        begin
          {
            :key    => Caterpillar::Security.get_session_key(),
            :secret => Caterpillar::Security.get_secret()
          }
        rescue nil
        end

      # create XML element tree
      portlets.each do |portlet|
        # <portlet>
        app.elements << self.portlet_element(portlet,session)
        # <filter>
        app.elements << self.filter_element(portlet)
        # filter mapping
        app.elements << self.filter_mapping(portlet)
      end
      xml = ''
      doc.write(xml, -1) # no indentation, tag and text should be on same line
      return xml.gsub('\'', '"') # fix rexml attribute single quotes to double quotes
    end

    # <portlet> element.
    # session is a hash containing session key and secret from Rails.
    def portlet_element(portlet,session=nil)
      element = REXML::Element.new('portlet')
      # NOTE: to pass validation, the elements need to be in proper order!

      REXML::Element.new('portlet-name', element).text = portlet[:name]
      REXML::Element.new('portlet-class', element).text = self.portlet_class

      # insert session key
      unless session.nil?
        param = REXML::Element.new('init-param', element)
        REXML::Element.new('name', param).text = 'session_key'
        REXML::Element.new('value', param).text = session[:key]

        param = REXML::Element.new('init-param', element)
        REXML::Element.new('name', param).text = 'secret'
        REXML::Element.new('value', param).text = session[:secret]
      end

      supports = REXML::Element.new('supports', element)
      REXML::Element.new('mime-type', supports).text = 'text/html'
      ### supported portlet modes
      REXML::Element.new('portlet-mode', supports).text = 'view'
      if portlet[:edit_mode] == true
        REXML::Element.new('portlet-mode', supports).text = 'edit'
      end

      info = REXML::Element.new('portlet-info', element)
      ### title for portlet container
      REXML::Element.new('title', info).text = portlet[:title]

      # add roles
      # TODO: move into portlet hash
      # administrator, power-user, user
      roles = %w{ administrator }
      roles.each do |role|
        ref = REXML::Element.new('security-role-ref', element)
        REXML::Element.new('role-name', ref).text = role
      end

      return element
    end

    # <filter> element.
    def filter_element(portlet)
      # the filter reads the settings and sets the portlet session
      element = REXML::Element.new('filter')

      REXML::Element.new('filter-name', element).text = portlet[:name] + '_filter'
      REXML::Element.new('filter-class', element).text = self.portlet_filter_class
      REXML::Element.new('lifecycle', element).text = 'RENDER_PHASE'
      REXML::Element.new('lifecycle', element).text = 'RESOURCE_PHASE'

      # define host, servlet and route (path to be more precise)
      param = REXML::Element.new('init-param', element)
      REXML::Element.new('name', param).text = 'host'
      REXML::Element.new('value', param).text = portlet[:host]

      param = REXML::Element.new('init-param', element)
      REXML::Element.new('name', param).text = 'servlet'
      REXML::Element.new('value', param).text = portlet[:servlet]

      param = REXML::Element.new('init-param', element)
      REXML::Element.new('name', param).text = 'route'
      REXML::Element.new('value', param).text =  portlet[:path].gsub(/&/,"&amp;")

      return element
    end

    # <filter-mapping> element.
    def filter_mapping(portlet)
      element = REXML::Element.new('filter-mapping')

      REXML::Element.new('filter-name', element).text = portlet[:name] + '_filter'
      REXML::Element.new('portlet-name', element).text = portlet[:name]

      return element
    end

    def debug(config,routes) # :nodoc:
      routes.select{|r| !r[:name].empty?}.each do |route|
        puts '%s: %s' % [route[:name], route[:path]]
      end
    end

  end # static methods
  end
end
