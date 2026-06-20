module Pathway

"""
Path model, based on Nosy.jl
"""

using Nosy

export TimeMesh, Sim, sim
export Model, model, lowermodel, uppermodel
export MassCarrier, EnergyCarrier, CO2Carrier, PowerCarrier
export BasicConverter
export BasicSink, Demand
export DispatchableSource, ProfileSource
export BasicStorage, LazyStorage
export ACLine, DCLine
export VariableCapacity, VariableComposedCapacity, FixedCapacity, FixedComposedCapacity
export CapacityMultiplier, Duration
export UnitCommitment
export Ramping
export YearlySum
export ReserveUp, ReserveDown
export VariableCost, FixedCost, NoLoadCost, StartupCost
export LinkedJointFlow, FreeJointFlow, FixedJointFlow
export Component, Node, Snapshot
export connect!
export capacity, nbunits
export cost, variablecost, fixedcost, noloadcost, startupcost
export dualprice
export reserve
export costs, table
export balance, flow
export mass, energy, co2
export finalize!, optimize!
export conflicts
export extract
export tag!, hastag, getnodes, getcomponents

export PathOpt, InitialCapacity, HistoricalCapacity
export PathSim, Path, MetaSnapshot, getsnapshot
export addsnapshot!
export firstyear, lastyear, allyears
export firstsnapshotyear, lastsnapshotyear, snapshotyears, snapshotyear
export alltech, mesh, years
export VariableDeployment, FixedDeployment
export VariableRetirement, FixedRetirement
export SingleCost, Lifetime
export deployment, retirement, singlecost, discount

include("options/_includes.jl")
include("sim.jl")
include("snapshot.jl")

# include("capacity.jl")

include("path.jl")

include("behaviors/_includes.jl")

include("metrics/_includes.jl")
include("constraints/_includes.jl")

include("optimization/_includes.jl")

include("show.jl")

end # module Pathway
