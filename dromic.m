function dc = dromic(kind_string)
    % if kind_string=='fake', use a fake spikegl
    if ~exist('kind_string', 'var') || isempty(kind_string) ,
        kind_string = '' ;
    end
    dc = dromic_controller(kind_string) ;
end
 