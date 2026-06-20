# API Reference

This page lists the main Pathway-specific API. Pathway also re-exports the
common Nosy API for components, nodes, snapshots, carriers, metrics, and
optimization.

## Options and Path Objects

```@docs
PathOpt
InitialCapacity
HistoricalCapacity
Path
PathSim
MetaSnapshot
getsnapshot
addsnapshot!
```

## Year Helpers

```@docs
years
mesh
firstyear
lastyear
allyears
firstsnapshotyear
lastsnapshotyear
snapshotyears
snapshotyear
alltech
```

## Dynamic Behaviors

```@docs
VariableDeployment
FixedDeployment
VariableRetirement
FixedRetirement
Lifetime
SingleCost
```

## Metrics

```@docs
capacity
deployment
retirement
singlecost
cost
fixedcost
variablecost
table
discount
```
