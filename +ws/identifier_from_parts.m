function result = identifier_from_parts(parts)
    % E.g. {'foo', 'bar', 'baz'} -> 'foo_bar_baz'
    if isempty(parts) ,
        result = '' ;
    elseif isscalar(parts) ,
        result = parts{1} ;
    else
        length_from_part_index = cellfun(@length, parts) ;
        part_count = length(parts) ;
        result_length = sum(length_from_part_index) + (part_count-1) ;
        result = repmat('_', [1 result_length]) ;
        offset = 0 ;
        for part_index = 1 : part_count ,
            part = parts{part_index} ;
            part_length = length_from_part_index(part_index) ;
            result(offset+1:offset+part_length) = part ;
            offset = offset + part_length + 1 ;
        end
    end
end
