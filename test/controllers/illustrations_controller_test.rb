require "test_helper"

class IllustrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @illustration = illustrations(:one)
  end

  test "should get index" do
    get illustrations_url
    assert_response :success
  end

  test "should get new" do
    get new_illustration_url
    assert_response :success
  end

  test "should create illustration" do
    assert_difference("Illustration.count") do
      post illustrations_url, params: { illustration: { illustrator_name: @illustration.illustrator_name, shot_at: @illustration.shot_at } }
    end

    assert_redirected_to illustration_url(Illustration.last)
  end

  test "should show illustration" do
    get illustration_url(@illustration)
    assert_response :success
  end

  test "should get edit" do
    get edit_illustration_url(@illustration)
    assert_response :success
  end

  test "should update illustration" do
    patch illustration_url(@illustration), params: { illustration: { illustrator_name: @illustration.illustrator_name, shot_at: @illustration.shot_at } }
    assert_redirected_to illustration_url(@illustration)
  end

  test "should destroy illustration" do
    assert_difference("Illustration.count", -1) do
      delete illustration_url(@illustration)
    end

    assert_redirected_to illustrations_url
  end
end
