function result = putative_property_name_from_control(source)
    tag = source.Tag ;  % should be something like 'trigger_device_type_edit_'
    tag_parts = strsplit(tag, '_') ;
        % Should be something like 
        % [ {'trigger'}    {'device'}    {'type'} {'edit'}    {0×0 char} ]
    % Drop the last two parts
    property_name_parts = tag_parts(1:end-2) ;
    result = ws.identifier_from_parts(property_name_parts) ;
end
