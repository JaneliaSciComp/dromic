function result = parse_natural_number_set_spec(input_string)
    % E.g '0,4,5,7-9' -> [ 0 4 5 7 8 9 ]
    range_string_from_range_index = strsplit(input_string, ',') ;
      % We call each comma-separated thing a "range".  The first thing we do is
      % to break the input string into ranges
    result = zeros(1, 0) ;
    range_count = length(range_string_from_range_index) ;
    for range_index = 1 : range_count ,
        range_string = range_string_from_range_index{range_index} ;
        % Split on hyphens, call the results of this "range ends".
        % A range like '4' will have only one range end.
        % A range like '4-5' will have two range ends.
        range_end_from_end_index = strsplit(range_string, '-') ;
        end_count = length(range_end_from_end_index) ;
        if end_count == 0 ,
            error('parse_natural_number_set_spec:bad_range', ...
                  'The range ''%s'' within the set specification ''%s'' is not valid.', range_string, input_string) ;
        elseif end_count == 1 ,
            element_string = range_end_from_end_index{1} ;
            element = str2double(element_string) ;
            if isfinite(element) ,
                result = horzcat(result, element) ;  %#ok<AGROW>
            else
                error('parse_natural_number_set_spec:bad_range', ...
                      'The range ''%s'' within the set specification ''%s'' is not valid.', range_string, input_string) ;                
            end
        elseif end_count == 2 ,
            first_element_string = range_end_from_end_index{1} ;
            last_element_string = range_end_from_end_index{2} ;
            first_element = str2double(first_element_string) ;
            if ~isfinite(first_element) ,
                error('parse_natural_number_set_spec:bad_range', ...
                      'The range ''%s'' within the set specification ''%s'' is not valid.', range_string, input_string) ;                
            end
            last_element = str2double(last_element_string) ;
            if ~isfinite(last_element) ,
                error('parse_natural_number_set_spec:bad_range', ...
                      'The range ''%s'' within the set specification ''%s'' is not valid.', range_string, input_string) ;                
            end
            if first_element > last_element ,
                error('parse_natural_number_set_spec:bad_range', ...
                      'The range ''%s'' within the set specification ''%s'' is not valid.  The first element must less than or equal to the second.', ...
                      range_string, input_string) ;                
            end                
            range = first_element:last_element ;
            result = horzcat(result, range) ;  %#ok<AGROW>
        else
            error('parse_natural_number_set_spec:bad_range', ...
                  'The range ''%s'' within the set specification ''%s'' is not valid', range_string, input_string) ;
        end
    end
end
