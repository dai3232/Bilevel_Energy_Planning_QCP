function value = matrixTable(matrixValue,rowVariableName)
%MATRIXTABLE Convert one small matrix to an indexed table.

dense = rkkt.validation.smallDense(matrixValue,16);
rowIndex = (1:size(dense,1)).';
names = [string(rowVariableName),compose("column_%02d",1:size(dense,2))];
value = array2table([rowIndex,dense],"VariableNames",cellstr(names));
end
