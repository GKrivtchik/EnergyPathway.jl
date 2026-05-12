# Tutorial

This tutorial builds a very small capacity expansion pathway. The system has
one electricity node, one load, and one dispatchable generator. Demand grows
between 2020 and 2030, so the model must decide how much generator capacity to
deploy in each snapshot year.

## Setup

```julia
using Pathway
using JuMP: set_silent, value, objective_value
```

Put the year-indexed input data in one place. `PathOpt` can start without a
complete list of years; the years are populated when snapshots are added. The
tiny two-step mesh keeps the example quick; real models usually use richer time
meshes.

```julia
demand_by_year = [2020 => 10, 2030 => 20]

opt = PathOpt(; mesh=TimeMesh(fill(1 // 1, 2)))
path = Path(opt)
set_silent(model(path))
```

## Build Each Snapshot

Each snapshot is an ordinary Nosy system. Pathway re-exports the Nosy API, so
the code uses `EnergyCarrier`, `Node`, `Component`, `Demand`,
`DispatchableSource`, and `connect!` directly.

```julia
function add_year!(snap, demand)
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

    return snap
end

for (year, demand) in demand_by_year
    snap = addsnapshot!(path, year)
    add_year!(snap, demand)
end
```

The important Pathway-specific behaviors are:

- `VariableDeployment`: the model can add capacity in a snapshot year.
- `VariableRetirement`: the model can retire capacity in a snapshot year.
- `Lifetime`: deployed capacity has a technical lifetime.
- `SingleCost`: deployment has a non-recurring cost.

`SingleCost` is typically used for construction or investment costs. In the
example above, the full construction cost is paid in the deployment year because
the profile is `nothing`, which defaults to `Dict(0 => 1.0)`. A construction
schedule can also spread the cost around the deployment year:

```julia
SingleCost(:capex, :deployment, "output", energy, 1_000.0, Dict(-1 => 0.4, 0 => 0.6))
```

Here, 40% of the cost is paid one year before deployment and 60% in the
deployment year. The cost is discounted according to the pathway options.

## Optimize

```julia
optimize!(path, cost(path))
```

`finalize!(path)` is called automatically by `optimize!`. It finalizes every
snapshot, then adds dynamic constraints linking capacity through time.

## Inspect Results

```julia
value(capacity(path, "gen", 2020))     # 10.0
value(capacity(path, "gen", 2030))     # 20.0
value(deployment(path, "gen", 2030))   # 10.0
objective_value(model(path))
```

The same model is available as a runnable script in
[`examples/simple_pathway.jl`](https://github.com/oecd-nea/Pathway.jl/blob/main/examples/simple_pathway.jl).
