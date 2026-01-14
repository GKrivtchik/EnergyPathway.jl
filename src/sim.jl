using OrderedCollections: LittleDict
using Memoize

using JuMP
using Gurobi, HiGHS

# @memoize gurobienv() = Gurobi.Env()
# makesim() = Sim(Model(() -> Gurobi.Optimizer(gurobienv())))


struct PathSim
    model::Model
    dsim::LittleDict{Int64,Sim}
    opt::PathOpt
end

function PathSim(opt::PathOpt)
    # m = Model(() -> Gurobi.Optimizer(gurobienv()))
    m = Model(HiGHS.Optimizer)
    s = LittleDict{Int64,Sim}((y => Sim(m, suffix=string(y)) for y in years(opt))...)
    return PathSim(m,s,opt)
end