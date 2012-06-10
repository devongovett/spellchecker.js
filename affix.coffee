{parseFlags} = require './shared'

class Affix
    constructor: (data) ->
        @lines = data.split('\n')
        @cur = 0
        
        @rules = {}
        @flags = {}
        @compoundRules = []
        @replacementTable = []
        @trystring = ''
        @keystring = 'qwertyuiop|asdfghjkl|zxcvbnm'
        @breakpoints = ['-']
        @breakpattern = /(^-)|(-$)/
        
        @rules = @parse(data)
        
    nextLine: ->
        len = @lines.length
        while @cur < len
            line = @lines[@cur++].replace(/#.*/g, '').trim() # remove comments and trim
            return line if line.length > 0                   # ignore blank lines
            
        return null
        
    parse: (data) ->
        rules = {}
        
        while line = @nextLine()
            parts = line.split /\s+/
            type = parts.shift()
            
            switch type
                when 'TRY'
                    @trystring = parts[0]
                    
                when 'KEY'
                    @keystring = parts[0]
            
                when 'PFX', 'SFX'
                    @parseRule(type, parts, rules)  
                                          
                when 'REP' 
                    @replacementTable.push [new RegExp(parts[0]), parts[1]] if parts.length is 2
                    
                when 'COMPOUNDRULE'
                    for i in [0...+parts[0]]
                        parts = @nextLine().split /\s+/
                        @compoundRules.push parts[1]
                        
                when 'BREAK'
                    num = +parts[0]
                    if num is 0
                        @breakpoints = @breakpattern = null
                        break
                        
                    @breakpoints = []
                    patterns = []
                    for i in [0...num]
                        pattern = @nextLine().split(/\s+/)[1]
                        if pattern[0] is '^' or pattern[pattern.length - 1] is '$'
                            patterns.push '(' + pattern + ')'
                        else
                            @breakpoints.push pattern
                            
                    @breakpattern = new RegExp(patterns.join '|')
                                                
                else
                    # ONLYINCOMPOUND
                    # COMPOUNDMIN
                    # FLAG
                    # KEEPCASE
                    # NEEDAFFIX

                    @flags[type] = parts[0]
                    
        return rules
        
    parseRule: (type, parts, rules) ->
        [code, combinable, count] = parts
        prefix = if type is 'PFX' then '^' else ''
        suffix = if type is 'SFX' then '$' else ''
        entries = []
            
        for i in [0...+count]
            parts = @nextLine().split /\s+/
            
            # string to strip or 0 for null 
            strip = parts[2]
            strip = '' if strip is '0'
            
            # affix string or 0 for null
            affix = parts[3].split '/'
            add = affix[0]
            add = '' if add is '0'
            
            continuation = parseFlags(@flags['FLAG'], affix[1])
            
            # the conditions descriptions
            regex = parts[4]
            
            entry = 
                add: new RegExp(prefix + add + suffix)
                remove: strip
                
            entry.continuation = continuation if continuation.length > 0
            entry.match = new RegExp(prefix + regex + suffix) unless regex is '.'
                                
            entries.push entry
            
        rules[code] = 
            type: type
            combinable: combinable is 'Y'
            entries: entries
            
    check: (word, dictionary) ->
        for code, rule of @rules
            for entry in rule.entries
                tmp = word.replace(entry.add, entry.remove)
                continue if tmp is word or entry.match?.test(tmp)
                words = dictionary.lookup(tmp)
                return true if words and code in words
                # continuation?
                
                # NEEDAFFIX
                
                # affix matched but no root word was found
                # check if the rule is continuable
                
        return false            
        
module.exports = Affix