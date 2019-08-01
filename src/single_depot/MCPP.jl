function MCPP_solve(data, graph)
    """Given data, solve a MRCPP problem with integer programming."""

    ### Constants linked to the problem ###

    Er = graph["req_edges"]
    Enr = graph["noreq_edges"]
    Ar = graph["req_arcs"]
    Anr = graph["noreq_arcs"]

    depot = data[1, :depots][1]

    # Return acs for edges
    Er_swap = copy(Er)
    Er_swap[:start_node], Er_swap[:end_node] = Er_swap[:end_node], Er_swap[:start_node]
    Enr_swap = copy(Enr)
    Enr_swap[:start_node], Enr_swap[:end_node] = Enr_swap[:end_node], Enr_swap[:start_node]

    # Edges as and return arcs
    E = vcat(Er, Enr, Er_swap, Enr_swap)

    # All arcs
    A = vcat(E, Ar, Anr)

    # All requested arcs
    R = vcat(Er, Er_swap, Ar)

    # Number of edges/arcs by category
    card_Er = nrow(Er)
    card_Enr = nrow(Enr)
    card_Er_swap = nrow(Er_swap)
    card_Enr_swap = nrow(Enr_swap)
    card_E = nrow(E)
    card_Ar = nrow(Ar)
    card_Anr = nrow(Anr)
    card_A = nrow(A)
    card_R = nrow(R)

    # Traversing cost
    trav_cost = A[:, :trav_cost]

    # Service cost
    serv_cost = R[:, :serv_cost]

    # Demand
    demand = R[:, :demand]


    ### Model definition ###
    model = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))


    ### Variables ###
    X_Enr = [0 for arc in 1:card_Enr]
    X_Enr_swap = [0 for arc in 1:card_Enr]
    X_Anr = [0 for arc in 1:card_Anr]
    X_Ar = [1 for arc in 1:card_Ar]
    @variable(model, X_Er[1:card_Er], Bin)
    @variable(model, X_Er_swap[1:card_Er_swap], Bin)
    X_R = vcat(X_Er, X_Er_swap,  X_Ar)
    X_tot = vcat(X_Er, X_Enr, X_Er_swap, X_Enr_swap, X_Ar, X_Anr)
    @variable(model, Y_Ar[1:card_Ar], Int)
    @variable(model, Y_Anr[1:card_Anr], Int)
    @variable(model, Y_Er[1:card_Er], Int)
    @variable(model, Y_Enr[1:card_Enr], Int)
    @variable(model, Y_Er_swap[1:card_Er_swap], Int)
    @variable(model, Y_Enr_swap[1:card_Enr_swap], Int)
    Y_tot = vcat(Y_Er, Y_Enr, Y_Er_swap, Y_Enr_swap, Y_Ar, Y_Anr)


    ### Objective ###
    @objective(model, Min, sum(X_R.*serv_cost)+sum(Y_tot.*trav_cost))


    ### Constraint ###
    # Positivity constraint
    @constraint(model, positivity, Y_tot .>= 0)
    # Service constraint on edges
    @constraint(model, [arc in 1:card_Er], X_R[arc]+X_R[arc+card_Er] == 1)

    # Connectivity constraint
    @constraint(model, connectivity[i=1:data[1,:nodes]],
        sum([X_tot[arc]+Y_tot[arc] for arc in 1:card_A if A[arc,:start_node]==i]) ==
        sum([X_tot[arc]+Y_tot[arc] for arc in 1:card_A if A[arc,:end_node]==i])
        )

    # Depot contraint
    @constraint(model, depot_constraint, sum([X_tot[arc]+Y_tot[arc] for arc in 1:card_A if starts_in(arc, depot, A)])>=1)


    ### Solve problem ###

    start = now()
    optimize!(model)
    stop = now()

    solving_time = stop-start


    ### Format output ###

    tours = []

    cost = sum(value.(X_R).*serv_cost) + sum(value.(Y_tot).*trav_cost)

    X = Dict(
        "req_arcs" => [X_Ar[arc] for arc in 1:nrow(Ar)],
        "req_edges" => [value.(X_Er[arc]) for arc in 1:nrow(Er)],
        "req_edges_swap" => [value.(X_Er_swap[arc]) for arc in 1:nrow(Er_swap)]
        )

    Y = Dict(
        "req_arcs" => [value.(Y_Ar[arc]) for arc in 1:nrow(Ar)],
        "noreq_arcs" => [value.(Y_Anr[arc]) for arc in 1:nrow(Anr)],
        "req_edges" => [value.(Y_Er[arc]) for arc in 1:nrow(Er)],
        "noreq_edges" => [value.(Y_Enr[arc]) for arc in 1:nrow(Enr)],
        "req_edges_swap" => [value.(Y_Er_swap[arc]) for arc in 1:nrow(Er)],
        "noreq_edges_swap" => [value.(Y_Enr_swap[arc]) for arc in 1:nrow(Enr)]
        )

    tour = Dict(
        "depot" => depot,
        "cost" => cost,
        "capacity" => sum(value.(X_R).*demand),
        "X" => X,
        "Y" => Y
        )

    push!(tours, tour)

    return(tours, solving_time)
end
