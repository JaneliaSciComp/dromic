function result = threshold_crossings_with_refractory_period(x, threshold, crossing_sign, refractory_scan_count, ...
                                                             x_previous, scans_since_last_event_from_channel_index)
    if crossing_sign >= 0 ,
        is_x_past_threshold = ([x_previous;x]>threshold) ;  % longer than x by 1, element 2 in this goes with element 1 of x
    else
        is_x_past_threshold = ([x_previous;x]<threshold) ;  % longer than x by 1, element 2 in this goes with element 1 of x        
    end
    is_desired_edge = is_x_past_threshold(2:end,:) & ~is_x_past_threshold(1:end-1,:) ;  % 1-to-1 with x
    result = impose_refractory_period(is_desired_edge, refractory_scan_count, scans_since_last_event_from_channel_index) ;
end


