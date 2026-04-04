ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

unless ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development")) == "production"
  begin
    require "dotenv"

    app_root = File.expand_path("..", __dir__)
    Dotenv.load(File.join(app_root, ".env.local"), File.join(app_root, ".env"))

    # Keep local defaults safe when .env is copied from .env.example unchanged.
    ENV.delete("RAILS_MASTER_KEY") if ENV["RAILS_MASTER_KEY"] == "replace_me"
  rescue LoadError
    # Dotenv is optional outside development and test.
  end
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
