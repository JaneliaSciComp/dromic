function position_edit_label_and_units_bang(label_gh,edit_gh,units_gh,edit_xoffset,edit_yoffset,edit_width,fixed_label_width)
    % Position the edit at the given position with the given width, and
    % position the label (a text uicontrol) and the units (ditto) on
    % either side.  We assume the units are already set to pixels.
    
    % Deal with optional args
    if nargin<7 || isempty(fixed_label_width) ,
        fixed_label_width = [] ;
    end
    
    % Constants
    width_from_label_to_edit=4;
    width_from_edit_to_units=3;
    label_shim_height=-4;
    units_shim_height=-4;
    text_pad=2;  % added to text X extent to get width
    
%     % Save current units
%     originalLabelUnits=get(labelGH,'Units');
%     originalEditUnits=get(editGH,'Units');
%     originalUnitsUnits=get(unitsGH,'Units');
% 
%     % Set units to pels
%     set(labelGH,'Units','pixels');
%     set(editGH,'Units','pixels');
%     set(unitsGH,'Units','pixels');

    % Get heights
    original_label_position=get(label_gh,'Position');
    label_height=original_label_position(4);
    original_edit_position=get(edit_gh,'Position');
    edit_height=original_edit_position(4);
    if isempty(units_gh) ,
        units_height=label_height;
    else
        original_units_position=get(units_gh,'Position');
        units_height=original_units_position(4);
    end

    % Position the edit itself
    set(edit_gh,'Position',[edit_xoffset edit_yoffset edit_width edit_height]) ;
    %           'BackgroundColor','w');
    
    % Position the label to the left of the edit
    label_extent_full=get(label_gh,'Extent');
    label_extent=label_extent_full(3:4);
    if isempty(fixed_label_width) ,
        label_width=label_extent(1)+text_pad;
    else
        label_width=fixed_label_width;
    end
    label_yoffset=edit_yoffset+label_shim_height;
    label_xoffset=edit_xoffset-label_width-width_from_label_to_edit;    
    set(label_gh,'Position',[label_xoffset label_yoffset label_width label_height], ...
                'HorizontalAlignment','right');
    
    % Position the units to the right of the edit
    if ~isempty(units_gh) ,
        units_extent_full=get(units_gh,'Extent');
        units_extent=units_extent_full(3:4);
        units_width=units_extent(1)+text_pad;
        units_yoffset=edit_yoffset+units_shim_height;
        units_xoffset=edit_xoffset+edit_width+width_from_edit_to_units;    
        set(units_gh,'Position',[units_xoffset units_yoffset units_width units_height], ...
                    'HorizontalAlignment','left');
    end
    
%     % Restore units
%     set(labelGH,'Units',originalLabelUnits);
%     set(editGH,'Units',originalEditUnits);
%     set(unitsGH,'Units',unitsUnitUnits);
end
