# GRiSP Mix plug-in

Mix plug-in to build and deploy GRiSP applications for the [GRiSP board][grisp].

## Installation

The package can be installed by adding `mix_grisp` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:mix_grisp, "~> 0.1.0", only: :dev}
  ]
end
```


[grisp]: https://www.grisp.org
