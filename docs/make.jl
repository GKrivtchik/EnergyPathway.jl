using Documenter
using Pathway

makedocs(
    sitename="Pathway.jl",
    authors="Guillaume KRIVTCHIK, OECD Nuclear Energy Agency (OECD-NEA)",
    modules=[Pathway],
    checkdocs=:exports,
    repo="https://github.com/GKrivtchik/Pathway.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://GKrivtchik.github.io/Pathway.jl/",
        repolink="https://github.com/GKrivtchik/Pathway.jl",
        edit_link="main",
    ),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "Pathway Concepts" => "concepts.md",
        "API Reference" => "api.md",
    ],
)

if get(ENV, "CI", "false") == "true"
    deploydocs(
        repo="github.com/GKrivtchik/Pathway.jl.git",
        devbranch="main",
    )
end
