# encoding: utf-8

module WG
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a WG gem configuration file at config/w_g.yml, and an initializer at config/initializers/w_g.rb'

      def self.source_root
        @_rcb_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def create_config_file
        template 'w_g.yml', File.join('config', 'w_g.yml')
      end

      def create_initializer_file
        template 'initializer.rb', File.join('config', 'initializers', 'w_g.rb')
      end
    end
  end
end
