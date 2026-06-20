# Pathway.jl

[![codecov](https://codecov.io/github/GKrivtchik/Pathway.jl/branch/main/graph/badge.svg)](https://app.codecov.io/github/GKrivtchik/Pathway.jl/tree/main)
[![CI](https://github.com/GKrivtchik/Pathway.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/GKrivtchik/Pathway.jl/actions/workflows/ci.yml)

Pathway is a capacity expansion pathway layer built on top of
[Nosy.jl](https://github.com/oecd-nea/Nosy.jl).

Nosy describes one optimized energy-system snapshot. Pathway links several
Nosy snapshots through time, adding deployment, retirement, lifetime, and
investment-cost logic so that a model can describe how installed capacity
evolves between years.

Pathway re-exports the common Nosy API, so most small models can start with:

```julia
using Pathway
```

## Highlights

- Build multi-year capacity expansion pathways from familiar Nosy snapshots.
- Link capacities over time with deployment and retirement decisions.
- Represent historical capacity with remaining lifetime.
- Attach non-recurring costs to deployment events.
- Use different `TimeMesh` values for different snapshot years.
- Optimize through JuMP with the same solver workflow as Nosy.
- Query pathway metrics such as `capacity`, `deployment`, `retirement`, and
  discounted `cost`.

## Requirements

Pathway requires Nosy and a JuMP-compatible LP/MILP solver. Pass the optimizer
constructor when constructing a `Path`:

```julia
using Pathway
using HiGHS

opt = PathOpt()
path = Path(HiGHS.Optimizer, opt)
```


## Quick Start

The following model has one grid, one load, and one dispatchable generator in
two snapshot years. Demand grows from 10 to 20, so the optimal pathway deploys
10 units in 2020 and 10 more in 2030.

```julia
using Pathway
using HiGHS
using JuMP: set_silent, value

demand_by_year = [2020 => 10, 2030 => 20]

opt = PathOpt(; mesh=TimeMesh(fill(1 // 1, 2)))
path = Path(HiGHS.Optimizer, opt)
set_silent(model(path))

for (year, demand) in demand_by_year
    snap = addsnapshot!(path, year)
    carrier = EnergyCarrier("power", sim(snap))
    grid = Node("grid", carrier)

    load = Component("load", Demand(carrier, demand))
    connect!(snap, load, grid)

    generator = Component(
        "gen",
        DispatchableSource(carrier),
        [
            VariableCapacity("output", energy),
            VariableDeployment("output", energy),
            VariableRetirement("output", energy),
            Lifetime(30),
            SingleCost(:capex, :deployment, "output", energy, 1.0, nothing),
        ],
    )
    connect!(snap, generator, grid)
end

optimize!(path, cost(path))

value(capacity(path, "gen", 2020))     # 10.0
value(capacity(path, "gen", 2030))     # 20.0
value(deployment(path, "gen", 2030))   # 10.0
```

See [`examples/simple_pathway.jl`](examples/simple_pathway.jl) for a complete
runnable script.

## Main Concepts

`PathOpt` holds the temporal configuration of a pathway: discount rate, base
year, final model year, default time mesh, and optional historical capacity.
It can start without snapshot years; `addsnapshot!` populates them as snapshots
are registered.

`Path` owns one Nosy `Snapshot` per snapshot year and one shared JuMP model.
Use `addsnapshot!(path, year)` to create a snapshot, or
`addsnapshot!(path, snapshot, year)` to register an existing snapshot built on
the pathway model. Use `path[year]` or `getsnapshot(path, year)` to access a
registered snapshot.

Pathway components are ordinary Nosy components with additional behaviors:

- `VariableDeployment` or `FixedDeployment`: capacity additions in a snapshot
  year.
- `VariableRetirement` or `FixedRetirement`: capacity retirements in a snapshot
  year.
- `Lifetime`: maximum operating lifetime for deployed capacity.
- `SingleCost`: one-time cost attached to an event, usually deployment.

## Metrics

Pathway extends Nosy metrics with year-aware methods:

- `capacity(path, cname, year)`
- `deployment(path, cname, year)`
- `retirement(path, cname, year)`
- `singlecost(path, cname, year[, type])`
- `fixedcost(path, cname, year[, type])`
- `variablecost(path, cname, year[, type])`
- `cost(path, cname, year[, type])`

Aggregated forms such as `cost(path)` and `cost(path, :capex)` are also
available.

## Documentation

The documentation sources live in [`docs/`](docs/). Build them with:

```julia
julia --project=docs docs/make.jl
```

## Authors

Guillaume Krivtchik (OECD - Nuclear Energy Agency)
