function result_from_scan_index_from_channel_index = ...
        impose_refractory_period(is_event_from_scan_index_from_channel_index, ...
                                 refractory_scan_count, ...
                                 initial_scans_since_last_event_from_channel_index)
                             
    scans_since_last_event_from_channel_index = initial_scans_since_last_event_from_channel_index ;  % row vector
    scan_count = size(is_event_from_scan_index_from_channel_index, 1) ;
    channel_count = size(is_event_from_scan_index_from_channel_index, 2) ;
    result_from_scan_index_from_channel_index = false(scan_count, channel_count) ;
    for channel_index = 1 : channel_count ,
        scans_since_last_event = scans_since_last_event_from_channel_index(channel_index) ;
        for scan_index = 1 : scan_count ,
            % at this point, scans_since_last_event should be the
            % scans_since_last_event for scan i.  E.g. if the last event was at index
            % i-2, the scans since last event should be 2.
            is_event = is_event_from_scan_index_from_channel_index(scan_index, channel_index) ;
            if is_event ,
                if scans_since_last_event >= refractory_scan_count ,
                    result_from_scan_index_from_channel_index(scan_index, channel_index) = true ;
                    scans_since_last_event = 1 ;  % for the next scan, it will be 1 scan since the last event
                else
                    % ignore this event, b/c it's within the refractory period
                end
            else
                scans_since_last_event = scans_since_last_event + 1 ;
            end
        end
    end
end
