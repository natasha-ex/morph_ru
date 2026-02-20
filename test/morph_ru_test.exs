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
      assert MorphRu.Tag.contains?(tag, "masc")
    end
  end

  describe "scoring" do
    test "стали VERB gets highest score" do
      [top | _] = MorphRu.parse("стали")
      assert top.normal_form == "стать"
      assert MorphRu.Tag.contains?(top.tag, "VERB")
      assert top.score > 0.9
    end

    test "scores match Python pymorphy3" do
      results = MorphRu.parse("стали")
      verb = Enum.find(results, &(&1.normal_form == "стать"))
      assert_in_delta verb.score, 0.975342, 0.001
    end
  end

  describe "inflect/2" do
    test "inflects дом to genitive" do
      [parse | _] = MorphRu.parse("дом")
      result = MorphRu.inflect(parse, ["gent"])
      assert result.word == "дома"
    end

    test "inflects дом to plural dative" do
      [parse | _] = MorphRu.parse("дом")
      result = MorphRu.inflect(parse, ["plur", "datv"])
      assert result.word == "домам"
    end

    test "returns nil for impossible inflection" do
      [parse | _] = MorphRu.parse("стол")
      result = MorphRu.inflect(parse, ["femn"])
      assert result == nil
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

  describe "prediction (unknown words)" do
    test "predicts путинизм as NOUN,masc" do
      refute MorphRu.word_is_known?("путинизм")
      parses = MorphRu.parse("путинизм")
      assert length(parses) > 0
      [top | _] = parses
      assert MorphRu.Tag.contains?(top.tag, "NOUN")
      assert MorphRu.Tag.contains?(top.tag, "masc")
      assert top.normal_form == "путинизм"
    end

    test "predicts ковидный as ADJF" do
      refute MorphRu.word_is_known?("ковидный")
      parses = MorphRu.parse("ковидный")
      assert length(parses) > 0
      [top | _] = parses
      assert MorphRu.Tag.contains?(top.tag, "ADJF")
    end

    test "predicts хабр as NOUN" do
      refute MorphRu.word_is_known?("хабр")
      parses = MorphRu.parse("хабр")
      assert length(parses) > 0
      [top | _] = parses
      assert MorphRu.Tag.contains?(top.tag, "NOUN")
    end

    test "prediction score is scaled by 0.5" do
      parses = MorphRu.parse("путинизм")

      for p <- parses do
        assert p.score <= 0.5
      end
    end
  end
end
