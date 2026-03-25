function loadFileHeaderV2(obj)
    %% data format:
    %             uint32_t magic_start          = MAGIC_NUMBER;
    %             uint32_t file_version         = 1;
    %             uint32_t fileHeaderSize_Bytes = XXXX;
    %
    %             uint32_t fieldId  = XXXX;
    %             uint32_t fieldVal = XXXX;
    %             uint32_t fieldId  = XXXX;
    %             uint32_t fieldVal = XXXX;
    %
    %             ...
    %
    %             uint32_t magic_end           = MAGIC_NUMBER;

    if ~strcmpi(obj.rawData.Format,'uint32')
        obj.rawData.Format = 'uint32';
    end
    
    fileMagicNumber = obj.rawData.Data(1);
    assert(fileMagicNumber == obj.MAGIC_NUMBER, 'Data format error.');

    fileFormatVersion = obj.rawData.Data(2);
    assert(fileFormatVersion == 2, 'Unknown format version');

    fileHeaderSize_Bytes = obj.rawData.Data(3);
    fileHeaderEntries = fileHeaderSize_Bytes / 4;

    headerEndMagicNumber = obj.rawData.Data(fileHeaderEntries);
    assert(headerEndMagicNumber == obj.MAGIC_NUMBER, 'Data corruption in file header.');

    fieldValuePairs = obj.rawData.Data(4:(fileHeaderEntries - 1));
    fieldValuePairs = reshape(fieldValuePairs, 2, [])';

    header_ = translateFieldValuePairs(fieldValuePairs);
    header_ = translateChannelMask(header_);
    header_ = translateReferenceTimestamp(header_);
    header_.file_version = fileFormatVersion;
    header_.magic_start = fileMagicNumber;
    header_.magic_end = headerEndMagicNumber;

    obj.header = header_;

    fileSizeBytes = numel(obj.rawData.Data) * 4;
    obj.numCycles = floor(double(fileSizeBytes - header_.firstCycleOffsetBytes) / double(header_.bytesPerCycle));
    obj.totalNumLines = obj.numCycles * obj.header.linesPerCycle;
    obj.numChannels = double(obj.header.numChannels);
end

function header = translateChannelMask(header)
    assert(isfield(header, 'channelMask'));
    channels = bitget(header.channelMask, 1:32, 'uint32');
    channels = find(channels);
    header.channels = channels;

    assert(isfield(header, 'numChannels'));
    assert(numel(channels) == header.numChannels, 'Data integrity error: header field ''numChannels'' does not agree with header field ''channelMask''');
end

function header = translateReferenceTimestamp(header)
    if isfield(header,'referenceTimestamp_lower') && isfield(header,'referenceTimestamp_upper')
        referenceTimestamp_lower = bitshift(uint64(header.referenceTimestamp_lower), 0);
        referenceTimestamp_upper = bitshift(uint64(header.referenceTimestamp_upper),32);
        header.referenceTimestamp = bitor(referenceTimestamp_lower,referenceTimestamp_upper);
    end
end

function structOut = translateFieldValuePairs(fieldValuePairs)
    FileHeaderFields = [
        "firstCycleOffsetBytes"
        "lineHeaderSizeBytes"
        "laserPathIdx"
        "bytesPerCycle"
        "linesPerCycle"
        "superPixelsPerCycle"
        "dmdPixelsPerRow"
        "dmdPixelsPerColumn"
        "numChannels"
        "channelMask"
        "numSlices"
        "channelsInterleave"
        "fpgaSystemClock_Hz"
        "referenceTimestamp_lower"
        "referenceTimestamp_upper"
        ];

    map = containers.Map(0:numel(FileHeaderFields) - 1, FileHeaderFields);

    structOut = struct();
    for idx = 1:size(fieldValuePairs, 1)
        field = fieldValuePairs(idx, 1);
        value = fieldValuePairs(idx, 2);

        if map.isKey(field)
            field = map(field);
            structOut.(field) = double(value);
        else
            warning('Unknown field/value pair in header: fieldID=%d value=%d', field, value);
        end
    end
end
