require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login page explains when github oauth is not configured" do
    with_env("GITHUB_CLIENT_ID" => nil, "GITHUB_CLIENT_SECRET" => nil) do
      get "/login"
    end

    assert_response :success
    assert_match "GitHub OAuth is not configured", response.body
    assert_match "GITHUB_CLIENT_ID", response.body
  end

  test "auth entrypoint redirects back to login when github oauth is not configured" do
    with_env("GITHUB_CLIENT_ID" => nil, "GITHUB_CLIENT_SECRET" => nil) do
      get "/auth/github"
    end

    assert_redirected_to "/login"
    follow_redirect!

    assert_response :success
    assert_match "GitHub OAuth is not configured", response.body
  end
end
