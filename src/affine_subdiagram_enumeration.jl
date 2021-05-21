
struct AllAffineOfRank
    das::DiagramAndSubs
    min::Int
    max::Int
    base::SBitSet{4}
    function AllAffineOfRank(das::DiagramAndSubs,min::Int,max::Int,base::SBitSet{4})
        @assert 1 ≤ min ≤ max ≤ das.d
        return new(das,min,max,base)
    end
end

function AllAffineOfRank(das,n)
    return IterTools.imap(x->x[1],AllAffineOfRank(das,n,n,SBitSet{4}()))
end

function AllAffineOfRank(das,min,max)
    return AllAffineOfRank(das,min,max,SBitSet{4}())
end

function Base.iterate(a::AllAffineOfRank)
    state = Stack{Tuple{SBitSet{4},SBitSet{4},Int,Int,Int},20}((a.base,boundary(a.das,a.base),length(a.base),1,1)) # Because we assume das.d ≤ 20 always!
    # TODO: If base is a valid diagram, also emit it
    
    return iterate(a,state)
end

function Base.iterate(a::AllAffineOfRank,state)
   
    das = a.das
    min = a.min
    max = a.max
    stack = state

    @label killbillvol2
    while !isempty(stack)

        (current_vertices,current_boundary,current_rank,start_rank,start_idx) = pop!(stack)

        @inbounds for piece_rank in start_rank:max-current_rank
            @inbounds for piece_idx in start_idx:length(das.connected_affine[piece_rank])
                piece = das.connected_affine[piece_rank][piece_idx]
                
                @tassert piece_rank == length(piece.vertices) - 1
                @tassert current_rank + piece_rank ≤ max
                
                if  piece.vertices ⟂ current_vertices && 
                    piece.boundary ⟂ current_vertices 
                    
                    new_vertices = piece.vertices ∪ current_vertices
                    new_boundary = ((piece.boundary ∩ ~current_vertices) ∪ (current_boundary ∩ ~piece.vertices))
                    new_rank = current_rank + piece_rank

                    (new_start_rank,new_start_idx) = piece_idx == length(das.connected_affine[piece_rank]) ? (piece_rank+1,1) : (piece_rank,piece_idx+1)

                    push!(stack, (current_vertices,current_boundary,current_rank,new_start_rank,new_start_idx))
                    new_rank ≠ max && push!(stack, (new_vertices,new_boundary,new_rank,new_start_rank,new_start_idx))
                    if min ≤ new_rank
                        return ((new_vertices,new_rank),stack)
                    else
                        @goto killbillvol2
                    end
                end
            end
            start_idx=1
        end 

    end


end

Base.IteratorEltype(::Type{AllAffineOfRank}) = Base.HasEltype() 
Base.eltype(::Type{AllAffineOfRank}) = Tuple{SBitSet{4},Int}
Base.IteratorSize(::Type{AllAffineOfRank}) = Base.SizeUnknown()

all_affine_of_rank(das::DiagramAndSubs,n::Int) = AllAffineOfRank(das,n) 
all_affine_of_rank(das::DiagramAndSubs,min::Int,max::Int) = AllAffineOfRank(das,min,max,SBitSet{4}())

"""
    all_affine_extend_well_safe(das)

Check that all affine diagram **of rank at least `2`** are contained in some affine diagram of rank `das.d-1`.
This is the “safe” version, in that the verification is done by first collecting all diagrams of  rank at least `2`, and storing the ones of rank `das.d-1`, and then checking containment for each.
"""
function all_affine_extend_well_safe(das)
    affine = SBitSet{4}[]
    affine_rank_dm = SBitSet{4}[]

    for (diag,rank) in AllAffineOfRank(das,1,das.d-1)
        rank ≥ 2 && push!(affine,diag)
        rank == das.d-1 && push!(affine_rank_dm, diag) 
    end
    
    for diag in affine

        if !any(diag ⊆ diag_dm for diag_dm in affine_rank_dm)
            return false
        end
    end
    return true
    
end

"""
    all_affine_extend_well(das)

Check that all affine diagram **of rank at least `2`** are contained in some affine diagram of rank `das.d-1`.
This is the “unsafe” version: it uses the iterator `AllAffineOfRank` and the fact that the iteration follows a kind of sawtooth pattern: 

    If the iterator yields `diagram[i]` and then `diagram[i+1]` (array notation used for convenience, both are bitsets representing the diagrams) and `diagram[i] ⊈ diagram[i+1]`, then any extension of `diagram[i]` must appear before step `i`, i.e. as some `diagram[j]` with `j<i`.  

Therefore, to check that all diagrams of rank at least `2` extend to one of rank `das.d-1`, we follow the iterator, store all diagrams of rank `das.d-1` we get, and everytime we have `diagram[i] ⊈ diagram[i+1]` and `2 ≤ rank(diagram[i]) ≠ das.d-1`, check that `diagram[i]` can be extended by one of the previously found diagrams of rank `das.d-1`: if not, this means we have found a non-extendable diagram; otherwise we continue.
"""
function all_affine_extend_well(das)

    affine_rank_dm = SBitSet{4}[]
    last_diag = nothing
    last_rank = nothing
    for (diag,rank) in AllAffineOfRank(das,1,das.d-1)

        if last_rank ≠ nothing && last_rank ≥ 2 && last_rank ≠ das.d-1 && !(last_diag ⊆ diag)
            if !any(last_diag ⊆ diag_dm for diag_dm in affine_rank_dm)
                return false
            end           
        end
        
        if rank == das.d-1
            push!(affine_rank_dm, diag)
            last_diag,last_rank = nothing,nothing
        else
            last_diag,last_rank = diag,rank
        end
        
    end
    if last_rank ≠ nothing && last_rank ≥ 2 && last_rank ≠ das.d-1
        if !any(last_diag ⊆ diag_dm for diag_dm in affine_rank_dm)
            return false
        end               
    end
    


    return true

