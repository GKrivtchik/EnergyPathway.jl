using Pathway
using Test

using HiGHS
using JuMP: is_solved_and_feasible, objective_value, set_silent, solver_name, value
using Nosy: nsteps

function add_dispatch_system!(snap, demand; late=false)
    s = snap.sim
    carrier = EnergyCarrier(late ? "late_power" : "power", s)
    grid = Node(late ? "late_grid" : "grid", carrier)

    if !late
        load = Component("load", Demand(carrier, demand))
        connect!(snap, load, grid)
    end

    gen = Component(
        late ? "late_gen" : "gen",
        DispatchableSource(carrier),
        [
            VariableCapacity("output", energy),
            VariableDeployment("output", energy),
            VariableRetirement("output", energy),
            Lifetime(30),
            SingleCost(:capex, :deployment, "output", energy, 1.0, nothing),
        ],
    )
    connect!(snap, gen, grid)

    return snap
end

@testset "Pathway usability" begin
    mesh2 = TimeMesh(fill(1 // 1, 2))

    @test PathOpt(2030:-10:2020; mesh=mesh2).years == [2020, 2030]
    @test InitialCapacity([(2010, "gen", 2, 20)]).capacities[2010][1].capacity == 2.0
    @test InitialCapacity([(year=2010, cname="gen", capacity=2, lifetime=20)]).capacities[2010][1].cname == "gen"
    @test FixedRetirement("output", energy, 0) isa FixedRetirement

    psim = PathSim(HiGHS.Optimizer, PathOpt(2020:10:2030; mesh=mesh2))
    @test occursin("ScaledOptimizer", solver_name(psim.model))
    @test psim.model === psim.dsim[2020].model
    @test psim.dsim[2030].options[:scalingtarget] == 1

    jump_model = Model()
    psim = PathSim(jump_model, PathOpt(2020:10:2020; mesh=mesh2))
    @test psim.model === jump_model
    @test psim.dsim[2020].model === jump_model

    ini = InitialCapacity([(2010, "gen", 2, 20)])
    @test sprint(show, ini.capacities[2010][1]) == "Historical capacity \"gen\" (2.0, lifetime 20 year(s))"
    @test sprint(show, ini) == "Initial capacity with 1 entry in 1 year(s)"
    @test occursin("Path options (2 snapshot year(s): 2020:10:2030", sprint(show, PathOpt(2020:10:2030; mesh=mesh2)))
    @test sprint(show, VariableDeployment("output", energy)) == "Variable deployment on \"output\" energy (0.0 <= deployment <= Inf)"
    @test sprint(show, FixedDeployment("output", energy, 3)) == "Fixed deployment on \"output\" energy (3.0)"
    @test sprint(show, VariableRetirement("output", energy)) == "Variable retirement on \"output\" energy (0.0 <= retirement <= Inf)"
    @test sprint(show, FixedRetirement("output", energy, 2)) == "Fixed retirement on \"output\" energy (2.0)"
    @test sprint(show, Lifetime(30)) == "Lifetime (30 year(s))"
    @test sprint(show, SingleCost(:capex, :deployment, "output", energy, 1.0, nothing)) == "Single cost :capex on deployment of \"output\" energy (1.0, profile 0 => 1.0)"

    empty_path = Path(HiGHS.Optimizer, PathOpt(; mesh=mesh2))
    set_silent(model(empty_path))
    @test isempty(snapshotyears(empty_path))
    @test occursin("Pathway with 0 snapshot year(s) (no years)", sprint(show, empty_path))
    snap2020 = addsnapshot!(empty_path, 2020)
    @test snap2020 === empty_path[2020]
    @test snapshotyears(empty_path) == [2020]
    @test firstsnapshotyear(empty_path) == 2020
    @test lastyear(empty_path) == 2020
    snap2030 = Snapshot(Sim(Model(), mesh=mesh2))
    @test_throws ArgumentError addsnapshot!(empty_path, snap2030, 2030)
    snap2030 = Snapshot(Sim(model(empty_path), mesh=mesh2, suffix="2030"))
    @test addsnapshot!(empty_path, snap2030, 2030) === snap2030
    @test snapshotyears(empty_path) == [2020, 2030]
    @test lastyear(empty_path) == 2030

    opt = PathOpt(2020:10:2030; discountrate=0.05, endyear=2030, mesh=mesh2)
    path = Path(HiGHS.Optimizer, opt)
    set_silent(model(path))

    @test length(path) == 2
    @test collect(keys(path)) == [2020, 2030]
    @test path[2020] === getsnapshot(path, 2020)
    @test nsteps(sim(path, 2020)) == 2
    @test alltech(path) == String[]
    @test occursin("Pathway with 2 snapshot year(s) (2020:10:2030)", sprint(show, path))
    @test sprint(show, path.sim) == "Path simulation (2 snapshot year(s), ScaledOptimizer(HiGHS))"
    @test startswith(sprint(show, path.snap[2020]), "Meta snapshot 2020: Snapshot with 0 component(s)")

    add_dispatch_system!(path[2020], 10)
    add_dispatch_system!(path[2030], 20)
    add_dispatch_system!(path[2030], 0; late=true)

    @test alltech(path) == ["gen", "late_gen", "load"]
    @test capacity(path, "late_gen", 2020) == 0.0
    @test fixedcost(path, "late_gen", 2020) == 0.0
    @test variablecost(path, "late_gen", 2020) == 0.0

    optimize!(path, cost(path))

    @test is_solved_and_feasible(model(path))
    @test value(capacity(path, "gen", 2020)) ≈ 10.0
    @test value(capacity(path, "gen", 2030)) ≈ 20.0
    @test value(deployment(path, "gen", 2020)) ≈ 10.0
    @test value(deployment(path, "gen", 2030)) ≈ 10.0
    @test value(deployment(path, "late_gen", 2030)) ≈ 0.0
    @test objective_value(model(path)) ≈ 10.0 + 10.0 * discount(opt, 2030)

    capacity_metric(p, cname, year) = cname == "load" ? nothing : capacity(p, cname, year)
    capacity_table = table(path, capacity_metric)
    @test names(capacity_table) == ["year", "gen", "late_gen"]
    @test capacity_table[!, "year"] == collect(2020:2030)
    @test value.(capacity_table[!, "gen"]) ≈ [fill(10.0, 10); 20.0]
    @test value.(capacity_table[!, "late_gen"]) ≈ zeros(11)

    full_table = table(path, capacity_metric; removenothing=false)
    @test names(full_table) == ["year", "gen", "late_gen", "load"]
    @test all(isnothing, full_table[!, "load"])
end
