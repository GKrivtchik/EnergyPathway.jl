using Pathway
using HiGHS
using JuMP: objective_value, set_silent

function populatesnapshot!(snap, demand)
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

function makepathway(demand_by_year=[2020 => 10, 2030 => 20])
    opt = PathOpt(; mesh=TimeMesh(fill(1 // 1, 2)))
    path = Path(HiGHS.Optimizer, opt)
    set_silent(model(path))

    for (year, demand) in demand_by_year
        snap = addsnapshot!(path, year)
        populatesnapshot!(snap, demand)
    end

    optimize!(path, cost(path))

    res = extract(path)

    println("Objective: ", objective_value(model(path)))
    println("2020 capacity: ", capacity(res, "gen", 2020))
    println("2030 capacity: ", capacity(res, "gen", 2030))
    println("2030 deployment: ", deployment(res, "gen", 2030))

    return res
end

# path = makepathway()