end

struct AllAffineDirectExtensions
    das::DiagramAndSubs
    base::SBitSet{4}
end

function Base.iterate(a::AllAffineDirectExtensions)
    state = Stack{Tuple{SBitSet{4},SBitSet{4},SBitSet{4},Int,Int},20}((SBitSet{4}(),SBitSet{4}(),a.base,1,1)) # Because we assume das.d ≤ 20 always!
    
    return iterate(a,state)
end

function Base.iterate(a::AllAffineDirectExtensions,state)
   
    das = a.das
    stack = state

    @label killbillvol2
    while !isempty(stack)
    
        (current_vertices,current_boundary,remaining_vertices,start_rank,start_idx) = pop!(stack)
        if isempty(remaining_vertices) 
            return (current_vertices,stack)
        end

        @inbounds for piece_rank in start_rank:length(das.connected_affine)
            @inbounds for piece_idx in start_idx:length(das.connected_affine[piece_rank])
                piece = das.connected_affine[piece_rank][piece_idx]
                if  piece.vertices ⟂ current_vertices && 
                    piece.boundary ⟂ current_vertices &&
                    length(piece.vertices ∩ ~remaining_vertices) == 1 &&
                    piece.boundary ⟂ remaining_vertices
                    
                    new_vertices = piece.vertices ∪ current_vertices
                    new_boundary = ((piece.boundary ∩ ~current_vertices) ∪ (current_boundary ∩ ~piece.vertices))
                    new_remaining_vertices = remaining_vertices ∩ ~piece.vertices
                    
                    (new_start_rank,new_start_idx) = piece_idx == length(das.connected_affine[piece_rank]) ? (piece_rank+1,1) : (piece_rank,piece_idx+1)
                    push!(stack,(current_vertices,current_boundary,remaining_vertices,new_start_rank,new_start_idx))
                    push!(stack,(new_vertices,new_boundary,new_remaining_vertices,new_start_rank,new_start_idx))
                    @goto killbillvol2
                end
            end
            start_idx = 1
        end  
    end
end

Base.IteratorEltype(::Type{AllAffineDirectExtensions}) = Base.HasEltype() 
Base.eltype(::Type{AllAffineDirectExtensions}) = SBitSet{4}
Base.IteratorSize(::Type{AllAffineDirectExtensions}) = Base.SizeUnknown()

function all_affine_direct_extensions(das::DiagramAndSubs,vertices::SBitSet{4})
    
    return AllAffineDirectExtensions(das,vertices)

end

function number_affine_direct_extensions_but_at_most_n(das::DiagramAndSubs,vertices::SBitSet{4},n)
    num_exts = 0
    for ext in all_affine_direct_extensions(das,vertices)
        num_exts += 1
        num_exts ≥ n && return num_exts
    end
    return num_exts
end

#=

function all_affine_direct_extensions(das::DiagramAndSubs,vertices::SBitSet{4})
    
    diagrams_go_here = SBitSet{4}[]#Tuple{SBitSet{4},SBitSet{4}}[]
    _all_affine_direct_extensions__all_extensions(das,SBitSet{4}(),SBitSet{4}(),vertices,diagrams_go_here)
    return diagrams_go_here

end
function _all_affine_direct_extensions__all_extensions(
    das::DiagramAndSubs,
    current_vertices::SBitSet{4},
    current_boundary::SBitSet{4},
    remaining_vertices::SBitSet{4},
    diagrams_go_here::Vector{SBitSet{4}};
    start_rank=1,
    start_idx=1
)
    
    if isempty(remaining_vertices) 
        push!(diagrams_go_here,current_vertices)
        return
    end


    @inbounds for piece_rank in start_rank:length(das.connected_affine)
        @inbounds for piece_idx in start_idx:length(das.connected_affine[piece_rank])
            piece = das.connected_affine[piece_rank][piece_idx]
            if  isempty(piece.vertices∩current_vertices) && 
                isempty(piece.boundary∩current_vertices) &&
                length(piece.vertices ∩ ~remaining_vertices) == 1 &&
                isempty(piece.boundary ∩ remaining_vertices)
                
                new_vertices = piece.vertices ∪ current_vertices
                new_boundary = ((piece.boundary ∩ ~current_vertices) ∪ (current_boundary ∩ ~piece.vertices))
                new_remaining_vertices = remaining_vertices ∩ ~piece.vertices
                
                (new_start_rank,new_start_idx) = piece_idx == length(das.connected_affine[piece_rank]) ? (piece_rank+1,1) : (piece_rank,piece_idx+1)
                _all_affine_direct_extensions__all_extensions(das,new_vertices,new_boundary,new_remaining_vertices,diagrams_go_here,start_rank=new_start_rank,start_idx=new_start_idx)
            end
        end
        start_idx = 1
    end               
end
=#
