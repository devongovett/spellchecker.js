Affix = require './affix'
Dictionary = require './dictionary'

class SpellChecker
    constructor: (aff, dict) ->
        @affix = new Affix(aff)
        @dictionary = new Dictionary(@affix, dict)
        
    check: (word) ->
        word = word.trim()
        return false unless word.length
        
        # check if this is a number (allow dots, dashes and commas)
        # TODO: fix?
        return true if /(^\d)|(\d$)/.test(word)
        
        # check for an exact match
        return true if @checkWord word
        
        # check for abbreviations
        return true if (w = word.replace(/\.$/, '')) isnt word and @checkWord w
        
        # check breakpoints
        # make sure compound words like Afro-American pass
        if @affix.breakpoints and @affix.breakpattern
            # check boundary patterns (^begin and end$)
            w = word.replace(@affix.breakpattern, '')
            return true if @checkWord word
            
            # other patterns
            for breakpoint, i in @affix.breakpoints
                parts = w.split(breakpoint)
                return false for part in parts when not @checkWord part
                return true
        
        # no match
        return false
        
    checkWord: (word) ->
        # check for an exact match
        return true if @checkExact word
        
        # if all caps, try a titleized version
        if word is word.toUpperCase()
            w = word[0] + word.slice(1).toLowerCase()
            return false if @dictionary.hasFlag(w, 'KEEPCASE')
            return true if @checkExact w
        
        # if the word is mixed case, try a lower case version    
        if (w = word.toLowerCase()) isnt word
            return false if @dictionary.hasFlag(w, 'KEEPCASE')
            return true if @checkExact w
        
        # finally, try an upper case version
        w = word.toUpperCase()
        return false if @dictionary.hasFlag(w, 'KEEPCASE')
        return true if @checkExact w
        
        # no match   
        return false
            
    checkExact: (word) ->
        # ignored chars...
        
        return false unless word.length
        
        # TODO: implement complexprefixes
        
        # check for an exact match
        flags = @dictionary.lookup(word)
        if flags
            # check forbidden and onlyincompound words
            return false if @dictionary.hasFlag word, 'FORBIDDENWORD'
            return false if @dictionary.hasFlag word, 'NEEDAFFIX'
            return not @dictionary.hasFlag word, 'ONLYINCOMPOUND' # FIXME: not sure about this
        
        # try stripping off affixes
        root = @affix.check(word, @dictionary)
        if root
            # check compound restriction
            return not @dictionary.hasFlag word, 'ONLYINCOMPOUND'
            
        # TODO: try check compound word
        
        return false
        
    suggest: (word, limit = 5) ->
        word = word.trim()
        return [] if @check word
        
        # TODO: implement FORCEUCASE
                
        suggestions = []
        if word is word.toLowerCase()
            suggestions = @suggestions word
        
        else if word is word.toUpperCase()
            w = word.toLowerCase()
            
            # FIXME: not sure about this...
            if @affix.flags['KEEPCASE'] and @check w
                suggestions.push(w)
                
            w2 = w[0].toUpperCase() + w.slice(1)
            for suggestion, i in @suggestions(w).concat(@suggestions(w2))
                suggestions.push suggestion.toUpperCase()
                # TODO: implement CHECKSHARPS??
            
        else if word[0] is word[0].toUpperCase() and word.slice(1) is word.slice(1).toLowerCase()
            capitalize = true
            w = word.toLowerCase()
            suggestions = @suggestions(word).concat(@suggestions(w))
            
        else
            if word[0] is word[0].toUpperCase()
                capitalize = true
            
            # exact, mixed case suggestions
            suggestions = @suggestions(word)
            
            # something.The -> something. The
            w = word.replace(/([^\.]+\.)([A-Z])/g, '$1 $2')
            suggestions.push w if w isnt word
            
            # try lower case suggestions
            w = w.toLowerCase()
            unless @check w
                suggestions.push @suggestions(w)...
            
            # if the word is capitalized, make the rest of the
            # word lower case and try that 
            if capitalize
                w = w[0].toUpperCase() + w.slice(1)
                suggestions.push @suggestions(w)...
            
        # try ngram approach since found nothing or only compound words
        # if suggestions.length is 0
            # TODO: implement
            
        if capitalize
            for suggestion, i in suggestions
                suggestions[i] = suggestion[0].toUpperCase() + suggestion.slice(1)
            
        # try dash suggestion 
        # Afo-American -> Afro-American
        if ~word.indexOf('-')
            parts = word.split('-')
            for part, i in parts when not @checkExact part
                for suggestion in @suggest part
                    parts[i] = suggestion
                    suggestions.push(parts.join('-'))

                parts[i] = part
                
        # TODO: remove bad capitalized and forbidden forms
            
        # remove duplicate suggestions
        output = {}
        output[val] = val for val in suggestions
        
        # TODO: rank suggestions?

        # return the suggestions as an array
        (value for key, value of output).slice(0, limit)
        
    suggestions: (word) ->
        len = word.length
        suggestions = []
        
        # suggestions for an uppercase word (html -> HTML)
        corrected = word.toUpperCase()
        unless corrected is word
            suggestions.push(corrected) if @checkExact corrected
        
        # perhaps we made a typical fault of spelling
        # check replacement table
        for entry in @affix.replacementTable when entry[0].test(word)
            corrected = word.replace(entry[0], entry[1])
            suggestions.push(corrected) if @checkExact corrected
        
        # perhaps we made chose the wrong char from a related set
        # TODO: implement MAP table
        
        # did we swap the order of chars by mistake?
        # try swapping adjacent chars one by one
        for char, i in word when i < len - 1
            corrected = word.slice(0, i) + word[i + 1] + char + word.slice(i + 2)
            suggestions.push(corrected) if @checkExact corrected
            
        # try double swaps for short words
        # ahev -> have, owudl -> would
        if len in [4,5]
            corrected = word[1] + word[0] + word.slice(2, -2) + word[len - 1] + word[len - 2]
            suggestions.push(corrected) if @checkExact corrected
            
            if len is 5
                corrected = word[0] + word[2] + word[1] + word.slice(3)
                suggestions.push(corrected) if @checkExact corrected
            
        # did we swap the order of non adjacent chars by mistake
        # hlleo -> hello, lisence -> license
        for p, i in word
            for char, j in word when Math.abs(i - j) > 1
                corrected = word.slice(0, i) + char + word.slice(i + 1, j) + p + word.slice(j + 1)
                suggestions.push(corrected) if @checkExact corrected
                
        # did we just hit the wrong key in place of a good char (case and keyboard)
        # swap out each char one by one and try uppercase and neighbor
        # keyboard chars in its place to see if that makes a good word
        for char, i in word
            # check with uppercase letters
            # germany -> Germany
            if char isnt char.toUpperCase()
                corrected = word.slice(0, i) + char.toUpperCase() + word.slice(i + 1)
                suggestions.push(corrected) if @checkExact corrected
            
            # check neighbor characters in keyboard string
            # gello -> hello
            keys = @affix.keystring
            loc = keys.indexOf(char)
            break unless ~loc
            
            # check to the left
            if loc > 0 and keys[loc - 1] isnt '|'
                corrected = word.slice(0, i) + keys[loc - 1] + word.slice(i + 1)
                suggestions.push(corrected) if @checkExact corrected
                
            if (next = keys[loc + 1]) and next isnt '|'
                corrected = word.slice(0, i) + next + word.slice(i + 1)
                suggestions.push(corrected) if @checkExact corrected
        
        # did we add a char that should not be there
        # try omitting one char of word at a time
        # helllo -> hello
        for char, i in word
            corrected = word.slice(0, i) + word.slice(i + 1)
            suggestions.push(corrected) if @checkExact corrected
            
        # did we forgot a char
        # try inserting a tryme character before every letter (and the null terminator)
        # hllo -> hello
        for trychar in @affix.trystring
            for i in [0...len + 1]
                corrected = word.slice(0, i) + trychar + word.slice(i)
                suggestions.push(corrected) if @checkExact corrected
                
        # did we move a char
        # heoll -> hello
        for p in [0...len]
            for q in [p..len] when q - p > 2
                corrected = word.slice(0, p) + word.slice(p + 1, q) + word[p] + word.slice(q + 1)
                suggestions.push(corrected) if @checkExact corrected
                        
        # did we just hit the wrong key in place of a good char?
        # swap out each char one by one and try all the tryme
        # chars in its place to see if that makes a good word
        # ghone -> phone
        for trychar in @affix.trystring
            for i in [0...len] when trychar isnt word[i]
                corrected = word.slice(0, i) + trychar + word.slice(i + 1)
                suggestions.push(corrected) if @checkExact corrected
                
        # did we double two characters?
        # vacacation -> vacation
        if len >= 5
            corrected = word.replace(/(.{2})\1/g, '$1')
            suggestions.push(corrected) if @checkExact corrected
            
        # perhaps we forgot to hit space and two words ran together
        # split the string into two pieces after every char
        # if both pieces are good words make them a suggestion
        # helloworld -> "hello world"
        if len >= 3
            for i in [1...len]
                w1 = word.slice(0, i)
                w2 = word.slice(i)
                if @checkExact(w1) and @checkExact(w2)
                    suggestions.push(w1 + ' ' + w2)                
                    trystr = @affix.trystring
                    
                    # add two word suggestion with dash, if TRY string
                    # contains "a" or "-"
                    if ~trystr.indexOf('a') or ~trystr.indexOf('-')
                        suggestions.push(w1 + '-' + w2)
        
        return suggestions
        
module.exports = SpellChecker