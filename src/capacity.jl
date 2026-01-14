"""
Time-dependent tracking of capacity.
"""

using JuMP
using ArgCheck

using Infiltrator

# Dict of year => (Dict of tech name => capacity)
struct Capacity{T}
    sim::PathSim
    ini::LittleDict{Int64, Dict{String,Float64}} # current capacity, from initialization
    cur::LittleDict{Int64, Dict{String,T}} # current capacity, optimized
    dep::LittleDict{Int64, Dict{String,T}} # deployed (new) capacity, optimized
    ret::LittleDict{Int64, Dict{String,T}} # retired (not present at current year) capacity, optimized
end

years(c::Capacity) = collect(keys(c.cur))
function alltech(c::Capacity, y::Int)
    @argcheck haskey(c.cur, y) "Year $y is not present in the Path"
    return collect(keys(c.cur[y]))
end

# return a capacity dict for a snapshot
# filter with tags for both nodes and components that will be integrated into the capacity dict
# this is necessary to remove components that are not supposed to be tracked (e.g. foreign)
function _getcapacities(s::Snapshot{T}; cwith=Symbol[], cwithout=Symbol[], nwith=Symbol[], nwithout=Symbol[]) where T
    d = Dict{String,T}()
    for (kn,_) in getnodes(s, with=nwith, without=nwithout)
        for (k,v) in getcomponents(s, kn, with=cwith, without=cwithout)
            if !haskey(d, k) # avoid duplicates in case of component connected to multiple nodes
                if Nosy.hasbehavior(v, Nosy.AbstractCapacityBehavior) # TODO check time
                    d[k] = capacity(v) # TODO check time
                end
            end
        end
    end
    return d
end

# this method must only be called once
# otherwise deployment / retirement variables are duplicated
# built from fields of a Path
function Capacity(sim::PathSim, opt::PathOpt, snap::LittleDict{Int64,MetaSnapshot{T}}) where T
    # initialization of capacity, from options
    # NB opt.ini reflects new capacity. We want the ini here to reflect current capacity => summation.
    stech = _initech(opt.ini) # initialized from ini, iteratively built, as years are iterated chronologically in the (always sorted) LittleDict
    ini = LittleDict{Int64,Dict{String,Float64}}()
    _temp = Dict(cname => 0. for cname in stech)
    for (y, d) in opt.ini
        for cname in stech
            if haskey(d, cname)
                _temp[cname] += d[cname]
            end
        end
        ini[y] = copy(_temp)
    end
    
    # Dict of all present capacities
    # in this context, "present" means: present as a variable (possibly equal to zero)
    cur = LittleDict{Int64, Dict{String,T}}()
    for (y,msnap) in snap
        cur[y] = _getcapacities(msnap.snap)
    end

    # all capacities can be deployed if they are present
    # capacities that are not present cannot be deployed
    # so the deployment dict mirrors the current dict
    dep = LittleDict{Int64, Dict{String,T}}()
    for (y, d) in cur
        dep[y] = Dict{String, T}()
        for (cname, _) in d
            dep[y][cname] = Nosy._to_affexpr(@variable(sim.model, base_name="deploy_$(cname)_$(y)", lower_bound=0.0), sim.model) # TODO: add upper bound
        end
    end

    # all capacities can be retired if they are present
    # capacities that are not present anymore, but were present before, can be retired
    ret = LittleDict{Int64, Dict{String,T}}()
    for (y, d) in cur
        ret[y] = Dict{String, T}()
        
        # increment set of technologies so far, including technologies not present in current year
        for (cname, _) in d
            push!(stech, cname)
        end
        
        # add retirement variables for all technologies seen so far
        for cname in stech
            ret[y][cname] = Nosy._to_affexpr(@variable(sim.model, base_name="retire_$(cname)_$(y)", lower_bound=0.0), sim.model) # TODO: add upper bound
        end
    end

    return Capacity{T}(sim, ini, cur, dep, ret)
end

function _previousyear(c::Capacity, y::Int) 
    s = filter(yy -> yy < y, keys(c.cur))
    isempty(s) && return nothing # no previous year: return nothing
    return maximum(s) # return previous year
end

function _initech(ini::LittleDict)
    s = Set{String}()
    for (_,i) in ini
        for (k,_) in i
            push!(s, k)
        end
    end
    return s
end

# return initialization value (capacity before sim starts). If not present, ini is zero.
function _inicap(c::Capacity{T}, cname::String) where T
    isempty(c.ini) && return 0.
    lini = c.ini[maximum(keys(c.ini))]
    haskey(lini, cname) && return lini[cname]
    return 0.
end

# variables
# * new capacity as variable > 0
# * retirement as variable > 0
# functions
# * difference of capacity as expression of current + old capacity => deltacap
# constraints
# * current = old + new - retired

# return difference between current capacity and previous capacity
function deltacap(c::Capacity{T}, cname::String, y::Int64) where T
    @assert haskey(c.cur, y) "Year $y not found in capacity data"
    
    # current capacity
    # if component is not present: current capacity is zero
    # otherwise: dict lookup
    if haskey(c.cur[y], cname)
        cc = c.cur[y][cname]
    else 
        cc = zero(T)
    end

    # previous capacity
    py = _previousyear(c, y)
    if isnothing(py)
        pc = _inicap(c, cname) # if no previous year: old capacity is set to ini
    else
        if haskey(c.cur[py], cname)
            pc = c.cur[py][cname]
        else 
            pc = zero(T)
        end
    end
    
    return cc - pc
end

function _apply_dynamic_capacity_constraint!(c::Capacity)
    # for each "current" year, apply the constraint "delta before previous and current capacity is equal to deployed - retired"
    for y in years(c)
        for cname in alltech(c, y)
            delta = deltacap(c, cname, y)
            dep = c.dep[y][cname]
            ret = c.ret[y][cname]
            @constraint(c.sim.model, delta == dep - ret)
        end
    end
end