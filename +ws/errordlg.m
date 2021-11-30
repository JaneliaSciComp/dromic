function fig = errordlg(varargin)
    % Like regular ws.errordlg(), but sets a few things we want to be the same
    % in all WS error dialogs, and different from the defaults.
    
    persistent default_uicontrol_background_color
   
    if isempty(default_uicontrol_background_color) ,
        default_uicontrol_background_color = ws.get_default_uicontrol_background_color() ;
    end
    
    % A lot of BS to make sure the background color works right for the
    % Windows 7 classic theme
    fig = errordlg(varargin{:}) ;
    ws.fix_dialog_background_color_bang(fig, default_uicontrol_background_color) ;
end
