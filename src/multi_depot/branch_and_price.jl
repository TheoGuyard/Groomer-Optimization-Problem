include("tree_func.jl")
include("solve_relax.jl")

function branch_and_price(data, graph, approx, verbose)
    """Branch-and-Price algorithm wich can output an approximated solution
    or an otpimal solution."""

    if verbose; println("--------------------------"); end
    if verbose; println("BRANCH-AND-PRICE"); end
    start = now()

    node_pile = []
    branch_pool = []
    tour_pool = []
    global_upper_bound = Nothing
    global_best_node = Nothing

    if verbose; println("-------"); end
    if verbose; println("Creating the root ..."); end

    push!(tour_pool, create_initial_tour(data, graph))
    root = Dict(
        "type" => "root",
        "branch" => [],
        "tours" => [1],
        "lower_bound" => 0,
        "alpha" => []
        )
    global_upper_bound = first(tour_pool)["cost"]
    global_best_node = root

    solve_relax(root, data, graph, global_upper_bound, tour_pool, branch_pool, global_best_node)

    if approx
        if verbose; println("-------"); end
        if verbose; println("Solving master without relaxation ..."); end
        solve_master(root, data, tour_pool, branch_pool, false)
        tours = [tour_pool[j] for (i,j) in enumerate(global_best_node["tours"]) if global_best_node["alpha"][i]>=1-10^-5]
        tours = remove_multiple_service(tours, graph)
        stop = now()
        solving_time = stop-start
        return(tours, solving_time)
    end

    pushfirst!(node_pile, root)

    # Explore tree
    while length(node_pile)!=0

        node = popfirst!(node_pile)
        if verbose; println("-------"); end
        if verbose; println("Exploring ", node["type"], " node"); end

        if !cut_branch(node, global_upper_bound, data, verbose)

            if verbose; println("-------"); end
            (branch_index, branch_pool) = create_branch(node, tour_pool, branch_pool, data)
            (even_node, odd_node) = create_child_node(node, branch_index)
            if verbose; println("Branch on depot ", branch_pool[branch_index][1],
                " and on ", branch_pool[branch_index][2], " number ",
                branch_pool[branch_index][3]); end

            if verbose; println("-------"); end
            if verbose; println("Solving odd node relaxation ..."); end
            (global_upper_bound, tour_pool, branch_pool, global_best_node) = solve_relax(odd_node, data, graph, global_upper_bound, tour_pool, branch_pool, global_best_node)
            pushfirst!(node_pile, odd_node)

            if verbose; println("-------"); end
            if verbose; println("Solving even node relaxation ..."); end
            (global_upper_bound, tour_pool, branch_pool, global_best_node) = solve_relax(even_node, data, graph, global_upper_bound, tour_pool, branch_pool, global_best_node)

            pushfirst!(node_pile, even_node)
        end
    end

    tours = [tour_pool[j] for (i,j) in enumerate(global_best_node["tours"]) if global_best_node["alpha"][i]>=1-10^-5]
    if (global_best_node==root) | (tour_pool[1] in tours)
        error("No solutions for the problem. Try to use more vehicle or
        increase the capacity.")
    end

    stop = now()
    solving_time = stop-start
    if verbose; println("--------------------------"); end
    return(tours, solving_time)
end
