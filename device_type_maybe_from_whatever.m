function result = device_type_maybe_from_whatever(x)
    if isa(x, 'device_type_type') ,
        result = {x} ;
    elseif ischar(x) ,
        switch x
            case 'nidq' ,
                result = {device_type_type.nidq} ;
            case 'obx' ,
                result = {device_type_type.obx} ;
            case 'imec' ,
                result = {device_type_type.imec} ;
            otherwise
                result = {} ;
        end
    else
        result = {} ;
   end
end

