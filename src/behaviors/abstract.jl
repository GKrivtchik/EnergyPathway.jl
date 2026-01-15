using Nosy: AbstractRegularBehaviorData, AbstractRegularBehavior

abstract type AbstractPathBehaviorData <: AbstractRegularBehaviorData end
abstract type AbstractPathBehavior{T} <: AbstractRegularBehavior{T} end

abstract type AbstractSingleEventData <: AbstractPathBehaviorData end
abstract type AbstractSingleEventBehavior{T} <: AbstractPathBehavior{T} end

abstract type AbstractDeploymentData <: AbstractSingleEventData end
abstract type AbstractDeploymentBehavior{T} <: AbstractSingleEventBehavior{T} end