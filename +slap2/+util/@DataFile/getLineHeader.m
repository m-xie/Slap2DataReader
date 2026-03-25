function lineHeader = getLineHeader(obj, lineIdx, cycleIdx)
    assert(lineIdx >= 1 && lineIdx <= obj.header.linesPerCycle, ...
        'Invalid lineIdx: %d. Lines per cycle is %d', lineIdx, obj.header.linesPerCycle);
    assert(cycleIdx >= 1 && cycleIdx <= obj.numCycles, ...
        'Invalid cycleIdx: %d. Number of cycles in file is %d', cycleIdx, obj.numCycles);

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

    cycleOffset = (cycleIdx - 1) * obj.header.bytesPerCycle / 2;

    idx = obj.lineHeaderIdxs(lineIdx) + cycleOffset;
    idxs = idx + (0:obj.header.lineHeaderSizeBytes/2-1);

    if ~strcmpi(obj.rawData.Format,'int16')
        obj.rawData.Format = 'int16';
    end

    data = obj.rawData.Data(idxs);
    data = typecast(data,'uint8');
    
    if isfield(obj.metaData,'fpgaTimeReference')
        fpgaTimeReference = obj.metaData.fpgaTimeReference;
    else
        fpgaTimeReference = NaT;
    end

    lineHeader = obj.parseLineHeader( ...
        data,                          ...
        obj.header.fpgaSystemClock_Hz, ...
        obj.header.referenceTimestamp, ...
        fpgaTimeReference              ...
    );
end
