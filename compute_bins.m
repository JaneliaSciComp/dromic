function [bin_edges, bin_centers] = compute_bins(pre_trigger_duration, post_trigger_duration, bin_duration, do_center_bin_at_zero)
    peri_trigger_window_start = -pre_trigger_duration ;  % ms
    peri_trigger_window_end = +post_trigger_duration ;  % ms
    if do_center_bin_at_zero 
        max_edge_number = ceilhalf(peri_trigger_window_end/bin_duration) ;
        min_edge_number = floorhalf(peri_trigger_window_start/bin_duration) ;
    else
        max_edge_number = ceil(peri_trigger_window_end/bin_duration) ;
        min_edge_number = floor(peri_trigger_window_start/bin_duration) ;
    end
    bin_edges = bin_duration * (min_edge_number:max_edge_number) ;
    bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2 ;    
end
