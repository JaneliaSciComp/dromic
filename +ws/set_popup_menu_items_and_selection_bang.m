function set_popup_menu_items_and_selection_bang(popup_gh, options, selection_as_string_or_cell_array, varargin)
    % Set popupGH String and Value to a "sanitized" version of
    % options.  selection is typically a string, with the empty string
    % representing no selection.  But selection can also be a cell array of
    % strings, with either zero elements or one element.  In this case, an
    % empty cell array reprents no selection.
    
    normal_background_color = ws.normal_background_color() ;
    warning_background_color = ws.warning_background_color() ;
        
    % If value is empty (e.g. the empty string), that gets treated as an
    % empty optional.
    % We call it "selections" b/c it's a list, even though it should always
    % have either zero elements or one element.
    if ischar(selection_as_string_or_cell_array) ,
        if isempty(selection_as_string_or_cell_array) ,
            selections = {} ;
        else
            selection = selection_as_string_or_cell_array ;
            selections = { selection } ;
        end
    else
        % presumably selectionOrSelections is a cell array
        selections = selection_as_string_or_cell_array ;
    end
    
    [menu_items, index_of_selected_menu_item, is_options_laden, is_selections_laden, is_selection_in_options] = ...
        ws.regularize_value_for_popup_menu(selections, options, varargin{:}) ;

    if is_options_laden && is_selections_laden && is_selection_in_options ,
        background_color = normal_background_color ;
    else
        background_color = warning_background_color ;
    end
    
    ws.setifhg(popup_gh, ...
                       'String',menu_items, ...
                       'Value',index_of_selected_menu_item, ...
                       'BackgroundColor',background_color);
    
end
