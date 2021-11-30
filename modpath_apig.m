function modpath()
    path_to_script = mfilename('fullpath') ;
    path_to_dromic_folder = fileparts(path_to_script) ;
%    path_to_parent_folder = fileparts(path_to_dromic_folder) ;
%     spikeglx_matlab_sdk_path = fullfile(path_to_parent_folder, 'MATLAB-SDK') ;
%     addpath(spikeglx_matlab_sdk_path) ;
%     addpath(fullfile(spikeglx_matlab_sdk_path, 'CalinsNetMex')) ;
    spikeglx_matlab_sdk_path = 'C:\Matlab' ;
    addpath(spikeglx_matlab_sdk_path) ;
    addpath(path_to_dromic_folder) ;    
end
