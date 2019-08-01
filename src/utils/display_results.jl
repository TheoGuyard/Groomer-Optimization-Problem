function extract_paths(tour, graph, graph_type)

    X = tour["X"]
    Y = tour["Y"]

    path = DataFrame(
            start_node = Int64[],
            end_node = Int64[],
            nb_passage = Float64[],
            serv = Bool[],
            )

    if nrow(graph["req_arcs"])>0
      for arc in 1:nrow(graph["req_arcs"])
        start_node = graph["req_arcs"][arc, :start_node]
        end_node = graph["req_arcs"][arc, :end_node]
        nb_passage = X["req_arcs"][arc] + Y["req_arcs"][arc]
        serv = X["req_arcs"][arc] >= 1
        if nb_passage > 10^-5
          push!(path, (start_node, end_node, nb_passage, serv))
        end
      end
    end

    if nrow(graph["noreq_arcs"])>0
      for arc in 1:nrow(graph["noreq_arcs"])
        start_node = graph["noreq_arcs"][arc, :start_node]
        end_node = graph["noreq_arcs"][arc, :end_node]
        nb_passage = Y["noreq_arcs"][arc]
        if nb_passage > 10^-5
          push!(path, (start_node, end_node, nb_passage, false))
        end
      end
    end

    if nrow(graph["req_edges"])>0
      for arc in 1:nrow(graph["req_edges"])
        start_node = graph["req_edges"][arc, :start_node]
        end_node = graph["req_edges"][arc, :end_node]
        nb_passage = X["req_edges"][arc] + Y["req_edges"][arc]
        serv = X["req_edges"][arc] >= 1
        if nb_passage > 10^-5
          push!(path, (start_node, end_node, nb_passage, serv))
        end
      end
    end

    if (nrow(graph["req_edges"])>0)&(graph_type=="directed")
      for arc in 1:nrow(graph["req_edges"])
        start_node = graph["req_edges"][arc, :end_node]
        end_node = graph["req_edges"][arc, :start_node]
        nb_passage = X["req_edges_swap"][arc] + Y["req_edges_swap"][arc]
        serv = X["req_edges_swap"][arc] >= 1
        if nb_passage > 10^-5
          push!(path, (start_node, end_node, nb_passage, serv))
        end
      end
    end

    if nrow(graph["noreq_edges"])>0
      for arc in 1:nrow(graph["noreq_edges"])
        start_node = graph["noreq_edges"][arc, :start_node]
        end_node = graph["noreq_edges"][arc, :end_node]
        nb_passage = Y["noreq_edges"][arc]
        if nb_passage > 10^-5
          push!(path, (start_node, end_node, nb_passage, false))
        end
      end
    end

    if (nrow(graph["req_edges"])>0)&(graph_type=="directed")
      for arc in 1:nrow(graph["noreq_edges"])
        start_node = graph["noreq_edges"][arc, :end_node]
        end_node = graph["noreq_edges"][arc, :start_node]
        nb_passage = Y["noreq_edges_swap"][arc]
        if nb_passage > 10^-5
          push!(path, (start_node, end_node, nb_passage, false))
        end
      end
    end

    return(path)
end

function display_results(tours, graph, data, solving_time)

  println("Solving time : ", solving_time)
  println("Total cost : ", sum([tour["cost"] for tour in tours]))
  println("Number of vehicule(s) used : ", length([tour for tour in tours if tour["cost"]!=0]))
  println("--------------")
  for (i,tour) in enumerate(tours)
    if tour["cost"] != 0
      println("Vehicle ", i)
      println("\tCost : ", tour["cost"])
      println("\tCapacity used : ", tour["capacity"])
      if (nrow(graph["req_arcs"])+nrow(graph["noreq_arcs"])==0) & (length(data[1, :depots])==1) & (data[1, :nb_vehicles]==1)
        graph_type = "undirected"
      else
        graph_type = "directed"
      end
      path = extract_paths(tour, graph, graph_type)
      println(path)
    end
  end

end
