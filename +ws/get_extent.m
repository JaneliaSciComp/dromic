function [w,h]=get_extent(gh)
    raw_extent=get(gh,'Extent');
    w=raw_extent(3);
    h=raw_extent(4);
end
