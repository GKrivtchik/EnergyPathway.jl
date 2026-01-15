using Nosy: hascomponent

function deployment(p::Path, cname::String, year::Int)
    d = _deployment(p, cname, year)
    return sum(first(v) for v in values(d))
end

"""
    _deployment(p::Path{T}, cname::String, year::Int) where T
Return a Vector of (deployed capacity, time ratio).
The time ratio means the share of the lifetime of the component present before the end of the path, and is to be used as a multiplier of the investment cost.
"""
function _deployment(p::Path{T}, cname::String, year::Int) where T
    dep = Dict{Int64,Tuple{T,Float64}}()
    if year > p.opt.endyear || (!(year in p.opt.years) && year < lastsnapshotyear(p))
        nothing
    elseif year in p.opt.years
        snap = getsnapshot(p, year)
        if hascomponent(snap, cname)
            c = getcomponent(snap, cname)
            b = uniquebehavior(c, AbstractDeploymentBehavior{T})
            if !isnothing(b)
                # some components canot be retired exactly at the end of lifetime, because there is no snapshot
                # we look the the next snapshot, and retire it at this point
                # below, we evaluate a ratio r2 that represents discounted extension of lifetime
                # r2 is to be applied to deployment cost
                l = uniquebehavior(c, LifetimeBehavior{T})
                if isnothing(l)
                    r2 = 1.
                else
                    eol = year + _lifetime(l)
                    if eol < lastsnapshotyear(p) && !(eol in years(p.opt))
                        ny = minimum(y for y in years(p.opt) if y >= eol)
                        r2 = sum(discount(p.opt, y) for y in year:ny) / sum(discount(p.opt,y) for y in year:eol)
                    else
                        r2 = 1.
                    end
                end
                dep[year] = (_deployment(b), r2)
            end
        end
    elseif lastsnapshotyear(p) < year # => the component will be deployed again after lifetime, until end of modeling window
        # check if there is a Lifetime behavior
        # this has to be checked for every snapshot and compared with both last snapshot year and end year
        for (y::Int64, msnap::MetaSnapshot{T}) in p.snap
            snap = msnap.snap::Snapshot{T}
            if hascomponent(snap, cname)
                c = getcomponent(snap, cname)
                l = uniquebehavior(c, LifetimeBehavior{T})::Union{Nothing,LifetimeBehavior{T}}
                if !isnothing(l)
                    if mod(year-y, _lifetime(l)) == 0
                        if (y+(div(year-y, _lifetime(l))+1)*_lifetime(l)) <= p.opt.endyear
                            dep[y] = (deployment(p, cname, y), 1.)
                        else
                            r = p.opt.endyear - (y+div(year-y, _lifetime(l))*_lifetime(l)) # number of remaining years, not present in the path
                            println(y)
                            ratio = sum((1+p.opt.discountrate)^-l for l in 0:r) / sum((1+p.opt.discountrate)^-l for l in 0:(_lifetime(l)-1)) # sum of discount until end of remaining time / sum of discount until end of lifetime
                            dep[y] = (deployment(p, cname, y), ratio) # recursive call, but this one lands on a straightforward case because y is a snapshot year. No multiple recursion.
                        end
                    end
                end
            end
        end
    end
    return dep
end