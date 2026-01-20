"""
Pathway-style cost metrics.

Costs are initially defined in Nosy for snapshots. However, some costs (investment) must be reimplemented.
Time-dependency must be added to all cost metrics.
"""

import Nosy: variablecost, fixedcost, cost


# path + cname + year (+type)

function singlecost(p::Path, cname::String, year::Int, type::Union{Nothing,Symbol}=nothing) # Pathway only
    _singlecost(p, cname, year, type)
end

function variablecost(p::Path{T}, cname::String, year::Int, type::Union{Nothing, Symbol}=nothing) where T # based on Nosy. Same implementation as fixedcost.
    # variable costs are assumed to be zero before the next snapshot
    if year < firstsnapshotyear(p)
        return zero(T)
    end

    # get the Nosy variable cost, then discount it against baseyear
    snap = getsnapshot(p, snapshotyear(p, year))
    disc = discount(p.opt, year)
    if isnothing(type)
        c = Nosy.variablecost(snap, cname)
    else
        c = Nosy.variablecost(snap, cname, type)
    end
    return c * disc
end

function fixedcost(p::Path{T}, cname::String, year::Int, type::Union{Nothing,Symbol}=nothing) where T # based on Nosy. Same implementatio nas variablecost.
    # fixed costs are assumed to be zero before the next snapshot
    if year < firstsnapshotyear(p)
        return zero(T)
    end

    # get the Nosy fixed cost, then discount it against baseyear
    snap = getsnapshot(p, snapshotyear(p, year))
    disc = discount(p.opt, year)
    if isnothing(type)
        c = Nosy.fixedcost(snap, cname)
    else
        c = Nosy.fixedcost(snap, cname, type)
    end

    return c * disc
end

cost(p::Path, cname::String, year::Int, type::Union{Nothing,Symbol}=nothing) = singlecost(p, cname, year, type) + fixedcost(p, cname, year, type) + variablecost(p, cname, year, type)


# path + cname (+type)

function singlecost(p::Path, cname::String, type::Union{Nothing,Symbol}=nothing) # optimization here: _singlecost is called only once
    return sum(sum.(values.(values(_singlecost(p, cname, type)))))
end

variablecost(p::Path, cname::String, type::Union{Nothing,Symbol}=nothing) = sum(variablecost(p, cname, y, type) for y in allyears(p))
fixedcost(p::Path, cname::String, type::Union{Nothing,Symbol}=nothing) = sum(fixedcost(p, cname, y, type) for y in allyears(p))

cost(p::Path, cname::String, type::Union{Nothing,Symbol}=nothing) = singlecost(p, cname, type) + fixedcost(p, cname, type) + variablecost(p, cname, type)

# path (+type)

singlecost(p::Path, type::Union{Nothing,Symbol}=nothing) = sum(singlecost(p, cname, type) for cname in alltech(p))
variablecost(p::Path, type::Union{Nothing,Symbol}=nothing) = sum(variablecost(p, cname, type) for cname in alltech(p))
fixedcost(p::Path, type::Union{Nothing,Symbol}=nothing) = sum(fixedcost(p, cname, type) for cname in alltech(p))
cost(p::Path, type::Union{Nothing,Symbol}=nothing) = singlecost(p, type) + variablecost(p, type) + fixedcost(p, type)