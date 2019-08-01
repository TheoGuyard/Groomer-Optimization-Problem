function overprint(str)
  print("\u1b[1F")
   #Moves cursor to beginning of the line n (default 1) lines up
  print(str)   #prints the new line
  print("\u1b[0K")
  # clears  part of the line.
  #If n is 0 (or missing), clear from cursor to the end of the line.
  #If n is 1, clear from cursor to beginning of the line.
  #If n is 2, clear entire line.
  #Cursor position does not change.
   println() #prints a new line, i really don't like this arcane codes
end

function print_info_dataset(data)
    println("Dataset name : ", data[1, :name])
    println("Number of vertices : ", data[1, :nodes])
    println("Number of edges (required/not-required) : ", data[1, :req_edges], " / ", data[1, :noreq_edges])
    println("Number of arcs (required/not-required) : ", data[1, :req_arcs], " / ", data[1, :noreq_arcs])
    println("Max capacity of vehicles : ", data[1, :capa])
    println("Depot(s) : ", string(data[1, :depots])[2:end-1])
    println("Number of vehicle(s) : ", data[1, :nb_vehicles])
end

function remove_multiple_service(tours, graph)

  for arc in 1:nrow(graph["req_arcs"])
    servicing_tours_indices = []
    for (i,tour) in enumerate(tours)
      if tour["X"]["req_arcs"][arc] == 1
        push!(servicing_tours_indices, i)
      end
    end
    if length(servicing_tours_indices) != 0
      (val,ind) = findmin([tours[i]["cost"] for i in servicing_tours_indices])
      for index in servicing_tours_indices
        if index != servicing_tours_indices[ind]
          tours[index]["X"]["req_arcs"][arc] = 0
          tours[index]["Y"]["req_arcs"][arc] += 1
          tours[index]["cost"] += (graph["req_arcs"][arc, :trav_cost] - graph["req_arcs"][arc, :serv_cost])
          tours[index]["capacity"] -= graph["req_arcs"][arc, :demand]
        end
      end
    end
  end

  for arc in 1:nrow(graph["req_edges"])
    servicing_tours_indices = []
    for (i,tour) in enumerate(tours)
      if (tour["X"]["req_edges"][arc]==1) | (tour["X"]["req_edges_swap"][arc]==1)
        push!(servicing_tours_indices, i)
      end
    end
    if length(servicing_tours_indices) != 0
      (val,ind) = findmin([tours[i]["cost"] for i in servicing_tours_indices])
      for index in servicing_tours_indices
        if index != servicing_tours_indices[ind]
          if tours[index]["X"]["req_edges"][arc] == 1
            tours[index]["X"]["req_edges"][arc] = 0
            tours[index]["Y"]["req_edges"][arc] += 1
          else
            tours[index]["X"]["req_edges_swap"][arc] = 0
            tours[index]["Y"]["req_edges_swap"][arc] += 1
          end
          tours[index]["cost"] += (graph["req_edges"][arc, :trav_cost] - graph["req_edges"][arc, :serv_cost])
          tours[index]["capacity"] -= graph["req_edges"][arc, :demand]
        end
      end
    end
  end

  return(tours)
end
