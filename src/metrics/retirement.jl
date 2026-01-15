using Nosy: hascomponent

function retirement(p::Path, cname::String, year::Int) # same as _retirement but with cleaner signature
    return _retirement(p, cname, year)
end

"""
    _retirement(p::Path{T}, cname::String, year::Int) where T
Return a Vector of retired capacity.
"""
function _retirement(p::Path{T}, cname::String, year::Int) where T
    if year > p.opt.endyear || (!(year in p.opt.years) && year < lastsnapshotyear(p))
        return zero(T)
    elseif year in p.opt.years
        snap = getsnapshot(p, year)
        if hascomponent(snap, cname)
            c = getcomponent(snap, cname)
            b = uniquebehavior(c, AbstractRetirementBehavior{T})
            if !isnothing(b)
                return _retirement(b)
            end
        end
    elseif lastsnapshotyear(p) < year # => the component will be deployed again after lifetime, until end of modeling window
        # check if there is a Deployment + Lifetime behavior
        # automatically retire at the end of lifetime if this date is between last snapshot year and end year
        for (y::Int64, msnap::MetaSnapshot{T}) in p.snap
            snap = msnap.snap::Snapshot{T}
            if hascomponent(snap, cname)
                c = getcomponent(snap, cname)
                d = uniquebehavior(c, AbstractDeploymentBehavior{T})
                l = uniquebehavior(c, LifetimeBehavior{T})::Union{Nothing,LifetimeBehavior{T}}
                if !isnothing(l) && !isnothing(d)
                    if mod(year-y, _lifetime(l)) == 0 && _lifetime(l) + y >= lastsnapshotyear(p) # if this matches an EOL and the first possible renewal is after the last snapshot year
                        return _deployment(d)
                    end
                end
            end
        end
    end
    return zero(T)
end