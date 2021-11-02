function set_uicontrol_offset_bang(gh, offset)
    % Set the x,t position of a UI control without changing its size.
    % We assume the units are already set to pixels.
   
    % Get width, height
    original_position=get(gh,'Position');
    width = original_position(3) ;
    height = original_position(4) ;
    
    % Position
    new_position = [offset width height] ;
    set(gh, 'Position', new_position) ;
end
