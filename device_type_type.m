classdef device_type_type < double
   enumeration
      nidq (0)
      obx  (1)
      imec (2)
   end

   methods
       function result = char(device_type)
           switch device_type 
               case device_type_type.nidq ,
                   result = 'nidq' ;
               case device_type_type.obx ,
                   result = 'obx' ;
               case device_type_type.imec ,
                   result = 'imec' ;
           end
       end
   end
end
