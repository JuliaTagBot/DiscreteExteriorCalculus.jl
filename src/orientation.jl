using MatrixNetworks: scomponents, bfs
using LinearAlgebra: det

export orientation
"""
    orientation(s::Simplex{N, K}) where {N, K}

Compute the relative orientation of the simplex with respect to the embedding space. Returns
`1` or `-1` if the simplex is non-degenerate and `0` otherwise. Requires `K == N+1`.
"""
function orientation(s::Simplex{N, K}) where {N, K}
    @assert K == N+1
    return sign(det(hcat(Wedge(s).vectors...)))
end

export change_orientation!
"""
    change_orientation!(c::Cell)

Reverse the orientation of a cell and return the cell.
"""
function change_orientation!(c::Cell)
    if length(c.points) >= 2
        a = c.points[1]
        c.points[1] = c.points[2]
        c.points[2] = a
    end
    for parent in keys(c.parents)
        c.parents[parent] = !c.parents[parent]
    end
    for child in c.children
        child.parents[c] = !child.parents[c]
    end
    return c
end

export orient_component!
"""
    orient_component!(cells::AbstractVector{Cell{N}}, adj::AbstractMatrix{<:Real},
        faces::Dict{Tuple{Cell{N}, Cell{N}}, Cell{N}}, root::Int) where N

Use breadth first search to orient the connected component of `cells` containing
`cells[root]` in the graph with adjacency matrix `adj`. `(adj, faces)` should be the output
of `adjacency(cells)`. If the cells are orientable, a consistent orientation will be
produced. Return `cells`.
"""
function orient_component!(cells::AbstractVector{Cell{N}},
    adj::AbstractMatrix{<:Real},
    faces::Dict{Tuple{Cell{N}, Cell{N}}, Cell{N}}, root::Int) where N
    orient!(cells[root])
    dists, _, predecessors = bfs(adj, root)
    for j in sortperm(dists)
        if dists[j] > 0 # exclude unreachables and the root
            c1, c2 = cells[predecessors[j]], cells[j]
            f = faces[(c1, c2)]
            if f.parents[c1] == f.parents[c2]
                change_orientation!(c2)
            end
        end
    end
    return cells
end

export orient!
"""
    orient!(cells::AbstractVector{Cell{N}}) where N

For each connected component of `cells`, use `orient_component!` to produce a consistent
orientation, if one exists. Return `cells`.
"""
function orient!(cells::AbstractVector{Cell{N}}) where N
    adj, faces = adjacency(cells)
    cc = scomponents(adj)
    roots = [findfirst(isequal(i), cc.map) for i in 1:cc.number]
    # start with higest dimensional component
    for i in reverse(sortperm([cells[r].K for r in roots]))
        orient_component!(cells, adj, faces, roots[i])
    end
    return cells
end

"""
    orient!(cell::Cell{N}) where N

If `cell` is of maximum dimension and is simplicial, orient it according to the orientation
of the embedding space. If `cell` is on the boundary, orient it accoring to its parent.
Otherwise leave its orientation as it is. Return `cell`.
"""
function orient!(cell::Cell{N}) where N
    num_parents = length(cell.parents)
    if (num_parents == 0) && (cell.K == length(cell.points) == N + 1)
        if orientation(Simplex(cell)) < 0
            change_orientation!(cell)
        end
    elseif (num_parents == 1) && (!(collect(values(cell.parents))[1]))
        change_orientation!(cell)
    end
    return cell
end

"""
    orient!(comp::CellComplex{N, K}) where {N, K}

If `K == N+1`, orient each highest dimensional cell according to the embedding space.
Otherwise orient the highest dimensional cells consistently with eachother, if such an
orientation exists. Return `comp`.
"""
function orient!(comp::CellComplex{N, K}) where {N, K}
    if K == N + 1
        map(orient!, comp.cells[end])
    else
        orient!(comp.cells[end])
    end
    return comp
end
