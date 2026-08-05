function value = nowText()
%NOWTEXT Return the current Asia/Shanghai timestamp.

value = string(datetime("now","TimeZone","Asia/Shanghai", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
end
