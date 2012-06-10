exports.parseFlags = (flagMode, flags) ->
    return [] unless flags
    
    switch flagMode
        when 'long' then flags.substr(i, 2) for i in [0...flags.length] by 2
        when 'num' then flags.split ','
        else flags.split ''