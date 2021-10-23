function result = device_type_from_whatever(x, fallback_value)
    if isa(x, 'device_type_type') ,
        result = x ;
    elseif ischar(x) ,
        switch str
            case 'nidq' ,
                result = device_type_type.nidq ;
            case 'obx' ,
                result = device_type_type.obx ;
            case 'imec' ,
                result = device_type_type.obx ;
            otherwise
                result = fallback_value ;
        end
    else
        result = 
   end
end

