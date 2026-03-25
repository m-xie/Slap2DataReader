function loadFileHeader(obj)
    if ~strcmpi(obj.rawData.Format,'uint32')
        obj.rawData.Format = 'uint32';
    end

    fileMagicNumber = obj.rawData.Data(1);
    assert(fileMagicNumber == obj.MAGIC_NUMBER, 'Data format error. This is not a SLAP2 data file.');

    fileFormatVersion = obj.rawData.Data(2);
    assert(fileFormatVersion <= 2, 'Unknown format version');

    switch fileFormatVersion
        case 1
            error('Slap2DataFile:UnsupportedVersion', ...
                'File format version 1 is not supported by the cross-platform reader.');
        case 2
            loadFileHeaderV2(obj);
        otherwise
            error('Unknown file format version: %d', fileFormatVersion);
    end

    %% Load Indices
    if ~strcmpi(obj.rawData.Format,'int16')
        obj.rawData.Format = 'int16';
    end
    
    lineIdxs = zeros(obj.header.linesPerCycle, 1);
    lineSize_Bytes = zeros(obj.header.linesPerCycle, 1);
    lineIdxs(1) = obj.header.firstCycleOffsetBytes / 2 + 1;
    lineSize_Bytes(1) = typecast(obj.rawData.Data(lineIdxs(1) + [0 1]), 'uint32');

    for idx = 2:obj.header.linesPerCycle
        lineIdxs(idx) = lineIdxs(idx - 1) + lineSize_Bytes(idx - 1) / 2;
        lineSize_Bytes(idx) = typecast(obj.rawData.Data(lineIdxs(idx) + [0 1]), 'uint32');
    end

    obj.lineHeaderIdxs = lineIdxs;
    obj.lineDataStartIdxs = lineIdxs + obj.header.lineHeaderSizeBytes / 2;
    obj.lineDataNumElements = (lineSize_Bytes - obj.header.lineHeaderSizeBytes) / 2;

    if ~isfield(obj.header, 'referenceTimestamp')
        obj.header.referenceTimestamp = uint64(0);
        firstLineHeader = obj.getLineHeader(1,1);
        obj.header.referenceTimestamp = firstLineHeader.timestamp;
    end
end
