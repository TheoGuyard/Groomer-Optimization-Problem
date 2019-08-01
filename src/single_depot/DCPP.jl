function DCPP_solve(data, graph)
    """Given data, solve a DRCPP problem with integer programming."""

    ### Constants linked to the problem ###

    # All arcs
    Ar = graph["req_arcs"]
    Anr = graph["noreq_arcs"]
    A = vcat(Ar, Anr)

    # Number of edges/arcs by category
    card_Ar = nrow(Ar)
    card_Anr = nrow(Anr)
    card_A = nrow(A)

    # Traversing cost
    trav_cost = A[:, :trav_cost]

    # Service cost
    serv_cost = A[:, :serv_cost]

    # Demand
    demand = A[:, :demand]


    ### Model definition ###
    model = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))



    ### Variables ###
    X_tot = vcat([1 for arc in 1:card_Ar], [0 for arc in 1:card_Anr])
    @variable(model, Y_tot[1:card_A], Int)


    ### Objective ###
    @objective(model, Min, sum(X_tot.*serv_cost+Y_tot.*trav_cost))


    ### Constraint ###
    # Positivity constraint
    @constraint(model, positivity[arc=1:card_A], Y_tot[arc] >= 0)

    # Connectivity constraint
    @constraint(model, connectivity[i=1:data[1,:nodes]],
        sum([X_tot[arc]+Y_tot[arc] for arc in 1:card_A if A[arc,:start_node]==i]) ==
        sum([X_tot[arc]+Y_tot[arc] for arc in 1:card_A if A[arc,:end_node]==i])
        )


    ### Solve problem ###

    start = now()
    optimize!(model)
    stop = now()

    solving_time = stop-start

    ### Format output ###

    tours = []

    cost = sum(X_tot.*serv_cost) + sum(value.(Y_tot).*trav_cost)

    X = Dict(
        "req_arcs" => [1 for arc in 1:card_Ar],
        "req_edges" => [],
        "req_edges_swap" => []
        )

    Y = Dict(
        "req_arcs" => [value.(Y_tot[arc]) for arc in 1:card_Ar],
        "noreq_arcs" => [value.(Y_tot[arc]) for arc in (1+card_Ar):card_A],
        "req_edges" => [],
        "noreq_edges" => [],
        "req_edges_swap" => [],
        "noreq_edges_swap" => []
        )

    tour = Dict(
        "depot" => data[1, :depots][1],
        "cost" => cost,
        "capacity" => sum(X_tot.*demand),
        "X" => X,
        "Y" => Y
        )

    push!(tours, tour)

    return(tours, solving_time)
end
