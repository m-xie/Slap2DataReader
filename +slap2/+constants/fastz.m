classdef fastz
    properties (Constant, Hidden)
        decimalDigits = 3;
    end

    methods (Static)
        function val = coerce(val)
            %val = round(single(val),slap2.constants.fastz.decimalDigits);
            val = single(val);
            val = round(val * 2^slap2.constants.fastz.decimalDigits) * 2^-slap2.constants.fastz.decimalDigits;
        end
    end
end
