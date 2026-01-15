"""
Single (non-recurring) cost.
Examples: investment cost, retirement cost.
Cost is proportional to related capacity (e.g. newly deployed capacity for investment cost).
"""

using ArgCheck
using OrderedCollections: OrderedDict
using Memoize: @memoize

using Nosy: getcomponent
using Nosy: AbstractCostBehaviorData, AbstractCostBehavior
using Nosy: VAL, exptype
using Nosy: uniquebehavior

# import Nosy functions that are extended
import Nosy: _costtype, _portname, _modifier, behaviorname, _apply_constraints!
import Nosy: buildbehavior

struct SingleCost{M<:Function} <: AbstractCostBehaviorData
    type::Symbol # user-chosen tag
    operation::Symbol # :deployment / :retiring
    pname::String
    modifier::M
    val::Float64
    profile::Dict{Int64,Float64} # normalized cost profile with key = time offset vs operation, value = share of cost. Sum is equal to one.

    @doc """
        SingleCost(type::Symbol, operation::Symbol, pname::String, modifier::Function, val::Number, profile::Union{Nothing,AbstractDict{<:Int,<:Number}})
    Return a SingleCost behavior data, associated with port name `pname`, modifier `modifier` and fixed value `val`.
    """
    function SingleCost(type::Symbol, operation::Symbol, pname::String, modifier::Function, val::Number, profile::Union{Nothing,AbstractDict{<:Int,<:Number}})
        @argcheck operation in (:deployment, :retiring) "operation must be either :deployment or :retiring"
        
        isnothing(profile) && (profile = Dict(0 => 1.))
        @argcheck isapprox(sum(values(profile)), 1., atol=0.001) "Sum of profile values must be equal to zero"
        new{typeof(modifier)}(type, operation, pname, modifier, val, profile)
    end
end

struct SingleCostBehavior{T<:VAL,M<:Function} <: AbstractCostBehavior{T}
    data::SingleCost{M}
    val::T
end

function buildbehavior(c::Component, b::SingleCost)
    if b.operation == :deployment
        cap = uniquebehavior(c, AbstractDeploymentBehavior)
        @argcheck b.pname == cap.data.pname "Deployment behavior uses a different port"
        @argcheck b.modifier == cap.data.modifier "Deployment behavior uses a different modifier"
        val = _deployment(cap)
    else
        throw(AssertionError("Not implemented"))
    end
    cost = convert(exptype(sim(c)), val * b.val)
    return SingleCostBehavior(b, cost)
end

_costtype(b::SingleCostBehavior) = b.data.type

_portname(b::SingleCostBehavior) = b.data.pname
_modifier(b::SingleCostBehavior) = b.data.modifier

behaviorname(::SingleCostBehavior) = "single cost"
_apply_constraints!(::Component, ::SingleCostBehavior) = nothing


# memoize this function 
# this function builds once and for all the Dict of deployment costs, at all times
# it will be used to then generate the deployment costs at specific times
function _singlecost(p::Path{T}, cname::String, type::Symbol) where T
    d = OrderedDict{Int64,Dict{Symbol,T}}() # Dict of year => (type => cost)
    
    ddep = OrderedDict(y => _deployment(p, cname, y) for y in (first(p.opt.years)-10):p.opt.endyear) #TODO: replace -10 with biggest anticipation

    # initialization of all yearly dict
    for (y,_) in ddep
        d[y] = Dict(:deployment => zero(T), :retirement => zero(T))
    end

    for (y,dep) in ddep
        if !isempty(dep)
            # there is a deployment occurring at y
            for (snapyear, tuple) in dep # all the snapshots the sub-parts or deployment are linked to
                ratio = tuple[2]
                snap = getsnapshot(p, snapyear)
                c = getcomponent(snap, cname)
                vb = Nosy.behaviors(c, SingleCostBehavior{T})
                for b in vb
                    for op in (:deployment, :retirement)
                        if b.data.operation == op
                            for (deltay, invratio) in b.data.profile
                                d[y+deltay][op] += __singlecost(p.snap[snapyear], b, y+deltay, p.opt, type) * ratio * invratio * discount(p.opt, y+deltay)
                            end
                        end
                    end
                end
            end
        end
    end
    return d
end



discount(o::PathOpt, year::Int) = (1. + o.discountrate)^(o.baseyear - year)

# return the non-discounted cost associated with a SingleCost, at a year shifted by deltayear from current year
# do NOT call this function if you're unsure what you're doing - it's not discounted
function __singlecost(b::SingleCostBehavior{T}, deltayear::Int, type::Union{Nothing,Symbol}) where T
    if haskey(b.data.profile, deltayear)
        if isnothing(type) || b.data.type == type
            return b.val * b.data.profile[deltayear]
        end
    end
    return zero(T)
end

# return the discounted cost associated with a SingleCost, at a given year
function __singlecost(snap::MetaSnapshot, b::SingleCostBehavior, year::Int, o::PathOpt, type::Union{Nothing,Symbol})
    deltay = year - snap.year # years between "year" and year the singe cost action occurs; negative year = anticipation
    discount = (1. + o.discountrate)^(o.baseyear - year) # discounting between baseyear and "year"
    return __singlecost(b, deltay, type) * discount
end

function _singlecost(p::Path{T}, cname::String, year::Int, operation::Symbol; type::Union{Nothing,Symbol}=nothing) where T
    # find all occurrences of the component named cname in all snapshots
    val = zero(T)
    for (y,snap) in p
        c = getcomponent(snap.snap, cname)
        vb = Nosy.behaviors(c, SingleCostBehavior{T})
        for b in vb
            if b.data.operation == operation
                val = Nosy.addto!(val, __singlecost(snap, b, year, p.opt, type))
            end
        end
    end
    return val
end

deploymentcost(p::Path, cname::String, year::Int; type::Union{Nothing,Symbol}=nothing) = _singlecost(p, cname, year, :deployment, type=type)