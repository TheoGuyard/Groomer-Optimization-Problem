include("CPP.jl")
include("DCPP.jl")
include("MCPP.jl")
include("MCARP.jl")

function starts_in(arc, vertex, arc_set)
    return(arc_set[arc, :start_node]==vertex)
end

function ends_in(arc, vertex, arc_set)
    return(arc_set[arc, :end_node]==vertex)
end

function find_problem_type(nb_vehicles, graph)
    """Finds of wich type the problem is."""

    if nb_vehicles == 1     # Chinese postman problem type
        if (nrow(graph["req_arcs"])==0) & (nrow(graph["noreq_arcs"])==0)
            problem_type = "CPP"
        elseif (nrow(graph["req_edges"])==0) & (nrow(graph["noreq_edges"])==0)
            problem_type = "DCPP"
        else
            problem_type = "MCPP"
        end
    elseif nb_vehicles > 1  # MCARP problem type
        problem_type = "MCARP"
    else
        error("Problem with vehicle number. Check the dataset's validity.")
    end

    return(problem_type)
end

function solve_with_appropriate_model(problem_type, data, graph)
    """Solve problem with the apropriated modelisation."""

    if problem_type == "MCARP"
        (tours, solving_time) = MCARP_solve(data, graph)
    elseif problem_type == "CPP"
        (tours, solving_time) = CPP_solve(data, graph)
    elseif problem_type == "DCPP"
        (tours, solving_time) = DCPP_solve(data, graph)
    elseif problem_type == "MCPP"
        (tours, solving_time) = MCPP_solve(data, graph)
    else
        error("Problem while choosing wich model to use.")
    end

    return(tours, solving_time)
end

function solve_single_depot(data, graph)
    """Solve problem in the case of a single-depot dataset."""

    problem_type = find_problem_type(data[1, :nb_vehicles], graph)
    println("Algorith used : ", problem_type)
    println("Solving problem ...")
    (tours, solving_time) = solve_with_appropriate_model(problem_type, data, graph)

    return(tours, solving_time)
end
