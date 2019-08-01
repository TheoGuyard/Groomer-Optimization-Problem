include("branch_and_price.jl")

function solve_multi_depot(data, graph, approx, verbose)
    """Solve problem in the case of a single-depot dataset."""

    if approx
        println("Algorithm used : Branch-and-Price with an approximated solution")
    else
        println("Algorithm used : Branch-and-Price with an optimal solution")
    end
    println("Solving problem ...")
    (tours, solving_time) = branch_and_price(data, graph, approx, verbose)

    return(tours, solving_time)
end
