function result = logical_maybe_from_whatever(x)
    if islogical(x) ,
        result = x ;
    elseif ischar(x) ,
        if strcmp(x, 'true') ,
            result = true ;
        elseif strcmp(x, 'false') ,
            result = false ;
        else
            result = logical([]) ;
        end
    elseif isnumeric(x) ,
        result = x ~= 0 ;
    else
        result = logical([]) ;
   end
end

