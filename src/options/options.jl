using OrderedCollections: OrderedDict
using ArgCheck: @argcheck

using Nosy: TimeMesh

using Infiltrator

struct PathOpt
    years::Vector{Int64} # sorted at construction
    discountrate::Float64
    baseyear::Int64
    endyear::Int64
    mesh::OrderedDict{Int64,TimeMesh}
    ini::InitialCapacity # initialized capacity, exempted from cost and construction

    function PathOpt(years, discountrate::Float64, baseyear::Int, endyear::Int, mesh::Union{AbstractDict{Int64,TimeMesh},TimeMesh}; ini=[]) # TODO update ini, must account for year for each sub-capacity
        @argcheck !isempty(years) "years cannot be empty"
        years = sort(years) # invariant: years are sorted at constructor
        @argcheck all(isinteger, years) "years must be integers"
        @argcheck 0 <= discountrate <= 0.2 "suspicious discountrate value - expected value around 0.05"
        
        if mesh isa AbstractDict
            @argcheck all(haskey(mesh, y) for y in years) "mesh must have entries for all years"
            mesh = OrderedDict(y => mesh[y] for y in years) # adapt to correct format
        elseif mesh isa TimeMesh
            mesh = OrderedDict(y => mesh for y in years)
        end

        re_ini = InitialCapacity(ini)
        @argcheck all(y < first(years) for y in keys(re_ini.capacities)) "initial capacities can only be defined for years before or equal to first snapshot year"
        for (y, v) in re_ini.capacities
            for tech in v
                @argcheck tech.lifetime + y >= first(years) "initialized capacity for component $(tech.cname) in year $y has expired before first snapshot year $(first(years))"
            end
        end

        new(years, discountrate, Int64(baseyear), Int64(endyear), mesh, re_ini)
    end
end

years(o::PathOpt) = o.years

function mesh(o::PathOpt, y::Int64)
    @argcheck haskey(o.mesh, y) "mesh not defined for year $y"
    return o.mesh[y]
end