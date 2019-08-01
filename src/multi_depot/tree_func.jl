function create_initial_tour(data, graph)
    """Create an initial tour with a very high cost and wich cover all
    required arcs/edges."""
    initial_tour = Dict()
    initial_tour["depot"] = Nothing
    initial_tour["reduced_cost"] = 10^3*(sum(graph["req_arcs"][:serv_cost]) +
        sum(graph["req_arcs"][:trav_cost]) + sum(graph["req_edges"][:serv_cost]) +
        sum(graph["req_edges"][:trav_cost]))
    initial_tour["cost"] = initial_tour["reduced_cost"]
    initial_tour["X"] = Dict(
        "req_arcs" => [1 for arc in 1:data[1,:req_arcs]],
        "req_edges" => [1 for arc in 1:data[1,:req_edges]],
        "req_edges_swap" => [1 for arc in 1:data[1,:req_edges]]
        )
    return(initial_tour)
end

function cut_branch(node, global_upper_bound, data, verbose)
    """Cut the branch if the current node can't improve the upper bound."""
    if (node["lower_bound"]>global_upper_bound)
        if verbose; println("Cut branch because of bound"); end
    elseif (isnan(node["lower_bound"]))
        if verbose; println("Cut branch because of NaN"); end
    end
    return((node["lower_bound"]>global_upper_bound) | (isnan(node["lower_bound"])))
end

function create_child_node(parent, branch_index)
    """From a parent node and a branch, create two child nodes."""

    even_node = Dict(
        "type" => "even",
        "branch" => push!(copy(parent["branch"]), branch_index),
        "tours" => copy(parent["tours"]),
        "dual_bound" => 0,
        "alpha" => [],
    )

    odd_node = Dict(
        "type" => "odd",
        "branch" => push!(copy(parent["branch"]), branch_index),
        "tours" => copy(parent["tours"]),
        "dual_bound" => 0,
        "alpha" => [],
    )

    return(even_node, odd_node)
end

function possible_branch(node, depot, arc_type, arc, branch_pool, data)
    """Checks if the branch doesn't already exists for the node and if it
    doesn't make the problem infeable by setting to 0 the number of passages
    in a required arc/edge."""

    if [depot, arc_type, arc] in [branch_pool[i] for i in node["branch"]]
        return(false)
    end

    depot_avoided_for_arc = 0
    for branch in [branch_pool[i] for i in node["branch"]]
        if (branch[2]==arc_type) & (branch[3]==arc)
            depot_avoided_for_arc += 1
        end
    end
    if depot_avoided_for_arc >= (length(data[1, :depots])-1)
        return(false)
    else
        return(true)
    end
end

function create_branch(node, tour_pool, branch_pool, data)
    """Create a branch from node depending of the coefficients of the
    master problem. Also checking if the branch hasen't already been created."""

    # Constructing delta
    delta = Dict()

    for depot in data[1, :depots]
        delta[depot] = Dict("req_arcs"=>[], "req_edges"=>[], "req_edges_swap"=>[])

        for arc in 1:data[1,:req_arcs]
            if possible_branch(node, depot, "req_arcs", arc, branch_pool, data)
                sum_arc = 0
                for (i,j) in enumerate(node["tours"])
                    if tour_pool[j]["depot"] == depot
                        sum_arc += node["alpha"][i]*tour_pool[j]["X"]["req_arcs"][arc]
                    end
                end
                push!(delta[depot]["req_arcs"], sum_arc)
            else
                push!(delta[depot]["req_arcs"], typemax(Int64))
            end
        end

        for arc in 1:data[1,:req_edges]
            if possible_branch(node, depot, "req_edges", arc, branch_pool, data)
                sum_arc = 0
                for (i,j) in enumerate(node["tours"])
                    if tour_pool[j]["depot"] == depot
                        sum_arc += node["alpha"][i]*tour_pool[j]["X"]["req_edges"][arc]
                    end
                end
                push!(delta[depot]["req_edges"], sum_arc)
            else
                push!(delta[depot]["req_edges"], typemax(Int64))
            end
        end

        for arc in 1:data[1,:req_edges]
            if possible_branch(node, depot, "req_edges_swap", arc, branch_pool, data)
                sum_arc = 0
                for (i,j) in enumerate(node["tours"])
                    if tour_pool[j]["depot"] == depot
                        sum_arc += node["alpha"][i]*tour_pool[j]["X"]["req_edges_swap"][arc]
                    end
                end
                push!(delta[depot]["req_edges_swap"], sum_arc)
            else
                push!(delta[depot]["req_edges_swap"], typemax(Int64))
            end
        end
    end

    min_depot = Dict()
    for depot in data[1, :depots]
        min_arcs = try
                findmin(abs.(delta[depot]["req_arcs"].-0.5))
            catch
                (1000000,1)
            end
        min_edges = try
                findmin(abs.(delta[depot]["req_edges"].-0.5))
            catch
                (1000000,1)
            end
        min_edges_swap = try
                findmin(abs.(delta[depot]["req_edges_swap"].-0.5))
            catch
                (1000000,1)
            end
        mins = [min_arcs, min_edges, min_edges_swap]
        type_min = ["req_arcs", "req_edges", "req_edges_swap"]
        min_tot = findmin([min_arcs[1], min_edges[1], min_edges_swap[1]])
        # Type d'arc/arête | Numéro de l'arc/arête | Valeur du min
        min_depot[depot] = [type_min[min_tot[2]], mins[min_tot[2]][2], mins[min_tot[2]][1]]
    end

    min_tot = findmin([val[3] for val in values(min_depot)])

    # Dépot | Type d'arc/arête | Numéro de l'arc/arête
    branch = [collect(keys(min_depot))[min_tot[2]], min_depot[collect(keys(min_depot))[min_tot[2]]][1], min_depot[collect(keys(min_depot))[min_tot[2]]][2]]

    branch_index = length(branch_pool)+1
    push!(branch_pool, branch)

    return(branch_index, branch_pool)
end
