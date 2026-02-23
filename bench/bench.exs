words = ~w(
  стали московским сирота договора январе
  красивый бежать дом работа программирование
  государственный предприниматель ответственность
  законодательство международный
)

unknown_words = ~w(перепрограммировать суперкомпьютеризация мегакрутейший)

MorphRu.parse("тест")

Benchee.run(
  %{
    "parse" => fn ->
      Enum.each(words, &MorphRu.parse/1)
    end,
    "parse (unknown words)" => fn ->
      Enum.each(unknown_words, &MorphRu.parse/1)
    end,
    "normal_forms" => fn ->
      Enum.each(words, &MorphRu.normal_forms/1)
    end,
    "tag" => fn ->
      Enum.each(words, &MorphRu.tag/1)
    end
  },
  memory_time: 2,
  reduction_time: 2
)
