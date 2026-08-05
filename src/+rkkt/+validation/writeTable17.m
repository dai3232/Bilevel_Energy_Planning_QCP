function writeTable17(value,destination)
%WRITETABLE17 Write a validation CSV with stable numeric formatting.

arguments
    value table
    destination (1,1) string
end

rkkt.artifacts.write_table_csv_17g(destination,value);
end
