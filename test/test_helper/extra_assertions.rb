# frozen_string_literal: true

module ExtraAssertions
  def assert_translation_missing_message(translation_key:)
    assert_translation_missing(translation_key: translation_key, field: "message")
  end

  def assert_translation_missing_error(translation_key:)
    assert_translation_missing(translation_key: translation_key, field: "error")
  end

  def assert_translation_missing(translation_key:, field:)
    assert_equal [field], response.parsed_body.keys
    assert_match(/^translation missing/i, response.parsed_body[field])
    assert_equal true, response.parsed_body[field].include?(translation_key)
  end
end
