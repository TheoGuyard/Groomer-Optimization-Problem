function solve_master(node, data, tour_pool, branch_pool, relax)

    ### Constants ###
    tour_number = length(node["tours"])
    tour_costs = [tour_pool[i]["cost"] for i in node["tours"]]
    vehicle_number = data[1,:nb_vehicles]

    ### Model definiton ###
    model = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))

    ### Variables ###
    if relax
        @variable(model, alpha[1:tour_number] >= 0)
    else
        @variable(model, alpha[1:tour_number], Bin)
    end

    ### Objective ###
    @objective(model, Min, sum(alpha.*tour_costs))


    ### Constraints ###
    # Add the branch constraints depending on node type
    sum_branchs = []
    for i in node["branch"]
        sum_branch = 0
        for (j,k) in enumerate(node["tours"])
            if branch_pool[i][1] == tour_pool[k]["depot"]
                sum_branch += alpha[j]*(tour_pool[k]["X"][branch_pool[i][2]][branch_pool[i][3]])
            end
        end
        push!(sum_branchs, sum_branch)
    end
    if node["type"]=="odd"
        @constraint(model, branch_lower[i=1:length(node["branch"])],
            -sum_branchs[i]<=-0)
        @constraint(model, branch_upper[i=1:length(node["branch"])],
            sum_branchs[i]<=0)
    elseif node["type"]=="even"
        @constraint(model, branch_lower[i=1:length(node["branch"])],
            -sum_branchs[i]<=-1)
        @constraint(model, branch_upper[i=1:length(node["branch"])],
            sum_branchs[i]<=vehicle_number)
    end

    # Respect the number of vehicles
    @constraint(model, respect_number_vehicle,
        sum(alpha)<=vehicle_number)

    # Service on required arcs (at least one tour service each arc)
    @constraint(model, service_arcs[arc=1:data[1,:req_arcs]],
        sum(alpha.*[tour_pool[i]["X"]["req_arcs"][arc] for i in node["tours"]])>=1
        )

    # Service on required edges (at least one tour service each edge)
    @constraint(model, service_edges[edge=1:data[1,:req_edges]],
        sum(alpha.*[tour_pool[i]["X"]["req_edges"][edge] + tour_pool[i]["X"]["req_edges_swap"][edge] for i in node["tours"]])>=1
        )

    ### Solver master problem ###
    optimize!(model)


    ### Query dual values ###
    dual_values = Dict{String, Any}()
    # Dual value associated to vehicule number constraint
    try
        dual_values["vehicle"] = dual(respect_number_vehicle)
    catch
        dual_values["vehicle"] = 0
    end
    # Dual values associate to the arc servicing constraint
    dual_values_req_arcs = []
    for arc in 1:data[1,:req_arcs]
        try
            push!(dual_values_req_arcs, dual(service_arcs[arc]))
        catch
            push!(dual_values_req_arcs, 0)
        end
    end
    dual_values["req_arcs"] = dual_values_req_arcs
    # Dual values associate to the edge servicing constraint
    dual_values_req_edges = []
    for edge in 1:data[1,:req_edges]
        try
            push!(dual_values_req_edges, dual(service_edges[edge]))
        catch
            push!(dual_values_req_edges, 0)
        end
    end
    dual_values["req_edges"] = dual_values_req_edges
    # Dual values of branch upper
    dual_values_branch_upper = []
    for i in 1:length(node["branch"])
        try
            push!(dual_values_branch_upper, dual(branch_upper[i]))
        catch
            push!(dual_values_branch_upper, 0)
        end
    end
    dual_values["branch_upper"] = dual_values_branch_upper
    # Dual values of branch lower
    dual_values_branch_lower = []
    for i in 1:length(node["branch"])
        try
            push!(dual_values_branch_lower, dual(branch_lower[i]))
        catch
            push!(dual_values_branch_lower, 0)
        end
    end
    dual_values["branch_lower"] = dual_values_branch_lower

    node["alpha"] = value.(alpha)

    return(dual_values)
end
