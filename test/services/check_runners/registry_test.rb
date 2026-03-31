require "test_helper"

module CheckRunners
  class RegistryTest < ActiveSupport::TestCase
    test "returns registered runner for http type" do
      runner = CheckRunners::Registry.fetch("http")

      assert_equal CheckRunners::HttpRunner, runner
    end

    test "raises key error for unknown type" do
      error = assert_raises(KeyError) do
        CheckRunners::Registry.fetch("unknown-check")
      end

      assert_match("unknown-check", error.message)
    end
  end
end
