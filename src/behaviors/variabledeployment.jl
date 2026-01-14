using JuMP: @variable, GenericAffExpr, set_upper_bound, set_lower_bound, set_start_value
using ArgCheck: @argcheck

using Nosy: AbstractRegularBehaviorData, AbstractRegularBehavior
using Nosy: getcapacitybehavior, hasport, hasmodifier, getport, VAL, name, modifiername, _to_affexpr

import Nosy: buildbehavior, _apply_constraints!, behaviorname, _portname, _modifier


abstract type AbstractSingleEventData <: AbstractRegularBehaviorData end
abstract type AbstractSingleEventBehavior{T} <: AbstractRegularBehavior{T} end

abstract type AbstractDeploymentData <: AbstractSingleEventData end
abstract type AbstractDeploymentBehavior{T} <: AbstractSingleEventBehavior{T} end

"""
Behavior: variable deployment.
"""

struct VariableDeployment{M<:Function} <: AbstractDeploymentData
    pname::String
    modifier::M
    lb::Float64
    ub::Float64
end

"""
    VariableDeployment(pname::String; lb::Number=0., ub::Number=Inf)
Return a VariableDeployment behavior data, associated with port name `pname` and modifier `modifier`.
Optional parameters:
* lb: lower bound
* ub: upper bound
"""
function VariableDeployment(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf)
    @argcheck lb >= 0. "Deployment cannot be negative"
    @argcheck lb <= ub "Lower bound is bigger than upper bound"
    VariableDeployment(pname, modifier, Float64(lb), Float64(ub))
end

struct VariableDeploymentBehavior{T<:VAL,M<:Function} <: AbstractDeploymentBehavior{T}
    data::VariableDeployment{M}
    val::T
end

# return a VariableDeploymentBehavior
function buildbehavior(c::Component, b::VariableDeployment)    
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"
    cap = getcapacitybehavior(c, b.pname) # same port
    @argcheck cap.data.modifier == b.modifier "Deployment must have same modifier as capacity"

    v = @variable(lowermodel(sim(c)), base_name=name(c) * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "dep" * "_" * sim(c).suffix, lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
    e = _to_affexpr(v, sim(c).model)

    return VariableDeploymentBehavior(b, e)
end

# deployment constraint is handled at Path level

_apply_constraints!(::Component, ::VariableDeploymentBehavior) = nothing

behaviorname(::VariableDeploymentBehavior) = "variable deployment"

# return the GenericAffExpr
_deployment(c::VariableDeploymentBehavior) = c.val

_portname(c::VariableDeploymentBehavior) = c.data.pname
_modifier(c::VariableDeploymentBehavior) = c.data.modifier