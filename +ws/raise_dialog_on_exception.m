function raise_dialog_on_exception(exception)
    indices_of_warning_phrase = strfind(exception.identifier,'ws:warnings_occurred') ;
    is_warning = (~isempty(indices_of_warning_phrase) && indices_of_warning_phrase(1)==1) ;
    if is_warning ,
        dialog_content_string = exception.message ;
        dialog_title_string = ws.fif(length(exception.cause)<=1, 'Warning', 'Warnings') ;
    else
        if isempty(exception.cause)
            dialog_content_string = exception.message ;
            dialog_title_string = 'Error' ;
        else
            primary_cause = exception.cause{1} ;
            if isempty(primary_cause.cause) ,
                dialog_content_string = sprintf('%s:\n%s',exception.message,primary_cause.message) ;
                dialog_title_string = 'Error' ;
            else
                secondary_cause = primary_cause.cause{1} ;
                dialog_content_string = sprintf('%s:\n%s\n%s', exception.message, primary_cause.message, secondary_cause.message) ;
                dialog_title_string = 'Error' ;
            end
        end            
    end
    ws.errordlg(dialog_content_string, dialog_title_string, 'modal') ;                
end  % method
