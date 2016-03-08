# encoding: utf-8

module WatchfulGuerilla
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a WatchfulGuerilla gem configuration file at config/watchful_guerilla.yml, and an initializer at config/initializers/watchful_guerilla.rb'

      def self.source_root
        @_rcb_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def create_config_file
        template 'watchful_guerilla.yml', File.join('config', 'watchful_guerilla.yml')
      end

      def create_initializer_file
        template 'initializer.rb', File.join('config', 'initializers', 'watchful_guerilla.rb')
      end
    end
  end
end
