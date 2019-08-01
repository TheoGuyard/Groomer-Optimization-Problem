function extract_data(file)
  # Given a file name, return infos about the file and DataFrames of edges/arcs

  # Infos about the dataset
  data = DataFrame(
    name = String[],
    nodes = Int64[],
    req_edges = Int64[],
    noreq_edges = Int64[],
    req_arcs = Int64[],
    noreq_arcs = Int64[],
    capa = Int64[],
    depots = Array{Int64,1}[],
    nb_vehicles = Int64[],
    )
  extracted_data = []
  fields = []

  # Required edges
  req_edges = DataFrame(
    start_node = Int64[],
    end_node = Int64[],
    serv_cost = Float64[],
    trav_cost = Float64[],
    demand = Float64[],
    )

  # Non-required edges
  noreq_edges = DataFrame(
    start_node = Int64[],
    end_node = Int64[],
    serv_cost = Float64[],
    trav_cost = Float64[],
    demand = Float64[],
    )

  # Required arcs
  req_arcs = DataFrame(
    start_node = Int64[],
    end_node = Int64[],
    serv_cost = Float64[],
    trav_cost = Float64[],
    demand = Float64[],
    )

  # Non-required arcs
  noreq_arcs = DataFrame(
    start_node = Int64[],
    end_node = Int64[],
    serv_cost = Float64[],
    trav_cost = Float64[],
    demand = Float64[],
    )

  # Read the .txt file and extract infos
  open(file) do f

    for (i, line) in enumerate(eachline(f))

      # Infos about dataset
      if startswith(line, "NAME :")
        s = split(line, " ")
        push!(extracted_data, last(s))
      elseif startswith(line, "NODES :")
        s = split(line, " ")
        push!(extracted_data, parse(Int64, last(s)))
      elseif startswith(line, "REQ_EDGES :")
        s = split(line, " ")
        push!(extracted_data, parse(Int64, last(s)))
      elseif startswith(line, "NOREQ_EDGES :")
        s = split(line, " ")
        push!(extracted_data, parse(Int64, last(s)))
      elseif startswith(line, "REQ_ARCS :")
        s = split(line, " ")
        push!(extracted_data, parse(Int64, last(s)))
      elseif startswith(line, "NOREQ_ARCS :")
        s = split(line, " ")
        push!(extracted_data, parse(Int64, last(s)))
      elseif startswith(line, "CAPACITY :")
        s = split(line, " ")
        push!(extracted_data, parse(Int64, last(s)))
      elseif startswith(line, "DEPOT :")
        depots = last(split(line, " "))
        depots = map(depot->parse(Int64,depot), split(depots, ","))
        push!(extracted_data, depots)
      end

      # Infos about fields with edges/rows
      if startswith(line, "LIST_REQ_EDGES :")
        push!(fields, i)
      elseif startswith(line, "LIST_NOREQ_EDGES :")
        push!(fields, i)
      elseif startswith(line, "LIST_REQ_ARCS :")
        push!(fields, i)
      elseif startswith(line, "LIST_NOREQ_ARCS :")
        push!(fields, i)
      end
    end

    # We don't know yet the number of vehicles
    push!(extracted_data, 0)

    push!(data, extracted_data)

    lines = readlines(file)

    # Required edges data
    for line in lines[fields[1]+1:fields[2]-1]
      s = split(line, ",")
      start_node = parse(Int64, last(split(s[1], " ")))
      end_node = parse(Int64, last(split(s[2], " ")))
      serv_cost = parse(Float64, last(split(s[3], " ")))
      trav_cost = parse(Float64, last(split(s[4], " ")))
      demand = parse(Float64, last(split(s[5], " ")))
      push!(req_edges, (start_node, end_node, serv_cost, trav_cost, demand))
    end

    # Non-required edges data
    for line in lines[fields[2]+1:fields[3]-1]
      s = split(line, ",")
      start_node = parse(Int64, last(split(s[1], " ")))
      end_node = parse(Int64, last(split(s[2], " ")))
      serv_cost = parse(Float64, last(split(s[3], " ")))
      trav_cost = parse(Float64, last(split(s[4], " ")))
      demand = parse(Float64, last(split(s[5], " ")))
      push!(noreq_edges, (start_node, end_node, serv_cost, trav_cost, demand))
    end

    # Required arcs data
    for line in lines[fields[3]+1:fields[4]-1]
      s = split(line, ",")
      start_node = parse(Int64, last(split(s[1], " ")))
      end_node = parse(Int64, last(split(s[2], " ")))
      serv_cost = parse(Float64, last(split(s[3], " ")))
      trav_cost = parse(Float64, last(split(s[4], " ")))
      demand = parse(Float64, last(split(s[5], " ")))
      push!(req_arcs, (start_node, end_node, serv_cost, trav_cost, demand))
    end

    # Non-required arcs data
    for line in lines[fields[4]+1:length(readlines(file))]
      s = split(line, ",")
      start_node = parse(Int64, last(split(s[1], " ")))
      end_node = parse(Int64, last(split(s[2], " ")))
      serv_cost = parse(Float64, last(split(s[3], " ")))
      trav_cost = parse(Float64, last(split(s[4], " ")))
      demand = parse(Float64, last(split(s[5], " ")))
      push!(noreq_arcs, (start_node, end_node, serv_cost, trav_cost, demand))
    end
  end
  close(open(file))

  graph = Dict("req_edges"=>req_edges, "noreq_edges"=>noreq_edges,
    "req_arcs"=>req_arcs, "noreq_arcs"=>noreq_arcs)

  return(data, graph)
end
