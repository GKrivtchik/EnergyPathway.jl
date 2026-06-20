using ArgCheck
using JuMP: AffExpr

using Nosy: AbstractElement, Snapshot, getnodes, getcomponents, _exptype
import Nosy: finalize!, model, sim



struct Path{T} <: AbstractElement{T}
    opt::PathOpt
    sim::PathSim
    snap::OrderedDict{Int64,MetaSnapshot{T}}
    finalized::Ref{Bool}

    function Path(opt::PathOpt, sim::PathSim, snap::AbstractDict{Int64,MetaSnapshot{T}}, finalized::Ref{Bool}=Ref(false)) where T
        @argcheck years(opt) == sort(collect(keys(snap))) "snapshot years do not match PathOpt years"
        ordered_snap = OrderedDict{Int64,MetaSnapshot{T}}(y => snap[y] for y in sort(collect(keys(snap))))
        new{T}(opt, sim, ordered_snap, finalized) # invariant: years are sorted at constructor
    end
end

"""
    Path(optimizer, opt::PathOpt)

Return a multi-year pathway made of one Nosy `Snapshot` per snapshot year and one
shared JuMP model.
"""
function Path(optimizer, opt::PathOpt)
    psim = PathSim(optimizer, opt)
    T = _exptype(psim.model)
    dsnap = OrderedDict{Int64,MetaSnapshot{T}}()
    for y in years(opt)
        dsnap[y] = MetaSnapshot{T}(y, Snapshot(psim.dsim[y]))
    end
    return Path(opt, psim, dsnap)
end

"""
    getsnapshot(path, year)

Return the Nosy `Snapshot` for snapshot `year`.
"""
function getsnapshot(p::Path{T}, y::Int) where T
    @argcheck y in p.opt.years "y not in path years"
    return p.snap[y].snap::Snapshot{T}
end


"""
    addsnapshot!(path, year; mesh=nothing)
    addsnapshot!(path, snapshot, year)

Add a snapshot year to `path` and return the added snapshot.

The first method creates an empty Nosy `Snapshot` using the pathway's shared
JuMP model. The second method registers an existing `snapshot`; it must use the
same JuMP model as the pathway.
"""
function addsnapshot!(p::Path{T}, year::Int; mesh=nothing) where T
    @argcheck !_isfinalized(p) "cannot add a snapshot to a finalized path"
    m = isnothing(mesh) ? p.opt.defaultmesh : mesh
    s = Sim(p.sim.model, mesh=m, suffix=string(year); p.sim.simkwargs...)
    snap = Snapshot(s)
    return addsnapshot!(p, snap, year)
end

function addsnapshot!(p::Path{T}, snap::Snapshot{T}, year::Int) where T
    @argcheck !_isfinalized(p) "cannot add a snapshot to a finalized path"
    @argcheck sim(snap).model === p.sim.model "snapshot must use the pathway JuMP model"

    y = _addyear!(p.opt, year, sim(snap).mesh)
    p.sim.dsim[y] = sim(snap)
    _sort_ordered_dict!(p.sim.dsim)
    p.snap[y] = MetaSnapshot(y, snap)
    _sort_ordered_dict!(p.snap)

    return snap
end

# key-value iteration over Path
Base.iterate(d::Path, st...) = iterate(pairs(d.snap), st...)
Base.length(p::Path) = length(p.snap)
Base.keys(p::Path) = keys(p.snap)
Base.values(p::Path) = values(p.snap)
Base.haskey(p::Path, y::Int) = haskey(p.snap, y)
Base.getindex(p::Path, y::Int) = getsnapshot(p, y)

model(p::Path) = p.sim.model
sim(p::Path, y::Int) = getsnapshot(p, y).sim

"""
    firstyear(p::Path)
Return the first year of the Path, considering both initialized capacities and snapshot years.
"""
function firstyear(p::Path)
    if isempty(p.opt.ini.capacities)
        return first(p.opt.years) # first snapshot year
    else
        return minimum(keys(p.opt.ini.capacities)) # first initialization year
    end
end
"""
    lastyear(path)

Return the final model year configured in `path`.
"""
lastyear(p::Path) = p.opt.endyear

"""
    allyears(path)

Return the full model-year range from `firstyear(path)` to `lastyear(path)`.
"""
allyears(p::Path) = firstyear(p):lastyear(p)

"""
    firstsnapshotyear(path)

Return the first snapshot year.
"""
firstsnapshotyear(p::Path) = minimum(p.opt.years)

"""
    lastsnapshotyear(path)

Return the last snapshot year.
"""
lastsnapshotyear(p::Path) = maximum(p.opt.years)

"""
    snapshotyears(path)

Return the sorted vector of snapshot years.
"""
snapshotyears(p::Path) = p.opt.years

"""
    snapshotyear(path, year)

Return the latest snapshot year less than or equal to `year`.
"""
function snapshotyear(p::Path, year::Int)
    @argcheck year >= firstsnapshotyear(p) "No snapshot before $(firstsnapshotyear(p))"
    return maximum(y for y in p.opt.years if y <= year)
end

"""
    alltech(path; cwith=[], cwithout=[], nwith=[], nwithout=[])

Return sorted component names appearing in historical capacity or snapshots.
Optional filters are forwarded to Nosy's node and component tag queries.
"""
function alltech(p::Path; cwith=Symbol[], cwithout=Symbol[], nwith=Symbol[], nwithout=Symbol[])
    tech = Set{String}()

    # TODO: manage tags at initialization level
    for (_,v) in p.opt.ini.capacities
        for t in v
            push!(tech, t.cname)
        end
    end

    for s in values(p.snap)
        for (kn,_) in getnodes(s.snap, with=nwith, without=nwithout)
            for (k,_) in getcomponents(s.snap, kn, with=cwith, without=cwithout)
                push!(tech, k)
            end
        end
    end

    return sort(collect(tech))
end

_isfinalized(p::Path) = p.finalized[]
_isoptimized(p::Path{<:Number}) = true
_isoptimized(p::Path) = false


function finalize!(p::Path)
    p.finalized[] && return
    
    # apply snapshot finalization 
    for (_, msnap) in p.snap
        finalize!(msnap.snap)
    end

    # apply path finalization
    apply_dynamic_constraints!(p)

    p.finalized[] = true
    return
end
