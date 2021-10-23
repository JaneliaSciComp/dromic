function device_type = device_type_from_string(str)
   switch str 
       case 'nidq' ,
           device_type = device_type_type.nidq ;
       case 'obx' ,
           device_type = device_type_type.obx ;
       otherwise
           device_type = device_type_type.imec ;
   end
end

