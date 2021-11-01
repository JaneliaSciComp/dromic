function result = double_maybe_from_whatever(x)
    if ischar(x) ,
        result = str2double(x) ;
        if isnan(result) ,
            result = [] ;
        end
    elseif isnumeric(x) ,
        result = double(x) ;
    else
        result = {} ;
   end
end

