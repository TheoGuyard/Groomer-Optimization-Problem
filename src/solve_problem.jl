using DataFrames, JuMP, CPLEX, Dates
include("utils/extract_data.jl")
include("utils/display_results.jl")
include("utils/misc.jl")
include("single_depot/solve_single_depot.jl")
include("multi_depot/solve_multi_depot.jl")

function solve_problem(file, nb_vehicles, approx, verbose)

    print("\n\n")
    println("===========================================")
    println("GROOMER OPTIMIZATION PROBLEM")
    println("-----------")

    println("Extracting data from file ...")
    (data, graph) = extract_data(file)
    data[1, :nb_vehicles] = nb_vehicles

    println("-----------")

    print_info_dataset(data)

    println("-----------")

    if length(data[1, :depots])>1
        (tours, solving_time) = solve_multi_depot(data, graph, approx, verbose)
    elseif length(data[1, :depots])==1
        (tours, solving_time) = solve_single_depot(data, graph)
    else
        error("Problem with depot list. Check dataset's validity.")
    end

    println("-----------")

    display_results(tours, graph, data, solving_time)

    println("===========================================")
end
