include("solve_master.jl")
include("solve_slave.jl")

function has_negative_reduced_cost(slave_solutions, tour_pool)
    """Check if solutions have a negative reduced cost taking acount an error
    precision."""
    if slave_solutions == []
        return(true)
    end
    for i in slave_solutions
        if tour_pool[i]["reduced_cost"]<-10^-3
            return(true)
        end
    end
    return(false)
end

function add_tours(node_tours, slave_solutions, tour_pool)
    """Add slave solutions tours with negative reduced cost to tour pool and
    the index of those solutions to the node tour index array."""
    nb_tours_added = 0
    for i in slave_solutions
        if tour_pool[i]["reduced_cost"]<-10^-3
            push!(node_tours, i)
            nb_tours_added += 1
        end
    end
    return(nb_tours_added, tour_pool)
end

function has_integer_solution(coefficients)
    """Check if all coefficents are integer taking account a precision."""
    for coef in coefficients
        if abs(round(coef)-coef)>10^-3
            return(false)
        end
    end
    return(true)
end


function update_upper_bound(global_upper_bound, coefficients, tours, tour_pool, global_best_node, node)
    """Compute the total cost of a node solution with cost of the tours taken
    into account if all coefficients are integer. Update the actual upper bound
    if needed."""
    if has_integer_solution(coefficients)
        new_upper_bound = sum([coefficients[i]*tour_pool[tour]["cost"] for (i,tour) in enumerate(tours)])
        if new_upper_bound < global_upper_bound
            return(true, new_upper_bound, node)
        end
    end
    return(false, global_upper_bound, global_best_node)
end

function not_feasible(alpha)
    return(isnan(alpha[1]))
end


function solve_relax(node, data, graph, global_upper_bound, tour_pool, branch_pool, global_best_node)
    """For a node, while the relaxation has solutions with a negative reduced
    cost, add those tour to the node tours (and the tour_pool). If solutions
    are integer, check for an upper bound update."""

    slave_solutions = []
    nb_master_solved = 0
    nb_slave_solved = 0
    nb_tours_added = 0

    # Solve node master-slave problem
    if verbose; println("Reduced cost :"); end
    while has_negative_reduced_cost(slave_solutions, tour_pool)
        (nb_tours, tour_pool) = add_tours(node["tours"], slave_solutions, tour_pool)
        nb_tours_added += nb_tours
        dual_values = solve_master(node, data, tour_pool, branch_pool, true)
        if not_feasible(node["alpha"])
            break
        end
        nb_master_solved += 1
        slave_solutions = []
        for depot in data[1, :depots]
            (slave_sol, tour_pool) = solve_slave(graph, data, tour_pool, branch_pool, depot, dual_values, node["branch"])
            push!(slave_solutions, slave_sol)
            nb_slave_solved += 1
            if verbose; overprint(string("Reduced cost : ", last(tour_pool)["reduced_cost"])); end
        end
    end

    # Update node lower bound
    node["lower_bound"] = sum([node["alpha"][i]*tour_pool[tour]["cost"] for (i,tour) in enumerate(node["tours"])])

    # Update upper bound in case of integer solution
    (bound_updated, global_upper_bound, global_best_node) = update_upper_bound(global_upper_bound, node["alpha"], node["tours"], tour_pool, global_best_node, node)

    if verbose; println("Master solved : ", nb_master_solved, " | Slave solved : ",
        nb_slave_solved, " | Tours added : ", nb_tours_added,
        " | Lower bound : ", node["lower_bound"],
        " | Upper bound updated : ", bound_updated,
        " | Number of tours : ", length(node["tours"]),
        " | Upper bound : ", global_upper_bound); end
    return(global_upper_bound, tour_pool, branch_pool, global_best_node)
end
