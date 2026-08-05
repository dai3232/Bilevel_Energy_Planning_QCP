function value = deterministicEqual(left,right)
%DETERMINISTICEQUAL Compare results after removing timing measurements.

value = isequaln(rkkt.validation.withoutTiming(left), ...
    rkkt.validation.withoutTiming(right));
end
