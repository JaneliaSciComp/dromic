load  impose_refractory_period_test_data

is_event_from_scan_index_from_channel_index = is_event_from_scan_index_from_channel_index(4631:4670,:) 
result_from_scan_index_from_channel_index = ...
    impose_refractory_period(is_event_from_scan_index_from_channel_index, ...
                             refractory_scan_count, ...
                             initial_scans_since_last_event_from_channel_index)
assert(sum(result_from_scan_index_from_channel_index(:))==10)

                         