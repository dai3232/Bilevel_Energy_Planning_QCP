function digest = compute_stage_a4_rns1_fingerprint(value,kind)
%COMPUTE_STAGE_A4_RNS1_FINGERPRINT Hash frozen RNS state/linearization data.
%
% The serializer is deliberately narrow and deterministic.  It hashes the
% canonical numeric arrays used by A4-RNS-1 rather than MATLAB's internal
% struct byte stream.

arguments
    value (1,1) struct
    kind (1,1) string {mustBeMember(kind,["state","linearization"])}
end

messageDigest = java.security.MessageDigest.getInstance("SHA-256");
update_text(messageDigest,"A4-RNS-1|"+kind+"|v1");
switch kind
    case "state"
        update_state(messageDigest,value);
    case "linearization"
        required = ["identity","H","A","G","r_eq","r_ineq", ...
            "r_dual","r_comp","l","z","mu","state","objective", ...
            "constraints"];
        assert(all(isfield(value,required)), ...
            "stageA4:rns1:LinearizationFingerprintFields", ...
            "The RNS linearization fingerprint is missing required fields.");
        update_text(messageDigest,string(value.identity));
        update_numeric(messageDigest,value.H);
        update_numeric(messageDigest,value.A);
        update_numeric(messageDigest,value.G);
        update_numeric(messageDigest,value.constraints.eq_offset);
        update_numeric(messageDigest,value.constraints.ineq_offset);
        update_numeric(messageDigest,value.objective.gradient);
        update_numeric(messageDigest,value.r_eq);
        update_numeric(messageDigest,value.r_ineq);
        update_numeric(messageDigest,value.r_dual);
        update_numeric(messageDigest,value.r_comp);
        update_numeric(messageDigest,value.l);
        update_numeric(messageDigest,value.z);
        update_numeric(messageDigest,value.mu);
        update_state(messageDigest,value.state);
end
digestBytes = mod(double(messageDigest.digest()),256);
digest = lower(join(compose("%02x",digestBytes),""));
digest = reshape(digest,1,1);
end

function update_state(messageDigest,state)
required = ["xi","y","l","z","iteration_index","state_revision", ...
    "newton_direction_number","completed_newton_direction_count"];
assert(all(isfield(state,required)), ...
    "stageA4:rns1:StateFingerprintFields", ...
    "The RNS state fingerprint is missing required fields.");
for name = required
    update_text(messageDigest,name);
    update_numeric(messageDigest,state.(name));
end
end

function update_numeric(messageDigest,value)
assert(isnumeric(value) && isreal(value), ...
    "stageA4:rns1:FingerprintNumeric", ...
    "RNS fingerprints accept only real numeric arrays.");
update_text(messageDigest,string(class(value)));
update_uint64(messageDigest,uint64(size(value)));
update_uint64(messageDigest,uint64(issparse(value)));
if issparse(value)
    [row,column,entry] = find(value);
    update_uint64(messageDigest,uint64(numel(entry)));
    update_uint64(messageDigest,uint64(row));
    update_uint64(messageDigest,uint64(column));
    update_dense_numeric(messageDigest,entry);
else
    update_uint64(messageDigest,uint64(numel(value)));
    update_dense_numeric(messageDigest,value(:));
end
end

function update_dense_numeric(messageDigest,value)
switch class(value)
    case "double"
        bytes = typecast(value(:),"uint8");
    case "single"
        bytes = typecast(value(:),"uint8");
    case {"uint64","int64","uint32","int32","uint16","int16", ...
            "uint8","int8"}
        bytes = typecast(value(:),"uint8");
    otherwise
        error("stageA4:rns1:FingerprintNumericClass", ...
            "Unsupported numeric fingerprint class: %s.",class(value));
end
update_bytes(messageDigest,bytes);
end

function update_uint64(messageDigest,value)
update_bytes(messageDigest,typecast(value(:),"uint8"));
end

function update_text(messageDigest,value)
value = join(string(value(:)),"|");
bytes = unicode2native(char(value),"UTF-8");
update_uint64(messageDigest,uint64(numel(bytes)));
update_bytes(messageDigest,uint8(bytes));
end

function update_bytes(messageDigest,bytes)
if isempty(bytes)
    return
end
messageDigest.update(typecast(uint8(bytes(:)),"int8"));
end
