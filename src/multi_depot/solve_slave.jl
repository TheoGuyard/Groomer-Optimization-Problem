function starts_in(arc, vertex, arc_set)
    return(arc_set[arc, :start_node]==vertex)
end

function ends_in(arc, vertex, arc_set)
    return(arc_set[arc, :end_node]==vertex)
end

function solve_slave(graph, data, tour_pool, branch_pool, depot, dual_values, node_branch)
    """Construct a tour starting and ending at the same depot wich is
    continuous and respects the capacity of the vehicle."""

    ### Constants ###

    # Number of arcs/edges
    card_Ar = data[1,:req_arcs]
    card_Anr = data[1,:noreq_arcs]
    card_Er = data[1,:req_edges]
    card_Enr = data[1,:noreq_edges]

    # Number of nodes
    nb_nodes = data[1,:nodes]

    # From an edge, create two opposite arcs
    Er_swap = copy(graph["req_edges"])
    Er_swap[:start_node], Er_swap[:end_node] = Er_swap[:end_node], Er_swap[:start_node]
    Enr_swap = copy(graph["noreq_edges"])
    Enr_swap[:start_node], Enr_swap[:end_node] = Enr_swap[:end_node], Enr_swap[:start_node]

    # All arcs
    A = vcat(graph["req_arcs"], graph["noreq_arcs"], graph["req_edges"],
        graph["noreq_edges"], Er_swap, Enr_swap)

    # Required arcs
    R = vcat(graph["req_arcs"], graph["req_edges"], Er_swap)

    # Demand on required arcs
    demand = R[:demand]

    # Costs of edges
    serv_cost = R[:serv_cost]
    trav_cost = A[:trav_cost]


    ### Model definiton ###
    model = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))

    ### Variables ###

    # Service variables
    @variable(model, X_Ar[1:card_Ar], Bin)
    @variable(model, X_Er[1:card_Er], Bin)
    @variable(model, X_Er_swap[1:card_Er], Bin)
    X_R = vcat(X_Ar, X_Er, X_Er_swap)
    X_tot = vcat(X_Ar, [0 for arc in 1:card_Anr],
        X_Er, [0 for arc in 1:card_Enr],
        X_Er_swap, [0 for arc in 1:card_Enr])

    # Passage without service variables
    @variable(model, Y_Ar[1:card_Ar], Int)
    @constraint(model, positivity_Ar, Y_Ar.>=0)
    @variable(model, Y_Anr[1:card_Anr], Int)
    @constraint(model, positivity_Anr, Y_Anr.>=0)
    @variable(model, Y_Er[1:card_Er], Int)
    @constraint(model, positivity_Er, Y_Er.>=0)
    @variable(model, Y_Enr[1:card_Enr], Int)
    @constraint(model, positivity_Enr, Y_Enr.>=0)
    @variable(model, Y_Er_swap[1:card_Er], Int)
    @constraint(model, positivity_Er_swap, Y_Er_swap.>=0)
    @variable(model, Y_Enr_swap[1:card_Enr], Int)
    @constraint(model, positivity_Enr_swap, Y_Enr_swap.>=0)
    Y_tot = vcat(Y_Ar, Y_Anr, Y_Er, Y_Enr, Y_Er_swap, Y_Enr_swap)

    # Flow variables
    @variable(model, F[1:(card_Ar+card_Anr+2*(card_Er+card_Enr))] >= 0)


    ### Objective ###
    sum_1 = try
        sum(dual_values["req_arcs"].*X_Ar)
    catch
        0
    end
    sum_2 = try
        sum(dual_values["req_edges"].*(X_Er+X_Er_swap))
    catch
        0
    end

    sum_3 = 0
    for (j,i) in enumerate(node_branch)
        if (branch_pool[i][2]=="req_arcs") & (branch_pool[i][1]==depot)
            sum_3 += try
                X_Ar[branch_pool[i][3]]*(-dual_values["branch_upper"][j]-dual_values["branch_lower"][j])
            catch
                0
            end
        elseif (branch_pool[i][2]=="req_edges") & (branch_pool[i][1]==depot)
            sum_3 += try
                X_Er[branch_pool[i][3]]*(-dual_values["branch_upper"][j]-dual_values["branch_lower"][j])
            catch
                0
            end
        elseif (branch_pool[i][2]=="req_edges_swap") & (branch_pool[i][1]==depot)
            sum_3 += try
                X_Er_swap[branch_pool[i][3]]*(-dual_values["branch_upper"][j]-dual_values["branch_lower"][j])
            catch
                0
            end
        end
    end

    @objective(model, Min,
        sum(X_R.*serv_cost) +
        sum(Y_tot.*trav_cost) +
        dual_values["vehicle"] -
        sum_1 -
        sum_2 +
        sum_3
        )


    ### Constraints ###

    # Continuity constraint
    @constraint(model, continuity[i=1:nb_nodes],
        sum(map(arc->starts_in(arc,i,A) ? Y_tot[arc] : 0, 1:nrow(A)))
        + sum(map(arc->starts_in(arc,i,R) ? X_R[arc] : 0, 1:nrow(R)))
        == sum(map(arc->ends_in(arc,i,A) ? Y_tot[arc] : 0, 1:nrow(A)))
        + sum(map(arc->ends_in(arc,i,R) ? X_R[arc] : 0, 1:nrow(R)))
        )

    # Dumping constraint
    @constraint(model, dumping,
        sum(map(arc->starts_in(arc,depot,A) ? Y_tot[arc] : 0, 1:nrow(A)))
        +  sum(map(arc->starts_in(arc,depot,R) ? X_R[arc] : 0, 1:nrow(R)))
        <= 1
        )


    # Flow constraint 1
    @constraint(model, flow_1[i=[node for node in 1:nb_nodes if node!=depot]],
        sum(map(arc->ends_in(arc,i,A) ? F[arc] : 0, 1:nrow(A)))
        - sum(map(arc->starts_in(arc,i,A) ? F[arc] : 0, 1:nrow(A)))
        == sum(map(arc->ends_in(arc,i,R) ? X_R[arc]*demand[arc] : 0, 1:nrow(R)))
        )

    # Flow constraint 2
    @constraint(model, flow_2,
        sum(map(arc->starts_in(arc,depot,A) ? F[arc] : 0, 1:nrow(A)))
        == sum(X_R.*demand)
        )

    # Flow constraint 3
    @constraint(model, flow_3,
        sum(map(arc->ends_in(arc,depot,A) ? F[arc] : 0, 1:nrow(A)))
        == sum(map(arc->ends_in(arc,depot,R) ? X_R[arc]*demand[arc] : 0, 1:nrow(R)))
        )

    # Capacity constraint
    @constraint(model, capacity[arc=1:nrow(A)],
        F[arc] <= data[1,:capa]*(Y_tot[arc]+X_tot[arc])
        )

    # Avoid servicing twice on edges
    @constraint(model, avoid_return[edge=1:data[1,:req_edges]],
        X_Er[edge]+X_Er_swap[edge] <= 1
        )


    ### Solve slave ###

    optimize!(model)


    ### Format output ###

    reduced_cost = objective_value(model)

    cost = sum(value.(X_R).*serv_cost) +sum(value.(Y_tot).*trav_cost)

    X = Dict(
        "req_arcs" => [value.(X_Ar[arc]) for arc in 1:length(X_Ar)],
        "req_edges" => [value.(X_Er[arc]) for arc in 1:length(X_Er)],
        "req_edges_swap" => [value.(X_Er_swap[arc]) for arc in 1:length(X_Er_swap)]
        )

    Y = Dict(
        "req_arcs" => [value.(Y_Ar[arc]) for arc in 1:length(Y_Ar)],
        "noreq_arcs" => [value.(Y_Anr[arc]) for arc in 1:length(Y_Anr)],
        "req_edges" => [value.(Y_Er[arc]) for arc in 1:length(Y_Er)],
        "noreq_edges" => [value.(Y_Enr[arc]) for arc in 1:length(Y_Enr)],
        "req_edges_swap" => [value.(Y_Er_swap[arc]) for arc in 1:length(Y_Er_swap)],
        "noreq_edges_swap" => [value.(Y_Enr_swap[arc]) for arc in 1:length(Y_Enr_swap)]
        )

    tour = Dict(
        "depot" => depot,
        "reduced_cost" => reduced_cost,
        "cost" => cost,
        "capacity" => sum(value.(X_R).*demand),
        "X" => X,
        "Y" => Y
        )

    tour_index = length(tour_pool)+1
    push!(tour_pool, tour)

    return(tour_index, tour_pool)
end
