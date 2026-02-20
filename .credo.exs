%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: %{
        extra: [
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.Specs, false}
        ]
      }
    }
  ]
}
