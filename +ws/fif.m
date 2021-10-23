function value=fif(test,true_value,false_value)
  % A handy function, like C's ?: operator 
  % Of course, in this version both trueValue and falseValue get evaluated,
  % so don't use if either will take a long time.
  if isscalar(test) ,
      % This is so fif(true,'true','false') yields 'true', for instance
      if test ,
          value=true_value;
      else
          value=false_value;
      end
  else
      % This is so we can use fif() when all args have the same size().
      value=true_value;
      value(~test)=false_value(~test);
  end
end
