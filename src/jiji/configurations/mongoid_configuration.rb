# frozen_string_literal: true

require 'mongoid'
require 'yaml'
require 'uri'
require 'jiji/utils/requires'

mongoid_setting_file = "#{Jiji::Utils::Requires.root}/config/mongoid.yml"

Mongoid.logger.level = Logger::WARN
Mongo::Logger.logger.level = Logger::WARN

if ENV['MONGOLAB_URI'] || ENV['MONGODB_URI']
  u = URI.parse(ENV['MONGOLAB_URI'] || ENV['MONGODB_URI'])

  config = YAML.load_file(mongoid_setting_file)['default']
  sessions = config['clients']['default']
  sessions['hosts']    = [u.host + ':' + (u.port ? u.port.to_s : '')]
  sessions['database'] = u.path.gsub(%r{/}, '')
  sessions['options']  = sessions['options'] || {}
  sessions['options']['user'] = u.user || nil
  sessions['options']['password'] = u.password || nil
  Mongoid.load_configuration(config)
else
  Mongoid.load!(mongoid_setting_file, ENV['RACK_ENV'] || :production)
end
