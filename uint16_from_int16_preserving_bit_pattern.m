function result = uint16_from_int16_preserving_bit_pattern(bits_as_int16)
    is_neg = (bits_as_int16<0) ;
    n = int32(bits_as_int16) ;
    result = uint16(bits_as_int16) ;
    result(is_neg) = uint16(n(is_neg)+65536) ;
end
