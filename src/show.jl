using JuMP: solver_name
using Nosy: modifiername

function _year_summary(years::AbstractVector{<:Integer})
    isempty(years) && return "no years"
    if length(years) == 1
        return string(only(years))
    end
    step = years[2] - years[1]
    if all(diff(years) .== step)
        return "$(first(years)):$step:$(last(years))"
    end
    return join(years, ", ")
end

function _n_entries(ini::InitialCapacity)
    return sum(length(v) for v in values(ini.capacities); init=0)
end

function _rate_summary(rate::Number)
    return "$(round(100 * rate; digits=3))%"
end

function _modifier_summary(modifier::Function)
    return modifiername(modifier)
end

function _solver_summary(model)
    try
        return solver_name(model)
    catch
        return string(typeof(model))
    end
end

function Base.show(io::IO, c::HistoricalCapacity)
    print(
        io,
        "Historical capacity \"$(c.cname)\" ($(c.capacity), lifetime $(c.lifetime) year(s))",
    )
end

function Base.show(io::IO, ini::InitialCapacity)
    n = _n_entries(ini)
    ny = length(ini.capacities)
    print(io, "Initial capacity with $n entr$(n == 1 ? "y" : "ies") in $ny year(s)")
end

function Base.show(io::IO, opt::PathOpt)
    n = length(years(opt))
    hist = _n_entries(opt.ini)
    horizon = isempty(years(opt)) ? "open horizon" : "base year $(opt.baseyear), end year $(opt.endyear)"
    print(io, "Path options ($n snapshot year(s): $(_year_summary(years(opt))); $horizon, discount rate $(_rate_summary(opt.discountrate)), $hist historical capacity entr$(hist == 1 ? "y" : "ies"))")
end

function Base.show(io::IO, ps::PathSim)
    print(
        io,
        "Path simulation ($(length(ps.dsim)) snapshot year(s), $(_solver_summary(ps.model)))",
    )
end

function Base.show(io::IO, snap::MetaSnapshot)
    print(io, "Meta snapshot $(snap.year): $(snap.snap)")
end

function Base.show(io::IO, path::Path)
    if _isoptimized(path)
        status = "optimized"
    elseif _isfinalized(path)
        status = "finalized"
    else
        status = "not finalized"
    end
    horizon = isempty(snapshotyears(path)) ? "open horizon" : "$(firstyear(path))-$(lastyear(path))"
    print(io, "Pathway with $(length(path)) snapshot year(s) ($(_year_summary(snapshotyears(path)))) over $horizon, $status")
end

function Base.show(io::IO, b::VariableDeployment)
    print(
        io,
        "Variable deployment on \"$(b.pname)\" $(_modifier_summary(b.modifier)) ($(b.lb) <= deployment <= $(b.ub))",
    )
end

function Base.show(io::IO, b::FixedDeployment)
    print(
        io,
        "Fixed deployment on \"$(b.pname)\" $(_modifier_summary(b.modifier)) ($(b.val))",
    )
end

function Base.show(io::IO, b::VariableRetirement)
    print(
        io,
        "Variable retirement on \"$(b.pname)\" $(_modifier_summary(b.modifier)) ($(b.lb) <= retirement <= $(b.ub))",
    )
end

function Base.show(io::IO, b::FixedRetirement)
    print(
        io,
        "Fixed retirement on \"$(b.pname)\" $(_modifier_summary(b.modifier)) ($(b.val))",
    )
end

function Base.show(io::IO, b::Lifetime)
    print(io, "Lifetime ($(b.years) year(s))")
end

function Base.show(io::IO, b::SingleCost)
    profile = join(["$y => $v" for (y, v) in sort(collect(b.profile); by=first)], ", ")
    print(
        io,
        "Single cost :$(b.type) on $(b.operation) of \"$(b.pname)\" $(_modifier_summary(b.modifier)) ($(b.val), profile $profile)",
    )
end
