include("solve_problem.jl")

# Path of the file containing problem data
file = "dataset/multi-depot/stations/ceuze-1.txt"
# Number of vehicules available
nb_vehicles = 3
# Wether using BnP-opt or BnP-approx in the case of a multi-depot dataset
approx = true
# Choose to display or not Branch-and-Price steps
verbose = true

solve_problem(file, nb_vehicles, approx, verbose)
