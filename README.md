# MorphRu

Russian morphological analyzer for Elixir. Lemmatizes, POS-tags, and inflects Russian words using the [OpenCorpora](http://opencorpora.org/) dictionary.

Elixir port of [pymorphy2](https://github.com/pymorphy2/pymorphy2). Ships with the full 390K+ word dictionary. 6.8× faster than pymorphy3.

## Installation

```elixir
def deps do
  [
    {:morph_ru, "~> 0.1"}
  ]
end
```

## Usage

### Parse

Returns all possible morphological analyses sorted by probability:

```elixir
MorphRu.parse("стали")
# [%MorphRu.Parse{word: "стали", normal_form: "стать",
#    tag: %MorphRu.Tag{pos: "VERB", ...}, score: 0.9628},
#  %MorphRu.Parse{word: "стали", normal_form: "сталь",
#    tag: %MorphRu.Tag{pos: "NOUN", ...}, score: 0.0372}]
```

### Normal forms

```elixir
MorphRu.normal_forms("стали")
# ["стать", "сталь"]
```

### Tag

Returns the tag for the most likely parse:

```elixir
tag = MorphRu.tag("договор")
MorphRu.Tag.pos(tag)         # "NOUN"
MorphRu.Tag.contains?(tag, "masc")  # true
MorphRu.Tag.contains?(tag, "inan")  # true
```

### Inflect

```elixir
[parse | _] = MorphRu.parse("договор")
MorphRu.inflect(parse, ["plur", "gent"])
# %MorphRu.Parse{word: "договоров", ...}
```

## Grammemes

Tags follow the [OpenCorpora tagset](http://opencorpora.org/dict.php?act=gram):

| Category | Values |
|---|---|
| POS | `NOUN`, `VERB`, `INFN`, `ADJF`, `ADJS`, `ADVB`, `NPRO`, … |
| Case | `nomn`, `gent`, `datv`, `accs`, `ablt`, `loct` |
| Number | `sing`, `plur` |
| Gender | `masc`, `femn`, `neut` |
| Tense | `past`, `pres`, `futr` |
| Animacy | `anim`, `inan` |

## License

MIT © Danila Poyarkov
