# Groomer-Optimisation-Problem
Work done during a third year's internship at INSA Rennes.

---

**Language** : `Julia 1.1`

**Packages requirements** : `JuMP`, `DataFrames`, `CPLEX`, `Dates`

As CPLEX is used, you need to have it installed on the computer. The version `12.9` was used during the project. The code will not be maintained so it's possible that due to huge changes during `Julia`'s updates, the code crashes.

## Problem
All the documentation about the problem, methods used and implementation details are presented in `rapport.pdf`.

## Datasets
Datasets are separted in two groups : those with a unique depot and those with multiples depots. In each groups, there are different datasets availables. The structure of datasets is copied from the structure of [these](https://www.sciencedirect.com/science/article/pii/S2352340916304358 "Take a look !") datasets.
##### Single depot
- `small` : Small datasets used to test algorithms on different configurations
- `stations` : Three stations modlised with graphs and declined in three different configurations
- `mval-IF-3L` and `Lpr-IF` : Classical CARP datasets
##### Multiples depots
Same datasets as those in `stations` but with an extra depot.

## Sources
To solve a **GOP** problem, open `src/main.jl` and input dataset path and vehicle number. The program will automatically choose wich algorithm to use. In the case of multiples depots, it's possible to specify wether an optimal or an approximated solution is needed.
