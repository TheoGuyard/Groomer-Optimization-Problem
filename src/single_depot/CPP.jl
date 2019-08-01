function CPP_solve(data, graph)
    """Given data, solve a CPP problem with integer programming."""

    Er = graph["req_edges"]
    Enr = graph["noreq_edges"]
    E = vcat(Er, Enr)

    depot = data[1, :depots][1]

    card_Er = nrow(Er)
    card_Enr = nrow(Enr)
    card_E = nrow(E)

    trav_cost = E[:, :trav_cost]
    serv_cost = E[:, :serv_cost]
    demand = E[:, :demand]

    ### Model definition ###
    model = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))

    ### Variables ###
    X_tot = vcat([1 for edge in 1:card_Er], [0 for edge in 1:card_Enr])
    @variable(model, Y_tot[1:card_E], Int)
    @variable(model, K[1:data[1,:nodes]], Int)


    ### Objective ###
    @objective(model, Min, sum(X_tot.*serv_cost+Y_tot.*trav_cost))


    ### Constraint ###
    # Positivity constraint
    @constraint(model, positivity_Y[edge=1:card_E], Y_tot[edge] >= 0)
    @constraint(model, positivity_K[i=1:data[1,:nodes]], K[i] >= 0)

    # Connectivity constrain
    @constraint(model, connectivity[i=1:data[1,:nodes]],
        sum([X_tot[edge]+Y_tot[edge] for edge in 1:card_E if (E[edge,:start_node]==i)!=(E[edge,:end_node]==i)]) == 2*K[i]
        )

    ### Solve problem ###

    optimize!(model)
    stop = now()

    solving_time = stop-start

    ### Format output ###

    tours = []

    cost = sum(X_tot.*serv_cost) + sum(value.(Y_tot).*trav_cost)

    X = Dict(
        "req_arcs" => [],
        "req_edges" => [1 for edge in 1:card_Er],
        "req_edges_swap" => []
        )

    Y = Dict(
        "req_arcs" => [],
        "noreq_arcs" => [],
        "req_edges" => [value.(Y_tot[arc]) for arc in 1:card_Er],
        "noreq_edges" => [value.(Y_tot[arc]) for arc in (1+card_Er):card_E],
        "req_edges_swap" => [],
        "noreq_edges_swap" => []
        )

    tour = Dict(
        "depot" => depot,
        "cost" => cost,
        "capacity" => sum(X_tot.*demand),
        "X" => X,
        "Y" => Y
        )

    push!(tours, tour)

    return(tours, solving_time)
end
