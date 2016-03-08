WatchfulGuerilla.configure do |config|
  config_file_path = File.join(Rails.root, 'config', 'watchful_guerilla.yml')
  environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || 'development'

  @config_file = YAML::load_file(config_file_path)
  @env_config = (@config_file['default'] || {}).merge(@config_file[environment] || {})

  # Tell if the block stack should output while measuring. Defaults to false
  # config.tracing                false

  # Tell if profiling blocks are active. Defaults to false
  # config.profiling              false

  # Tell if measuring blocks are active. Defaults to false
  # config.measuring              false

  # Tell minimum threshold of milliseconds required for a block to be considered long running
  # config.reporting_threshold              = false

end