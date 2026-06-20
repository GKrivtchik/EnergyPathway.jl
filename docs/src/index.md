# Pathway.jl

Pathway is a capacity expansion pathway layer built on top of
[Nosy.jl](https://github.com/oecd-nea/Nosy.jl).

Nosy describes one optimized energy-system snapshot. Pathway links several
Nosy snapshots through time, adding deployment, retirement, lifetime, and
investment-cost logic so that a model can describe how installed capacity
evolves between years.

```julia
using Pathway
```

## What Pathway Adds

- A `Path` object containing one Nosy `Snapshot` per model year.
- A `PathOpt` object for discounting, model horizon, default time mesh, and
  historical capacity.
- `addsnapshot!` to register snapshot years as the pathway is built.
- Dynamic capacity constraints linking each snapshot to the previous state.
- Deployment and retirement behaviors.
- Lifetime constraints and automatic renewal logic after the last snapshot.
- Year-aware cost, capacity, deployment, and retirement metrics.

## Requirements

Pathway uses JuMP through Nosy. You need a JuMP-compatible LP/MILP solver.
Pass the optimizer constructor when constructing a `Path`:

```julia
using HiGHS

opt = PathOpt(2020:10:2050)
path = Path(HiGHS.Optimizer, opt)
```

or start with no years and add snapshots explicitly:

```julia
using HiGHS

opt = PathOpt()
path = Path(HiGHS.Optimizer, opt)
snap = addsnapshot!(path, 2030)
```

The same form works with any JuMP optimizer constructor; pass it in place of
`HiGHS.Optimizer`.

## Author

Pathway is authored by Guillaume KRIVTCHIK at the OECD Nuclear Energy Agency
(OECD-NEA).

## Pages

- [Tutorial](@ref): a complete two-year capacity expansion model.
- [Pathway Concepts](@ref): the main objects and behaviors.
- [API Reference](@ref): exported Pathway types and functions.
