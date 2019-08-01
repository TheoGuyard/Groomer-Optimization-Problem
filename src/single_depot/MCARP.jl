function MCARP_solve(data, graph)
    """Given data, solve a MCARP problem with integer programming."""

    ### Constants linked to the problem ###

    Er = graph["req_edges"]
    Enr = graph["noreq_edges"]
    Ar = graph["req_arcs"]
    Anr = graph["noreq_arcs"]

    # Return acs for edges
    Er_swap = copy(Er)
    Er_swap[:start_node], Er_swap[:end_node] = Er_swap[:end_node], Er_swap[:start_node]
    Enr_swap = copy(Enr)
    Enr_swap[:start_node], Enr_swap[:end_node] = Enr_swap[:end_node], Enr_swap[:start_node]

    # All arcs
    A = vcat(Er, Enr, Er_swap, Enr_swap, Ar, Anr)
    # Required arcs
    R = vcat(Er, Er_swap, Ar)
    # Non-required arcs
    NR = vcat(Enr, Enr_swap, Anr)

    # Number of nodes
    nb_nodes = data[1, :nodes]
    # Depot node
    depot = data[1, :depots][1]
    # Vehicle capacity
    W = data[1, :capa]
    # Traversing cost on arcs
    trav_cost = A[:, :trav_cost]
    # Service cost on required arcs
    serv_cost = R[:, :serv_cost]
    # Demand on required arcs
    demand = R[:, :demand]

    # Number of vehicle
    P = data[1, :nb_vehicles]


    ### Model definition ###

    model = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))


    ### Variables ###

    # Service variables
    @variable(model, X_R[1:P, 1:nrow(R)], Bin)
    X_Er = X_R[:, 1:nrow(Er)]
    X_Er_swap = X_R[:, (nrow(Er)+1):(nrow(Er)+nrow(Er_swap))]
    X_Ar = X_R[:, (nrow(Er)+nrow(Er_swap)+1):nrow(R)]
    X_tot = hcat(X_Er, [0 for p in 1:P, arc in 1:nrow(Enr)],
        X_Er_swap, [0 for p in 1:P, arc in 1:nrow(Enr_swap)],
        X_Ar, [0 for p in 1:P, arc in 1:nrow(Anr)])

    # Passage without service variables
    @variable(model, Y_Er[1:P, 1:nrow(Er)], Int)
    @constraint(model, Y_Er .>= 0)
    @variable(model, Y_Enr[1:P, 1:nrow(Enr)], Int)
    @constraint(model, Y_Enr .>= 0)
    @variable(model, Y_Er_swap[1:P, 1:nrow(Er_swap)], Int)
    @constraint(model, Y_Er_swap .>= 0)
    @variable(model, Y_Enr_swap[1:P, 1:nrow(Enr_swap)], Int)
    @constraint(model, Y_Enr_swap .>= 0)
    @variable(model, Y_Ar[1:P, 1:nrow(Ar)], Int)
    @constraint(model, Y_Ar .>= 0)
    @variable(model, Y_Anr[1:P, 1:nrow(Anr)], Int)
    @constraint(model, Y_Anr .>= 0)
    Y_tot = hcat(Y_Er, Y_Enr, Y_Er_swap, Y_Enr_swap, Y_Ar, Y_Anr)
    Y_NR = hcat(Y_Enr, Y_Enr_swap, Y_Anr)

    # Flow variables
    @variable(model, F_Er[1:P, 1:nrow(Er)] >= 0)
    @variable(model, F_Enr[1:P, 1:nrow(Enr)] >= 0)
    @variable(model, F_Er_swap[1:P, 1:nrow(Er_swap)] >= 0)
    @variable(model, F_Enr_swap[1:P, 1:nrow(Enr_swap)] >= 0)
    @variable(model, F_Ar[1:P, 1:nrow(Ar)] >= 0)
    @variable(model, F_Anr[1:P, 1:nrow(Anr)] >= 0)
    F = hcat(F_Er, F_Enr, F_Er_swap, F_Enr_swap, F_Ar, F_Anr)
    F_R = hcat(F_Er, F_Er_swap, F_Ar)
    F_NR = hcat(F_Enr, F_Enr_swap, F_Anr)


    ### Objective ###

    @objective(model, Min, sum(X_R*serv_cost + Y_tot*trav_cost))


    ### Constraint ###

    # Continuity constrain
    @constraint(model, continuity[p=1:P, i=1:nb_nodes],
        sum(map(arc->starts_in(arc,i,A) ? Y_tot[p,arc] : 0, 1:nrow(A)))
        + sum(map(arc->starts_in(arc,i,R) ? X_R[p,arc] : 0, 1:nrow(R)))
        == sum(map(arc->ends_in(arc,i,A) ? Y_tot[p,arc] : 0, 1:nrow(A)))
        + sum(map(arc->ends_in(arc,i,R) ? X_R[p,arc] : 0, 1:nrow(R)))
        )

    # Service constraint on arcs
    @constraint(model, service_Ar[arc=1:nrow(Ar)], sum(X_Ar[:,arc]) == 1)

    # Service constraint on edges
    @constraint(model, service_Er[arc=1:nrow(Er)], sum(X_Er[:,arc] + X_Er_swap[:,arc]) == 1)

    # Dumping constraint
    @constraint(model, dumping[p=1:P],
        sum(map(arc->starts_in(arc,depot,A) ? Y_tot[p,arc] : 0, 1:nrow(A)))
        +  sum(map(arc->starts_in(arc,depot,R) ? X_R[p,arc] : 0, 1:nrow(R)))
        <= 1
        )

    # Flow constraint 1
    @constraint(model, flow_1[p=1:P, i=[node for node in 1:nb_nodes if node!=depot]],
        sum(map(arc->ends_in(arc,i,A) ? F[p,arc] : 0, 1:nrow(A)))
        - sum(map(arc->starts_in(arc,i,A) ? F[p,arc] : 0, 1:nrow(A)))
        == sum(map(arc->ends_in(arc,i,R) ? X_R[p,arc]*demand[arc] : 0, 1:nrow(R)))
        )

    # Flow constraint 2
    @constraint(model, flow_2[p=1:P],
        sum(map(arc->starts_in(arc,depot,A) ? F[p,arc] : 0, 1:nrow(A)))
        == sum(X_R[p,:].*demand)
        )

    # Flow constraint 3
    @constraint(model, flow_3[p=1:P],
        sum(map(arc->ends_in(arc,depot,A) ? F[p,arc] : 0, 1:nrow(A)))
        == sum(map(arc->ends_in(arc,depot,R) ? X_R[p,arc]*demand[arc] : 0, 1:nrow(R)))
        )

    # Capacity constraint
    @constraint(model, capacity[p=1:P, arc=1:nrow(A)],
        F[p,arc] <= W*(Y_tot[p,arc]+X_tot[p,arc])
        )

    # Minimum vehicle constrain
    @constraint(model, min_vehicle,
        sum(map(arc->starts_in(arc,depot,A) ? sum(Y_tot[:,arc]) : 0, 1:nrow(A)))
        + sum(map(arc->starts_in(arc,depot,R) ? sum(X_R[:,arc]) : 0, 1:nrow(R)))
        >= ceil((sum(Er[:,:demand])+sum(Ar[:,:demand]))/W)
        )

    # Flow lower bound 1
    @constraint(model, flow_bound_1[p=1:P,arc=1:nrow(R)],
        F_R[p,arc] >= X_R[p,arc]*demand[arc]
        )

    # Flow lower bound 2
    @constraint(model, flow_bound_2[p=1:P,arc=1:nrow(NR)],
        F_NR[p,arc] >= Y_NR[p,arc]-1
        )

    # Symmetries breaking
    @constraint(model, symmetries[p=1:(P-1)],
        sum(map(arc->starts_in(arc,depot,A) ? Y_tot[p,arc] : 0, 1:nrow(A)))
        + sum(map(arc->starts_in(arc,depot,R) ? X_R[p,arc] : 0, 1:nrow(R)))
        >= sum(map(arc->starts_in(arc,depot,A) ? Y_tot[p+1,arc] : 0, 1:nrow(A)))
        + sum(map(arc->starts_in(arc,depot,R) ? X_R[p+1,arc] : 0, 1:nrow(R)))
        )



    ### Solve problem ###

    start = now()
    optimize!(model)
    stop = now()

    solving_time = stop-start

    ### Format output ###

    tours = []

    for p in 1:P

        cost = (value.(X_R)*serv_cost + value.(Y_tot)*trav_cost)[p]

        X = Dict(
            "req_arcs" => [value.(X_Ar[p, arc]) for arc in 1:nrow(Ar)],
            "req_edges" => [value.(X_Er[p, arc]) for arc in 1:nrow(Er)],
            "req_edges_swap" => [value.(X_Er_swap[p, arc]) for arc in 1:nrow(Er_swap)]
            )

        Y = Dict(
            "req_arcs" => [value.(Y_Ar[p, arc]) for arc in 1:nrow(Ar)],
            "noreq_arcs" => [value.(Y_Anr[p, arc]) for arc in 1:nrow(Anr)],
            "req_edges" => [value.(Y_Er[p, arc]) for arc in 1:nrow(Er)],
            "noreq_edges" => [value.(Y_Enr[p, arc]) for arc in 1:nrow(Enr)],
            "req_edges_swap" => [value.(Y_Er_swap[p, arc]) for arc in 1:nrow(Er)],
            "noreq_edges_swap" => [value.(Y_Enr_swap[p, arc]) for arc in 1:nrow(Enr)]
            )

        tour = Dict(
            "depot" => depot,
            "cost" => cost,
            "capacity" => sum(value.(X_R[p,:]).*demand),
            "X" => X,
            "Y" => Y
            )

        push!(tours, tour)
    end
    return(tours, solving_time)

end
