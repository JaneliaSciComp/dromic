function [menu_items, index_of_selected_menu_item, is_options_laden, is_selections_laden, is_selection_in_options] = ...
    regularize_value_for_popup_menu(selections, options, always_show_no_selection_item_in_menu, string_to_represent_no_options, string_to_represent_no_selection)

    % Given selections (a cell array of strings, *with either zero or one
    % element*) and a list of options (a cell array of strings, possibly
    % empty), returns a "sanitized" list of menuItems (a cell array of
    % strings, never empty), and an indexOfSelectedMenuItem, guaranteed to
    % be between 1 and length(menuItems).  If selections is nonempty
    % (a.k.a. "laden"), and selections{1} is an element of options, and
    % alwaysShowNoSelectionItemInMenu is false (or missing) then menuItems
    % will be equal to options, and menuItems{indexOfSelectedMenuItem} will
    % be equal to selections{1}. If this condition does not hold, then the
    % behavior is more complicated, but menuItems will never be empty, and
    % indexOfSelectedMenuItem will always point to an element of it.
    
    if ~exist('alwaysShowUnspecifiedItemInMenu','var') || isempty(always_show_no_selection_item_in_menu) ,
        always_show_no_selection_item_in_menu = false ;
    end
    
    if ~exist('stringToRepresentNoOptions','var') || isempty(string_to_represent_no_options) ,
        string_to_represent_no_options = '(No options)' ;
    end
    
    if ~exist('stringToRepresentNoSelection','var') || isempty(string_to_represent_no_selection) ,
        string_to_represent_no_selection = '(No selection)' ;
    end
    
    if isempty(options) ,
        is_options_laden = false ;
        if isempty(selections) ,
            is_selections_laden = false ;
            is_selection_in_options = true ;  % true b/c all values in selections are in options (!)
            menu_items = {string_to_represent_no_options} ;  % We could try to communicate that there is no selection either, but probably not worth it...  
            index_of_selected_menu_item = 1 ;
        else
            % In this case, there's a selection, but no options.
            is_selections_laden = true ;
            is_selection_in_options = false ;  % b/c options is empty
            selection = selections{1} ;  % do this just in case selections has more than one element
            menu_items = {selection} ;
            index_of_selected_menu_item = 1 ;  % the caller will hopefully use the fact that isSelectionInOptions == false to indicate that there's a problem
        end                
    else
        is_options_laden = true ;
        if isempty(selections) ,
            is_selections_laden = false ;
            is_selection_in_options = true ;  % true b/c all values in selections are in options (!)
            menu_items = [ {string_to_represent_no_selection} options ] ;
            index_of_selected_menu_item = 1 ;
        else
            is_selections_laden = true ;
            selection = selections{1} ;
            is_match = strcmp(selection,options) ;
            index_of_selection_in_options = find(is_match,1) ;    % if more than one match (WTF?), just use the first one
            if isempty(index_of_selection_in_options) ,
                % If no match, add the current item to the menu, but mark as as
                % invalid
                is_selection_in_options = false ;
                if always_show_no_selection_item_in_menu ,
                    menu_items = [ {string_to_represent_no_selection} {selection} options ] ;
                    index_of_selected_menu_item = 2 ;
                else
                    menu_items = [ {selection} options ] ;
                    index_of_selected_menu_item = 1 ;
                end
            else
                % If we get here, there's at least one match
                is_selection_in_options = true ;
                if always_show_no_selection_item_in_menu ,
                    menu_items = [ {string_to_represent_no_selection} options ];
                    index_of_selected_menu_item = index_of_selection_in_options + 1 ;
                else
                    menu_items = options ;
                    index_of_selected_menu_item = index_of_selection_in_options ;
                end
            end
        end
    end

end
