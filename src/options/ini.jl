"""
Initialization of capacity.
"""

using ArgCheck: @argcheck
using OrderedCollections: OrderedDict

# one initialization entry
# there can be multiple entries per component, for different years
mutable struct HistoricalCapacity
    cname::String
    capacity::Float64 # in same unit / modifier as the component capacity
    lifetime::Int64
end

# collection of initialization entries
# wrapper to hold an ordered dictionary of year => HistoricalCapacity
struct InitialCapacity
    capacities::OrderedDict{Int64, Vector{HistoricalCapacity}}
end

"""
    InitialCapacity(v::AbstractVector)
Return an InitialCapacity object from a vector of tuples (year::Int64, cname::String, capacity::Float64, lifetime::Int64).
"""
function InitialCapacity(v::AbstractVector)
    d = Dict{Int64,Vector{HistoricalCapacity}}()
    
    for e in v
        (y, cname, cap, lifetime) = e
        if haskey(d, y)
            for hc in d[y]
                if hc.cname == cname
                    throw(ArgumentError("duplicate initialization entry for component $cname in year $y"))
                end
            end
        else
            d[y] = Vector{HistoricalCapacity}()
        end
        @argcheck cap > 0 "capacity must be strictly positive"
        @argcheck isinteger(lifetime) "lifetime must be an integer"
        @argcheck lifetime > 0 "lifetime must be strictly positive"
        push!(d[y], HistoricalCapacity(cname, Float64(cap), Int64(lifetime)))
    end

    return InitialCapacity(sort(d))
end

# example of initialization vector:
# v = [(year, cname, capacity, lifetime), ...]
# v = [(2000, "PV", 100, 25), (2000, "battery", 50, 15), (2010, "PV", 200, 25)]