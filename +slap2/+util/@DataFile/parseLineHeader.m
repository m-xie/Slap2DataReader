function lineHeader = parseLineHeader(data,fpgaSystemClock_Hz,referenceTimestamp,fpgaTimeReference)
    arguments
        data
        fpgaSystemClock_Hz = [];
        referenceTimestamp = [];
        fpgaTimeReference  = []; % datetime
    end

    %% lineHeaderFormat
    % bytes   0 1 2 3 4 5 6 7 
    %       0 l l l l m m m m 
    %       8 n n n n a a a a 
    %      16 f f f f x x y y 
    %      24 t t t t t t t t
    %      32 z z z z f f f f // optional

    % l .. (uint32) lineSizeBytes
    % m .. (uint32) magicNumber
    % n .. (uint32) lineNumber 
    % a .. (uint32) acqNumber
    % f .. (uint32) flags
    % x .. ( int16) xOffset_pix
    % y .. ( int16) yOffset_pix
    % t .. (uint64) timestamp
    % z .. ( float) zOffset_um
    % f .. ( float) zFeedback_um

    lineHeaderRaw = typecast(data,'uint8');

    lineHeader = struct();
    lineHeader.lineSizeBytes = double(typecast(lineHeaderRaw(01:04),'uint32'));
    lineHeader.magicNumber   = double(typecast(lineHeaderRaw(05:08),'uint32'));
    lineHeader.lineNumber    = double(typecast(lineHeaderRaw(09:12),'uint32'));
    lineHeader.acqNumber     = double(typecast(lineHeaderRaw(13:16),'uint32'));
    lineHeader.rawFlags      =        typecast(lineHeaderRaw(17:20),'uint32');
    lineHeader.xOffset_pix   = double(typecast(lineHeaderRaw(21:22),'int16'));
    lineHeader.yOffset_pix   = double(typecast(lineHeaderRaw(23:24),'int16'));
    lineHeader.timestamp     =        typecast(lineHeaderRaw(25:32),'uint64');

    assert(lineHeader.magicNumber == slap2.util.DataFile.MAGIC_NUMBER, ...
        'Corrupt data - Magic number was %04x. (Expected: %04x)', ... 
        lineHeader.magicNumber, ...
        slap2.util.DataFile.MAGIC_NUMBER ...
    );

    if numel(lineHeaderRaw) > 32
        lineHeader.zOffset_um   = typecast(lineHeaderRaw(33:36),'single');
        lineHeader.zFeedback_um = typecast(lineHeaderRaw(37:40),'single');
    else
        lineHeader.zOffset_um = 0;
        lineHeader.zFeedback_um = NaN;
    end

    lineHeader.flags = decodeFlags(lineHeader.rawFlags);

    [timestamp_s,timestamp_date] = decodeTimestamp(...
        lineHeader.timestamp, ...
        fpgaSystemClock_Hz,   ...
        referenceTimestamp,   ...
        fpgaTimeReference     ...
    );
    
    lineHeader.timestamp_s= timestamp_s;
    lineHeader.timestamp_date = timestamp_date;    
end

%% Local functions
function flags = decodeFlags(rawFlags)
    flags.startOfAcq   = bitget(rawFlags,1);
    flags.endOfAcq     = bitget(rawFlags,2);
    flags.startOfCycle = bitget(rawFlags,4);
    flags.endOfCylce   = bitget(rawFlags,5);
    flags.dmdSyncPin   = bitget(rawFlags,6);
    flags.syncPending  = bitget(rawFlags,7);
end

function [timestamp_s,timestamp_date] = decodeTimestamp(timestamp,fpgaSystemClock_Hz,referenceTimestamp,fpgaTimeReference)
    timestamp_s = NaN;
    timestamp_date = NaT;

    if isempty(referenceTimestamp) || isempty(fpgaSystemClock_Hz)
        return
    end
    
    timestamp_s = double(timestamp-referenceTimestamp) / double(fpgaSystemClock_Hz);

    if isempty(fpgaTimeReference) || isnat(fpgaTimeReference)
        return
    end

    secondsint  = seconds(idivide(timestamp,uint64(fpgaSystemClock_Hz)));
    secondsfrac = seconds(double(mod(timestamp,uint64(fpgaSystemClock_Hz))) / double(fpgaSystemClock_Hz));
    timestamp_date = (fpgaTimeReference + secondsint) + secondsfrac;
end
