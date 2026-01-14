using Nosy: hascomponent

function deployment(p::Path{T}, cname::String, year::Int) where T
    !(year in p.opt.years) && return zero(T)
    snap = p.snap[year].snap
    !hascomponent(snap, cname) && return zero(T) # NB this is zero, not nothing
    c = getcomponent(snap, cname)
    b = uniquebehavior(c, AbstractDeploymentBehavior)
    return _deployment(b)
end