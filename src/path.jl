using ArgCheck

mutable struct Path{T}
    const opt::PathOpt
    const sim::PathSim
    const snap::LittleDict{Int64,MetaSnapshot{T}}
    cap::Union{Nothing,Capacity{T}}

    function Path(opt::PathOpt, sim::PathSim, snap::AbstractDict{Int64,MetaSnapshot{T}}) where T
        @argcheck years(opt) == sort(collect(keys(snap))) "snapshot years do not match PathOpt years"
        new{T}(opt, sim, sort(snap), nothing) # invariant: years are sorted at constructor
    end
end

function Path(opt::PathOpt)
    psim = PathSim(opt)
    dsnap = LittleDict([y => MetaSnapshot(y,Snapshot(psim.dsim[y])) for y in years(opt)])
    return Path(opt, psim, dsnap)
end

# updated capacity, after all snapshots are defined
function updatecapacity!(p::Path)
    @argcheck isnothing(p.cap) "Path capacity is already defined"
    p.cap = Capacity(p.sim, p.opt, p.snap)
    return nothing
end

# apply dynamic capacity constraints
function apply_dynamic_constraints!(p::Path)
    @argcheck !isnothing(p.cap) "Path capacity is not defined yet - please run updatecapacity!(p)"
    _apply_dynamic_capacity_constraint!(p.cap)
end

# key-value iteration over Path
Base.iterate(d::Path, st...) = iterate(pairs(d.snap), st...)