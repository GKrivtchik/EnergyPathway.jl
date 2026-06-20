using OrderedCollections: OrderedDict
using Memoize

using Nosy: Sim

using JuMP

"""
    PathSim(model, opt; simkwargs...)

Shared simulation state for a `Path`.

`model` follows Nosy's `Sim` constructor: pass either an existing JuMP model or
an optimizer constructor. When an optimizer constructor is passed, Nosy handles
constraint scaling.
"""
struct PathSim
    model::JuMP.AbstractModel
    dsim::OrderedDict{Int64,Sim}
    opt::PathOpt
    simkwargs::Dict{Symbol,Any}
end

function PathSim(model, opt::PathOpt; simkwargs...)
    kwargs = Dict{Symbol,Any}(pairs(simkwargs))
    sample = Sim(model, mesh=opt.defaultmesh; kwargs...)
    m = sample.model
    s = OrderedDict{Int64,Sim}((y => Sim(m, mesh=mesh(opt, y), suffix=string(y); kwargs...) for y in years(opt))...)
    return PathSim(m, s, opt, kwargs)
end