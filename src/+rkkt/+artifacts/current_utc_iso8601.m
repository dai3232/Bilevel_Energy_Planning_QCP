function timestamp = current_utc_iso8601()
%CURRENT_UTC_ISO8601 Return an ISO-8601 UTC timestamp with milliseconds.

    timestamp = char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
