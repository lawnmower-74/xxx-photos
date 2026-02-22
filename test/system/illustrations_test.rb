require "application_system_test_case"

class IllustrationsTest < ApplicationSystemTestCase
  setup do
    @illustration = illustrations(:one)
  end

  test "visiting the index" do
    visit illustrations_url
    assert_selector "h1", text: "Illustrations"
  end

  test "should create illustration" do
    visit illustrations_url
    click_on "New illustration"

    fill_in "Illustrator name", with: @illustration.illustrator_name
    fill_in "Shot at", with: @illustration.shot_at
    click_on "Create Illustration"

    assert_text "Illustration was successfully created"
    click_on "Back"
  end

  test "should update Illustration" do
    visit illustration_url(@illustration)
    click_on "Edit this illustration", match: :first

    fill_in "Illustrator name", with: @illustration.illustrator_name
    fill_in "Shot at", with: @illustration.shot_at
    click_on "Update Illustration"

    assert_text "Illustration was successfully updated"
    click_on "Back"
  end

  test "should destroy Illustration" do
    visit illustration_url(@illustration)
    click_on "Destroy this illustration", match: :first

    assert_text "Illustration was successfully destroyed"
  end
end
