classdef Totp
    %TOTP RFC 6238 time-based one-time password generation.

    methods (Static)
        function code = generate(base32Secret, options)
            arguments
                base32Secret (1, 1) string
                options.Time = datetime("now", "TimeZone", "UTC")
                options.Period (1, 1) double {mustBePositive, ...
                    mustBeInteger} = 30
                options.Digits (1, 1) double {mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.Digits, 6), ...
                    mustBeLessThanOrEqual(options.Digits, 8)} = 6
            end
            key = decodeBase32(base32Secret);
            if isempty(key)
                error("KSSOLV:Remote:TotpSecretEmpty", ...
                    "The TOTP secret must not be empty.");
            end
            instant = options.Time;
            if ~isdatetime(instant) || ~isscalar(instant) || isnat(instant)
                error("KSSOLV:Remote:TotpTimeInvalid", ...
                    "The TOTP time must be a scalar datetime.");
            end
            if strlength(instant.TimeZone) == 0
                instant.TimeZone = "UTC";
            end
            counter = uint64(floor(posixtime(instant) / options.Period));
            message = zeros(1, 8, "uint8");
            for index = 8:-1:1
                message(index) = uint8(bitand(counter, uint64(255)));
                counter = bitshift(counter, -8);
            end

            mac = javax.crypto.Mac.getInstance("HmacSHA1");
            keySpec = javax.crypto.spec.SecretKeySpec( ...
                typecast(uint8(key), "int8"), "HmacSHA1");
            mac.init(keySpec);
            digest = typecast(int8(mac.doFinal( ...
                typecast(message, "int8"))), "uint8");
            offset = bitand(digest(end), uint8(15));
            first = double(offset) + 1;
            binary = bitshift(uint32(bitand(digest(first), ...
                uint8(127))), 24);
            binary = bitor(binary, bitshift(uint32( ...
                digest(first + 1)), 16));
            binary = bitor(binary, bitshift(uint32( ...
                digest(first + 2)), 8));
            binary = bitor(binary, uint32(digest(first + 3)));
            modulus = uint32(10 ^ options.Digits);
            value = mod(binary, modulus);
            code = compose("%0" + options.Digits + "u", value);
        end
    end
end

function bytes = decodeBase32(value)
value = upper(regexprep(char(string(value)), '[\s=-]', ''));
alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
bytes = zeros(1, 0, "uint8");
buffer = uint32(0);
bitCount = 0;
for index = 1:numel(value)
    digit = find(alphabet == value(index), 1) - 1;
    if isempty(digit)
        error("KSSOLV:Remote:TotpSecretInvalid", ...
            "The TOTP secret is not valid Base32 text.");
    end
    buffer = bitor(bitshift(buffer, 5), uint32(digit));
    bitCount = bitCount + 5;
    if bitCount >= 8
        bitCount = bitCount - 8;
        bytes(end + 1) = uint8(bitand( ...
            bitshift(buffer, -bitCount), uint32(255))); %#ok<AGROW>
        if bitCount == 0
            buffer = uint32(0);
        else
            buffer = bitand(buffer, bitshift(uint32(1), bitCount) - 1);
        end
    end
end
end
