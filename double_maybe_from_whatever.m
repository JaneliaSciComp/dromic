function result = double_maybe_from_whatever(x, test, coerce)
    do_test_for_validity = ( exist('test', 'var') && ~isempty(test) ) ;
    do_coerce = ( exist('coerce', 'var') && ~isempty(coerce) ) ;
    if ischar(x) ,
        result = str2double(x) ;
        if isnan(result) ,
            result = [] ;
        end
    elseif isnumeric(x) ,
        result = double(x) ;
    else
        result = [] ;
    end
    if do_test_for_validity && ~isempty(result) ,
        is_valid = feval(test, result) ;
        if ~is_valid ,
            result = [] ;
        end
    end
    if do_coerce && ~isempty(result) ,
        result = feval(coerce, result) ;
    end
end
