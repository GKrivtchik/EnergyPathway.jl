using Nosy, HiGHS

function test()

    o = PathOpt(2025:5:2030, 0.05, 2020, TimeMesh(), Dict(2015 => Dict("PV" => 10), 2016 => Dict("PV" => 5, "battery" => 12)))

    p = Path(o)

    for (y, ms) in p

        snapshot = ms.snap
        s = snapshot.sim

        #carrier
        elec_carrier = EnergyCarrier("power", s)

        # Synthetic data for load
        hours = 1:8760
        day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
        season_angle = 2pi .* (hours .- 1) ./ 8760
        load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi/2) .+ 120 .* sin.(season_angle .- pi/2)

        # Synthetic data for PV
        cf_pv = [x < 1e-6 ? 0.0 : x for x in [max(0, cos((h%24 - 12)/12*pi) * (0.6 + 0.4*sin(2*pi*(h/24)/365))) for h in 1:8760]]

        # One electricity node
        grid = Node("grid", elec_carrier, rule=:curtailed, evalprice=true)

        # Component: Electricity consumption
        consumption = Component(
            "consumption",
            Demand(elec_carrier, load_profile),
        )
        connect!(snapshot, consumption, grid)

        # Component: PV
        pv = Component(
            "PV",
            ProfileSource(elec_carrier, cf_pv),
            [
                VariableCapacity("output", energy),
                FixedDeployment("output", energy, 20.),
                SingleCost(:capex, :deployment, "output", energy, 50000, Dict(-1=>0.5, 0=>0.5)),
            ]
        )
        connect!(snapshot, pv, grid)

        # Component: battery storage
        battery = Component(
            "battery",
            BasicStorage(elec_carrier, elec_carrier, elec_carrier, energy, eff_i=0.85), # Battery storage with 85% roundtrip efficiency
            [
                VariableCapacity("input", energy), # Behavior: variable capacity associated with the input of the battery # in MW
                VariableDeployment("input", energy), # Behavior: variable capacity deployment
                SingleCost(:capex, :deployment, "input", energy, 30000, Dict(-1=>0.5, 0=>0.5)), # Behavior: annualized fixed cost, tagged as capex, associated with the capacity of the input of the battery (in €/MW)
                Duration(6), # Behavior: battery duration is 6 hours (i.e. level capacity = 6 * input capacity; output capacity = level capacity)
            ]
        )
        connect!(snapshot, battery, grid) # connect the battery to the grid. NB both input and output will be connected

        finalize!(snapshot)    
    end

    updatecapacity!(p)
    apply_dynamic_constraints!(p)
    # Optimization
    # Nosy.optimize!(snapshot, cost)
    # result = extract(snapshot)

    return p
end