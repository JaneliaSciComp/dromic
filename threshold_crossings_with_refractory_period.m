function result = threshold_crossings_with_refractory_period(x, threshold, refractory_scan_count, x_previous, scans_since_last_event)
    is_x_above_threshold = ([x_previous;x]>threshold) ;  % longer than x by 1, element 2 in this goes with element 1 of x
    is_rising_edge = is_x_above_threshold(2:end) & ~is_x_above_threshold(1:end-1) ;  % 1-to-1 with x
    result = impose_refractory_period(is_rising_edge, refractory_scan_count, scans_since_last_event) ;
end


function result_from_scan_index = impose_refractory_period(is_event_from_scan_index, refractory_scan_count, initial_scans_since_last_event)
    scans_since_last_event = initial_scans_since_last_event ;
    n = length(is_event_from_scan_index) ;
    result_from_scan_index = false(size(is_event_from_scan_index)) ;
    for i = 1 : n 
        % at this point, scans_since_last_event should be the
        % scans_since_last_event for scan i.  E.g. if the last event was at index
        % i-2, the scans since last event should be 2.
        is_event = is_event_from_scan_index(i) ;
        if is_event 
            if scans_since_last_event >= refractory_scan_count 
                result_from_scan_index(i) = true ;
                scans_since_last_event = 1 ;  % for the next scan, it will be 1 scan since the last event
            else
                % ignore this event, b/c it's within the refractory period
            end
        else
            scans_since_last_event = scans_since_last_event + 1 ;
        end
    end
end
