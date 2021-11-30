function h = uipanel(varargin)
    % Like regular uipanel(), but sets a few things we want to be the same
    % in all WS windows, and different from the defaults.
    persistent default_uicontrol_background_color
   
    if isempty(default_uicontrol_background_color) ,
        default_uicontrol_background_color = ws.get_default_uicontrol_background_color() ;
    end
    
    h = uipanel(varargin{:}, ...
                'Units', 'pixels', ...
                'FontName', 'Tahoma', ...
                'FontSize', 8, ...
                'BackgroundColor', default_uicontrol_background_color ) ;
end
