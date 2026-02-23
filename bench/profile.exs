words =
  ~w(стали московским сирота договора январе красивый бежать дом работа программирование государственный предприниматель ответственность законодательство международный)

unknown_words = ~w(перепрограммировать суперкомпьютеризация мегакрутейший)

MorphRu.parse("тест")

dict = MorphRu.dict()
prob = :persistent_term.get({MorphRu, :prob})
n = 50_000

measure = fn label, fun ->
  {time, result} = :timer.tc(fn -> for _ <- 1..n, do: fun.() end)
  avg = Float.round(time / n, 2)
  IO.puts("  #{String.pad_trailing(label, 40)} #{String.pad_leading("#{avg}", 10)} μs")
  result
end

IO.puts("=== Per-phase breakdown (#{n} iterations) ===\n")

IO.puts("--- DAWG lookup ---")

for word <- words do
  downcased = String.downcase(word)

  measure.("follow_bytes(#{word})", fn ->
    MorphRu.Dawg.Dictionary.follow_bytes(dict.words.dict, downcased, 0)
  end)

  measure.("RecordDAWG.get(#{word})", fn ->
    MorphRu.Dawg.RecordDAWG.get(dict.words, downcased)
  end)

  measure.("lookup_similar(#{word})", fn ->
    MorphRu.Dict.lookup_similar(dict, downcased)
  end)
end

IO.puts("\n--- Paradigm info ---")

stali_entries = MorphRu.Dict.lookup_similar(dict, "стали")
para_ids = stali_entries |> Enum.flat_map(fn {_, e} -> Enum.map(e, &elem(&1, 0)) end) |> Enum.uniq()

for para_id <- para_ids do
  measure.("paradigm_info(#{para_id})", fn ->
    MorphRu.Dict.paradigm_info(dict, para_id)
  end)
end

IO.puts("\n--- Tag parsing ---")

measure.("Tag.parse(short)", fn -> MorphRu.Tag.parse("NOUN,inan,masc sing,nomn") end)
measure.("Tag.parse(long)", fn -> MorphRu.Tag.parse("VERB,perf,tran plur,past,indc") end)

IO.puts("\n--- Probability scoring ---")

parses = MorphRu.parse("стали")

measure.("Prob.apply_to_parses(стали, 6)", fn ->
  MorphRu.Prob.apply_to_parses(prob, "стали", parses)
end)

IO.puts("\n--- Full parse per word ---")

for word <- words do
  measure.("parse(#{word})", fn -> MorphRu.parse(word) end)
end

IO.puts("\n--- Unknown word prediction ---")

for word <- unknown_words do
  measure.("parse(#{word})", fn -> MorphRu.parse(word) end)
end

IO.puts("\n--- Batch (15 known words) ---")

measure.("parse batch", fn -> Enum.each(words, &MorphRu.parse/1) end)
