function fix_dialog_background_color_bang(fig, default_uicontrol_background_color)
    % Set the dialog background color (Matlab botches this for the Windows
    % 7 classic theme.)    
    set(fig,'Color', default_uicontrol_background_color) ;
    cmap = get(fig,'Colormap') ;  % empirically, the highest non-zero row of this corresponds to the BG color
    is_row_nonzero = any(cmap,2) ;
    last_nonzero_row_index = find(is_row_nonzero, 1, 'last') ;  % find last nonzero index
    if ~isempty(last_nonzero_row_index) ,
        cmap(last_nonzero_row_index,:) = default_uicontrol_background_color ;
        set(fig, 'Colormap', cmap) ;
    end
    kids = get(fig,'Children') ;
    for k = 1:length(kids) ,
        kid = kids(k) ;
        if ~isequal(get(kid,'Type'),'axes') ,            
            set(kid,'BackgroundColor', default_uicontrol_background_color) ;
        end
    end
end
