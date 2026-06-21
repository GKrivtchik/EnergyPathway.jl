using Documenter
using EnergyPathway

makedocs(
    sitename="EnergyPathway.jl",
    authors="Guillaume KRIVTCHIK",
    modules=[EnergyPathway],
    checkdocs=:exports,
    repo="https://github.com/GKrivtchik/EnergyPathway.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://GKrivtchik.github.io/EnergyPathway.jl/",
        repolink="https://github.com/GKrivtchik/EnergyPathway.jl",
        edit_link="main",
    ),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "EnergyPathway Concepts" => "concepts.md",
        "API Reference" => "api.md",
    ],
)

if get(ENV, "CI", "false") == "true"
    deploydocs(
        repo="github.com/GKrivtchik/EnergyPathway.jl.git",
        devbranch="main",
    )
end
