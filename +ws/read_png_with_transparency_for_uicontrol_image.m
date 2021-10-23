function rgb_image = read_png_with_transparency_for_uicontrol_image(file_name)
    % Reads a PNG image in, and does some hocus-pocus so that the transparency works
    % right.  Returns an image suitable for setting as the value of a
    % uicontrol CData property.
    [raw_image, lut] = imread(file_name);
    if ndims(raw_image)==3 ,
        % Means a true-color image.  We use the convention that white==background
        image = double(raw_image)/255 ;  % convert form uint8 to default matlab RGB image
        is_background = all(image==1,3) ;  % all-white pels are taken as background, make pel slightly off-white if you want white
        is_background_full = repmat(is_background, [1 1 3]) ;
        rgb_image = ws.replace(image, is_background_full, nan) ;
        %rgbImage = image ;
        %rgbImage(isBackgroundFull) = NaN ;
    else
        % Indexed RGB.  For these, use older convention where all-black is taken as background.
        % (Can use very very dark gray if need black pels.)
        is_lut_entry_all_zeros = all(lut==0,2) ;
        lut(is_lut_entry_all_zeros,:) = nan ;  % This is interpreted as transparent, apparently
        rgb_image = ind2rgb(raw_image, lut);                          
    end
end
