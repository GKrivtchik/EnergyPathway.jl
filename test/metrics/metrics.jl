@testset "Metrics and dynamic constraints" begin
    mesh2 = TimeMesh(fill(1 // 1, 2))
    path = optimized_dispatch_path()

    @test is_solved_and_feasible(model(path))
    @test value(capacity(path, "gen", 2020)) ≈ 10.0
    @test value(capacity(path, "gen", 2030)) ≈ 20.0
    @test value(deployment(path, "gen", 2020)) ≈ 10.0
    @test value(deployment(path, "gen", 2030)) ≈ 10.0
    @test value(deployment(path, "late_gen", 2030)) ≈ 0.0
    @test objective_value(model(path)) ≈ 10.0 + 10.0 * discount(path.opt, 2030)

    split_cost_path = Path(
        HiGHS.Optimizer,
        PathOpt([2020]; discountrate=0.05, endyear=2020, mesh=mesh2),
    )
    set_silent(model(split_cost_path))
    add_fixed_dispatch_system!(split_cost_path[2020], "front_loaded", 5, 5; deployment_value=5)
    @test singlecost(split_cost_path, "front_loaded", 2019, :capex) == 5 * 4 * 0.25 * discount(split_cost_path.opt, 2019)
    @test singlecost(split_cost_path, "front_loaded", :capex) == 5 * 4 * (
        0.25 * discount(split_cost_path.opt, 2019) +
        0.75 * discount(split_cost_path.opt, 2020)
    )

    capacity_metric(p, cname, year) = cname == "load" ? nothing : capacity(p, cname, year)
    capacity_table = table(path, capacity_metric)
    @test names(capacity_table) == ["year", "gen", "late_gen"]
    @test capacity_table[!, "year"] == collect(2020:2030)
    @test value.(capacity_table[!, "gen"]) ≈ [fill(10.0, 10); 20.0]
    @test value.(capacity_table[!, "late_gen"]) ≈ zeros(11)

    full_table = table(path, capacity_metric; removenothing=false)
    @test names(full_table) == ["year", "gen", "late_gen", "load"]
    @test all(isnothing, full_table[!, "load"])

    hist_path = Path(
        HiGHS.Optimizer,
        PathOpt(2020:10:2030; endyear=2045, mesh=mesh2, ini=[(2010, "legacy", 5, 25)]),
    )
    set_silent(model(hist_path))
    add_fixed_dispatch_system!(hist_path[2020], "legacy", 5, 5; retirement_value=5, lifetime_years=10)
    add_fixed_dispatch_system!(hist_path[2030], "legacy", 5, 5; deployment_value=5, lifetime_years=10)

    @test capacity(hist_path, "legacy", 2010) == 5.0
    @test capacity(hist_path, "legacy", 2019) == 5.0
    @test capacity(hist_path, "legacy", 2046) == 0.0
    @test deployment(hist_path, "legacy", 2010) == 5.0
    @test deployment(hist_path, "legacy", 2015) == 0.0
    @test retirement(hist_path, "legacy", 2025) == 0.0
    @test retirement(hist_path, "legacy", 2046) == 0.0
    @test retirement(hist_path, "legacy", 2040) == 5.0
    @test !iszero(deployment(hist_path, "legacy", 2040))
    @test singlecost(hist_path, "legacy", 2019, :capex) == 5 * 4 * 0.25 * discount(hist_path.opt, 2019)
    @test singlecost(hist_path, "legacy", 2020, :missing) == 0.0
    @test singlecost(hist_path, "missing", 2020) == 0.0
    @test variablecost(hist_path, "missing", 2020) == 0.0
    @test fixedcost(hist_path, "missing", 2020) == 0.0
    @test variablecost(hist_path, "legacy", 2019) == 0.0
    @test fixedcost(hist_path, "legacy", 2019) == 0.0

    finalize!(hist_path)
    @test occursin("finalized", sprint(show, hist_path))
    @test_throws ArgumentError addsnapshot!(hist_path, 2040)

    finalize!(hist_path)
    @test snapshotyears(hist_path) == [2020, 2030]
end
