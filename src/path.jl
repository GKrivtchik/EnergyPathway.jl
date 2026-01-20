using ArgCheck

using Nosy: AbstractElement

import Nosy: finalize!

struct Path{T} <: AbstractElement{T}
    opt::PathOpt
    sim::PathSim
    snap::OrderedDict{Int64,MetaSnapshot{T}}
    finalized::Ref{Bool}

    function Path(opt::PathOpt, sim::PathSim, snap::AbstractDict{Int64,MetaSnapshot{T}}, finalized::Ref{Bool}=Ref(false)) where T
        @argcheck years(opt) == sort(collect(keys(snap))) "snapshot years do not match PathOpt years"
        new{T}(opt, sim, sort(snap), finalized) # invariant: years are sorted at constructor
    end
end

function getsnapshot(p::Path{T}, y::Int) where T
    @argcheck y in p.opt.years "y not in path years"
    return p.snap[y].snap::Snapshot{T}
end

function Path(opt::PathOpt)
    psim = PathSim(opt)
    dsnap = OrderedDict([y => MetaSnapshot(y,Snapshot(psim.dsim[y])) for y in years(opt)])
    return Path(opt, psim, dsnap)
end

# key-value iteration over Path
Base.iterate(d::Path, st...) = iterate(pairs(d.snap), st...)

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
lastyear(p::Path) = p.opt.endyear
allyears(p::Path) = firstyear(p):lastyear(p)

firstsnapshotyear(p::Path) = minimum(p.opt.years)
lastsnapshotyear(p::Path) = maximum(p.opt.years)
snapshotyears(p::Path) = p.opt.years
function snapshotyear(p::Path, year::Int)
    @argcheck year >= firstsnapshotyear(p) "No snapshot before $(firstsnapshotyear(p))"
    return maximum(y for y in p.opt.years if y <= year)
end

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

    return collect(tech)
end

_isfinalized(p::Path) = p.finalized[]

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