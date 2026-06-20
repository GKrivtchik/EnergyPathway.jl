# Pathway Concepts

Pathway keeps the Nosy modeling philosophy: build systems from carriers, nodes,
components, model archetypes, and reusable behaviors. It adds only the concepts
needed to connect snapshots through time.

## `PathOpt`

`PathOpt` stores the temporal options of a pathway:

- `years`: snapshot years, initially empty if no year list is provided.
- `discountrate`: discount rate used for pathway costs.
- `baseyear`: reference year for discounting.
- `endyear`: final model year, which can be after the last snapshot year.
- `mesh`: default `TimeMesh`, or a dictionary of year-specific meshes when
  years are known up front.
- `ini`: optional historical capacity.

The preferred incremental workflow starts without declaring years twice:

```julia
using HiGHS

opt = PathOpt()
path = Path(HiGHS.Optimizer, opt)
snap = addsnapshot!(path, 2030)
```

For compatibility, snapshot years can still be declared up front:

```julia
opt = PathOpt(2020:10:2050)
```

## `Path`

`Path` owns:

- one shared JuMP model,
- one Nosy `Sim` per snapshot year,
- one Nosy `Snapshot` per snapshot year,
- the dynamic constraints that link snapshots.

Access snapshots with:

```julia
snapshot = path[2030]
```

or:

```julia
snapshot = getsnapshot(path, 2030)
```

Add snapshots with:

```julia
snap = addsnapshot!(path, 2030)
```

or register an existing snapshot that uses the pathway's shared JuMP model:

```julia
snap = Snapshot(Sim(model(path), mesh=TimeMesh(), suffix="2030"))
addsnapshot!(path, snap, 2030)
```

## Historical Capacity

Historical capacity is passed with `ini`. Each entry is:

```julia
(year, component_name, capacity, lifetime)
```

For example:

```julia
opt = PathOpt(
    2020:10:2040;
    ini=[
        (2010, "PV", 100, 25),
        (2015, "PV", 200, 25),
    ],
)
```

Historical capacity must be installed before the first snapshot year and must
still be alive at the first snapshot year.

## Dynamic Behaviors

Pathway components are ordinary Nosy components with extra behaviors:

- `VariableDeployment` creates an optimized deployment variable.
- `FixedDeployment` fixes deployment to a given value.
- `VariableRetirement` creates an optimized retirement variable.
- `FixedRetirement` fixes retirement to a given value.
- `Lifetime` defines when capacity must be retired.
- `SingleCost` attaches a non-recurring cost to an event.

`SingleCost` is useful for construction costs, investment costs, connection
costs, dismantling costs, or any other cost paid once because a capacity event
happens. The `type` symbol is user-defined, so `:capex`, `:construction`, or
`:grid_connection` are all valid tags.

For construction cost, the cost profile can represent payment timing relative
to deployment:

```julia
SingleCost(:construction, :deployment, "output", energy, 50_000, Dict(-2 => 0.3, -1 => 0.4, 0 => 0.3))
```

This means 30% of the construction cost is paid two years before deployment,
40% one year before deployment, and 30% in the deployment year. Profile shares
must sum to one, and Pathway discounts each payment in its own year.

Dynamic capacity constraints are added only for components that use deployment
or retirement behaviors. Ordinary fixed Nosy components remain snapshot-local.

## Metrics

The main year-aware pathway metrics are:

```julia
capacity(path, "gen", 2030)
deployment(path, "gen", 2030)
retirement(path, "gen", 2030)
singlecost(path, "gen", 2030, :capex)
cost(path, "gen", 2030)
```

Aggregated forms are also available:

```julia
cost(path)
cost(path, "gen")
cost(path, :capex)
```
