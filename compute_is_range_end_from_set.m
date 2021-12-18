function result = compute_is_range_end_from_set(element_from_index)
    % set should be monotoically increasing
    delta_from_step_index = diff(element_from_index) ;
    is_gap_from_step_index = (delta_from_step_index>1) ;
    result = [is_gap_from_step_index true] | [true is_gap_from_step_index] ;
      % Elements on either side of a gap are range ends.
      % First and last element are also range ends.
end
