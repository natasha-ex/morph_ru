defmodule MorphRuTest do
  use ExUnit.Case

  describe "parse/1" do
    test "parses стали into стать and сталь" do
      results = MorphRu.parse("стали")
      normal_forms = Enum.map(results, & &1.normal_form) |> Enum.uniq()
      assert "стать" in normal_forms
      assert "сталь" in normal_forms
    end

    test "parses московским" do
      results = MorphRu.parse("московским")
      assert results != []
      assert Enum.all?(results, &(&1.normal_form == "московский"))
    end

    test "parses сирота as ms-f gender" do
      results = MorphRu.parse("сирота")
      assert length(results) == 1
      result = hd(results)
      assert result.normal_form == "сирота"
      assert MorphRu.Tag.contains?(result.tag, "NOUN")
    end

    test "parses договора" do
      results = MorphRu.parse("договора")
      normal_forms = Enum.map(results, & &1.normal_form) |> Enum.uniq()
      assert normal_forms == ["договор"]
    end
  end

  describe "normal_forms/1" do
    test "returns lemmas for стали" do
      forms = MorphRu.normal_forms("стали")
      assert "стать" in forms
      assert "сталь" in forms
    end
  end

  describe "tag/1" do
    test "returns most likely tag" do
      tag = MorphRu.tag("договор")
      assert tag != nil
      assert MorphRu.Tag.contains?(tag, "NOUN")
      assert MorphRu.Tag.contains?(tag, "nomn")
    end
  end

  describe "word_is_known?/1" do
    test "known words" do
      assert MorphRu.word_is_known?("договор")
      assert MorphRu.word_is_known?("стали")
    end

    test "unknown words" do
      refute MorphRu.word_is_known?("фыва")
    end
  end
end
